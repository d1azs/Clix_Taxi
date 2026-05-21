import React, { useState, useEffect } from 'react';
import { fetchPendingKyc, reviewKyc } from '../services/api';

export default function KycManager() {
  const [pending, setPending] = useState([]);
  const [loading, setLoading] = useState(true);

  const loadData = async () => {
    setLoading(true);
    try {
      const data = await fetchPendingKyc();
      setPending(data.results || data || []);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleReview = async (id, status) => {
    if (!window.confirm(`Змінити статус на ${status}?`)) return;
    try {
      await reviewKyc(id, status);
      loadData(); // refresh list
    } catch (err) {
      alert(err.message);
    }
  };

  if (loading) return <div style={{ padding: 20 }}>Завантаження документів...</div>;

  return (
    <div style={{ padding: '20px', color: '#fff' }}>
      <h2 style={{ marginBottom: 20 }}>Модуль Безпеки (Перевірка водіїв)</h2>
      {pending.length === 0 ? (
        <p style={{ color: '#aaa' }}>Немає водіїв, що очікують підтвердження.</p>
      ) : (
        <table className="order-table">
          <thead>
            <tr>
              <th>ID Водія</th>
              <th>Ім'я / Телефон</th>
              <th>Документи (Фото)</th>
              <th>Дії</th>
            </tr>
          </thead>
          <tbody>
            {pending.map((d) => (
              <tr key={d.id}>
                <td>{d.id.slice(0, 8)}...</td>
                <td>
                  <strong>{d.driver_name}</strong>
                  <br />
                  <span style={{ fontSize: '0.85rem', color: '#bbb' }}>{d.driver_phone}</span>
                </td>
                <td>
                  <div style={{ display: 'flex', gap: 10 }}>
                    {d.license && <a href={d.license} target="_blank" rel="noreferrer" style={{color:'#8B7CF6'}}>Права</a>}
                    {d.id_card && <a href={d.id_card} target="_blank" rel="noreferrer" style={{color:'#8B7CF6'}}>Паспорт</a>}
                    {d.registration && <a href={d.registration} target="_blank" rel="noreferrer" style={{color:'#8B7CF6'}}>Авто</a>}
                  </div>
                </td>
                <td>
                  <button 
                    onClick={() => handleReview(d.id, 'APPROVED')}
                    style={{ backgroundColor: '#10B981', color: 'white', border: 'none', padding: '6px 12px', borderRadius: 4, marginRight: 8, cursor: 'pointer' }}>
                    Схвалити
                  </button>
                  <button 
                    onClick={() => handleReview(d.id, 'REJECTED')}
                    style={{ backgroundColor: '#EF4444', color: 'white', border: 'none', padding: '6px 12px', borderRadius: 4, cursor: 'pointer' }}>
                    Відхилити
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
