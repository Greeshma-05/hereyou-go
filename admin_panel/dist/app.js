import { initializeApp } from 'https://www.gstatic.com/firebasejs/12.19.0/firebase-app.js';
import { getAuth, connectAuthEmulator, setPersistence, browserSessionPersistence, onAuthStateChanged, signInWithEmailAndPassword, sendPasswordResetEmail, signOut, updatePassword, reauthenticateWithCredential, EmailAuthProvider } from 'https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js';
import { firebaseConfig, endpoint, authEmulator } from './config.js';

const $ = id => document.getElementById(id);
const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const num = value => new Intl.NumberFormat('en-IN').format(value ?? 0);
const money = value => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 }).format((value ?? 0) / 100);
const date = value => value ? new Date(value).toLocaleString(undefined, { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : 'Not recorded';
const shortDate = value => value ? new Date(value).toLocaleString(undefined, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : 'Not recorded';
const age = value => { if (!value) return 'No GPS fix'; const s = Math.max(0, Math.round((Date.now() - value) / 1000)); return s < 60 ? `${s}s ago` : s < 3600 ? `${Math.floor(s / 60)}m ago` : s < 86400 ? `${Math.floor(s / 3600)}h ago` : `${Math.floor(s / 86400)}d ago`; };
const paths = {
 overview: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
 orders: '<path d="m3 7 9-4 9 4-9 4-9-4Zm0 0v10l9 4 9-4V7M12 11v10M7 5l10 4"/>',
 vendors: '<path d="M3 10h18l-2-6H5l-2 6Zm1 0v10h16V10M9 20v-6h6v6M3 10c0 4 5 4 5 0 0 4 8 4 8 0 0 4 5 4 5 0"/>',
 couriers: '<circle cx="5" cy="17" r="3"/><circle cx="19" cy="17" r="3"/><path d="m5 17 5-9 5 9H5m5-9h6l3 9M8 5h4M16 5l2 3"/>',
 customers: '<circle cx="9" cy="8" r="3"/><path d="M3 21v-3a6 6 0 0 1 12 0v3M16 5a3 3 0 0 1 0 6M18 15a5 5 0 0 1 3 5"/>',
 activity: '<path d="M3 12h4l3-8 4 16 3-8h4"/>',
 info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10v1"/>',
 search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/>',
 arrow: '<path d="M4 12h16m-6-6 6 6-6 6"/>',
};
const icon = name => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] || paths.info}</svg>`;
const labels = { placed: 'New order', confirmed: 'Accepted', preparing: 'Preparing', ready: 'Ready for pickup', pickedUp: 'On the way', handedOver: 'Delivered', cancelled: 'Cancelled', available: 'Available', offline: 'Offline', stale: 'GPS stale', onDelivery: 'On delivery' };
const badge = status => `<span class="badge ${['handedOver', 'available', 'ready'].includes(status) ? 'green' : ['placed', 'preparing', 'stale'].includes(status) ? 'amber' : ['confirmed', 'pickedUp', 'onDelivery'].includes(status) ? 'blue' : status === 'cancelled' ? 'red' : ''}">${esc(labels[status] || status)}</span>`;
const recordLink = (kind, id, label) => id ? `<button class="record-button" data-kind="${esc(kind)}" data-record="${esc(id)}">${esc(label || id)}</button>` : '<span class="muted">Unassigned</span>';
const empty = (title, text, type = 'orders') => `<div class="empty">${icon(type)}<strong>${esc(title)}</strong>${esc(text)}</div>`;
const loading = text => `<div class="loader"><span class="spinner"></span>${esc(text || 'Loading your live records…')}</div>`;
const views = {
 overview: ['Overview', 'Operations overview', 'A shared view of your three apps.', 'YOUR NETWORK AT A GLANCE'],
 orders: ['Orders', 'Every order, in view.', 'Follow the journey from checkout to handover.', 'CUSTOMER → VENDOR → DELIVERY'],
 vendors: ['Vendors', 'Your vendor network', 'Shops, pickup locations and their current inventory.', 'SHOPS & INVENTORY'],
 vendorAccounts: ['Vendor accounts', 'Vendor account profiles', 'Registered owners, including those still setting up their shop.', 'VENDOR DIRECTORY'],
 couriers: ['Delivery partners', 'Your delivery network', 'Availability, active assignments and the latest recorded GPS fix.', '5 KM PICKUP RADIUS'],
 customers: ['Customers', 'Your customers', 'Customer profiles saved by the Here You Go app.', 'CUSTOMER DIRECTORY'],
 activity: ['Activity log', 'What’s happening', 'A timestamped record of order and delivery changes.', 'NETWORK ACTIVITY'],
 info: ['About this panel', 'A clear view of your network', 'What this dashboard monitors and how it stays current.', 'WORKSPACE GUIDE'],
};
const state = { user: null, admin: null, view: 'overview', items: [], cursor: null, status: '', search: '', pageRequest: 0, detailRequest: 0, session: 0, busy: false, loadedAt: null, lastInteraction: Date.now() };
const controllers = new Set();
const app = initializeApp(firebaseConfig), auth = getAuth(app);
if (authEmulator) {
  if (!['localhost', '127.0.0.1'].includes(location.hostname)) throw new Error('Local test configuration cannot run on a hosted site.');
  connectAuthEmulator(auth, authEmulator, { disableWarnings: true });
}
await setPersistence(auth, browserSessionPersistence);

function friendly(error) {
  const code = error?.code || '';
  if (['auth/invalid-credential', 'auth/wrong-password', 'auth/user-not-found'].includes(code)) return 'The email or password is incorrect. Use the admin login provided by your project owner, or choose Forgot password.';
  if (code === 'auth/weak-password') return 'Choose a stronger password with at least 10 characters.';
  if (code === 'auth/too-many-requests') return 'Too many attempts. Please wait a few minutes before trying again.';
  if (code === 'auth/invalid-email') return 'Enter a valid email address.';
  if (code === 'auth/network-request-failed' || error instanceof TypeError) return 'Cannot reach the service. Check your connection and try again.';
  if (error?.name === 'AbortError' || error?.name === 'TimeoutError') return 'The service is taking longer than expected. It may be waking up; please refresh in a moment.';
  if (code === 'INTERNAL') return 'The service could not load this view. Please try again.';
  return error?.message || 'Something went wrong. Please try again.';
}
async function api(action, data = {}) {
  const user = state.user, session = state.session;
  if (!user) throw new Error('Sign in to continue.');
  const controller = new AbortController(); controllers.add(controller);
  const timeout = setTimeout(() => controller.abort(), 120000);
  try {
    const token = await user.getIdToken();
    const response = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` }, body: JSON.stringify({ data: { action, ...data } }), signal: controller.signal, cache: 'no-store' });
    const result = await response.json();
    if (session !== state.session) throw new DOMException('Session ended', 'AbortError');
    if (result.error || !response.ok) { const e = new Error(result.error?.message || 'Could not load this data.'); e.code = result.error?.status; throw e; }
    return result.result ?? result.data;
  } finally { clearTimeout(timeout); controllers.delete(controller); }
}
function authMessage(message, error = false) { $('auth-message').textContent = message; $('auth-message').classList.toggle('error', error); }
function lockedScreen(user) {
  $('auth-screen').hidden = false; $('workspace').hidden = true;
  $('auth-form').hidden = !!user; $('forgot').hidden = !!user; $('auth-signout').hidden = !user;
  $('auth-heading').textContent = user ? 'Checking your access…' : 'Welcome back.';
  $('auth-description').textContent = user ? 'The service may take about a minute to wake up.' : 'Sign in with your approved Here You Go account.';
  authMessage('');
}
async function enter(user) {
  const session = state.session;
  lockedScreen(user);
  if (!user) return;
  try {
    state.admin = await api('adminClaimAccess');
    if (session !== state.session) return;
    $('auth-screen').hidden = true; $('workspace').hidden = false; $('account-email').textContent = state.admin.email;
    authMessage(''); navigate();
  } catch (e) { if (session === state.session) { $('auth-heading').textContent = 'Access unavailable'; $('auth-description').textContent = 'Only an approved admin account can open this workspace.'; authMessage(friendly(e), true); } }
}
onAuthStateChanged(auth, user => {
  state.session++; state.pageRequest++; state.detailRequest++; state.user = user; state.admin = null; state.items = []; state.cursor = null; state.busy = false;
  for (const controller of controllers) controller.abort();
  $('content').replaceChildren(); $('detail-content').replaceChildren(); $('detail-dialog').close(); $('password').value = ''; $('page-error').hidden = true;
  enter(user);
});
$('auth-submit').disabled = false; $('auth-submit').textContent = 'Open dashboard';
$('auth-form').onsubmit = async e => {
  e.preventDefault(); $('auth-submit').disabled = true; authMessage('Connecting securely…');
  const email = $('email').value.trim(), password = $('password').value;
  try {
    await signInWithEmailAndPassword(auth, email, password);
  } catch (error) { authMessage(friendly(error), true); }
  finally { $('auth-submit').disabled = false; }
};
$('forgot').onclick = async () => {
  if (!$('email').reportValidity()) return;
  $('forgot').disabled = true;
  try { await sendPasswordResetEmail(auth, $('email').value.trim()); authMessage('If an account exists, a password reset email is on its way.'); } catch (e) { authMessage(friendly(e), true); } finally { $('forgot').disabled = false; }
};
const logout = () => signOut(auth).catch(e => authMessage(friendly(e), true));
$('logout').onclick = logout; $('auth-signout').onclick = logout;

