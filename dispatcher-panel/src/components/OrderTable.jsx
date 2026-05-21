/**
 * components/OrderTable.jsx — Live order data grid with status indicators.
 */

import { useState } from 'react';

const STATUS_COLORS = {
  PENDING: '#f59e0b',
  ACCEPTED: '#3b82f6',
  EN_ROUTE: '#8b5cf6',
  IN_PROGRESS: '#10b981',
  COMPLETED: '#6b7280',
  CANCELLED: '#ef4444',
};

const STATUS_LABELS = {
  PENDING: 'Очікує',
  ACCEPTED: 'Прийнято',
  EN_ROUTE: 'У дорозі',
  IN_PROGRESS: 'Поїздка',
  COMPLETED: 'Завершено',
  CANCELLED: 'Скасовано',
};

export default function OrderTable({ orders, onSelect, selectedId, onForceAssign, onCancel }) {
  const [filter, setFilter] = useState('ALL');

  const filtered = filter === 'ALL'
    ? orders
    : orders.filter((o) => o.status === filter);

  return (
    <div className="order-table-container">
      <div className="table-header">
        <h2>Замовлення</h2>
        <div className="table-filters">
          {['ALL', 'PENDING', 'ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS'].map((f) => (
            <button
              key={f}
              className={`filter-btn ${filter === f ? 'active' : ''}`}
              onClick={() => setFilter(f)}
            >
              {f === 'ALL' ? 'Усі' : STATUS_LABELS[f]}
            </button>
          ))}
        </div>
      </div>

      <div className="table-scroll">
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Статус</th>
              <th>Звідки</th>
              <th>Куди</th>
              <th>Клас</th>
              <th>Ціна</th>
              <th>Водій</th>
              <th>Дії</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((order) => (
              <tr
                key={order.id}
                className={selectedId === order.id ? 'selected' : ''}
                onClick={() => onSelect(order)}
              >
                <td className="cell-id">{order.id?.slice(0, 8)}</td>
                <td>
                  <span
                    className="status-badge"
                    style={{ backgroundColor: STATUS_COLORS[order.status] }}
                  >
                    {STATUS_LABELS[order.status] || order.status}
                  </span>
                </td>
                <td className="cell-addr">{order.pickup_address?.slice(0, 30)}</td>
                <td className="cell-addr">{order.dropoff_address?.slice(0, 30)}</td>
                <td>{order.class_display || order.required_class}</td>
                <td>{order.upfront_price || order.estimated_price || '—'} Kč</td>
                <td>
                  {order.driver_info
                    ? `${order.driver_info.first_name || ''} ${order.driver_info.phone_number}`
                    : '—'}
                </td>
                <td className="cell-actions">
                  {order.status === 'PENDING' && (
                    <button
                      className="btn-assign"
                      onClick={(e) => { e.stopPropagation(); onForceAssign(order); }}
                    >
                      Призначити
                    </button>
                  )}
                  {['PENDING', 'ACCEPTED'].includes(order.status) && (
                    <button
                      className="btn-cancel"
                      onClick={(e) => { e.stopPropagation(); onCancel(order.id); }}
                    >
                      ✕
                    </button>
                  )}
                </td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr>
                <td colSpan="8" className="empty-row">Немає замовлень</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
