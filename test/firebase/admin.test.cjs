const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { createHash } = require('node:crypto');
const { initializeTestEnvironment, assertFails } = require('@firebase/rules-unit-testing');
const { initializeApp, deleteApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, createUserWithEmailAndPassword } = require('firebase/auth');
const { getFirestore, connectFirestoreEmulator, doc, setDoc, getDoc, updateDoc, Timestamp } = require('firebase/firestore');
const { getFunctions, connectFunctionsEmulator, httpsCallable, httpsCallableFromURL } = require('firebase/functions');
const projectId = 'demo-route-rescue';
let env, owner, other, unverified;
const apps = [];
async function client(name, verified = true) {
  const app = initializeApp({ projectId, apiKey: 'emulator-key', appId: `test-${name}` }, `${name}-${Date.now()}`);
  apps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`, { disableWarnings: true });
  const email = `${name}-${Date.now()}@example.test`;
  const user = (await createUserWithEmailAndPassword(auth, email, 'Test-password-123')).user;
  if (verified) {
    const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:update?key=emulator-key`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' }, body: JSON.stringify({ localId: user.uid, emailVerified: true }) });
    assert.equal(response.status, 200);
    await user.getIdToken(true);
  }
  const db = getFirestore(app), [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  connectFirestoreEmulator(db, host, Number(port));
  const functions = getFunctions(app, 'asia-south1');
  if (!process.env.FULFILLMENT_TEST_URL) connectFunctionsEmulator(functions, '127.0.0.1', 5101);
  const call = process.env.FULFILLMENT_TEST_URL ? httpsCallableFromURL(functions, process.env.FULFILLMENT_TEST_URL) : httpsCallable(functions, 'fulfillment');
  return { uid: user.uid, email, db, user, call: async (action, data = {}) => (await call({ action, ...data })).data };
}
before(async () => {
  env = await initializeTestEnvironment({ projectId, firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') } });
  owner = await client('admin'); other = await client('ordinary'); unverified = await client('unverified', false);
});
after(async () => { await Promise.all(apps.map(deleteApp)); await env.cleanup(); });
const admin = fn => env.withSecurityRulesDisabled(c => fn(c.firestore()));
const invitePath = c => `adminInvites/${createHash('sha256').update(c.email).digest('hex')}`;
beforeEach(async () => {
  await env.clearFirestore();
  await admin(async db => {
    await setDoc(doc(db, invitePath(owner)), { email: owner.email, enabled: true });
    await setDoc(doc(db, invitePath(unverified)), { email: unverified.email, enabled: true });
  });
});
test('only the invited verified identity can activate admin; ordinary accounts and unverified emails are rejected', async () => {
  for (const c of [owner, other, unverified]) await assert.rejects(c.call('adminDashboard'), e => e.code === 'functions/permission-denied');
  await assert.rejects(other.call('adminClaimAccess'), e => e.code === 'functions/permission-denied');
  await assert.rejects(unverified.call('adminClaimAccess'), /Verify/);
  const role = await owner.call('adminClaimAccess');
  assert.equal(role.uid, owner.uid); assert.equal(role.role, 'superadmin');
  assert.equal((await owner.call('adminSession')).email, owner.email);
  await assertFails(setDoc(doc(other.db, `adminAccess/${other.uid}`), { role: 'superadmin', enabled: true, email: other.email }));
  await assertFails(setDoc(doc(other.db, invitePath(other)), { enabled: true, email: other.email }));
  await assertFails(getDoc(doc(owner.db, invitePath(owner))));
  await assertFails(setDoc(doc(owner.db, 'adminActivity/forged'), { type: 'orderCreated' }));
});
test('revocation is immediate and cannot be undone by claiming the original invitation again', async () => {
  await owner.call('adminClaimAccess');
  await admin(db => updateDoc(doc(db, `adminAccess/${owner.uid}`), { enabled: false }));
  await assert.rejects(owner.call('adminDashboard'), e => e.code === 'functions/permission-denied');
  await assert.rejects(owner.call('adminClaimAccess'), e => e.code === 'functions/permission-denied');
});
test('admin queries are bounded, paginated without timestamp rounding, and never expose private handover codes', async () => {
  await owner.call('adminClaimAccess');
  await admin(async db => {
    for (const [id, ns] of [['a', 901000], ['b', 900000], ['c', 900000]]) await setDoc(doc(db, `orders/${id}`), {
      reference: id, status: 'placed', totalPaise: 5000, customerUid: 'customer', vendorId: 'vendor',
      verificationCode: '9999', privateToken: 'hidden', items: [{ quantity: 1, product: { name: 'Water', pricePaise: 2000, privateToken: 'hidden' } }],
      createdAt: new Timestamp(1700000000, ns),
    });
    await setDoc(doc(db, 'orderSecrets/a'), { verificationCode: '9999' });
    await setDoc(doc(db, 'users/customer'), { displayName: 'Customer', email: 'customer@example.test', password: 'hidden' });
  });
  const first = await owner.call('adminList', { kind: 'orders', pageSize: 1 });
  const second = await owner.call('adminList', { kind: 'orders', pageSize: 1, cursor: first.nextCursor });
  const third = await owner.call('adminList', { kind: 'orders', pageSize: 1, cursor: second.nextCursor });
  assert.deepEqual([first, second, third].map(p => p.items[0].id), ['a', 'c', 'b']);
  assert.equal(third.nextCursor, null);
  assert.equal(first.items[0].verificationCode, undefined);
  const detail = await owner.call('adminDetail', { kind: 'orders', id: 'a' });
  assert.equal(detail.customer.displayName, 'Customer');
  assert.ok(!JSON.stringify(detail).includes('hidden')); assert.ok(!JSON.stringify(detail).includes('9999'));
  for (const data of [{ kind: 'orderSecrets' }, { kind: 'orders', pageSize: 101 }, { kind: 'orders', cursor: { id: '../secrets' } }, { kind: 'orders', status: 'fake' }, { kind: 'products', vendorId: '../x' }]) await assert.rejects(owner.call('adminList', data), e => e.code === 'functions/invalid-argument');
});
test('dashboard totals and delivered order value reflect persisted data; GPS availability distinguishes stale, busy and offline', async () => {
  await owner.call('adminClaimAccess');
  await admin(async db => {
    for (const [id, status] of [['a', 'placed'], ['b', 'handedOver'], ['c', 'cancelled']]) await setDoc(doc(db, `orders/${id}`), { reference: id, status, totalPaise: 5000, createdAt: Timestamp.now() });
    for (const [id, patch] of [['fresh', {}], ['stale', { location: { latitude: 9, longitude: 76, accuracy: 10, recordedAt: Timestamp.fromMillis(Date.now() - 100000) } }], ['offline', { online: false }], ['busy', { activeOrderId: 'a' }]]) await setDoc(doc(db, `couriers/${id}`), { name: id, online: true, activeOrderId: null, location: { latitude: 9, longitude: 76, accuracy: 10, recordedAt: Timestamp.now() }, ...patch });
  });
  const result = await owner.call('adminDashboard');
  assert.equal(result.counts.orders, 3); assert.equal(result.counts.activeOrders, 1); assert.equal(result.deliveredValuePaise, 5000);
  const couriers = await owner.call('adminList', { kind: 'couriers' });
  assert.deepEqual(Object.fromEntries(couriers.items.map(c => [c.id, c.availability])), { busy: 'onDelivery', fresh: 'available', offline: 'offline', stale: 'stale' });
});
test('availability audit records state changes once, without logging every GPS heartbeat', async () => {
  await owner.call('adminClaimAccess');
  await other.call('registerCourier', { name: 'Partner', phone: '+919876543210', vehicle: 'Bicycle' });
  for (let i = 0; i < 2; i++) await other.call('presence', { online: true, location: { latitude: 9, longitude: 76, accuracy: 10, recordedAt: Date.now() } });
  await other.call('presence', { online: false });
  const activity = (await owner.call('adminList', { kind: 'activity' })).items;
  assert.equal(activity.filter(e => e.type === 'courierAvailability').length, 2);
  assert.equal(activity.filter(e => e.type === 'courierRegistered').length, 1);
  await assert.rejects(other.call('adminList', { kind: 'activity' }), e => e.code === 'functions/permission-denied');
});
