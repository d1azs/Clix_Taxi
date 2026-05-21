import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  createDispatcherOrder,
  searchUserByPhone,
  searchAddress,
  getRoute,
} from '../services/api';

/**
 * CreateOrderModal — Створення замовлення диспетчером.
 *
 * Потік відповідає діаграмі послідовностей:
 *   1. Пошук клієнта за номером телефону  (GET /api/dispatcher/users/?phone=...)
 *   2. Введення маршруту через Nominatim   (nominatim.openstreetmap.org/search)
 *   3. Розрахунок маршруту через OSRM      (router.project-osrm.org/route)
 *   4. Підтвердження та створення замовлення (POST /api/dispatcher/orders/)
 */

/* ── стилі ── */
const overlay = {
  position: 'fixed', inset: 0,
  backgroundColor: 'rgba(0,0,0,.65)',
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  zIndex: 1000,
};
const modal = {
  background: '#1c1f2e', borderRadius: 12, padding: 28,
  width: 480, maxHeight: '90vh', overflowY: 'auto',
  border: '1px solid #2e3148', color: '#fff',
};
const inputStyle = {
  padding: '9px 12px', borderRadius: 6, border: '1px solid #3a3d55',
  background: '#12141f', color: '#fff', width: '100%', boxSizing: 'border-box',
  fontSize: '0.9rem',
};
const labelStyle = {
  display: 'flex', flexDirection: 'column', gap: 4,
  fontSize: '0.85rem', color: '#9ca3af',
};
const dropdownStyle = {
  position: 'absolute', left: 0, right: 0, top: '100%',
  background: '#22253a', border: '1px solid #3a3d55', borderRadius: 6,
  zIndex: 10, maxHeight: 200, overflowY: 'auto',
};
const dropdownItem = {
  padding: '8px 12px', cursor: 'pointer', fontSize: '0.82rem',
  borderBottom: '1px solid #2e3148', color: '#d1d5db',
};
const badgeOk = {
  display: 'inline-block', padding: '2px 8px', borderRadius: 20,
  fontSize: '0.75rem', background: '#065f46', color: '#6ee7b7',
};
const badgeWarn = {
  display: 'inline-block', padding: '2px 8px', borderRadius: 20,
  fontSize: '0.75rem', background: '#78350f', color: '#fbbf24',
};
const routeBox = {
  background: '#22253a', borderRadius: 8, padding: 14,
  border: '1px solid #3a3d55', fontSize: '0.88rem', color: '#d1d5db',
};

/* ── debounce хук ── */
function useDebounce(value, delay) {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(t);
  }, [value, delay]);
  return debounced;
}

/* ══════════════════════════════════════════════════════════════════════ */