$('today').textContent = new Date().toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' });
$('nav').innerHTML = ['overview', 'orders', 'vendors', 'couriers', 'customers', 'activity', 'info'].map(key => `<a class="nav-link" href="#${key}" data-view="${key}">${icon(key)}<span>${views[key][0]}</span><span class="nav-arrow" aria-hidden="true">${key === 'overview' ? '↗' : ''}</span></a>`).join('');
$('menu-toggle').onclick = () => { const open = $('sidebar').classList.toggle('open'); $('menu-toggle').setAttribute('aria-expanded', String(open)); };
document.addEventListener('click', e => {
  state.lastInteraction = Date.now();
  if (!$('sidebar').contains(e.target) && !$('menu-toggle').contains(e.target)) { $('sidebar').classList.remove('open'); $('menu-toggle').setAttribute('aria-expanded', 'false'); }
  const record = e.target.closest('[data-record]');
  if (record) openDetail(record.dataset.kind, record.dataset.record);
});
document.addEventListener('keydown', () => { state.lastInteraction = Date.now(); });
window.addEventListener('hashchange', navigate);
function navigate() {
  if (!state.admin) return;
  const key = location.hash.slice(1); state.view = Object.hasOwn(views, key) ? key : 'overview';
  state.status = ''; state.search = ''; state.items = []; state.cursor = null;
  const [label, title, description, kicker] = views[state.view];
  $('breadcrumb').textContent = label; $('page-title').textContent = title; $('page-description').textContent = description; $('page-kicker').textContent = kicker;
  document.querySelectorAll('[data-view]').forEach(el => { const selected = el.dataset.view === (state.view === 'vendorAccounts' ? 'vendors' : state.view); el.classList.toggle('active', selected); if (selected) el.setAttribute('aria-current', 'page'); else el.removeAttribute('aria-current'); });
  $('sidebar').classList.remove('open'); $('menu-toggle').setAttribute('aria-expanded', 'false');
  $('content').innerHTML = loading(); loadView();
}
function syncLabel(error = false) {
  $('status-strip').classList.toggle('stale', error);
  const prefix = authEmulator ? 'LOCAL TEST DATABASE · ' : '';
  $('sync-status').textContent = prefix + (error ? 'Update failed · data may be out of date' : state.loadedAt ? `Database synced ${new Date(state.loadedAt).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })}` : 'Connecting to your database…');
}
async function loadView(more = false) {
  const request = ++state.pageRequest, session = state.session, view = state.view;
  state.busy = true; $('refresh').disabled = true; $('page-error').hidden = true;
  if (!more && !state.loadedAt) $('sync-status').textContent = 'Loading your records · the service may take a minute to wake up…';
  try {
    if (view === 'info') { await api('adminSession'); if (request !== state.pageRequest) return; renderInfo(); }
    else if (view === 'overview') { const dashboard = await api('adminDashboard'); if (request !== state.pageRequest) return; renderOverview(dashboard); }
    else {
      const result = await api('adminList', { kind: view, pageSize: 25, ...(state.status ? { status: state.status } : {}), ...(more && state.cursor ? { cursor: state.cursor } : {}) });
      if (request !== state.pageRequest) return;
      state.items = more ? [...state.items, ...result.items] : result.items; state.cursor = result.nextCursor; renderList();
    }
    state.loadedAt = Date.now(); syncLabel();
  } catch (e) {
    if (request !== state.pageRequest || session !== state.session) return;
    if (e.code === 'PERMISSION_DENIED' || e.code === 'UNAUTHENTICATED') { state.admin = null; state.items = []; $('content').replaceChildren(); $('detail-dialog').close(); lockedScreen(state.user); $('auth-heading').textContent = 'Access unavailable'; authMessage(friendly(e), true); return; }
    $('page-error').hidden = false; $('page-error').textContent = friendly(e); syncLabel(true);
    if ($('content').querySelector('.loader')) $('content').innerHTML = empty('Data could not be loaded', 'Use Refresh to try again.', 'info');
  } finally { if (request === state.pageRequest) { state.busy = false; $('refresh').disabled = false; const moreButton = $('load-more'); if (moreButton) moreButton.disabled = false; } }
}
$('refresh').onclick = () => loadView();
setInterval(() => {
  if (!state.admin || state.busy || document.hidden || !$('auto-refresh').checked || $('detail-dialog').open || state.view === 'info') return;
  if (Date.now() - state.lastInteraction > 300000) { $('sync-status').textContent = 'Automatic updates paused while idle · use Refresh to resume'; return; }
  if (state.items.length > 25 || state.search || document.activeElement?.matches('input,select')) return;
  loadView();
}, 60000);

