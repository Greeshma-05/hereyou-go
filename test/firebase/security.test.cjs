const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc, getDocFromServer, getDocs, collection, serverTimestamp, Timestamp, getFirestore, connectFirestoreEmulator, writeBatch, query, where, orderBy, limit, deleteDoc } = require('firebase/firestore');
const { initializeApp, deleteApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithEmailAndPassword, signOut } = require('firebase/auth');
const projectId = 'demo-route-rescue';
let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId, firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') } });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });
const db = uid => env.authenticatedContext(uid, { email: `${uid}@example.test` }).firestore();
const profile = (uid = 'alice') => ({ displayName: 'Traveler', email: `${uid}@example.test`, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
const journey = () => ({ mode: 'bus', operatorName: 'KSRTC 101', boarding: 'Kochi', destination: 'Thrissur', departure: Timestamp.fromMillis(Date.now() + 3600000), pickup: { id: 'ksrtc', name: 'Bus stand', latitude: 9.97, longitude: 76.29, instructions: 'Meet at the entrance.' } });
const savedJourney = () => ({ schemaVersion: 1, journey: journey(), createdAt: serverTimestamp(), clientCreatedAt: Timestamp.now() });
const order = () => ({ schemaVersion: 1, reference: 'RR-1', createdAt: serverTimestamp(), clientCreatedAt: Timestamp.now(), vendorId: 'cafe', vendorName: 'Kitchen', journey: journey(), items: [{ product: { id: 'meal', name: 'Meal', pricePaise: 14000 }, quantity: 1 }], deliveryFeePaise: 2500, platformFeePaise: 500, totalPaise: 17000, verificationCode: '1234', status: 'placed', isPreview: true });

test('profile belongs only to its authenticated user', async () => {
  await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), profile()));
  await assertSucceeds(getDoc(doc(db('alice'), 'users/alice')));
  await assertFails(getDoc(doc(db('bob'), 'users/alice')));
  await assertFails(setDoc(doc(db('bob'), 'users/alice'), profile('bob')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/alice')));
  await assertFails(getDocs(collection(db('alice'), 'users')));
});
test('passwords and role escalation cannot be stored in a profile', async () => {
  await assertFails(setDoc(doc(db('alice'), 'users/alice'), { ...profile(), password: 'do-not-store' }));
  await assertFails(setDoc(doc(db('alice'), 'users/alice'), { ...profile(), role: 'admin' }));
  await assertFails(setDoc(doc(db('alice'), 'users/alice'), { ...profile(), email: 'bob@example.test' }));
  await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), profile()));
  await assertSucceeds(updateDoc(doc(db('alice'), 'users/alice'), { displayName: 'Asha', updatedAt: serverTimestamp() }));
});
const courierProfile = () => ({ name: 'Asha Partner', phone: '+919876543210', vehicle: 'Motorbike', online: false, activeOrderId: null, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
test('courier can register and edit contact details without Cloud Functions', async () => {
  const ref = doc(db('courier'), 'couriers/courier');
  await assertSucceeds(setDoc(ref, courierProfile()));
  const created = (await getDoc(ref)).data().createdAt;
  await assertSucceeds(updateDoc(ref, { name: 'Asha', phone: '+919876543211', vehicle: 'Bicycle', updatedAt: serverTimestamp() }));
  const saved = (await getDoc(ref)).data();
  assert.equal(saved.name, 'Asha');
  assert.equal(saved.online, false);
  assert.equal(saved.activeOrderId, null);
  assert.ok(saved.createdAt.isEqual(created));
});
test('courier contact records are private and cannot be enumerated or deleted', async () => {
  const own = db('courier'), other = db('stranger'), guest = env.unauthenticatedContext().firestore();
  await assertSucceeds(setDoc(doc(own, 'couriers/courier'), courierProfile()));
  for (const forbidden of [other, guest]) {
    await assertFails(getDoc(doc(forbidden, 'couriers/courier')));
    await assertFails(setDoc(doc(forbidden, 'couriers/courier'), courierProfile()));
    await assertFails(updateDoc(doc(forbidden, 'couriers/courier'), { name: 'Impersonator', updatedAt: serverTimestamp() }));
  }
  await assertFails(getDocs(collection(own, 'couriers')));
  await assertFails(deleteDoc(doc(own, 'couriers/courier')));
});
test('courier registration cannot forge availability, assignment, location or privileges', async () => {
  const ref = doc(db('courier'), 'couriers/courier');
  for (const forbidden of [{ online: true }, { activeOrderId: 'order-1' }, { location: { latitude: 9.97, longitude: 76.29 } }, { role: 'admin' }, { createdAt: Timestamp.fromMillis(1) }]) {
    await assertFails(setDoc(ref, { ...courierProfile(), ...forbidden }));
  }
});
test('editing courier contact details preserves all server-owned fields', async () => {
  const ref = doc(db('courier'), 'couriers/courier');
  await setDoc(ref, courierProfile());
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'couriers/courier'), {
    online: true, activeOrderId: 'order-1', location: { latitude: 9.97, longitude: 76.29 },
  }));
  await assertSucceeds(updateDoc(ref, { name: 'Edited name', updatedAt: serverTimestamp() }));
  const saved = (await getDoc(ref)).data();
  assert.equal(saved.online, true);
  assert.equal(saved.activeOrderId, 'order-1');
  assert.deepEqual(saved.location, { latitude: 9.97, longitude: 76.29 });
  for (const forbidden of [{ online: false }, { activeOrderId: null }, { location: null }, { role: 'admin' }, { createdAt: serverTimestamp() }]) {
    await assertFails(updateDoc(ref, { ...forbidden, updatedAt: serverTimestamp() }));
  }
  await assertFails(setDoc(ref, courierProfile()));
  await assertFails(setDoc(ref, { name: 'Removed operational fields', phone: saved.phone, vehicle: saved.vehicle, updatedAt: serverTimestamp() }));
});
test('courier contact writes validate details and require server timestamps', async () => {
  const ref = doc(db('courier'), 'couriers/courier');
  for (const invalid of [{ name: '' }, { name: 'x'.repeat(81) }, { phone: '123' }, { phone: 'invalid-phone' }, { vehicle: 'Plane' }, { updatedAt: Timestamp.fromMillis(1) }]) {
    await assertFails(setDoc(ref, { ...courierProfile(), ...invalid }));
  }
  await setDoc(ref, courierProfile());
  for (const invalid of [{ name: '' }, { phone: 'abc1234' }, { vehicle: 'Plane' }, { updatedAt: Timestamp.fromMillis(1) }]) {
    await assertFails(updateDoc(ref, { updatedAt: serverTimestamp(), ...invalid }));
  }
});
test('travel history is private, append-only and validates locations', async () => {
  const ref = doc(db('alice'), 'users/alice/journeys/trip-1');
  await assertSucceeds(setDoc(ref, savedJourney()));
  await assertSucceeds(getDocs(collection(db('alice'), 'users/alice/journeys')));
  await assertFails(getDoc(doc(db('bob'), 'users/alice/journeys/trip-1')));
  await assertFails(updateDoc(ref, { journey: journey() }));
  const invalid = savedJourney(); invalid.journey.pickup.latitude = 999;
  await assertFails(setDoc(doc(db('alice'), 'users/alice/journeys/trip-bad'), invalid));
});
test('orders are private snapshots and customers cannot alter status or totals', async () => {
  const ref = doc(db('alice'), 'users/alice/orders/RR-1');
  await assertSucceeds(setDoc(ref, order()));
  await assertSucceeds(getDoc(ref));
  await assertFails(getDoc(doc(db('bob'), 'users/alice/orders/RR-1')));
  await assertFails(updateDoc(ref, { status: 'handedOver' }));
  await assertFails(updateDoc(ref, { totalPaise: 1 }));
  await assertFails(setDoc(doc(db('bob'), 'users/alice/orders/RR-2'), { ...order(), reference: 'RR-2' }));
});
test('typed delivery addresses and pins fit the existing journey and order schema', async () => {
  const custom = { ...journey(), pickup: { id: 'custom-bus', name: '42 Market Road, Kaloor, Kochi', latitude: 9.99, longitude: 76.29, instructions: 'Meet beside the bakery.' } };
  const tripRef = doc(db('alice'), 'users/alice/journeys/custom-address');
  const orderRef = doc(db('alice'), 'users/alice/orders/HYG-1');
  await assertSucceeds(setDoc(tripRef, { ...savedJourney(), journey: custom }));
  await assertSucceeds(setDoc(orderRef, { ...order(), reference: 'HYG-1', journey: custom }));
  assert.deepEqual((await getDoc(tripRef)).data().journey.pickup, custom.pickup);
  assert.deepEqual((await getDoc(orderRef)).data().journey.pickup, custom.pickup);
  await assertFails(getDoc(doc(db('bob'), 'users/alice/journeys/custom-address')));
});
test('client cannot create real fulfillment orders or pre-approved orders', async () => {
  const ref = doc(db('alice'), 'users/alice/orders/RR-1');
  await assertFails(setDoc(ref, { ...order(), isPreview: false }));
  await assertFails(setDoc(ref, { ...order(), status: 'confirmed' }));
  await assertFails(setDoc(ref, { ...order(), totalPaise: -100 }));
  await assertFails(setDoc(ref, { ...order(), reference: 'mismatch' }));
});
test('preferences are private and unrecognized fields are rejected', async () => {
  const value = { notifications: true, checklist: ['Drinking water'], updatedAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(db('alice'), 'users/alice/preferences/general'), value));
  await assertFails(getDoc(doc(db('bob'), 'users/alice/preferences/general')));
  await assertFails(setDoc(doc(db('alice'), 'users/alice/preferences/general'), { ...value, admin: true }));
});
test('unconfigured collections are denied', async () => {
  await assertFails(setDoc(doc(db('alice'), 'products/meal'), { price: 1 }));
  await assertFails(setDoc(doc(db('alice'), 'orders/global'), order()));
});
test('real Auth emulator signup, sign-out and sign-in restore saved Firestore history', async () => {
  const app = initializeApp({ apiKey: 'emulator-key', projectId }, 'account-roundtrip');
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099'}`, { disableWarnings: true });
  const firestore = getFirestore(app); connectFirestoreEmulator(firestore, ...(process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':').map((v, i) => i ? Number(v) : v));
  const email = `roundtrip-${Date.now()}@example.test`;
  try {
    const user = (await createUserWithEmailAndPassword(auth, email, 'Test-only-password-42')).user;
    const uid = user.uid;
    await setDoc(doc(firestore, `users/${uid}`), { ...profile(), email });
    await setDoc(doc(firestore, `users/${uid}/orders/RR-1`), order());
    await setDoc(doc(firestore, `users/${uid}/journeys/trip-1`), savedJourney());
    await signOut(auth);
    await assertFails(getDocFromServer(doc(firestore, `users/${uid}/orders/RR-1`)));
    await signInWithEmailAndPassword(auth, email, 'Test-only-password-42');
    assert.equal(auth.currentUser.uid, uid);
    assert.equal((await getDocFromServer(doc(firestore, `users/${uid}/orders/RR-1`))).data().totalPaise, 17000);
    assert.equal((await getDocFromServer(doc(firestore, `users/${uid}/journeys/trip-1`))).data().journey.destination, 'Thrissur');
  } finally { await signOut(auth); await deleteApp(app); }
});

