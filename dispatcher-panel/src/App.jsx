/**
 * App.jsx — CLIX Dispatcher Dashboard (Hybrid Table + Map layout).
 */

import { useState, useEffect, useCallback } from 'react';
import LoginScreen from './components/LoginScreen';
import StatusBar from './components/StatusBar';
import OrderTable from './components/OrderTable';
import FleetMap from './components/FleetMap';
import AssignModal from './components/AssignModal';
import { useFleetSocket } from './hooks/useFleetSocket';
import { fetchOrders, fetchDrivers, fetchQueues, cancelOrder } from './services/api';

import KycManager from './components/KycManager';
import CreateOrderModal from './components/CreateOrderModal';

export default function App() {
  const [authed, setAuthed] = useState(!!localStorage.getItem('dispatcher_token'));
  const [activeTab, setActiveTab] = useState('orders'); // 'orders' | 'kyc'
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [orders, setOrders] = useState([]);
  const [drivers, setDrivers] = useState([]);
  const [queues, setQueues] = useState([]);
  const [selectedOrder, setSelectedOrder] = useState(null);
  const [assignOrder, setAssignOrder] = useState(null);

  // ── Load initial data ──
  const loadData = useCallback(async () => {
    try {
      const [ordersData, driversData, queuesData] = await Promise.all([
        fetchOrders(),
        fetchDrivers(),
        fetchQueues(),
      ]);
      setOrders(ordersData.results || ordersData || []);
      setDrivers(driversData || []);
      setQueues(queuesData || []);
    } catch (err) {
      console.error('Data load failed:', err);
    }
  }, []);

  useEffect(() => {
    if (authed) loadData();
  }, [authed, loadData]);

  // ── WebSocket handler ──
  const handleWsMessage = useCallback((data) => {
    switch (data.type) {
      case 'driver_location':
        setDrivers((prev) =>
          prev.map((d) =>
            d.id === data.driver_id
              ? { ...d, current_lat: data.lat, current_lng: data.lng }
              : d
          )
        );
        break;

      case 'new_order':
        setOrders((prev) => [data.order, ...prev]);
        break;

      case 'order_status_update':
        setOrders((prev) =>
          prev.map((o) =>
            o.id === data.order_id ? { ...o, status: data.status } : o
          )
        );
        break;

      default:
        break;
    }
  }, []);

  const { connected } = useFleetSocket(authed ? handleWsMessage : () => {});

  // ── Auto-refresh every 30s as fallback ──
  useEffect(() => {
    if (!authed) return;
    const interval = setInterval(loadData, 30000);
    return () => clearInterval(interval);
  }, [authed, loadData]);

  // ── Actions ──
  const handleCancel = async (orderId) => {
    if (!window.confirm('Скасувати замовлення?')) return;
    try {
      await cancelOrder(orderId);
      loadData();
    } catch (err) {
      alert(err.message);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('dispatcher_token');
    localStorage.removeItem('dispatcher_refresh');
    setAuthed(false);
  };

  if (!authed) {
    return <LoginScreen onAuth={() => setAuthed(true)} />;
  }

  const activeOrders = orders.filter(
    (o) => !['COMPLETED', 'CANCELLED'].includes(o.status)
  );
  const onlineDrivers = drivers.filter((d) => d.status === 'ONLINE');

  return (
    <div className="dashboard" style={{ display: 'flex', flexDirection: 'row' }}>
      
      {/* ── Sidebar ── */}
      <div style={{ width: '220px', backgroundColor: '#161923', borderRight: '1px solid #2e3148', display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '16px', borderBottom: '1px solid #2e3148' }}>
          <h1 style={{ color: '#8b5cf6', margin: 0, fontSize: 20 }}>CLIX DSP</h1>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', padding: '16px 0', gap: 8 }}>
          <button 
            onClick={() => setActiveTab('orders')}
            style={{ 
              background: activeTab === 'orders' ? '#2a2d42' : 'transparent', 
              color: '#fff', border: 'none', padding: '12px 20px', textAlign: 'left', cursor: 'pointer',
              fontWeight: activeTab === 'orders' ? 'bold' : 'normal'
            }}>
            📡 Радар та Замовлення
          </button>
          <button 
            onClick={() => setActiveTab('kyc')}
            style={{ 
              background: activeTab === 'kyc' ? '#2a2d42' : 'transparent', 
              color: '#fff', border: 'none', padding: '12px 20px', textAlign: 'left', cursor: 'pointer',
              fontWeight: activeTab === 'kyc' ? 'bold' : 'normal'
            }}>
            🛡️ Безпека (KYC)
          </button>
        </div>
        <div style={{ marginTop: 'auto', padding: 16 }}>
          <button onClick={handleLogout} className="btn-logout" style={{ width: '100%' }}>Вийти</button>
        </div>
      </div>

      {/* ── Main Content Area ── */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', height: '100vh', overflow: 'hidden' }}>
        <StatusBar
          connected={connected}
          orderCount={activeOrders.length}
          driverCount={onlineDrivers.length}
          onLogout={handleLogout}
        />

        {activeTab === 'kyc' && <KycManager />}

        {activeTab === 'orders' && (
          <div className="dashboard-body">
            <div className="dashboard-left" style={{ position: 'relative' }}>
              <div style={{ padding: '10px 16px', background: '#1c1f2e', borderBottom: '1px solid #2e3148', display: 'flex', justifyContent: 'flex-end' }}>
                 <button onClick={() => setShowCreateModal(true)} style={{ background: '#5E48E8', color: 'white', padding: '6px 12px', border: 'none', borderRadius: '4px', cursor: 'pointer' }}>
                   + Створити замовлення
                 </button>
              </div>
              <OrderTable
                orders={orders}
                selectedId={selectedOrder?.id}
                onSelect={setSelectedOrder}
                onForceAssign={setAssignOrder}
                onCancel={handleCancel}
              />
            </div>

            <div className="dashboard-right">
              <FleetMap
                drivers={drivers}
                orders={orders}
                queues={queues}
                selectedOrder={selectedOrder}
              />
            </div>
          </div>
        )}

        {assignOrder && (
          <AssignModal
            order={assignOrder}
            onClose={() => setAssignOrder(null)}
            onAssigned={loadData}
          />
        )}

        {showCreateModal && (
          <CreateOrderModal
            onClose={() => setShowCreateModal(false)}
            onCreated={() => {
              setShowCreateModal(false);
              loadData();
            }}
          />
        )}
      </div>
    </div>
  );
}