function stat(label, value, foot, type, emphasis = false) { return `<div class="stat ${emphasis ? 'emphasis' : ''}"><div class="stat-label">${esc(label)}<span class="stat-icon">${icon(type)}</span></div><div class="stat-value">${num(value)}</div><div class="stat-foot">${esc(foot)}</div></div>`; }
function orderTable(items, compact = false) {
  if (!items.length) return empty('No orders here yet', 'Placed customer orders will appear here automatically.');
  return `<div class="table-scroll"><table><thead><tr><th>ORDER / VENDOR</th><th>STATUS</th>${compact ? '' : '<th>PARTNER</th><th>JOURNEY</th>'}<th>AMOUNT</th><th>PLACED</th></tr></thead><tbody>${items.map(o => `<tr><td>${recordLink('orders', o.id, o.reference)}<small>${esc(o.vendorName || o.vendorId)}</small></td><td>${badge(o.status)}</td>${compact ? '' : `<td>${o.courierId ? recordLink('couriers', o.courierId, o.courierName) : '<span class="muted">Unassigned</span>'}</td><td>${esc(o.journey?.boarding || '—')} → ${esc(o.journey?.destination || '—')}</td>`}<td class="money">${money(o.totalPaise)}</td><td>${shortDate(o.createdAt)}</td></tr>`).join('')}</tbody></table></div>`;
}
function eventText(e) {
  switch (e.type) {
    case 'orderCreated': return ['New customer order', `${e.reference} · placed with vendor`];
    case 'orderStatusChanged': return [`Order ${labels[e.toStatus]?.toLowerCase() || e.toStatus}`, `${e.reference} · ${labels[e.fromStatus] || e.fromStatus} → ${labels[e.toStatus] || e.toStatus}`];
    case 'courierAssigned': return ['Delivery partner assigned', `${e.name || 'Partner'} · ${e.reference}`];
    case 'courierRegistered': return ['Delivery partner registered', e.name || e.courierId];
    case 'courierProfileUpdated': return ['Partner profile updated', e.name || e.courierId];
    case 'courierAvailability': return [e.online ? 'Partner went online' : 'Partner went offline', e.name || e.courierId];
    case 'adminActivated': return ['Admin access activated', 'Approved administrator joined the workspace'];
    default: return ['Activity recorded', e.type];
  }
}
function activityList(items) {
  return items.length ? `<div class="activity-list">${items.map(e => { const [title, sub] = eventText(e); return `<div class="event"><span class="event-icon">${icon(e.reference ? 'orders' : e.courierId ? 'couriers' : 'info')}</span><div class="event-content"><strong>${esc(title)}</strong><p>${esc(sub)}${e.reference ? ` · ${recordLink('orders', e.reference, 'View order')}` : e.courierId ? ` · ${recordLink('couriers', e.courierId, 'View partner')}` : ''}</p></div><time title="${esc(date(e.createdAt))}">${shortDate(e.createdAt)}</time></div>`; }).join('')}</div>` : empty('Your activity log starts here', 'New order, assignment and availability changes will be recorded from now on.', 'activity');
}
function renderOverview(d) {
  const c = d.counts, active = ['placed', 'confirmed', 'preparing', 'ready', 'pickedUp'], max = Math.max(1, ...active.map(s => d.status[s]));
  $('content').innerHTML = `<div class="stats-grid">${stat('Active orders', c.activeOrders, `${num(d.status.placed)} awaiting vendor acceptance`, 'orders', true)}${stat('Total orders', c.orders, `${num(d.status.handedOver)} delivered · ${num(d.status.cancelled)} cancelled`, 'overview')}${stat('Vendor network', c.vendors, `${num(c.openVendors)} marked open`, 'vendors')}${stat('Delivery partners', c.partners, `${num(c.onlinePartners)} marked online · check GPS freshness`, 'couriers')}</div>
    <div class="overview-grid"><div><section class="panel"><div class="panel-head"><div><h3>Recent orders</h3><p class="muted">The latest orders across your network</p></div><a class="text-button" href="#orders">View all orders ↗</a></div>${orderTable(d.recentOrders, true)}</section>
    <section class="panel"><div class="panel-head"><div><h3>Latest activity</h3><p class="muted">Order updates, assignments and partner availability</p></div><a class="text-button" href="#activity">View log ↗</a></div>${activityList(d.recentActivity)}</section></div>
    <div class="overview-side"><section class="panel"><div class="panel-head"><h3>Order pipeline</h3><span class="count-tag">${num(c.activeOrders)} active</span></div><div class="pipeline">${active.map(s => `<div class="pipeline-row"><span>${esc(labels[s])}</span><div class="bar"><span style="width:${d.status[s] / max * 100}%"></span></div><strong>${num(d.status[s])}</strong></div>`).join('')}</div></section>
    <section class="panel"><div class="panel-head"><h3>Your three apps</h3><span class="header-tag">Connected</span></div><div class="network-summary">${[['customers', 'Customer app', 'Saved customer profiles', c.customers], ['vendors', 'Vendor app', 'Registered shops', c.vendors], ['couriers', 'Delivery app', `${d.radiusKm} km pickup radius`, c.partners]].map(([kind, name, sub, count]) => `<div class="network-row"><span class="stat-icon">${icon(kind)}</span><div><strong>${name}</strong><small>${sub}</small></div><b>${num(count)}</b></div>`).join('')}</div></section>
    <section class="panel value-panel"><p>Delivered order value · all time</p><strong>${money(d.deliveredValuePaise)}</strong><small>Value of completed orders, including fees.<br>Cash on delivery; this is not a payout balance.</small></section></div></div>`;
}
function renderList() {
  const view = state.view;
  $('content').innerHTML = `${view === 'activity' ? '<div class="info-note">Activity history begins when monitoring was enabled. Shop, product and customer edits are visible in their current records; they are not recorded as historical events here.</div>' : view === 'couriers' ? '<div class="info-note">Available means online, unassigned, and a GPS fix no older than 90 seconds with accuracy within 150 m. A partner must also be within 5 km of a pickup to be assigned. Locations below are last recorded positions.</div>' : ''}
    <div class="toolbar"><div class="search-wrap">${icon('search')}<input type="search" id="record-search" aria-label="Search loaded records" placeholder="Search loaded records…" value="${esc(state.search)}"></div>${view === 'orders' ? `<select id="order-status" aria-label="Filter by order status"><option value="">All statuses</option>${Object.entries(labels).filter(([key]) => ['placed', 'confirmed', 'preparing', 'ready', 'pickedUp', 'handedOver', 'cancelled'].includes(key)).map(([key, value]) => `<option value="${key}" ${state.status === key ? 'selected' : ''}>${value}</option>`).join('')}</select>` : ''}${view === 'vendors' ? '<a class="button" href="#vendorAccounts">Owner profiles ↗</a>' : view === 'vendorAccounts' ? '<a class="button" href="#vendors">View shops ↗</a>' : ''}<button id="export" class="button">↓ Export loaded CSV</button></div>
    <p class="list-caption" id="list-caption"></p><section class="panel" id="records"></section><div class="pagination"><span id="pagination-label"></span>${state.cursor ? '<button id="load-more" class="button">Load next 25</button>' : ''}</div>${view === 'orders' ? '<div class="detail-block"><h3>Find a specific order</h3><form id="lookup-form" class="lookup-form"><input id="order-reference" type="text" placeholder="Full order reference" aria-label="Full order reference" maxlength="140" required pattern="[A-Za-z0-9_-]+"><button class="button" type="submit">Find order</button></form></div>' : ''}`;
  updateRows();
  $('record-search').oninput = e => { state.search = e.target.value; updateRows(); };
  if ($('order-status')) $('order-status').onchange = e => { state.status = e.target.value; state.cursor = null; state.items = []; $('records').innerHTML = loading(); loadView(); };
  if ($('load-more')) $('load-more').onclick = () => { $('load-more').disabled = true; loadView(true); };
  if ($('lookup-form')) $('lookup-form').onsubmit = e => { e.preventDefault(); openDetail('orders', $('order-reference').value.trim()); };
  $('export').onclick = exportCSV;
}
function visibleItems() { const q = state.search.trim().toLowerCase(); return q ? state.items.filter(r => JSON.stringify(r).toLowerCase().includes(q)) : state.items; }
function updateRows() {
  const items = visibleItems(), view = state.view;
  $('list-caption').textContent = `${num(items.length)} shown of ${num(state.items.length)} loaded${state.cursor ? ' · More records are available below' : ' · All matching records loaded'}${state.search ? ' · Search applies to loaded records only' : ''}`;
  $('pagination-label').textContent = state.cursor ? 'Browse older / additional records' : 'End of records';
  if (!items.length) { $('records').innerHTML = empty(state.search ? 'No matches in loaded records' : 'No records yet', state.search ? 'Try a different search or load more records.' : 'Records will appear as people use the apps.', view); return; }
  if (view === 'orders') { $('records').innerHTML = orderTable(items); return; }
  if (view === 'activity') { $('records').innerHTML = activityList(items); return; }
  let headings, rows;
  if (view === 'vendors') { headings = ['SHOP', 'CATEGORY', 'STATUS', 'PICKUP ADDRESS', 'UPDATED']; rows = items.map(v => `<td>${recordLink('vendors', v.id, v.name)}<small>${esc(v.id)}</small></td><td>${esc(v.category)}</td><td>${badge(v.isOpen ? 'Open' : 'Closed')} <small>${v.isPublished ? 'Published' : 'Unpublished'}</small></td><td>${esc(v.address)}</td><td>${shortDate(v.updatedAt)}</td>`); }
  if (view === 'vendorAccounts') { headings = ['OWNER', 'EMAIL', 'PHONE', 'LICENSE', 'UPDATED']; rows = items.map(v => `<td>${recordLink('vendorAccounts', v.id, v.ownerName)}</td><td>${esc(v.email)}</td><td>${esc(v.phone)}</td><td>${esc(v.licenseNumber || 'Not provided')}</td><td>${shortDate(v.updatedAt)}</td>`); }
  if (view === 'couriers') { headings = ['PARTNER', 'AVAILABILITY', 'VEHICLE / PHONE', 'ACTIVE ORDER', 'LAST GPS FIX']; rows = items.map(c => `<td>${recordLink('couriers', c.id, c.name)}</td><td>${badge(c.availability)}${c.activeOrderId && !c.online ? '<small>Currently offline</small>' : ''}</td><td>${esc(c.vehicle)}<small>${esc(c.phone)}</small></td><td>${c.activeOrderId ? recordLink('orders', c.activeOrderId) : '—'}</td><td>${age(c.location?.recordedAt)}<small>${c.location?.accuracy ? `±${Math.round(c.location.accuracy)} m accuracy` : 'No location recorded'}</small></td>`); }
  if (view === 'customers') { headings = ['CUSTOMER', 'EMAIL', 'JOINED', 'UPDATED']; rows = items.map(c => `<td>${recordLink('customers', c.id, c.displayName || 'Unnamed customer')}<small>${esc(c.id)}</small></td><td>${esc(c.email || 'Not provided')}</td><td>${shortDate(c.createdAt)}</td><td>${shortDate(c.updatedAt)}</td>`); }
  $('records').innerHTML = `<div class="table-scroll"><table><thead><tr>${headings.map(h => `<th>${h}</th>`).join('')}</tr></thead><tbody>${rows.map(r => `<tr>${r}</tr>`).join('')}</tbody></table></div>`;
}
function exportCSV() {
  const items = visibleItems(); if (!items.length) return;
  const columns = { orders: ['reference', 'vendorName', 'status', 'courierName', 'customerUid', 'totalPaise', 'createdAt'], vendors: ['id', 'name', 'category', 'address', 'isOpen', 'isPublished', 'updatedAt'], vendorAccounts: ['id', 'ownerName', 'email', 'phone', 'licenseNumber'], couriers: ['id', 'name', 'phone', 'vehicle', 'availability', 'activeOrderId'], customers: ['id', 'displayName', 'email', 'createdAt'], activity: ['id', 'type', 'reference', 'actorRole', 'fromStatus', 'toStatus', 'createdAt'] }[state.view];
  const cell = v => { let text = String(v ?? ''); if (/^[\s]*[=+@\-]/.test(text)) text = "'" + text; return '"' + text.replaceAll('"', '""') + '"'; };
  const csv = [columns.map(cell).join(','), ...items.map(r => columns.map(c => cell(c.endsWith('At') && r[c] ? new Date(r[c]).toISOString() : r[c])).join(','))].join('\r\n');
  const url = URL.createObjectURL(new Blob(['\uFEFF', csv], { type: 'text/csv;charset=utf-8' }));
  const a = document.createElement('a'); a.href = url; a.download = `here-you-go-${state.view}-${new Date().toISOString().slice(0, 10)}.csv`; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
}
const field = (label, value) => `<div class="detail-field"><dt>${esc(label)}</dt><dd>${esc(value ?? 'Not provided')}</dd></div>`;
const block = (title, body) => `<section class="detail-block"><h3>${esc(title)}</h3>${body}</section>`;
const mapLink = (p, title = 'View location on map') => p && Number.isFinite(p.latitude) && Number.isFinite(p.longitude) ? `<a class="button" target="_blank" rel="noopener noreferrer" href="https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${p.latitude},${p.longitude}`)}">${esc(title)} ↗</a>` : '';
function person(title, person, kind, name) { return block(title, person ? `<p>${recordLink(kind, person.id, person[name] || person.id)}</p><dl>${field('Email / phone', person.email || person.phone)}${person.vehicle ? field('Vehicle', person.vehicle) : ''}</dl>` : '<p class="muted">Profile not yet saved.</p>'); }
async function openDetail(kind, id) {
  const request = ++state.detailRequest, session = state.session;
  $('detail-kicker').textContent = `${views[kind]?.[0] || 'Record'} / DETAILS`; $('detail-title').textContent = id;
  $('detail-content').innerHTML = loading('Loading record…');
  if (!$('detail-dialog').open) $('detail-dialog').showModal();
  try {
    const d = await api('adminDetail', { kind, id });
    if (request !== state.detailRequest || session !== state.session) return;
    const r = d.record; $('detail-title').textContent = r.reference || r.name || r.displayName || r.ownerName || r.id;
    if (kind === 'orders') {
      $('detail-content').innerHTML = `<p>${badge(r.status)} <span class="small muted">${esc(r.reference)}</span></p><div class="detail-grid">${block('Order', `<dl>${field('Placed', date(r.createdAt))}${field('Updated', date(r.updatedAt))}${field('Total · cash on delivery', money(r.totalPaise))}${field('Delivery fee', money(r.deliveryFeePaise))}${field('Platform fee', money(r.platformFeePaise))}</dl>`)}${block('Assignment', `<p>${r.courierId ? recordLink('couriers', r.courierId, r.courierName) : 'Not assigned yet'}</p><dl>${field('Assigned by', r.assignmentSource || 'Not assigned')}${field('Assigned at', r.assignedAt ? date(r.assignedAt) : 'Not assigned')}${field('Delivered at', r.deliveredAt ? date(r.deliveredAt) : 'Not delivered')}</dl>`)}</div>
      ${block('Items', `<div class="table-scroll"><table><thead><tr><th>PRODUCT</th><th>QUANTITY</th><th>UNIT PRICE</th><th>LINE TOTAL</th></tr></thead><tbody>${r.items.map(i => `<tr><td>${esc(i.product.name)}</td><td>${num(i.quantity)}</td><td>${money(i.product.pricePaise)}</td><td>${money(i.quantity * i.product.pricePaise)}</td></tr>`).join('')}</tbody></table></div>`)}
      <div class="detail-grid">${block('Vendor pickup', `<p>${recordLink('vendors', r.vendorId, r.vendorName)}</p><p class="muted">${esc(r.pickup?.address)}</p>${mapLink(r.pickup)}`)}${block('Customer handoff', `<dl>${field('Stop', r.journey?.pickup?.name)}${field('Instructions', r.journey?.pickup?.instructions)}${field('Journey', `${r.journey?.boarding || '—'} → ${r.journey?.destination || '—'}`)}${field('Travel', `${r.journey?.mode || ''} · ${r.journey?.operatorName || ''}`)}${field('Departure', date(r.journey?.departure))}</dl>${mapLink(r.journey?.pickup)}`)}</div>
      <div class="detail-grid">${person('Customer', d.customer, 'customers', 'displayName')}${person('Vendor owner', d.vendorAccount, 'vendorAccounts', 'ownerName')}</div>
      ${block('Delivery tracking', d.tracking ? `<p>Last recorded ${esc(date(d.tracking.recordedAt))} · ${age(d.tracking.recordedAt)}</p><p class="muted">Accuracy ±${num(d.tracking.accuracy)} m. This position may be stale.</p>${mapLink(d.tracking, 'View recorded partner location')}` : '<p class="muted">No active tracking point. Tracking is removed after delivery or cancellation.</p>')}
      <p class="detail-note">Handover codes remain private to the customer. This view does not display them.</p>`;
    } else if (kind === 'vendors') {
      $('detail-content').innerHTML = `<div class="detail-grid">${block('Shop profile', `<p>${badge(r.isOpen ? 'Open' : 'Closed')} ${badge(r.isPublished ? 'Published' : 'Unpublished')}</p><dl>${field('Category', r.category)}${field('Description', r.description)}${field('Address', r.address)}${field('Preparation time', `${r.preparationMinutes ?? '—'} minutes`)}${field('Updated', date(r.updatedAt))}</dl>${mapLink(r, 'View pickup location')}`)}${person('Owner', d.account, 'vendorAccounts', 'ownerName')}</div><h3>Shop inventory</h3><div id="products"></div><button id="more-products" class="button" hidden>Load more products</button>`;
      let products = d.products.items, cursor = d.products.nextCursor;
      const renderProducts = () => { $('products').innerHTML = products.length ? `<div class="product-grid">${products.map(p => `<article class="product-card"><h3>${esc(p.name)}</h3><p>${money(p.pricePaise)} / ${esc(p.unit || 'item')} · ${num(p.stock)} in stock</p><p>${esc(p.category || '')}${p.brand ? ` · ${esc(p.brand)}` : ''}</p><p>${esc(p.description || '')}</p>${p.expiryDate ? `<p>Expires: ${esc(p.expiryDate)}</p>` : ''}<p>${badge(p.isPublished ? 'Published' : 'Unpublished')}${p.prescriptionRequired ? ' · Prescription required' : ''}</p></article>`).join('')}</div>` : empty('No products saved', 'Products will appear when the vendor adds inventory.', 'vendors'); $('more-products').hidden = !cursor; };
      renderProducts();
      $('more-products').onclick = async () => { $('more-products').disabled = true; try { const page = await api('adminList', { kind: 'products', vendorId: id, cursor }); if (request !== state.detailRequest) return; products.push(...page.items); cursor = page.nextCursor; renderProducts(); } catch (e) { if (request === state.detailRequest) $('more-products').textContent = `Retry: ${friendly(e)}`; } finally { if (request === state.detailRequest) $('more-products').disabled = false; } };
    } else if (kind === 'couriers') {
      $('detail-content').innerHTML = `${block('Partner profile', `<p>${badge(r.availability)}</p><dl>${field('Phone', r.phone)}${field('Vehicle', r.vehicle)}${field('Marked online', r.online ? 'Yes' : 'No')}${field('Profile updated', date(r.updatedAt))}</dl><p style="margin-top:16px">Active order: ${r.activeOrderId ? recordLink('orders', r.activeOrderId) : 'None'}</p>`)}${block('Last recorded location', r.location ? `<dl>${field('Coordinates', `${r.location.latitude}, ${r.location.longitude}`)}${field('Accuracy', `±${Math.round(r.location.accuracy)} metres`)}${field('Captured', `${date(r.location.recordedAt)} · ${age(r.location.recordedAt)}`)}</dl>${mapLink(r.location)}` : '<p class="muted">No device location has been synced yet.</p>')}<p class="detail-note">The partner must go online in the delivery app with precise location enabled. GPS fixes older than 90 seconds do not qualify for new assignments.</p>`;
    } else if (kind === 'customers') {
      $('detail-content').innerHTML = block('Customer profile', `<dl>${field('Name', r.displayName)}${field('Email', r.email)}${field('Account ID', r.id)}${field('Joined', date(r.createdAt))}${field('Updated', date(r.updatedAt))}</dl><p class="detail-note">Use this account ID to search loaded orders for this customer.</p>`);
    } else {
      $('detail-content').innerHTML = block('Vendor owner', `<dl>${field('Name', r.ownerName)}${field('Email', r.email)}${field('Phone', r.phone)}${field('License number', r.licenseNumber)}${field('Joined', date(r.createdAt))}</dl><p style="margin-top:16px">Shop: ${d.shop ? recordLink('vendors', d.shop.id, d.shop.name) : 'Not set up yet'}</p>`);
    }
  } catch (e) { if (request === state.detailRequest && session === state.session) $('detail-content').innerHTML = `<div class="alert">${esc(friendly(e))}</div>`; }
}
$('detail-close').onclick = () => $('detail-dialog').close();
$('detail-dialog').addEventListener('close', () => { state.detailRequest++; $('detail-content').replaceChildren(); });
$('detail-dialog').addEventListener('click', e => { if (e.target === $('detail-dialog')) { const r = e.target.getBoundingClientRect(); if (e.clientX < r.left || e.clientX > r.right || e.clientY < r.top || e.clientY > r.bottom) e.target.close(); } });
function renderInfo() {
  $('content').innerHTML = `<div class="help-grid">${block('One shared source of truth', '<p>All three apps use the same order service and database. New orders, acceptance, preparation, assignment, pickup and handover appear in this panel.</p><p class="muted">This panel is for monitoring. Order actions continue in the customer, vendor and delivery apps.</p>')}${block('Fresh data, clear limits', '<p>Views refresh every minute while this page is visible and in use. Updates pause after five minutes without interaction, while searching or browsing more than 25 records, and while details are open.</p><p class="muted">Use Refresh at any time. On the free server plan, the first request after inactivity can take about a minute.</p>')}${block('Understanding delivery availability', '<p>A partner is available when online, unassigned and using a GPS fix captured within 90 seconds with accuracy within 150 metres. Vendors can assign eligible partners within 5 km of the order’s pickup.</p><p class="muted">An online flag by itself does not prove a fresh GPS connection. Check the partner’s availability and location age.</p>')}${block('Activity history', '<p>New orders, status changes, assignments, partner registration and online/offline changes are logged from the time monitoring was enabled.</p><p class="muted">Customer, shop and inventory screens show current saved records. Earlier history, screen views, searches, crashes, unsaved profiles and app login events are not recorded here.</p>')}${block('Restricted admin access', `<p>Signed in as ${esc(state.admin.email)}.</p><p class="muted">Access requires your account password and approval for your specific account. Every server request checks its admin permission. Ordinary customer, vendor and partner logins cannot open admin data.</p>`)}${block('Reading financial totals', '<p>Delivered order value sums completed orders, including delivery and platform fees. Cancelled and unfinished orders are excluded.</p><p class="muted">Orders use cash on delivery. These figures do not confirm bank settlement, earnings or payouts. CSV exports include only the records currently loaded and filtered.</p>')}</div>`;
  $('content').insertAdjacentHTML('beforeend', `<section class="detail-block" style="margin-top:20px"><h3>Change password</h3><p class="muted small">Choose your own password for this admin account. No email verification is needed.</p><form id="password-form" class="password-form"><label for="current-password">Current password</label><input id="current-password" type="password" autocomplete="current-password" required><label for="new-password">New password</label><input id="new-password" type="password" autocomplete="new-password" minlength="10" required><label for="confirm-password">Confirm new password</label><input id="confirm-password" type="password" autocomplete="new-password" minlength="10" required><button class="button primary" type="submit" id="change-password">Update password</button><p id="password-message" class="form-message" role="status"></p></form></section>`);
  $('password-form').onsubmit = async event => {
    event.preventDefault();
    const form = event.currentTarget, button = $('change-password'), message = $('password-message');
    const current = $('current-password').value, next = $('new-password').value;
    message.classList.remove('error');
    if (next !== $('confirm-password').value) { message.textContent = 'The new passwords do not match.'; message.classList.add('error'); return; }
    if (current === next) { message.textContent = 'Choose a different password.'; message.classList.add('error'); return; }
    button.disabled = true; message.textContent = 'Updating your password…';
    try {
      const user = auth.currentUser;
      if (!user || user.uid !== state.admin?.uid) throw new Error('Sign in again before changing your password.');
      await reauthenticateWithCredential(user, EmailAuthProvider.credential(user.email, current));
      await updatePassword(user, next);
      form.reset(); message.textContent = 'Password updated. Use your new password next time you sign in.';
    } catch (error) { message.textContent = friendly(error); message.classList.add('error'); }
    finally { button.disabled = false; }
  };
}
