'use strict';
const { getFirestore, FieldPath, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { createHash } = require('node:crypto');
const error = (message, code = 'invalid-argument') => { throw new HttpsError(code, message); };
const statuses = ['placed', 'confirmed', 'preparing', 'ready', 'pickedUp', 'handedOver', 'cancelled'];
const activeStatuses = statuses.slice(0, 5);
const ms = v => v?.toMillis?.() ?? null;
const fields = (data, keys) => Object.fromEntries(keys.filter(k => data[k] !== undefined).map(k => [k, data[k]]));
const dates = d => ({ createdAt: ms(d.createdAt), updatedAt: ms(d.updatedAt) });
const point = p => p ? { ...fields(p, ['name', 'address', 'latitude', 'longitude', 'accuracy', 'instructions']), recordedAt: ms(p.recordedAt) } : null;
function identifier(v) {
  if (typeof v !== 'string' || !/^[A-Za-z0-9_-]{1,140}$/.test(v)) error('Invalid record identifier.');
  return v;
}
function courierState(c) {
  const p = c.location, age = p?.recordedAt?.toMillis?.();
  const fresh = Number.isFinite(age) && Math.abs(Date.now() - age) <= 90000
    && Number.isFinite(p.latitude) && Math.abs(p.latitude) <= 90
    && Number.isFinite(p.longitude) && Math.abs(p.longitude) <= 180
    && Number.isFinite(p.accuracy) && p.accuracy > 0 && p.accuracy <= 150;
  return c.activeOrderId ? 'onDelivery' : !c.online ? 'offline' : fresh ? 'available' : 'stale';
}
// Explicit output contracts prevent private handover codes, auth credentials,
// or future internal fields from leaking into the monitoring dashboard.
function serialize(kind, doc) {
  if (!doc.exists) return null;
  const d = doc.data(), base = { id: doc.id, ...dates(d) };
  if (kind === 'orders') return { ...base, ...fields(d, ['reference', 'customerUid', 'vendorId', 'vendorName', 'courierId', 'courierName', 'status', 'totalPaise', 'deliveryFeePaise', 'platformFeePaise', 'paymentMethod', 'assignmentSource']), assignedAt: ms(d.assignedAt), deliveredAt: ms(d.deliveredAt), pickup: point(d.pickup), journey: d.journey ? { ...fields(d.journey, ['mode', 'operatorName', 'boarding', 'destination']), departure: ms(d.journey.departure), pickup: point(d.journey.pickup) } : null, items: (d.items || []).map(i => ({ quantity: i.quantity, product: fields(i.product || {}, ['id', 'name', 'unit', 'pricePaise', 'category']) })) };
  if (kind === 'vendors') return { ...base, ...fields(d, ['ownerUid', 'name', 'category', 'address', 'latitude', 'longitude', 'description', 'preparationMinutes', 'isOpen', 'isPublished']) };
  if (kind === 'vendorAccounts') return { ...base, ...fields(d, ['ownerName', 'email', 'phone', 'licenseNumber']) };
  if (kind === 'couriers') return { ...base, ...fields(d, ['name', 'phone', 'vehicle', 'online', 'activeOrderId']), location: point(d.location), availability: courierState(d) };
  if (kind === 'customers') return { ...base, ...fields(d, ['displayName', 'email']) };
  if (kind === 'products') return { ...base, ...fields(d, ['vendorId', 'name', 'category', 'pricePaise', 'stock', 'unit', 'description', 'strength', 'dosageForm', 'genericName', 'brand', 'manufacturer', 'expiryDate', 'prescriptionRequired', 'isPublished']) };
  if (kind === 'activity') return { ...base, ...fields(d, ['type', 'actorUid', 'actorRole', 'reference', 'vendorId', 'courierId', 'fromStatus', 'toStatus', 'name', 'online']) };
  error('Unsupported record type.');
}
function audit(tx, event) {
  tx.create(getFirestore().collection('adminActivity').doc(), { ...event, createdAt: FieldValue.serverTimestamp() });
}
async function requireAdmin(auth) {
  if (!auth) error('Sign in to continue.', 'unauthenticated');
  const role = (await getFirestore().doc(`adminAccess/${auth.uid}`).get()).data();
  // Only a privileged project owner can waive verification on an existing UID.
  // An unverified email invitation alone never grants admin access.
  if (!role || role.role !== 'superadmin' || role.enabled !== true
    || role.requireEmailVerification !== false && auth.token.email_verified !== true
    || !auth.token.email || role.email !== auth.token.email.toLowerCase()) error('This account does not have approved super-admin access.', 'permission-denied');
  return { uid: auth.uid, email: role.email, role: 'superadmin' };
}
async function claimAccess(auth) {
  if (!auth?.token.email) error('Sign in with your approved admin account.', 'permission-denied');
  const db = getFirestore(), email = auth.token.email.toLowerCase();
  const inviteRef = db.doc(`adminInvites/${createHash('sha256').update(email).digest('hex')}`);
  const roleRef = db.doc(`adminAccess/${auth.uid}`);
  await db.runTransaction(async tx => {
    const [inviteDoc, roleDoc] = await tx.getAll(inviteRef, roleRef);
    const invite = inviteDoc.data();
    if (roleDoc.exists) return; // Revoked accounts must be explicitly re-enabled by the project owner.
    if (auth.token.email_verified !== true) error('This account has not been approved for admin access. Contact the project owner.', 'permission-denied');
    if (invite?.enabled !== true || invite.email !== email || invite.usedBy && invite.usedBy !== auth.uid) error('No admin invitation is available for this account.', 'permission-denied');
    tx.create(roleRef, { role: 'superadmin', email, enabled: true, createdAt: FieldValue.serverTimestamp() });
    tx.update(inviteRef, { usedBy: auth.uid, claimedAt: FieldValue.serverTimestamp() });
    audit(tx, { type: 'adminActivated', actorUid: auth.uid, actorRole: 'admin' });
  });
  return requireAdmin(auth);
}
const collections = { orders: 'orders', vendors: 'vendors', vendorAccounts: 'vendorAccounts', couriers: 'couriers', customers: 'users', activity: 'adminActivity' };
async function list(data) {
  const db = getFirestore(), kind = data.kind;
  if (!Object.hasOwn(collections, kind) && kind !== 'products') error('Unsupported record type.');
  const size = data.pageSize ?? 25;
  if (!Number.isInteger(size) || size < 1 || size > 100) error('Page size must be between 1 and 100.');
  let q = kind === 'products' ? db.collection(`vendors/${identifier(data.vendorId)}/products`) : db.collection(collections[kind]);
  if (data.status) {
    if (kind !== 'orders' || !statuses.includes(data.status)) error('Invalid order status.');
    q = q.where('status', '==', data.status);
  }
  const byTime = kind === 'orders' || kind === 'activity';
  q = byTime ? q.orderBy('createdAt', 'desc').orderBy(FieldPath.documentId(), 'desc') : q.orderBy(FieldPath.documentId());
  if (data.cursor) {
    identifier(data.cursor.id);
    if (byTime) {
      // Preserve nanoseconds; millisecond cursors can skip documents with equal timestamps.
      const t = data.cursor.time;
      if (!t || !Number.isSafeInteger(t.seconds) || t.seconds < 0 || !Number.isInteger(t.nanoseconds) || t.nanoseconds < 0 || t.nanoseconds >= 1e9) error('Invalid page cursor.');
      q = q.startAfter(new Timestamp(t.seconds, t.nanoseconds), data.cursor.id);
    } else q = q.startAfter(data.cursor.id);
  }
  const snapshot = await q.limit(size + 1).get(), docs = snapshot.docs.slice(0, size), last = docs.at(-1);
  const t = last?.data().createdAt;
  return { items: docs.map(d => serialize(kind, d)), nextCursor: snapshot.size > size ? { id: last.id, ...(byTime ? { time: { seconds: t.seconds, nanoseconds: t.nanoseconds } } : {}) } : null };
}
async function dashboard() {
  const db = getFirestore();
  const count = async q => (await q.count().get()).data().count;
  const orders = db.collection('orders');
  const [statusCounts, vendors, openVendors, customers, partners, onlinePartners, recent, activity, deliveredValue] = await Promise.all([
    Promise.all(statuses.map(async s => [s, await count(orders.where('status', '==', s))])),
    count(db.collection('vendors')), count(db.collection('vendors').where('isOpen', '==', true)),
    count(db.collection('users')), count(db.collection('couriers')), count(db.collection('couriers').where('online', '==', true)),
    list({ kind: 'orders', pageSize: 8 }), list({ kind: 'activity', pageSize: 8 }),
    orders.where('status', '==', 'handedOver').aggregate({ total: require('firebase-admin/firestore').AggregateField.sum('totalPaise') }).get(),
  ]);
  const status = Object.fromEntries(statusCounts);
  return { generatedAt: Date.now(), radiusKm: 5, status, counts: { orders: statusCounts.reduce((n, [, c]) => n + c, 0), activeOrders: activeStatuses.reduce((n, s) => n + status[s], 0), vendors, openVendors, customers, partners, onlinePartners }, deliveredValuePaise: deliveredValue.data().total, recentOrders: recent.items, recentActivity: activity.items };
}
async function detail(data) {
  const db = getFirestore(), kind = data.kind, key = identifier(data.id);
  if (!['orders', 'vendors', 'couriers', 'customers', 'vendorAccounts'].includes(kind)) error('Unsupported detail type.');
  const record = serialize(kind, await db.doc(`${collections[kind]}/${key}`).get());
  if (!record) error('Record not found.', 'not-found');
  if (kind === 'orders') {
    const paths = [`users/${record.customerUid}`, `vendorAccounts/${record.vendorId}`, ...(record.courierId ? [`couriers/${record.courierId}`] : []), `orderTracking/${key}`];
    const docs = await db.getAll(...paths.map(p => db.doc(p)));
    return { record, customer: serialize('customers', docs[0]), vendorAccount: serialize('vendorAccounts', docs[1]), courier: record.courierId ? serialize('couriers', docs[2]) : null, tracking: point(docs.at(-1).data()) };
  }
  if (kind === 'vendors') return { record, account: serialize('vendorAccounts', await db.doc(`vendorAccounts/${key}`).get()), products: await list({ kind: 'products', vendorId: key }) };
  if (kind === 'vendorAccounts') return { record, shop: serialize('vendors', await db.doc(`vendors/${key}`).get()) };
  return { record };
}
async function dispatchAdmin(request) {
  const data = request.data || {};
  if (data.action === 'adminClaimAccess') return claimAccess(request.auth);
  const identity = await requireAdmin(request.auth); // Always read role again, including after revocation.
  switch (data.action) {
    case 'adminSession': return identity;
    case 'adminDashboard': return dashboard();
    case 'adminList': return list(data);
    case 'adminDetail': return detail(data);
    default: error('Unknown admin action.');
  }
}
module.exports = { dispatchAdmin, audit };
