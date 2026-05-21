/**
 * components/LoginScreen.jsx — Dispatcher authentication screen.
 */

import { useState } from 'react';
import { login } from '../services/api';

export default function LoginScreen({ onAuth }) {
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const data = await login(phone, password);
      if (!data.roles?.includes('DISPATCHER')) {
        setError('Цей акаунт не має прав диспетчера');
        setLoading(false);
        return;
      }
      localStorage.setItem('dispatcher_token', data.access);
      localStorage.setItem('dispatcher_refresh', data.refresh);
      onAuth(data);
    } catch (err) {
      setError(err.message || 'Помилка авторизації');
    }
    setLoading(false);
  };

  return (
    <div className="login-screen">
      <div className="login-card">
        <div className="login-logo">CLIX</div>
        <h1>Диспетчерська панель</h1>
        <form onSubmit={handleSubmit}>
          <input
            id="login-phone"
            type="tel"
            placeholder="Номер телефону"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            required
          />
          <input
            id="login-password"
            type="password"
            placeholder="Пароль"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          {error && <div className="login-error">{error}</div>}
          <button id="login-submit" type="submit" disabled={loading}>
            {loading ? 'Вхід...' : 'Увійти'}
          </button>
        </form>
      </div>
    </div>
  );
}
