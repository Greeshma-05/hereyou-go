// Local preview only. --emulator uses isolated Firebase emulators for browser QA.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../dist');
const emulator = process.argv.includes('--emulator');
const port = Number(process.env.ADMIN_PREVIEW_PORT || 4173);
http.createServer((req, res) => {
  const pathname = new URL(req.url, 'http://localhost').pathname;
  if (emulator && pathname === '/config.js') {
    res.setHeader('Content-Type', 'text/javascript'); res.setHeader('Cache-Control', 'no-store');
    return res.end("export const firebaseConfig={apiKey:'emulator-key',projectId:'demo-route-rescue',authDomain:'demo-route-rescue.firebaseapp.com',appId:'preview-admin'};export const endpoint='http://127.0.0.1:10000/fulfillment';export const authEmulator='http://127.0.0.1:9199';");
  }
  const file = path.resolve(root, '.' + decodeURIComponent(pathname === '/' ? '/index.html' : pathname));
  if (!file.startsWith(root + path.sep)) { res.writeHead(403); return res.end(); }
  fs.readFile(file, (error, data) => {
    if (error) { res.writeHead(404); return res.end('Not found'); }
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Content-Type', ({ '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml' })[path.extname(file)] || 'application/octet-stream');
    res.end(data);
  });
}).listen(port, '127.0.0.1', () => console.log(`Local: http://127.0.0.1:${port}${emulator ? ' (isolated emulator data)' : ''}`));
