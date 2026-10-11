const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const url = process.env.FULFILLMENT_TEST_URL;

test('standalone service rejects missing/forged identity and malformed HTTP requests', { skip: !url }, async () => {
  for (const authorization of [undefined, 'Bearer forged-token']) {
    const response = await fetch(url, {
      method: 'POST', headers: { 'Content-Type': 'application/json', ...(authorization ? { Authorization: authorization } : {}) },
      body: JSON.stringify({ data: { action: 'registerCourier', uid: 'forged-uid', name: 'Fake', phone: '+919876543210', vehicle: 'Car' } }),
    });
    assert.equal(response.status, 401);
    assert.equal((await response.json()).error.status, 'UNAUTHENTICATED');
  }
  const spoof = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ data: { action: 'nearby' }, auth: { uid: 'forged-uid' } }) });
  assert.equal(spoof.status, 400);
  for (const body of ['not json', JSON.stringify({ data: 'x'.repeat(70000) })]) {
    const response = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body });
    assert.equal(response.status, 400);
    assert.equal((await response.json()).error.status, 'INVALID_ARGUMENT');
  }
  assert.equal((await fetch(url)).status, 400);
  const health = await fetch(new URL('/healthz', url));
  assert.equal(health.headers.get('cache-control'), 'no-store');
  assert.equal(health.headers.get('x-powered-by'), null);
  assert.deepEqual(await health.json(), { status: 'ok' });
});

test('production startup refuses emulator authentication bypass settings', () => {
  const result = spawnSync(process.execPath, ['-e', "require('./functions/server').createApp()"], {
    env: { ...process.env, NODE_ENV: 'production', FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9199' }, encoding: 'utf8',
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Emulator configuration is forbidden/);
});
