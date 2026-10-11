'use strict';
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { randomInt } = require('node:crypto');
const { geohashForLocation, geohashQueryBounds, distanceBetween } = require('geofire-common');
const { dispatchAdmin, audit } = require('./admin');
initializeApp();
const db = getFirestore();
const RADIUS_KM = 5;
const activeStates = ['preparing', 'ready'];
const assignableStates = ['confirmed', 'preparing', 'ready'];
const fail = (message, code = 'failed-precondition') => { throw new HttpsError(code, message); };
function text(v, max = 160) {
  if (typeof v !== 'string' || !v.trim() || v.length > max) fail('A required field is missing or too long.', 'invalid-argument');
  return v.trim();
}
function id(v) {
  if (typeof v !== 'string' || !/^[A-Za-z0-9_-]{1,140}$/.test(v)) fail('Invalid identifier.', 'invalid-argument');
  return v;
}
function coords(p) {
  if (!p || !Number.isFinite(p.latitude) || !Number.isFinite(p.longitude) || Math.abs(p.latitude) > 90 || Math.abs(p.longitude) > 180) fail('A valid location is required.', 'invalid-argument');
  return [p.latitude, p.longitude];
}
function fix(p) {
  coords(p);
  if (!Number.isFinite(p.recordedAt) || Math.abs(Date.now() - p.recordedAt) > 90000 || !Number.isFinite(p.accuracy) || p.accuracy <= 0 || p.accuracy > 150) fail('Refresh your precise GPS location (accuracy within 150 m).');
  return { latitude: p.latitude, longitude: p.longitude, accuracy: p.accuracy, recordedAt: Timestamp.fromMillis(p.recordedAt) };
}
function journey(j) {
  if (!j || !['bus', 'train'].includes(j.mode)) fail('Choose a bus or train journey.', 'invalid-argument');
  const boarding = text(j.boarding, 120), destination = text(j.destination, 120);
  if (boarding.toLowerCase() === destination.toLowerCase() || !Number.isFinite(j.departure) || j.departure <= Date.now()) fail('Update your journey and future departure time.');
  coords(j.pickup);
  return { mode: j.mode, operatorName: text(j.operatorName, 120), boarding, destination, departure: Timestamp.fromMillis(j.departure), pickup: { id: text(j.pickup.id, 120), name: text(j.pickup.name), latitude: j.pickup.latitude, longitude: j.pickup.longitude, instructions: text(j.pickup.instructions, 1000) } };
}
const mirrorRef = o => db.doc(`users/${o.customerUid}/orders/${o.reference}`);
function change(tx, ref, o, patch) {
  const update = { ...patch, updatedAt: FieldValue.serverTimestamp() };
  tx.update(ref, update);
  tx.update(mirrorRef(o), update);
}
async function createOrder(uid, data) {
  const reference = id(data.reference), vendorId = id(data.vendorId);
  const ref = db.doc(`orders/${reference}`);
  return db.runTransaction(async tx => {
    const previous = await tx.get(ref);
    if (previous.exists) {
      if (previous.data().customerUid !== uid) fail('This order reference is already in use.', 'already-exists');
      return { reference };
    }
    const trip = journey(data.journey);
    if (!Array.isArray(data.items) || data.items.length < 1 || data.items.length > 50) fail('Review your cart.', 'invalid-argument');
    const vendorDoc = await tx.get(db.doc(`vendors/${vendorId}`));
    const vendor = vendorDoc.data();
    if (!vendor || !vendor.isPublished || !vendor.isOpen) fail('This shop is unavailable.');
    if (distanceBetween(coords(vendor), coords(trip.pickup)) > (trip.mode === 'bus' ? 7 : 20)) fail('The delivery pin is outside this shop’s delivery area.');
    const seen = new Set();
    const lines = data.items.map(item => {
      const productId = id(item.productId);
      if (seen.has(productId) || !Number.isInteger(item.quantity) || item.quantity < 1 || item.quantity > 100) fail('Invalid item quantity.', 'invalid-argument');
      seen.add(productId);
      return { ...item, ref: db.doc(`vendors/${vendorId}/products/${productId}`) };
    });
    const docs = await tx.getAll(...lines.map(l => l.ref));
    const today = new Date().toISOString().slice(0, 10);
    const items = docs.map((doc, i) => {
      const p = doc.data(), line = lines[i];
      if (!p || !p.isPublished || p.vendorId !== vendorId || p.stock < line.quantity || p.expiryDate && p.expiryDate < today) fail('An item is unavailable. Refresh your cart.');
      if (p.prescriptionRequired) fail('Prescription items need pharmacy verification before online ordering. Remove this item and contact the pharmacy.');
      if (p.pricePaise !== line.pricePaise) fail('An item price changed. Review the updated cart before ordering.');
      const { createdAt, updatedAt, isPublished, schemaVersion, ...product } = p;
      return { product: { ...product, id: doc.id }, quantity: line.quantity };
    });
    const subtotal = items.reduce((sum, l) => sum + l.product.pricePaise * l.quantity, 0);
    const totalPaise = subtotal + 3000;
    if (totalPaise !== data.totalPaise || totalPaise > 100000000) fail('The total changed. Review your cart.');
    const now = Timestamp.now();
    const order = { schemaVersion: 2, reference, customerUid: uid, vendorId, vendorName: vendor.name, pickup: { name: vendor.name, address: vendor.address, latitude: vendor.latitude, longitude: vendor.longitude }, pickupGeohash: geohashForLocation(coords(vendor)), journey: trip, items, deliveryFeePaise: 2500, platformFeePaise: 500, totalPaise, status: 'placed', courierId: null, courierName: null, isPreview: false, paymentMethod: 'cashOnDelivery', createdAt: now, clientCreatedAt: now, updatedAt: now };
    const verificationCode = randomInt(1000, 10000).toString();
    tx.create(ref, order);
    audit(tx, { type: 'orderCreated', reference, vendorId, actorUid: uid, actorRole: 'customer', toStatus: 'placed' });
    tx.create(db.doc(`orderSecrets/${reference}`), { verificationCode, attempts: 0, lockedUntil: null });
    tx.create(mirrorRef(order), { ...order, verificationCode });
    lines.forEach((line, i) => tx.update(line.ref, { stock: docs[i].data().stock - line.quantity, updatedAt: now }));
    return { reference };
  });
}
async function registerCourier(uid, data) {
  const name = text(data.name, 80), phone = text(data.phone, 24), vehicle = text(data.vehicle, 40);
  if (!/^[+0-9 ()-]{7,24}$/.test(phone) || !['Bicycle', 'Motorbike', 'Car'].includes(vehicle)) fail('Enter a valid phone and vehicle.', 'invalid-argument');
  await db.runTransaction(async tx => {
    const ref = db.doc(`couriers/${uid}`), doc = await tx.get(ref);
    if (doc.exists) tx.update(ref, { name, phone, vehicle, updatedAt: FieldValue.serverTimestamp() });
    else tx.create(ref, { name, phone, vehicle, online: false, activeOrderId: null, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
    audit(tx, { type: doc.exists ? 'courierProfileUpdated' : 'courierRegistered', courierId: uid, name, actorUid: uid, actorRole: 'courier' });
  });
  return { registered: true };
}
async function presence(uid, data) {
  const location = data.online === true ? fix(data.location) : null;
  return db.runTransaction(async tx => {
    const ref = db.doc(`couriers/${uid}`), doc = await tx.get(ref);
    if (!doc.exists) fail('Complete your delivery partner profile first.');
    const courier = doc.data();
    const orderRef = courier.activeOrderId ? db.doc(`orders/${courier.activeOrderId}`) : null;
    const order = orderRef ? (await tx.get(orderRef)).data() : null;
    if (location && courier.location && location.recordedAt.toMillis() < courier.location.recordedAt.toMillis()) fail('An older location was ignored. Refresh GPS.');
    tx.update(ref, { online: data.online === true, ...(location ? { location, locationGeohash: geohashForLocation(coords(location)) } : {}), updatedAt: FieldValue.serverTimestamp() });
    if (courier.online !== (data.online === true)) audit(tx, { type: 'courierAvailability', courierId: uid, name: courier.name, online: data.online === true, actorUid: uid, actorRole: 'courier' });
    if (order && order.courierId === uid && !['handedOver', 'cancelled'].includes(order.status)) {
      const track = db.doc(`orderTracking/${order.reference}`);
      if (location) tx.set(track, { ...location, courierId: uid, name: courier.name, updatedAt: FieldValue.serverTimestamp() });
      else tx.delete(track);
    }
    return { online: data.online === true };
  });
}
function freshLocation(c) {
  const p = c?.location, recordedAt = p?.recordedAt?.toMillis?.();
  return c?.online === true && Number.isFinite(recordedAt) && Math.abs(Date.now() - recordedAt) <= 90000
    && Number.isFinite(p.latitude) && Math.abs(p.latitude) <= 90
    && Number.isFinite(p.longitude) && Math.abs(p.longitude) <= 180
    && Number.isFinite(p.accuracy) && p.accuracy > 0 && p.accuracy <= 150;
}
function available(c) {
  if (!freshLocation(c)) fail('This partner is offline or their GPS is stale. Refresh nearby partners or go online again.');
  if (c.activeOrderId) fail('Finish your active delivery before claiming another.');
}
function vendorOrder(uid, o) {
  if (!o || o.vendorId !== uid) fail('This order does not belong to your shop.', 'permission-denied');
}
function canAssign(o) {
  if (!assignableStates.includes(o.status) || o.courierId) fail('Accept the order first. Only unassigned accepted, preparing or ready orders can be assigned.');
}
async function nearbyCouriers(uid, data) {
  const o = (await db.doc(`orders/${id(data.reference)}`).get()).data();
  vendorOrder(uid, o);
  canAssign(o);
  const center = coords(o.pickup);
  const bounds = geohashQueryBounds(center, RADIUS_KM * 1000);
  const snapshots = await Promise.all(bounds.map(([start, end]) => db.collection('couriers')
    .where('online', '==', true).where('activeOrderId', '==', null)
    .orderBy('locationGeohash').startAt(start).endAt(end).get()));
  const found = new Map();
  for (const snap of snapshots) for (const doc of snap.docs) {
    const c = doc.data();
    if (doc.id === o.vendorId || doc.id === o.customerUid || !freshLocation(c) || c.activeOrderId) continue;
    const distanceKm = distanceBetween(center, coords(c.location));
    // Vendors see only availability, vehicle and pickup distance, never the
    // courier's private contact record or exact unassigned GPS coordinates.
    if (distanceKm <= RADIUS_KM) found.set(doc.id, { id: doc.id, name: c.name, vehicle: c.vehicle, distanceKm });
  }
  return { radiusKm: RADIUS_KM, partners: [...found.values()].sort((a, b) => a.distanceKm - b.distanceKm).slice(0, 100) };
}
function assign(tx, ref, o, courierRef, c, source) {
  const courierId = courierRef.id;
  available(c);
  if (o.vendorId === courierId || o.customerUid === courierId) fail('The shop owner or customer cannot deliver their own order.', 'permission-denied');
  if (distanceBetween(coords(c.location), coords(o.pickup)) > RADIUS_KM) fail('This pickup is outside the partner’s 5 km radius.', 'permission-denied');
  change(tx, ref, o, { courierId, courierName: c.name, assignmentSource: source, assignedAt: FieldValue.serverTimestamp() });
  audit(tx, { type: 'courierAssigned', reference: o.reference, vendorId: o.vendorId, courierId, name: c.name, actorUid: source === 'vendor' ? o.vendorId : courierId, actorRole: source });
  tx.update(courierRef, { activeOrderId: o.reference });
  tx.set(db.doc(`orderTracking/${o.reference}`), { ...c.location, courierId, name: c.name, updatedAt: FieldValue.serverTimestamp() });
  return { reference: o.reference };
}
async function assignCourier(uid, data) {
  const ref = db.doc(`orders/${id(data.reference)}`), courierRef = db.doc(`couriers/${id(data.courierId)}`);
  return db.runTransaction(async tx => {
    const [doc, courierDoc] = await tx.getAll(ref, courierRef);
    const o = doc.data(), c = courierDoc.data();
    vendorOrder(uid, o);
    if (!['handedOver', 'cancelled'].includes(o.status) && o.courierId === courierRef.id && c?.activeOrderId === o.reference) return { reference: o.reference };
    canAssign(o);
    return assign(tx, ref, o, courierRef, c, 'vendor');
  });
}
async function nearby(uid) {
  const c = (await db.doc(`couriers/${uid}`).get()).data();
  available(c);
  const center = coords(c.location);
  const bounds = geohashQueryBounds(center, RADIUS_KM * 1000);
  const snapshots = await Promise.all(bounds.map(([start, end]) => db.collection('orders').where('status', 'in', activeStates).where('courierId', '==', null).orderBy('pickupGeohash').startAt(start).endAt(end).get()));
  const found = new Map();
  for (const snap of snapshots) for (const doc of snap.docs) {
    const o = doc.data(), distanceKm = distanceBetween(center, coords(o.pickup));
    if (distanceKm <= RADIUS_KM) found.set(doc.id, { reference: doc.id, vendorName: o.vendorName, pickup: o.pickup, status: o.status, distanceKm, deliveryDistanceKm: distanceBetween(coords(o.pickup), coords(o.journey.pickup)), deliveryFeePaise: o.deliveryFeePaise, itemCount: o.items.reduce((sum, i) => sum + i.quantity, 0) });
  }
  return { radiusKm: RADIUS_KM, offers: [...found.values()].sort((a, b) => a.distanceKm - b.distanceKm).slice(0, 100) };
}
async function claim(uid, data) {
  return db.runTransaction(async tx => {
    const ref = db.doc(`orders/${id(data.reference)}`), courierRef = db.doc(`couriers/${uid}`);
    const [doc, courierDoc] = await tx.getAll(ref, courierRef);
    const o = doc.data(), c = courierDoc.data();
    if (o && o.courierId === uid && c?.activeOrderId === o.reference) return { reference: o.reference };
    available(c);
    if (!o || !activeStates.includes(o.status) || o.courierId) fail('This order is no longer available.', 'already-exists');
    return assign(tx, ref, o, courierRef, c, 'courier');
  });
}
async function transition(uid, data) {
  return db.runTransaction(async tx => {
    const ref = db.doc(`orders/${id(data.reference)}`), doc = await tx.get(ref), o = doc.data();
    if (!o) fail('Order not found.', 'not-found');
    const vendor = uid === o.vendorId, courier = uid === o.courierId, customer = uid === o.customerUid;
    if (!vendor && !courier && !customer) fail('This order belongs to another account.', 'permission-denied');
    const next = data.status;
    const legal = vendor && ({ placed: 'confirmed', confirmed: 'preparing', preparing: 'ready' })[o.status] === next
      || courier && o.status === 'ready' && next === 'pickedUp'
      || courier && o.status === 'pickedUp' && next === 'handedOver'
      || next === 'cancelled' && (vendor && ['placed', 'confirmed', 'preparing', 'ready'].includes(o.status) || customer && o.status === 'placed');
    if (!legal) fail('This action is no longer available. Refresh the order.');
    let secret;
    if (next === 'handedOver') {
      const secretRef = db.doc(`orderSecrets/${o.reference}`);
      secret = (await tx.get(secretRef)).data();
      if (secret.lockedUntil && secret.lockedUntil.toMillis() > Date.now()) return { error: 'Too many incorrect codes. Wait 10 minutes before trying again.' };
      if (typeof data.code !== 'string' || data.code !== secret.verificationCode) {
        const attempts = secret.attempts + 1;
        tx.update(secretRef, { attempts, lockedUntil: attempts % 5 === 0 ? Timestamp.fromMillis(Date.now() + 600000) : null });
        return { error: 'Incorrect handover code. Ask the customer for the four-digit code.' };
      }
    }
    const products = next === 'cancelled' ? await tx.getAll(...o.items.map(i => db.doc(`vendors/${o.vendorId}/products/${i.product.id}`))) : [];
    change(tx, ref, o, { status: next, ...(next === 'handedOver' ? { deliveredAt: FieldValue.serverTimestamp() } : {}) });
    audit(tx, { type: 'orderStatusChanged', reference: o.reference, vendorId: o.vendorId, courierId: o.courierId || null, fromStatus: o.status, toStatus: next, actorUid: uid, actorRole: vendor ? 'vendor' : courier ? 'courier' : 'customer' });
    if (['handedOver', 'cancelled'].includes(next)) {
      if (o.courierId) tx.update(db.doc(`couriers/${o.courierId}`), { activeOrderId: null });
      tx.delete(db.doc(`orderTracking/${o.reference}`));
      tx.delete(db.doc(`orderSecrets/${o.reference}`));
    }
    products.forEach((p, i) => { if (p.exists) tx.update(p.ref, { stock: p.data().stock + o.items[i].quantity, updatedAt: FieldValue.serverTimestamp() }); });
    return { reference: o.reference, status: next };
  });
}
async function dispatch(request) {
  if (!request.auth) fail('Sign in to continue.', 'unauthenticated');
  const uid = request.auth.uid, data = request.data ?? {};
  if (typeof data.action === 'string' && data.action.startsWith('admin')) return dispatchAdmin(request);
  switch (data.action) {
    case 'createOrder': return createOrder(uid, data);
    case 'registerCourier': return registerCourier(uid, data);
    case 'presence': return presence(uid, data);
    case 'nearby': return nearby(uid);
    case 'nearbyCouriers': return nearbyCouriers(uid, data);
    case 'assignCourier': return assignCourier(uid, data);
    case 'claim': return claim(uid, data);
    case 'transition': return transition(uid, data);
    default: fail('Unknown action.', 'invalid-argument');
  }
}
exports.fulfillment = onCall({ region: 'asia-south1', maxInstances: 10, timeoutSeconds: 30, memory: '256MiB' }, dispatch);
