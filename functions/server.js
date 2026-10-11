'use strict';
// Host the same authenticated callable protocol on any Node.js web server.
// Firebase Auth, Firestore transactions and access rules stay unchanged.
const express = require('express');
const { readFileSync } = require('node:fs');

function createApp() {
  if (process.env.NODE_ENV === 'production') {
    if (Object.keys(process.env).some(key => /EMULATOR/.test(key) && process.env[key])) {
      throw new Error('Emulator configuration is forbidden in production.');
    }
    if (!process.env.GOOGLE_CLOUD_PROJECT) {
      throw new Error('Set GOOGLE_CLOUD_PROJECT before starting the order service.');
    }
    const credentialPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (!credentialPath) throw new Error('Configure the server-only GOOGLE_APPLICATION_CREDENTIALS secret file.');
    let credential;
    try { credential = JSON.parse(readFileSync(credentialPath, 'utf8')); }
    catch { throw new Error('The server service-account secret file is missing or invalid.'); }
    if (credential.type !== 'service_account' || credential.project_id !== process.env.GOOGLE_CLOUD_PROJECT || !credential.private_key || !credential.client_email) {
      throw new Error('The server service-account secret must match GOOGLE_CLOUD_PROJECT.');
    }
  }
  const { fulfillment } = require('./index');
  const app = express();
  app.disable('x-powered-by');
  app.use((_req, res, next) => {
    res.set('Cache-Control', 'no-store');
    res.set('X-Content-Type-Options', 'nosniff');
    next();
  });
  app.get('/healthz', (_req, res) => res.json({ status: 'ok' }));
  app.use('/fulfillment', express.json({ limit: '64kb' }));
  // onCall verifies the Firebase ID token, then dispatch derives the UID from
  // that verified identity. Never use fulfillment.run() here: it skips auth.
  app.all('/fulfillment', fulfillment);
  app.use((_req, res) => res.status(404).json({ error: { status: 'NOT_FOUND', message: 'Endpoint not found.' } }));
  app.use((err, _req, res, _next) => {
    const malformed = err.type === 'entity.parse.failed' || err.type === 'entity.too.large';
    res.status(malformed ? 400 : 500).json({ error: {
      status: malformed ? 'INVALID_ARGUMENT' : 'INTERNAL',
      message: malformed ? 'Send a valid JSON request smaller than 64 KB.' : 'The order service could not complete this request.',
    } });
  });
  return app;
}

if (require.main === module) {
  const port = Number(process.env.PORT || 10000);
  const server = createApp().listen(port, '0.0.0.0', () => console.log(`Order service listening on port ${port}`));
  server.requestTimeout = 30000;
  server.headersTimeout = 15000;
  const shutdown = () => {
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10000).unref();
  };
  process.once('SIGTERM', shutdown);
  process.once('SIGINT', shutdown);
}
module.exports = { createApp };
