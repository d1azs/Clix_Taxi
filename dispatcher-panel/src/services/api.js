/**
 * services/api.js — HTTP client for CLIX Dispatcher Panel.
 */

const BASE_URL = '/api';

function getHeaders() {
  const token = localStorage.getItem('dispatcher_token');
  return {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
}

async function request(method, path, body = null) {
  const opts = { method, headers: getHeaders() };
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(`${BASE_URL}${path}`, opts);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error || err.detail || `HTTP ${res.status}`);
  }
  return res.json();
}

// ── Auth ──
export const login = (phone_number, password) =>
  request('POST', '/auth/login/', { phone_number, password });

// ── Orders ──
export const fetchOrders = (params = '') =>
  request('GET', `/dispatcher/orders/list/${params}`);

export const fetchOrderDetail = (id) =>
  request('GET', `/dispatcher/orders/${id}/`);

export const forceAssignDriver = (orderId, driverProfileId) =>
  request('POST', `/dispatcher/orders/${orderId}/force-assign/`, {
    driver_profile_id: driverProfileId,
  });

export const overrideFare = (orderId, data) =>
  request('PATCH', `/dispatcher/orders/${orderId}/override/`, data);

export const cancelOrder = (orderId) =>
  request('PATCH', `/dispatcher/orders/${orderId}/`, { status: 'CANCELLED' });

// ── Drivers ──
export const fetchDrivers = (status = '') => {
  const qs = status ? `?status=${status}` : '';
  return request('GET', `/dispatcher/drivers/${qs}`);
};

// ── Queues ──
export const fetchQueues = () =>
  request('GET', '/dispatcher/queues/');

export const fetchQueueEntries = (queueId) =>
  request('GET', `/dispatcher/queues/${queueId}/entries/`);

// ── Complaints ──
export const fetchComplaints = () =>
  request('GET', '/dispatcher/complaints/');

// ── KYC & Admin ──
export const fetchPendingKyc = () =>
  request('GET', '/dispatcher/kyc/pending/');

export const reviewKyc = (userId, status) =>
  request('PATCH', `/dispatcher/kyc/${userId}/review/`, { status });

// ── Create Order ──
export const createDispatcherOrder = (data) =>
  request('POST', '/dispatcher/orders/', data);

// ── User Search ──
export const searchUserByPhone = (phone) =>
  request('GET', `/dispatcher/users/?phone=${encodeURIComponent(phone)}`);

// ── Nominatim Geocoding (OpenStreetMap) ──
export async function searchAddress(query) {
  if (!query || query.length < 3) return [];
  const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=5&addressdetails=1&countrycodes=ua,cz`;
  const res = await fetch(url, {
    headers: { 'Accept-Language': 'uk' },
  });
  if (!res.ok) return [];
  const data = await res.json();
  return data.map((item) => ({
    display_name: item.display_name,
    lat: parseFloat(item.lat),
    lng: parseFloat(item.lon),
  }));
}

// ── OSRM Route Calculation ──
export async function getRoute(pickupLat, pickupLng, dropoffLat, dropoffLng) {
  const url = `https://router.project-osrm.org/route/v1/driving/${pickupLng},${pickupLat};${dropoffLng},${dropoffLat}?overview=full&geometries=polyline`;
  const res = await fetch(url);
  if (!res.ok) throw new Error('Помилка маршрутизації OSRM');
  const data = await res.json();
  if (!data.routes || data.routes.length === 0) throw new Error('Маршрут не знайдено');
  const route = data.routes[0];
  return {
    distance_km: (route.distance / 1000).toFixed(1),
    duration_min: Math.round(route.duration / 60),
    polyline: route.geometry,
  };
}
