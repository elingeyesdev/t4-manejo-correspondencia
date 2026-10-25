const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

test('consulta real por guía, estado, inexistencia y persistencia', async t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'consulta-guia-'));
  const legacy = { id: 'antiguo', guia: 'COR-2025-000001', remitente: 'Anterior', destinatario: 'Archivo', fecha: '2025-01-01', creadoEn: '2025-01-01T10:00:00.000Z' };
  fs.writeFileSync(path.join(dir, 'correspondencia.json'), JSON.stringify([legacy]));
  let child;
  async function start() {
    child = spawn(process.execPath, ['server.js'], { cwd: path.join(__dirname, '..'), env: { ...process.env, PORT: '0', DATA_DIR: dir }, stdio: ['ignore', 'pipe', 'pipe'] });
    return new Promise((resolve, reject) => {
      child.once('error', reject);
      child.once('exit', () => reject(new Error('Servidor cerrado antes de iniciar')));
      child.stdout.on('data', d => { const m = String(d).match(/localhost:(\d+)/); if (m) resolve(`http://127.0.0.1:${m[1]}`); });
    });
  }
  async function stop() { if (child && child.exitCode === null) { const exited = once(child, 'exit'); child.kill(); await exited; } }
  t.after(async () => { await stop(); fs.rmSync(dir, { recursive: true, force: true }); });
  let base = await start();
  let registered;
  await t.test('el backend registra el primer movimiento y no acepta estado inventado del cliente', async () => {
    const before = Date.now();
    const res = await fetch(base + '/api/correspondencia', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ remitente: 'Prueba remitente', destinatario: 'Prueba destinatario', fecha: '2026-10-15', estado: 'Entregado', fechaUltimoMovimiento: '2000-01-01' }) });
    assert.equal(res.status, 201);
    registered = await res.json();
    assert.equal(registered.estado, 'Registrado');
    assert.equal(registered.fechaUltimoMovimiento, registered.creadoEn);
    assert.ok(Date.parse(registered.fechaUltimoMovimiento) >= before);
    assert.ok(Date.parse(registered.fechaUltimoMovimiento) <= Date.now());
  });
  await t.test('consulta devuelve exactamente el registro persistido', async () => {
    const res = await fetch(base + '/api/correspondencia/guia/' + registered.guia);
    assert.equal(res.status, 200);
    const result = await res.json();
    const stored = JSON.parse(fs.readFileSync(path.join(dir, 'correspondencia.json'), 'utf8')).find(r => r.guia === registered.guia);
    assert.deepEqual(result, stored);
    const lower = await fetch(base + '/api/correspondencia/guia/' + registered.guia.toLowerCase());
    assert.equal(lower.status, 200);
  });
  await t.test('guía inexistente devuelve 404 identificable', async () => {
    const res = await fetch(base + '/api/correspondencia/guia/COR-9999-999999');
    assert.equal(res.status, 404);
    assert.equal((await res.json()).codigo, 'GUIA_NO_ENCONTRADA');
  });
  await t.test('guía vacía, codificación inválida y método incorrecto no se aceptan', async () => {
    for (const suffix of ['', '/', '/%20', '/%ZZ']) assert.equal((await fetch(base + '/api/correspondencia/guia' + suffix)).status, 400);
    assert.equal((await fetch(base + '/api/correspondencia/guia/' + registered.guia, { method: 'POST' })).status, 405);
  });
  await t.test('registros antiguos no obtienen estados ni movimientos ficticios', async () => {
    const res = await fetch(base + '/api/correspondencia/guia/' + legacy.guia);
    assert.equal(res.status, 409);
    assert.equal((await res.json()).codigo, 'SEGUIMIENTO_NO_DISPONIBLE');
    const stored = JSON.parse(fs.readFileSync(path.join(dir, 'correspondencia.json'), 'utf8'))[0];
    assert.deepEqual(stored, legacy);
  });
  await t.test('consulta conserva estado y fecha exactos después de reiniciar', async () => {
    await stop(); base = await start();
    const res = await fetch(base + '/api/correspondencia/guia/' + registered.guia);
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), registered);
  });
});
