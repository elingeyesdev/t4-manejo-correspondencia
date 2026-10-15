const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');

const dataDir = process.env.DATA_DIR || path.join(__dirname, 'data');
const file = path.join(dataDir, 'correspondencia.json');
fs.mkdirSync(dataDir, { recursive: true });
let records = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : [];
function send(res, status, data) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(data));
}
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/api/correspondencia') {
    if (req.method === 'GET') return send(res, 200, records.slice().reverse());
    if (req.method !== 'POST') return send(res, 405, { error: 'Método no permitido.' });
    try {
      let body = '';
      for await (const chunk of req) {
        body += chunk;
        if (Buffer.byteLength(body) > 16384) return send(res, 413, { error: 'Solicitud demasiado grande.' });
      }
      let input;
      try { input = JSON.parse(body); } catch { return send(res, 400, { error: 'El contenido debe ser JSON válido.' }); }
      if (!input || typeof input !== 'object' || Array.isArray(input)) return send(res, 400, { error: 'Datos no válidos.' });
      const errors = {};
      for (const field of ['remitente', 'destinatario', 'fecha']) {
        if (typeof input[field] !== 'string' || !input[field].trim()) errors[field] = 'Este campo es obligatorio.';
      }
      for (const field of ['remitente', 'destinatario']) {
        if (typeof input[field] === 'string' && input[field].trim().length > 150) errors[field] = 'Máximo 150 caracteres.';
      }
      if (!errors.fecha && (!/^\d{4}-\d{2}-\d{2}$/.test(input.fecha) || !Number.isFinite(Date.parse(input.fecha)) || new Date(input.fecha).toISOString().slice(0, 10) !== input.fecha)) errors.fecha = 'Ingresa una fecha válida.';
      if (input.asunto !== undefined && (typeof input.asunto !== 'string' || input.asunto.length > 500)) errors.asunto = 'El asunto debe tener hasta 500 caracteres.';
      if (Object.keys(errors).length) return send(res, 400, { error: 'Revisa los campos del formulario.', errors });
      const record = { id: randomUUID(), guia: `COR-${input.fecha.slice(0, 4)}-${String(records.length + 1).padStart(6, '0')}`, remitente: input.remitente.trim(), destinatario: input.destinatario.trim(), fecha: input.fecha, asunto: (input.asunto || '').trim(), creadoEn: new Date().toISOString() };
      const next = [...records, record];
      fs.writeFileSync(file + '.tmp', JSON.stringify(next, null, 2), 'utf8');
      fs.renameSync(file + '.tmp', file);
      records = next;
      return send(res, 201, record);
    } catch (error) {
      console.error(error.message);
      return send(res, 500, { error: 'No se pudo guardar el registro. Intenta nuevamente.' });
    }
  }
  if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/index.html')) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'X-Content-Type-Options': 'nosniff' });
    return fs.createReadStream(path.join(__dirname, 'public', 'index.html')).pipe(res);
  }
  return send(res, 404, { error: 'Recurso no encontrado.' });
});
server.listen(Number(process.env.PORT || 3000), '127.0.0.1', () => console.log(`Correspondencia disponible en http://localhost:${server.address().port}`));
