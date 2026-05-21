/**
 * components/FleetMap.jsx — Real-time fleet positioning on Leaflet map.
 */

import { MapContainer, TileLayer, Marker, Popup, Circle } from 'react-leaflet';
import L from 'leaflet';

// Custom driver marker icon
const driverIcon = new L.Icon({
  iconUrl: 'https://cdn-icons-png.flaticon.com/512/3097/3097180.png',
  iconSize: [32, 32],
  iconAnchor: [16, 32],
  popupAnchor: [0, -32],
});

const orderIcon = new L.Icon({
  iconUrl: 'https://cdn-icons-png.flaticon.com/512/684/684908.png',
  iconSize: [28, 28],
  iconAnchor: [14, 28],
  popupAnchor: [0, -28],
});

// Prague Airport center
const PRAGUE_CENTER = [50.0755, 14.4378];

export default function FleetMap({ drivers, orders, queues, selectedOrder }) {
  const center = selectedOrder
    ? [selectedOrder.pickup_lat, selectedOrder.pickup_lng]
    : PRAGUE_CENTER;

  return (
    <div className="fleet-map-container">
      <MapContainer
        center={center}
        zoom={12}
        style={{ height: '100%', width: '100%' }}
        zoomControl={false}
      >
        <TileLayer
          attribution='&copy; <a href="https://carto.com">CARTO</a>'
          url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
        />

        {/* Driver markers */}
        {drivers
          .filter((d) => d.current_lat && d.current_lng)
          .map((d) => (
            <Marker key={d.id} position={[d.current_lat, d.current_lng]} icon={driverIcon}>
              <Popup>
                <strong>{d.first_name || d.phone_number}</strong>
                <br />
                Статус: {d.status}
                <br />
                Рейтинг: ★{d.rating}
              </Popup>
            </Marker>
          ))}

        {/* Active order pickup markers */}
        {orders
          .filter((o) => ['PENDING', 'ACCEPTED', 'EN_ROUTE'].includes(o.status))
          .map((o) => (
            <Marker key={o.id} position={[o.pickup_lat, o.pickup_lng]} icon={orderIcon}>
              <Popup>
                <strong>Замовлення {o.id?.slice(0, 8)}</strong>
                <br />
                {o.pickup_address}
                <br />
                Ціна: {o.upfront_price || o.estimated_price || '—'} Kč
              </Popup>
            </Marker>
          ))}

        {/* Virtual queue geofences */}
        {queues.map((q) => (
          <Circle
            key={q.id}
            center={[q.lat, q.lng]}
            radius={q.radius_meters}
            pathOptions={{
              color: '#8b5cf6',
              fillColor: '#8b5cf6',
              fillOpacity: 0.1,
              weight: 2,
            }}
          >
            <Popup>
              <strong>{q.name}</strong>
              <br />
              Водіїв: {q.active_drivers}
            </Popup>
          </Circle>
        ))}
      </MapContainer>
    </div>
  );
}
