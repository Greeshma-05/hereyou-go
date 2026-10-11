'use strict';
const { spawn } = require('node:child_process');
const { readdirSync } = require('node:fs');
if (!process.env.FIREBASE_AUTH_EMULATOR_HOST || !process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Run through npm run test:standalone; never run these fixtures against production.');
}
process.env.GCLOUD_PROJECT = process.env.GOOGLE_CLOUD_PROJECT = 'demo-route-rescue';
process.env.NODE_ENV = 'test';
const { createApp } = require('../functions/server');
const server = createApp().listen(0, '127.0.0.1', () => {
  const files = readdirSync('test/firebase').filter(name => name.endsWith('.test.cjs')).map(name => `test/firebase/${name}`);
  const child = spawn(process.execPath, ['--test', '--test-concurrency=1', ...files], {
    stdio: 'inherit',
    env: { ...process.env, FULFILLMENT_TEST_URL: `http://127.0.0.1:${server.address().port}/fulfillment` },
  });
  child.on('exit', code => server.close(() => process.exit(code ?? 1)));
  child.on('error', () => server.close(() => process.exit(1)));
});
