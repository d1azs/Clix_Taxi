/**
 * components/AssignModal.jsx — Force-assign driver modal.
 */

import { useState, useEffect } from 'react';
import { fetchDrivers, forceAssignDriver } from '../services/api';

export default function AssignModal({ order, onClose, onAssigned }) {
  const [drivers, setDrivers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [assigning, setAssigning] = useState(null);

  useEffect(() => {
    fetchDrivers('ONLINE')
      .then(setDrivers)
      .catch(() => setDrivers([]))
      .finally(() => setLoading(false));
  }, []);

  const handleAssign = async (driverProfileId) => {
    setAssigning(driverProfileId);
    try {
      await forceAssignDriver(order.id, driverProfileId);
      onAssigned();
      onClose();
    } catch (err) {
      alert(err.message);
    }
    setAssigning(null);
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>Призначити водія</h3>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <p className="modal-subtitle">
          Замовлення: {order.pickup_address} → {order.dropoff_address}
        </p>

        {loading ? (
          <div className="modal-loading">Завантаження водіїв...</div>
        ) : drivers.length === 0 ? (
          <div className="modal-empty">Немає онлайн водіїв</div>
        ) : (
          <div className="driver-list">
            {drivers.map((d) => (
              <div key={d.id} className="driver-item">
                <div className="driver-info">
                  <span className="driver-name">
                    {d.first_name || d.phone_number}
                  </span>
                  <span className="driver-rating">★{d.rating}</span>
                  <span className="driver-trips">{d.total_trips} поїздок</span>
                </div>
                <button
                  className="btn-assign-sm"
                  disabled={assigning === d.id}
                  onClick={() => handleAssign(d.id)}
                >
                  {assigning === d.id ? '...' : 'Призначити'}
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
