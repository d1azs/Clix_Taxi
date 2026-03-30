<p align="center">
  <img src="assets/logo.jpg" width="120" alt="CLIX Logo" />
</p>

<h1 align="center">CLIX — Taxi Service Platform</h1>

<p align="center">
  <strong>Мобільна платформа для замовлення таксі з ролями пасажира та водія</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.10+-02569B?style=flat-square&logo=flutter" />
  <img src="https://img.shields.io/badge/Django-6.0-092E20?style=flat-square&logo=django" />
  <img src="https://img.shields.io/badge/DRF-3.16-red?style=flat-square" />
  <img src="https://img.shields.io/badge/SQLite-3-003B57?style=flat-square&logo=sqlite&logoColor=white" />
  <img src="https://img.shields.io/badge/JWT-Auth-orange?style=flat-square&logo=jsonwebtokens" />
</p>

---

## 📖 Опис проєкту

**CLIX** — це повноцінна платформа для виклику таксі. Система складається з:

- **📱 Flutter-додаток** — єдиний мобільний застосунок з підтримкою ролей пасажира та водія
- **⚙️ Django REST API** — бекенд з JWT-аутентифікацією, управлінням замовленнями та рейтинговою системою

## 🏗️ Архітектура

```
┌──────────────────────────────────────────────┐
│              Flutter Mobile App              │
│       ┌──────────┐    ┌──────────┐           │
│       │ Passenger │    │  Driver  │          │
│       │  Screen   │    │  Screen  │          │
│       └────┬─────┘    └────┬─────┘           │
│            └───────┬───────┘                 │
│                    ▼                         │
│            API Service (Dio)                 │
└─────────────────── │ ────────────────────────┘
                     │  REST API (JWT)
┌─────────────────── ▼ ────────────────────────┐
│           Django REST Framework              │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐  │
│  │ Accounts │ │  Orders  │ │   Vehicles   │  │
│  │  Module  │ │  Module  │ │    Module    │  │
│  └──────────┘ └──────────┘ └──────────────┘  │
│                    │                         │
│               SQLite DB                      │
└──────────────────────────────────────────────┘
```

## ✨ Функціональність

### 🧍 Пасажир
- Замовлення таксі з вибором адрес (автокомпліт через Nominatim)
- Вибір класу авто: **Економ**, **Комфорт**, **Бізнес**
- Відстеження водія на карті в реальному часі
- Маршрут на карті через OSRM
- Оцінка водія після поїздки (1–5 ⭐)
- Історія поїздок

### 🚗 Водій
- Радар замовлень з пульсуючою анімацією
- Прийняття/відхилення замовлень
- Прогрес-бар етапів поїздки (Прибуття → Забираю → В дорозі → Готово)
- Маршрут до пасажира та до точки призначення
- Статистика заробітку та кількості поїздок
- Рейтингова система

## 🛠️ Технологічний стек

| Компонент | Технологія |
|-----------|-----------|
| **Mobile App** | Flutter 3.10+, Dart |
| **State Management** | Provider |
| **HTTP Client** | Dio |
| **Maps** | flutter_map + OpenStreetMap |
| **Routing** | OSRM (Open Source Routing Machine) |
| **Geocoding** | Nominatim API |
| **Backend** | Django 6.0, Django REST Framework 3.16 |
| **Auth** | JWT (SimpleJWT) |
| **Database** | SQLite 3 |
| **Code Quality** | Black, isort, Flake8 |
| **CI/CD** | GitHub Actions |

## 🚀 Запуск проєкту

### Передумови
- Python 3.12+
- Flutter 3.10+

### Backend

```bash
# Клонування репозиторію
git clone https://github.com/d1azs/Clix_Taxi.git
cd Clix_Taxi

# Створення віртуального оточення
python -m venv venv
source venv/bin/activate  # macOS/Linux

# Встановлення залежностей
pip install -r requirements.txt

# Міграції
python manage.py migrate

# Завантаження тестових даних
python seed_data.py

# Запуск сервера
python manage.py runserver 0.0.0.0:8000
```

### Flutter App

```bash
cd clix_app

# Встановлення залежностей
flutter pub get

# Запуск
flutter run
```

### Тестові акаунти

| Роль | Телефон | Пароль |
|------|---------|--------|
| 🧍 Пасажир | `+380971234567` | `password123` |
| 🚗 Водій | `+380661234567` | `password123` |

## 📁 Структура проєкту

```
Clix_Taxi/
├── accounts/           # Модуль аутентифікації та профілів
│   ├── models.py       # User, DriverProfile, Role
│   ├── views.py        # Login, Register, Profile API
│   └── serializers.py
├── orders/             # Модуль замовлень
│   ├── models.py       # Order, Review
│   ├── views.py        # CRUD, статуси, рейтинги
│   └── serializers.py
├── vehicles/           # Модуль транспортних засобів
│   ├── models.py       # Vehicle, VehicleClass
│   └── views.py
├── clix_backend/       # Налаштування Django
│   ├── settings.py
│   └── urls.py
├── clix_app/           # Flutter мобільний додаток
│   └── lib/
│       ├── config/     # Теми, API конфігурація
│       ├── models/     # Моделі даних
│       ├── providers/  # Auth Provider
│       ├── screens/    # UI екрани
│       │   ├── auth/       # Логін, вибір ролі
│       │   ├── passenger/  # Екран пасажира
│       │   └── driver/     # Екран водія
│       └── services/   # API, Routing, Geocoding
├── seed_data.py        # Скрипт для тестових даних
├── requirements.txt    # Python залежності
└── pyproject.toml      # Конфігурація Black/isort
```

## 🔌 API Endpoints

### Аутентифікація
| Метод | Endpoint | Опис |
|-------|----------|------|
| `POST` | `/api/auth/login/` | Вхід (JWT) |
| `POST` | `/api/auth/register/` | Реєстрація |
| `POST` | `/api/auth/token/refresh/` | Оновлення токена |
| `GET` | `/api/auth/me/` | Профіль користувача |

### Пасажир
| Метод | Endpoint | Опис |
|-------|----------|------|
| `POST` | `/api/passenger/orders/` | Створити замовлення |
| `GET` | `/api/passenger/orders/active/` | Активне замовлення |
| `POST` | `/api/passenger/orders/<id>/cancel/` | Скасувати |

### Водій
| Метод | Endpoint | Опис |
|-------|----------|------|
| `GET` | `/api/orders/available/` | Доступні замовлення |
| `POST` | `/api/orders/<id>/accept/` | Прийняти |
| `PATCH` | `/api/orders/<id>/status/` | Змінити статус |

### Спільні
| Метод | Endpoint | Опис |
|-------|----------|------|
| `GET` | `/api/orders/history/` | Історія поїздок |
| `POST` | `/api/orders/<id>/review/` | Залишити відгук |