export default function CreateOrderModal({ onClose, onCreated }) {
  /* ── Крок 1: Пошук клієнта ── */
  const [phone, setPhone] = useState('+380');
  const [userResults, setUserResults] = useState([]);
  const [selectedUser, setSelectedUser] = useState(null);
  const [userLoading, setUserLoading] = useState(false);
  const [showUserDropdown, setShowUserDropdown] = useState(false);
  const phoneDebounced = useDebounce(phone, 400);

  useEffect(() => {
    if (phoneDebounced.length < 5) { setUserResults([]); return; }
    let cancelled = false;
    setUserLoading(true);
    searchUserByPhone(phoneDebounced)
      .then((data) => { if (!cancelled) { setUserResults(data); setShowUserDropdown(true); } })
      .catch(() => { if (!cancelled) setUserResults([]); })
      .finally(() => { if (!cancelled) setUserLoading(false); });
    return () => { cancelled = true; };
  }, [phoneDebounced]);

  const pickUser = (u) => {
    setSelectedUser(u);
    setPhone(u.phone_number);
    setShowUserDropdown(false);
  };

  /* ── Крок 2: Пошук адрес (Nominatim) ── */
  const [pickupQuery, setPickupQuery] = useState('');
  const [dropoffQuery, setDropoffQuery] = useState('');
  const [pickupResults, setPickupResults] = useState([]);
  const [dropoffResults, setDropoffResults] = useState([]);
  const [pickupCoords, setPickupCoords] = useState(null);
  const [dropoffCoords, setDropoffCoords] = useState(null);
  const [showPickupDD, setShowPickupDD] = useState(false);
  const [showDropoffDD, setShowDropoffDD] = useState(false);
  const [addrLoading, setAddrLoading] = useState(false);

  const pickupDebounced = useDebounce(pickupQuery, 500);
  const dropoffDebounced = useDebounce(dropoffQuery, 500);

  useEffect(() => {
    if (pickupDebounced.length < 3) { setPickupResults([]); return; }
    let cancelled = false;
    setAddrLoading(true);
    searchAddress(pickupDebounced)
      .then((data) => { if (!cancelled) { setPickupResults(data); setShowPickupDD(true); } })
      .finally(() => { if (!cancelled) setAddrLoading(false); });
    return () => { cancelled = true; };
  }, [pickupDebounced]);

  useEffect(() => {
    if (dropoffDebounced.length < 3) { setDropoffResults([]); return; }
    let cancelled = false;
    searchAddress(dropoffDebounced)
      .then((data) => { if (!cancelled) { setDropoffResults(data); setShowDropoffDD(true); } })
      .finally(() => { if (!cancelled) setAddrLoading(false); });
    return () => { cancelled = true; };
  }, [dropoffDebounced]);

  const pickPickup = (item) => {
    setPickupQuery(item.display_name);
    setPickupCoords({ lat: item.lat, lng: item.lng });
    setShowPickupDD(false);
    setRouteInfo(null); // скинути старий маршрут
  };

  const pickDropoff = (item) => {
    setDropoffQuery(item.display_name);
    setDropoffCoords({ lat: item.lat, lng: item.lng });
    setShowDropoffDD(false);
    setRouteInfo(null);
  };

  /* ── Крок 3: Розрахунок маршруту (OSRM) ── */
  const [routeInfo, setRouteInfo] = useState(null);
  const [routeLoading, setRouteLoading] = useState(false);
  const [estimatedPrice, setEstimatedPrice] = useState(null);
  const [carClass, setCarClass] = useState('ECONOMY');

  const multipliers = { ECONOMY: 1.0, PREMIUM: 1.4, BUSINESS: 1.8, MINIVAN: 1.5 };

  const calculateRoute = async () => {
    if (!pickupCoords || !dropoffCoords) {
      alert('Спочатку оберіть обидві адреси зі списку');
      return;
    }
    setRouteLoading(true);
    try {
      const route = await getRoute(pickupCoords.lat, pickupCoords.lng, dropoffCoords.lat, dropoffCoords.lng);
      setRouteInfo(route);
      // Формула ціни: 45₴ + 12₴/км * множник класу
      const base = 45 + parseFloat(route.distance_km) * 12;
      const price = Math.max(Math.round(base * multipliers[carClass]), 45);
      setEstimatedPrice(price);
    } catch (err) {
      alert(err.message);
    } finally {
      setRouteLoading(false);
    }
  };

  // Перерахувати ціну при зміні класу (якщо маршрут вже є)
  useEffect(() => {
    if (routeInfo) {
      const base = 45 + parseFloat(routeInfo.distance_km) * 12;
      const price = Math.max(Math.round(base * multipliers[carClass]), 45);
      setEstimatedPrice(price);
    }
  }, [carClass, routeInfo]);

  /* ── Крок 4: Створення замовлення ── */
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!pickupCoords || !dropoffCoords) {
      alert('Оберіть адреси зі списку, щоб отримати координати');
      return;
    }
    if (!routeInfo) {
      alert('Спочатку розрахуйте маршрут');
      return;
    }
    setLoading(true);
    try {
      await createDispatcherOrder({
        passenger_phone: phone,
        pickup_address: pickupQuery,
        dropoff_address: dropoffQuery,
        required_class: carClass,
        pickup_lat: pickupCoords.lat,
        pickup_lng: pickupCoords.lng,
        dropoff_lat: dropoffCoords.lat,
        dropoff_lng: dropoffCoords.lng,
        pickup_time: new Date().toISOString(),
        estimated_price: estimatedPrice,
        calculated_distance: parseFloat(routeInfo.distance_km),
        route_polyline: routeInfo.polyline,
      });
      onCreated();
    } catch (err) {
      alert(err.message);
    } finally {
      setLoading(false);
    }
  };

  /* ── Render ── */
  return (
    <div style={overlay} onClick={onClose}>
      <div style={modal} onClick={(e) => e.stopPropagation()}>
        <h3 style={{ marginBottom: 18, color: '#fff', fontSize: '1.1rem' }}>
          🚕 Створити нове замовлення
        </h3>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>

          {/* ═══ 1. Пошук клієнта ═══ */}
          <fieldset style={{ border: '1px solid #2e3148', borderRadius: 8, padding: '12px 14px', margin: 0 }}>
            <legend style={{ color: '#8b5cf6', fontSize: '0.8rem', padding: '0 6px' }}>1. Пошук клієнта</legend>
            <label style={labelStyle}>
              Телефон пасажира
              <div style={{ position: 'relative' }}>
                <input
                  value={phone}
                  onChange={(e) => { setPhone(e.target.value); setSelectedUser(null); }}
                  required
                  placeholder="+380..."
                  style={inputStyle}
                />
                {userLoading && <span style={{ position: 'absolute', right: 10, top: 10, color: '#6b7280', fontSize: '0.8rem' }}>🔍</span>}

                {showUserDropdown && userResults.length > 0 && (
                  <div style={dropdownStyle}>
                    {userResults.map((u) => (
                      <div key={u.id} style={dropdownItem}
                        onMouseDown={() => pickUser(u)}
                        onMouseEnter={(e) => e.target.style.background = '#2e3148'}
                        onMouseLeave={(e) => e.target.style.background = 'transparent'}
                      >
                        📱 {u.phone_number} — {u.first_name} {u.last_name}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </label>
            {selectedUser && (
              <div style={{ marginTop: 8 }}>
                <span style={badgeOk}>✓ Клієнт знайдений: {selectedUser.first_name} {selectedUser.last_name}</span>
              </div>
            )}
            {!selectedUser && phone.length >= 5 && !userLoading && userResults.length === 0 && (
              <div style={{ marginTop: 8 }}>
                <span style={badgeWarn}>⚠ Клієнта не знайдено — буде створено як гостьове замовлення</span>
              </div>
            )}
          </fieldset>

          {/* ═══ 2. Введення маршруту (Nominatim) ═══ */}
          <fieldset style={{ border: '1px solid #2e3148', borderRadius: 8, padding: '12px 14px', margin: 0 }}>
            <legend style={{ color: '#8b5cf6', fontSize: '0.8rem', padding: '0 6px' }}>2. Маршрут (Nominatim)</legend>

            {/* Адреса відправлення */}
            <label style={labelStyle}>
              Адреса відправлення
              <div style={{ position: 'relative' }}>
                <input
                  value={pickupQuery}
                  onChange={(e) => { setPickupQuery(e.target.value); setPickupCoords(null); }}
                  placeholder="Почніть вводити адресу..."
                  required
                  style={inputStyle}
                  onFocus={() => pickupResults.length > 0 && setShowPickupDD(true)}
                  onBlur={() => setTimeout(() => setShowPickupDD(false), 200)}
                />
                {showPickupDD && pickupResults.length > 0 && (
                  <div style={dropdownStyle}>
                    {pickupResults.map((item, i) => (
                      <div key={i} style={dropdownItem}
                        onMouseDown={() => pickPickup(item)}
                        onMouseEnter={(e) => e.target.style.background = '#2e3148'}
                        onMouseLeave={(e) => e.target.style.background = 'transparent'}
                      >
                        📍 {item.display_name}
                      </div>
                    ))}
                  </div>
                )}
              </div>
              {pickupCoords && <span style={{ fontSize: '0.72rem', color: '#6b7280' }}>📌 {pickupCoords.lat.toFixed(4)}, {pickupCoords.lng.toFixed(4)}</span>}
            </label>

            {/* Адреса призначення */}
            <label style={{ ...labelStyle, marginTop: 12 }}>
              Адреса призначення
              <div style={{ position: 'relative' }}>
                <input
                  value={dropoffQuery}
                  onChange={(e) => { setDropoffQuery(e.target.value); setDropoffCoords(null); }}
                  placeholder="Почніть вводити адресу..."
                  required
                  style={inputStyle}
                  onFocus={() => dropoffResults.length > 0 && setShowDropoffDD(true)}
                  onBlur={() => setTimeout(() => setShowDropoffDD(false), 200)}
                />
                {showDropoffDD && dropoffResults.length > 0 && (
                  <div style={dropdownStyle}>
                    {dropoffResults.map((item, i) => (
                      <div key={i} style={dropdownItem}
                        onMouseDown={() => pickDropoff(item)}
                        onMouseEnter={(e) => e.target.style.background = '#2e3148'}
                        onMouseLeave={(e) => e.target.style.background = 'transparent'}
                      >
                        📍 {item.display_name}
                      </div>
                    ))}
                  </div>
                )}
              </div>
              {dropoffCoords && <span style={{ fontSize: '0.72rem', color: '#6b7280' }}>📌 {dropoffCoords.lat.toFixed(4)}, {dropoffCoords.lng.toFixed(4)}</span>}
            </label>
          </fieldset>

          {/* ═══ 3. Розрахунок маршруту (OSRM) ═══ */}
          <fieldset style={{ border: '1px solid #2e3148', borderRadius: 8, padding: '12px 14px', margin: 0 }}>
            <legend style={{ color: '#8b5cf6', fontSize: '0.8rem', padding: '0 6px' }}>3. Маршрут та вартість (OSRM)</legend>

            <label style={labelStyle}>
              Клас авто
              <select
                value={carClass}
                onChange={(e) => setCarClass(e.target.value)}
                style={{ ...inputStyle, cursor: 'pointer' }}
              >
                <option value="ECONOMY">Економ (×1.0)</option>
                <option value="PREMIUM">Преміум (×1.4)</option>
                <option value="BUSINESS">Бізнес (×1.8)</option>
                <option value="MINIVAN">Мінівен (×1.5)</option>
              </select>
            </label>

            <button
              type="button"
              onClick={calculateRoute}
              disabled={routeLoading || !pickupCoords || !dropoffCoords}
              style={{
                marginTop: 10, padding: '10px 0', borderRadius: 6,
                border: 'none', cursor: 'pointer', fontWeight: 600,
                background: pickupCoords && dropoffCoords ? '#3b82f6' : '#374151',
                color: '#fff', fontSize: '0.9rem', width: '100%',
                opacity: (!pickupCoords || !dropoffCoords) ? 0.5 : 1,
              }}
            >
              {routeLoading ? '⏳ Розрахунок...' : '🗺️ Розрахувати маршрут'}
            </button>

            {routeInfo && (
              <div style={{ ...routeBox, marginTop: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                  <span>📏 Відстань:</span>
                  <strong style={{ color: '#fff' }}>{routeInfo.distance_km} км</strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                  <span>⏱ Орієнт. час:</span>
                  <strong style={{ color: '#fff' }}>{routeInfo.duration_min} хв</strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', borderTop: '1px solid #3a3d55', paddingTop: 8 }}>
                  <span>💰 Вартість ({carClass}):</span>
                  <strong style={{ color: '#6ee7b7', fontSize: '1.1rem' }}>{estimatedPrice} ₴</strong>
                </div>
              </div>
            )}
          </fieldset>

          {/* ═══ 4. Підтвердження ═══ */}
          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 6 }}>
            <button
              type="button"
              onClick={onClose}
              style={{
                padding: '10px 20px', borderRadius: 6,
                border: '1px solid #3a3d55', background: 'transparent',
                color: '#9ca3af', cursor: 'pointer', fontSize: '0.9rem',
              }}
            >
              Скасувати
            </button>
            <button
              type="submit"
              disabled={loading || !routeInfo}
              style={{
                padding: '10px 24px', borderRadius: 6,
                border: 'none', background: routeInfo ? '#5E48E8' : '#374151',
                color: '#fff', cursor: 'pointer', fontWeight: 600,
                fontSize: '0.9rem', opacity: routeInfo ? 1 : 0.5,
              }}
            >
              {loading ? '⏳ Створення...' : '✅ Створити замовлення'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
