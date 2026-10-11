const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { initializeTestEnvironment, assertFails } = require('@firebase/rules-unit-testing');
const { initializeApp, deleteApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, createUserWithEmailAndPassword } = require('firebase/auth');
const { getFirestore, connectFirestoreEmulator, doc, getDoc, getDocs, collection, query, where, updateDoc, setDoc, Timestamp } = require('firebase/firestore');
const { getFunctions, connectFunctionsEmulator, httpsCallable, httpsCallableFromURL } = require('firebase/functions');
const projectId = 'demo-route-rescue';
let env, customer, vendor, courier, rival, stranger;
const clients = [];
async function client(name) {
  const app = initializeApp({ projectId, apiKey: 'emulator-key', appId: `test-${name}` }, `${name}-${Date.now()}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`, { disableWarnings: true });
  const user = (await createUserWithEmailAndPassword(auth, `${name}-${Date.now()}@example.test`, 'Test-password-123')).user;
  const db = getFirestore(app);
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  connectFirestoreEmulator(db, host, Number(port));
  const functions = getFunctions(app, 'asia-south1');
  if (!process.env.FULFILLMENT_TEST_URL) connectFunctionsEmulator(functions, '127.0.0.1', 5101);
  const callable = process.env.FULFILLMENT_TEST_URL
    ? httpsCallableFromURL(functions, process.env.FULFILLMENT_TEST_URL)
    : httpsCallable(functions, 'fulfillment');
  const result = { app, db, uid: user.uid, call: async (action, data = {}) => (await callable({ action, ...data })).data };
  clients.push(result); return result;
}
before(async () => {
  env = await initializeTestEnvironment({ projectId, firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') } });
  [customer, vendor, courier, rival, stranger] = await Promise.all(['customer', 'vendor', 'courier', 'rival', 'stranger'].map(client));
});
after(async () => { await Promise.all(clients.map(c => deleteApp(c.app))); await env.cleanup(); });
const location = (latitude = 9.9772, longitude = 76.289) => ({ latitude, longitude, accuracy: 10, recordedAt: Date.now() });
const trip = () => ({ mode: 'bus', operatorName: 'KSRTC', boarding: 'Kochi', destination: 'Thrissur', departure: Date.now() + 3600000, pickup: { id: 'custom-bus', name: 'Test bus stand', latitude: 9.98, longitude: 76.29, instructions: 'Meet at the entrance.' } });
async function admin(fn) { return env.withSecurityRulesDisabled(c => fn(c.firestore())); }
async function read(path, client = customer) { return (await getDoc(doc(client.db, path))).data(); }
async function create(reference = 'HYG-test', overrides = {}) { return customer.call('createOrder', { reference, vendorId: vendor.uid, journey: trip(), items: [{ productId: 'water', quantity: 2, pricePaise: 2000 }], totalPaise: 7000, ...overrides }); }
async function prepare(reference = 'HYG-test') {
  await vendor.call('transition', { reference, status: 'confirmed' });
  await vendor.call('transition', { reference, status: 'preparing' });
}
async function online(c = courier, loc = location()) {
  await c.call('registerCourier', { name: 'Delivery Partner', phone: '+919876543210', vehicle: 'Motorbike' });
  await c.call('presence', { online: true, location: loc });
}
beforeEach(async () => {
  await env.clearFirestore();
  await admin(async db => {
    await setDoc(doc(db, `vendors/${vendor.uid}`), { schemaVersion: 1, ownerUid: vendor.uid, name: 'Journey Store', category: 'food', address: 'Test pickup road', latitude: 9.9772, longitude: 76.289, description: 'Essentials', preparationMinutes: 10, isPublished: true, isOpen: true, createdAt: Timestamp.now(), updatedAt: Timestamp.now() });
    await setDoc(doc(db, `vendors/${vendor.uid}/products/water`), { schemaVersion: 1, vendorId: vendor.uid, name: 'Water', category: 'food', pricePaise: 2000, stock: 20, unit: 'Bottle', description: 'Water bottle', strength: '', dosageForm: '', genericName: '', brand: '', manufacturer: '', expiryDate: '', prescriptionRequired: false, isPublished: true, createdAt: Timestamp.now(), updatedAt: Timestamp.now() });
  });
});
test('three authenticated apps complete a real order with shared statuses, tracking and private OTP', async () => {
  await create();
  const saved = await read(`users/${customer.uid}/orders/HYG-test`);
  assert.equal(saved.isPreview, false); assert.equal(saved.totalPaise, 7000); assert.match(saved.verificationCode, /^\d{4}$/);
  assert.equal((await read(`vendors/${vendor.uid}/products/water`)).stock, 18);
  assert.equal((await read('orders/HYG-test', vendor)).verificationCode, undefined);
  const vendorOrders = await getDocs(query(collection(vendor.db, 'orders'), where('vendorId', '==', vendor.uid)));
  assert.equal(vendorOrders.size, 1);
  await online();
  assert.equal((await courier.call('nearby')).offers.length, 0);
  await prepare();
  const offers = (await courier.call('nearby')).offers;
  assert.equal(offers.length, 1); assert.equal(offers[0].customerUid, undefined); assert.equal(offers[0].journey, undefined); assert.equal(offers[0].verificationCode, undefined);
  await courier.call('claim', { reference: 'HYG-test' });
  assert.equal((await read(`users/${customer.uid}/orders/HYG-test`)).courierId, courier.uid);
  await assert.rejects(courier.call('transition', { reference: 'HYG-test', status: 'pickedUp' }));
  await vendor.call('transition', { reference: 'HYG-test', status: 'ready' });
  await courier.call('transition', { reference: 'HYG-test', status: 'pickedUp' });
  await courier.call('presence', { online: true, location: location(9.979, 76.290) });
  assert.equal((await read('orderTracking/HYG-test')).latitude, 9.979);
  await assertFails(getDoc(doc(stranger.db, 'orderTracking/HYG-test')));
  await assertFails(getDoc(doc(courier.db, 'orderSecrets/HYG-test')));
  await assertFails(getDoc(doc(vendor.db, `users/${customer.uid}/orders/HYG-test`)));
  await courier.call('transition', { reference: 'HYG-test', status: 'handedOver', code: saved.verificationCode });
  assert.equal((await read(`users/${customer.uid}/orders/HYG-test`)).status, 'handedOver');
  assert.equal((await read(`couriers/${courier.uid}`, courier)).activeOrderId, null);
  assert.equal((await getDoc(doc(customer.db, 'orderTracking/HYG-test'))).exists(), false);
});
test('5 km boundary filters offers and server rejects out-of-radius claims, stale and inaccurate fixes', async () => {
  await create(); await prepare();
  await online(courier, location(10.0212)); // about 4.9 km north
  assert.equal((await courier.call('nearby')).offers.length, 1);
  await courier.call('presence', { online: true, location: location(10.0232) }); // about 5.1 km north
  assert.equal((await courier.call('nearby')).offers.length, 0);
  await assert.rejects(courier.call('claim', { reference: 'HYG-test' }), /5 km/);
  await assert.rejects(courier.call('presence', { online: true, location: { ...location(), recordedAt: Date.now() - 180000 } }));
  await assert.rejects(courier.call('presence', { online: true, location: { ...location(), accuracy: 1000 } }));
  await courier.call('presence', { online: false });
  await assert.rejects(courier.call('nearby'));
});
test('two competing couriers cannot claim the same order; one courier cannot take two jobs', async () => {
  await create(); await create('HYG-second'); await prepare(); await prepare('HYG-second');
  await Promise.all([online(courier), online(rival)]);
  const results = await Promise.allSettled([courier.call('claim', { reference: 'HYG-test' }), rival.call('claim', { reference: 'HYG-test' })]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  const winner = results[0].status === 'fulfilled' ? courier : rival;
  await assert.rejects(winner.call('claim', { reference: 'HYG-second' }));
  assert.equal((await winner.call('claim', { reference: 'HYG-test' })).reference, 'HYG-test');
});
test('order retry is idempotent and concurrent orders cannot oversell', async () => {
  await Promise.all([create(), create()]);
  assert.equal((await read(`vendors/${vendor.uid}/products/water`)).stock, 18);
  await admin(db => updateDoc(doc(db, `vendors/${vendor.uid}/products/water`), { stock: 2 }));
  const results = await Promise.allSettled([create('HYG-last-one'), create('HYG-last-two')]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal((await read(`vendors/${vendor.uid}/products/water`)).stock, 0);
});
test('forged totals, changed prices, malformed journeys and prescription products are rejected', async () => {
  await assert.rejects(create('HYG-bad', { totalPaise: 1 }));
  await assert.rejects(create('HYG-bad', { items: [{ productId: 'water', quantity: 2, pricePaise: 1 }] }));
  await assert.rejects(create('HYG-bad', { journey: { ...trip(), departure: 1 } }));
  await assert.rejects(create('HYG-bad', { journey: { ...trip(), pickup: { ...trip().pickup, latitude: 20 } } }));
  await assert.rejects(create('HYG-bad', { items: [{ productId: '../water', quantity: 2, pricePaise: 2000 }] }));
  await admin(db => updateDoc(doc(db, `vendors/${vendor.uid}/products/water`), { prescriptionRequired: true }));
  await assert.rejects(create('HYG-rx'), /Prescription/);
  assert.equal((await read(`vendors/${vendor.uid}/products/water`)).stock, 20);
});
test('cancellation restores inventory, clears assignment and cannot repeat', async () => {
  await create(); await prepare(); await online(); await courier.call('claim', { reference: 'HYG-test' });
  await vendor.call('transition', { reference: 'HYG-test', status: 'cancelled' });
  assert.equal((await read(`vendors/${vendor.uid}/products/water`)).stock, 20);
  assert.equal((await read(`couriers/${courier.uid}`, courier)).activeOrderId, null);
  assert.equal((await read(`users/${customer.uid}/orders/HYG-test`)).status, 'cancelled');
  await assert.rejects(vendor.call('transition', { reference: 'HYG-test', status: 'cancelled' }));
  assert.equal((await read(`vendors/${vendor.uid}/products/water`)).stock, 20);
});
test('OTP attempts persist and lock after five incorrect codes', async () => {
  await create(); await prepare(); await online(); await courier.call('claim', { reference: 'HYG-test' });
  await vendor.call('transition', { reference: 'HYG-test', status: 'ready' });
  await courier.call('transition', { reference: 'HYG-test', status: 'pickedUp' });
  for (let i = 0; i < 5; i++) assert.match((await courier.call('transition', { reference: 'HYG-test', status: 'handedOver', code: '0000' })).error, /Incorrect/);
  const secret = await read(`users/${customer.uid}/orders/HYG-test`);
  assert.match((await courier.call('transition', { reference: 'HYG-test', status: 'handedOver', code: secret.verificationCode })).error, /10 minutes/);
  assert.equal((await read('orders/HYG-test')).status, 'pickedUp');
});
test('unrelated accounts cannot read orders or change status, assignment, location or profiles', async () => {
  await create();
  await assertFails(getDoc(doc(stranger.db, 'orders/HYG-test')));
  await assertFails(getDocs(collection(courier.db, 'orders')));
  await assertFails(updateDoc(doc(customer.db, 'orders/HYG-test'), { status: 'handedOver' }));
  await assertFails(updateDoc(doc(vendor.db, 'orders/HYG-test'), { courierId: courier.uid }));
  await assertFails(setDoc(doc(courier.db, `couriers/${courier.uid}`), { online: true }));
  await assertFails(setDoc(doc(courier.db, 'orderTracking/HYG-test'), { latitude: 9, longitude: 76 }));
  await assert.rejects(stranger.call('transition', { reference: 'HYG-test', status: 'confirmed' }));
  await assert.rejects(customer.call('transition', { reference: 'HYG-test', status: 'ready' }));
  await customer.call('transition', { reference: 'HYG-test', status: 'cancelled' });
});

test('vendor assigns an accepted order and all three clients see the assignment', async () => {
  await create(); await online();
  await assert.rejects(vendor.call('nearbyCouriers', { reference: 'HYG-test' }), /Accept/);
  await assert.rejects(vendor.call('assignCourier', { reference: 'HYG-test', courierId: courier.uid }), /Accept/);
  await vendor.call('transition', { reference: 'HYG-test', status: 'confirmed' });
  const result = await vendor.call('nearbyCouriers', { reference: 'HYG-test' });
  assert.equal(result.radiusKm, 5);
  assert.deepEqual(Object.keys(result.partners[0]).sort(), ['distanceKm', 'id', 'name', 'vehicle']);
  assert.equal(result.partners[0].id, courier.uid);
  await vendor.call('assignCourier', { reference: 'HYG-test', courierId: courier.uid });
  const assigned = await read('orders/HYG-test', vendor);
  assert.equal(assigned.status, 'confirmed');
  assert.equal(assigned.courierId, courier.uid);
  assert.equal(assigned.assignmentSource, 'vendor');
  assert.equal((await read(`users/${customer.uid}/orders/HYG-test`)).courierId, courier.uid);
  assert.equal((await read(`couriers/${courier.uid}`, courier)).activeOrderId, 'HYG-test');
  const deliveries = await getDocs(query(collection(courier.db, 'orders'), where('courierId', '==', courier.uid)));
  assert.equal(deliveries.docs[0].id, 'HYG-test');
  assert.equal((await read('orderTracking/HYG-test', vendor)).courierId, courier.uid);
  const stamp = assigned.assignedAt;
  await vendor.call('assignCourier', { reference: 'HYG-test', courierId: courier.uid });
  assert.ok((await read('orders/HYG-test', vendor)).assignedAt.isEqual(stamp));
  await assert.rejects(vendor.call('nearbyCouriers', { reference: 'HYG-test' }));
  await vendor.call('transition', { reference: 'HYG-test', status: 'preparing' });
  await vendor.call('transition', { reference: 'HYG-test', status: 'ready' });
  await courier.call('transition', { reference: 'HYG-test', status: 'pickedUp' });
  const saved = await read(`users/${customer.uid}/orders/HYG-test`);
  await courier.call('transition', { reference: 'HYG-test', status: 'handedOver', code: saved.verificationCode });
  await assert.rejects(vendor.call('assignCourier', { reference: 'HYG-test', courierId: courier.uid }));
});

test('only the owning vendor can discover or assign partners for an order', async () => {
  await create(); await prepare(); await online();
  for (const other of [customer, courier, rival, stranger]) {
    await assert.rejects(other.call('nearbyCouriers', { reference: 'HYG-test' }), e => e.code === 'functions/permission-denied');
    await assert.rejects(other.call('assignCourier', { reference: 'HYG-test', courierId: courier.uid }), e => e.code === 'functions/permission-denied');
  }
  await assertFails(getDoc(doc(vendor.db, `couriers/${courier.uid}`)));
  await assertFails(getDocs(collection(vendor.db, 'couriers')));
  assert.equal((await read('orders/HYG-test', vendor)).courierId, null);
});

test('vendor discovery sorts nearest partners, enforces 5 km and rechecks movement on assignment', async () => {
  await create(); await prepare();
  await online(courier, location(10.0212)); // 4.9 km
  await online(rival, location(9.978));
  let partners = (await vendor.call('nearbyCouriers', { reference: 'HYG-test' })).partners;
  assert.deepEqual(partners.map(p => p.id), [rival.uid, courier.uid]);
  await courier.call('presence', { online: true, location: location(10.0232) }); // 5.1 km
  partners = (await vendor.call('nearbyCouriers', { reference: 'HYG-test' })).partners;
  assert.deepEqual(partners.map(p => p.id), [rival.uid]);
  await assert.rejects(vendor.call('assignCourier', { reference: 'HYG-test', courierId: courier.uid }), /5 km/);
});

test('stale, inaccurate, offline and busy partners cannot be discovered or assigned', async () => {
  await create(); await prepare();
  for (const patch of [
    { online: false },
    { 'location.recordedAt': Timestamp.fromMillis(Date.now() - 180000) },
    { 'location.recordedAt': Timestamp.fromMillis(Date.now() + 180000) },
    { 'location.accuracy': 500 },
    { activeOrderId: 'another-order' },
  ]) {
    await online();
    await admin(db => updateDoc(doc(db, `couriers/${courier.uid}`), patch));
    assert.equal((await vendor.call('nearbyCouriers', { reference: 'HYG-test' })).partners.length, 0);
    await assert.rejects(vendor.call('assignCourier', { reference: 'HYG-test', courierId: courier.uid }));
    // Reset only the test fixture before the next availability case.
    await admin(db => updateDoc(doc(db, `couriers/${courier.uid}`), { activeOrderId: null, location: { ...location(), recordedAt: Timestamp.now() } }));
  }
});

test('customers and shop owners cannot be assigned to deliver their own order', async () => {
  await create(); await prepare();
  await online(customer); await online(vendor);
  assert.equal((await vendor.call('nearbyCouriers', { reference: 'HYG-test' })).partners.length, 0);
  for (const candidate of [customer, vendor]) {
    await assert.rejects(vendor.call('assignCourier', { reference: 'HYG-test', courierId: candidate.uid }), e => e.code === 'functions/permission-denied');
  }
});

test('vendor assignment racing with courier claim produces exactly one assigned partner', async () => {
  await create(); await prepare(); await online(courier); await online(rival);
  const results = await Promise.allSettled([
    vendor.call('assignCourier', { reference: 'HYG-test', courierId: courier.uid }),
    rival.call('claim', { reference: 'HYG-test' }),
  ]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  const o = await read('orders/HYG-test', vendor);
  const winner = o.courierId === courier.uid ? courier : rival;
  const loser = winner === courier ? rival : courier;
  assert.equal((await read(`couriers/${winner.uid}`, winner)).activeOrderId, 'HYG-test');
  assert.equal((await read(`couriers/${loser.uid}`, loser)).activeOrderId, null);
  assert.equal((await read(`users/${customer.uid}/orders/HYG-test`)).courierId, winner.uid);
});

test('two vendor assignments cannot give a partner two jobs and cancellation releases them', async () => {
  await create(); await create('HYG-second'); await prepare(); await prepare('HYG-second'); await online();
  const results = await Promise.allSettled(['HYG-test', 'HYG-second'].map(reference =>
    vendor.call('assignCourier', { reference, courierId: courier.uid })));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  const assigned = (await read(`couriers/${courier.uid}`, courier)).activeOrderId;
  const remaining = assigned === 'HYG-test' ? 'HYG-second' : 'HYG-test';
  await vendor.call('transition', { reference: assigned, status: 'cancelled' });
  await assert.rejects(vendor.call('assignCourier', { reference: assigned, courierId: courier.uid }));
  await vendor.call('assignCourier', { reference: remaining, courierId: courier.uid });
  assert.equal((await read(`couriers/${courier.uid}`, courier)).activeOrderId, remaining);
});