const merchant = uid => ({ ownerName: 'Test owner', email: `${uid}@example.test`, phone: '+919876543210', licenseNumber: 'TEST-LIC-123', createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
const shop = uid => ({ schemaVersion: 1, ownerUid: uid, name: 'Test medical shop', category: 'medicine', address: 'Public test address', latitude: 9.9772, longitude: 76.289, description: 'Test pharmacy catalog', preparationMinutes: 15, isOpen: true, isPublished: true, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
const medicine = uid => ({ schemaVersion: 1, vendorId: uid, name: 'Test labeled medicine', category: 'medicine', pricePaise: 12550, stock: 10, unit: 'Strip of 10', description: 'Test product label', strength: '10 mg', dosageForm: 'Tablet', genericName: 'Test ingredient', brand: 'Test brand', manufacturer: 'Test manufacturer', expiryDate: '2030-12-31', prescriptionRequired: true, isPublished: true, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
async function registerShop(uid, changes = {}) {
  const database = db(uid), batch = writeBatch(database);
  batch.set(doc(database, `vendorAccounts/${uid}`), merchant(uid));
  batch.set(doc(database, `vendors/${uid}`), { ...shop(uid), ...changes });
  await assertSucceeds(batch.commit());
  return database;
}
test('vendor registration is atomic, owner-scoped and private contact details stay private', async () => {
  await assertFails(setDoc(doc(db('vendor'), 'vendors/vendor'), shop('vendor')));
  const vendor = await registerShop('vendor');
  const guest = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(guest, 'vendors/vendor')));
  await assertSucceeds(getDoc(doc(vendor, 'vendorAccounts/vendor')));
  await assertFails(getDoc(doc(guest, 'vendorAccounts/vendor')));
  await assertFails(getDoc(doc(db('customer'), 'vendorAccounts/vendor')));
  await assertFails(updateDoc(doc(db('other-vendor'), 'vendors/vendor'), { name: 'Taken over', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(vendor, 'vendors/vendor'), { ownerUid: 'other-vendor', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(vendor, 'vendors/vendor'), { category: 'food', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(vendor, 'vendors/vendor'), { verified: true, updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(vendor, 'vendorAccounts/vendor'), { licenseNumber: '', updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(doc(vendor, 'vendors/vendor')));
});
test('vendor products validate medicine labels, prices and stock, and reject cross-vendor writes', async () => {
  const vendor = await registerShop('vendor');
  const ref = doc(vendor, 'vendors/vendor/products/medicine');
  await assertSucceeds(setDoc(ref, medicine('vendor')));
  for (const change of [{ pricePaise: -1 }, { pricePaise: 12.5 }, { stock: -1 }, { stock: 1.5 }, { strength: '' }, { dosageForm: '' }, { manufacturer: '' }, { expiryDate: '' }, { vendorId: 'attacker' }, { category: 'food' }, { expiryDate: 'invalid' }, { name: '' }]) {
    await assertFails(updateDoc(ref, { ...change, updatedAt: serverTimestamp() }));
  }
  await assertFails(setDoc(doc(db('attacker'), 'vendors/vendor/products/stolen'), medicine('vendor')));
  await assertFails(updateDoc(doc(db('customer'), 'vendors/vendor/products/medicine'), { stock: 999, updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(ref, { stock: 0, pricePaise: 12000, updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(ref));
});
test('guest customer queries receive published shops and products, and archives immediately restrict reads', async () => {
  const vendor = await registerShop('vendor');
  const guest = env.unauthenticatedContext().firestore();
  const productRef = doc(vendor, 'vendors/vendor/products/medicine');
  await setDoc(productRef, medicine('vendor'));
  const shops = query(collection(guest, 'vendors'), where('isPublished', '==', true), where('latitude', '>=', 9.8), where('latitude', '<=', 10.1), orderBy('latitude'), limit(200));
  const products = query(collection(guest, 'vendors/vendor/products'), where('isPublished', '==', true));
  assert.equal((await assertSucceeds(getDocs(shops))).size, 1);
  assert.equal((await assertSucceeds(getDocs(products))).size, 1);
  await assertFails(getDocs(collection(guest, 'vendors')));
  await assertFails(getDocs(collection(guest, 'vendors/vendor/products')));
  await updateDoc(productRef, { isPublished: false, updatedAt: serverTimestamp() });
  assert.equal((await getDocs(products)).size, 0);
  await assertFails(getDoc(doc(guest, 'vendors/vendor/products/medicine')));
  await assertSucceeds(getDoc(productRef));
  await updateDoc(productRef, { isPublished: true, updatedAt: serverTimestamp() });
  await updateDoc(doc(vendor, 'vendors/vendor'), { isPublished: false, updatedAt: serverTimestamp() });
  assert.equal((await getDocs(shops)).size, 0);
  await assertFails(getDoc(doc(guest, 'vendors/vendor')));
  await assertFails(getDocs(products));
});
test('catalog owners cannot read customer history or write fulfillment status', async () => {
  const vendor = await registerShop('vendor');
  await setDoc(doc(db('alice'), 'users/alice/orders/RR-1'), order());
  await assertFails(getDoc(doc(vendor, 'users/alice/orders/RR-1')));
  await assertFails(updateDoc(doc(vendor, 'users/alice/orders/RR-1'), { status: 'confirmed' }));
});
