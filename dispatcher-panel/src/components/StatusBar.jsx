/**
 * components/StatusBar.jsx — Top status bar with connection indicator & stats.
 */

export default function StatusBar({ connected, orderCount, driverCount, onLogout }) {
  return (
    <header className="status-bar">
      <div className="status-bar-left">
        <span className="brand">CLIX</span>
        <span className="brand-sub">Dispatcher</span>
        <span className={`ws-indicator ${connected ? 'online' : 'offline'}`}>
          {connected ? '● Live' : '○ Offline'}
        </span>
      </div>
      <div className="status-bar-center">
        <div className="stat-chip">
          <span className="stat-value">{orderCount}</span>
          <span className="stat-label">замовлень</span>
        </div>
        <div className="stat-chip">
          <span className="stat-value">{driverCount}</span>
          <span className="stat-label">водіїв</span>
        </div>
      </div>
      <div className="status-bar-right">
        <button className="btn-logout" onClick={onLogout}>Вийти</button>
      </div>
    </header>
  );
}
