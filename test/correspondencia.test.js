const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

test('registro: validación, guías únicas, listado y persistencia al reiniciar', async t => {
 const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'correspondencia-test-'));
 let child;
 async function start() {
  child = spawn(process.execPath, ['server.js'], { cwd: path.join(__dirname, '..'), env: { ...process.env, PORT: '0', DATA_DIR: dir }, stdio: ['ignore', 'pipe', 'pipe'] });
  return await new Promise((resolve, reject) => { child.once('error', reject); child.stderr.on('data', d => reject(new Error(String(d)))); child.stdout.on('data', d => { const match = String(d).match(/http:\/\/localhost:(\d+)/); if (match) resolve(`http://127.0.0.1:${match[1]}`); }); });
 }
 async function stop() { const exited=once(child,'exit');child.kill();await exited; }
 t.after(async()=>{if(child&&child.exitCode===null)await stop();fs.rmSync(dir,{recursive:true,force:true});});
 let base = await start();
 const post = input => fetch(base+'/api/correspondencia',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(input)});
 await t.test('rechaza campos vacíos sin consumir guías',async()=>{for(const input of [{},{remitente:' ',destinatario:'Unidad A',fecha:'2026-10-15'},{remitente:'Ana',destinatario:'',fecha:'2026-10-15'}]){const response=await post(input);assert.equal(response.status,400);}assert.deepEqual(await (await fetch(base+'/api/correspondencia')).json(),[]);});
 await t.test('rechaza fechas inexistentes y entradas mal formadas',async()=>{assert.equal((await post({remitente:'Ana',destinatario:'Unidad A',fecha:'2026-02-30'})).status,400);assert.equal((await post(null)).status,400);assert.equal((await fetch(base+'/api/correspondencia',{method:'POST',body:'{'})).status,400);});
 const input={remitente:'  Alcaldía  ',destinatario:'Secretaría',fecha:'2026-10-15',asunto:'Solicitud de informe'};
 let first;
 await t.test('registra y genera guía en el servidor',async()=>{const response=await post({...input,guia:'MANIPULADA'});assert.equal(response.status,201);first=await response.json();assert.equal(first.guia,'COR-2026-000001');assert.equal(first.remitente,'Alcaldía');});
 await t.test('solicitudes simultáneas producen guías diferentes',async()=>{const responses=await Promise.all(Array.from({length:5},()=>post(input)));assert.ok(responses.every(r=>r.status===201));const rows=await Promise.all(responses.map(r=>r.json()));assert.equal(new Set(rows.map(r=>r.guia)).size,5);});
 await t.test('lista los seis documentos, más recientes primero',async()=>{const rows=await (await fetch(base+'/api/correspondencia')).json();assert.equal(rows.length,6);assert.equal(rows.at(-1).id,first.id);});
 await t.test('conserva registros y secuencia después de reiniciar',async()=>{await stop();base=await start();const rows=await (await fetch(base+'/api/correspondencia')).json();assert.equal(rows.length,6);const next=await (await post(input)).json();assert.equal(next.guia,'COR-2026-000007');});
 await t.test('sirve la interfaz y devuelve 404 para rutas desconocidas',async()=>{const page=await fetch(base);assert.equal(page.status,200);assert.match(await page.text(),/Registro de correspondencia/);assert.equal((await fetch(base+'/inexistente')).status,404);});
});
