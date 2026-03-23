"""
Скрипт для створення тестових даних CLIX.
Запуск: python manage.py shell < seed_data.py
"""

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'clix_backend.settings')
django.setup()

from accounts.models import User, DriverProfile
from vehicles.models import Vehicle
from orders.models import Order, OrderStatus
from django.utils import timezone

print("=" * 60)
print("  CLIX — Створення тестових даних")
print("=" * 60)

# ---------------------------------------------------------------------------
# 1. Створення користувачів
# ---------------------------------------------------------------------------

# Пасажир
passenger, created = User.objects.get_or_create(
    phone_number='+380971234567',
    defaults={
        'first_name': 'Олена',
        'last_name': 'Коваленко',
        'roles': ['PASSENGER'],
    }
)
if created:
    passenger.set_password('pass1234')
    passenger.save()
    print(f"✅ Пасажир створений: {passenger.phone_number}")
else:
    print(f"ℹ️  Пасажир вже існує: {passenger.phone_number}")

# Водій
driver_user, created = User.objects.get_or_create(
    phone_number='+380661234567',
    defaults={
        'first_name': 'Олександр',
        'last_name': 'Мельник',
        'roles': ['DRIVER'],
    }
)
if created:
    driver_user.set_password('pass1234')
    driver_user.save()
    print(f"✅ Водій створений: {driver_user.phone_number}")
else:
    print(f"ℹ️  Водій вже існує: {driver_user.phone_number}")

# Профіль водія
driver_profile, created = DriverProfile.objects.get_or_create(
    user=driver_user,
    defaults={
        'status': 'ONLINE',
        'rating': 4.90,
        'current_lat': 49.8397,
        'current_lng': 24.0297,
    }
)
if created:
    print(f"✅ Профіль водія створений")

# Мульти-роль (Пасажир + Водій)
multi_user, created = User.objects.get_or_create(
    phone_number='+380501234567',
    defaults={
        'first_name': 'Марія',
        'last_name': 'Шевченко',
        'roles': ['PASSENGER', 'DRIVER'],
    }
)
if created:
    multi_user.set_password('pass1234')
    multi_user.save()
    mp, _ = DriverProfile.objects.get_or_create(
        user=multi_user,
        defaults={
            'current_lat': 49.8400,
            'current_lng': 24.0300,
        }
    )
    print(f"✅ Мульті-роль створена: {multi_user.phone_number}")
else:
    print(f"ℹ️  Мульті-роль вже існує: {multi_user.phone_number}")

# Диспетчер (він же адмін)
dispatcher, created = User.objects.get_or_create(
    phone_number='+380931234567',
    defaults={
        'first_name': 'Адмін',
        'last_name': 'Диспетчер',
        'roles': ['DISPATCHER'],
        'is_staff': True,
        'is_superuser': True,
    }
)
if created:
    dispatcher.set_password('pass1234')
    dispatcher.save()
    print(f"✅ Диспетчер/Адмін створений: {dispatcher.phone_number}")
else:
    print(f"ℹ️  Диспетчер/Адмін вже існує: {dispatcher.phone_number}")

# ---------------------------------------------------------------------------
# 2. Автомобілі (усі класи)
# ---------------------------------------------------------------------------
cars = [
    {
        'license_plate': 'BC 1234 AA',
        'make_model': 'Daewoo Lanos',
        'vehicle_class': 'ECONOMY',
        'color': 'Сірий',
        'is_pet_friendly': False,
        'has_child_seat': False,
    },
    {
        'license_plate': 'BC 5678 BB',
        'make_model': 'Toyota Camry',
        'vehicle_class': 'PREMIUM',
        'color': 'Білий',
        'is_pet_friendly': True,
        'has_child_seat': True,
    },
    {
        'license_plate': 'BC 9012 CC',
        'make_model': 'Mercedes E-Class',
        'vehicle_class': 'BUSINESS',
        'color': 'Чорний',
        'is_pet_friendly': False,
        'has_child_seat': False,
    },
    {
        'license_plate': 'BC 3456 DD',
        'make_model': 'Volkswagen Multivan',
        'vehicle_class': 'MINIVAN',
        'color': 'Синій',
        'is_pet_friendly': True,
        'has_child_seat': True,
        'is_wheelchair_accessible': True,
    },
]

for car_data in cars:
    plate = car_data.pop('license_plate')
    v, created = Vehicle.objects.get_or_create(
        license_plate=plate,
        defaults={'driver_profile': driver_profile, **car_data}
    )
    if created:
        print(f"✅ Авто: {v}")
    else:
        print(f"ℹ️  Авто вже існує: {v}")

# ---------------------------------------------------------------------------
# 3. Тестове замовлення (Львів)
# ---------------------------------------------------------------------------
order, created = Order.objects.get_or_create(
    pickup_address='пр. Свободи, Львів',
    dropoff_address='вул. Шевченка, Львів',
    defaults={
        'passenger': passenger,
        'pickup_lat': 49.8429,
        'pickup_lng': 24.0315,
        'dropoff_lat': 49.8397,
        'dropoff_lng': 24.0297,
        'pickup_time': timezone.now(),
        'required_class': 'ECONOMY',
        'status': OrderStatus.PENDING,
        'estimated_price': 65.00,
    }
)
if created:
    print(f"✅ Тестове замовлення створено: {order}")

print()
print("=" * 60)
print("  Готово! Тестові дані завантажені.")
print("=" * 60)
print()
print("  Тестові акаунти (пароль: pass1234):")
print("  • Пасажир:       +380971234567")
print("  • Водій:         +380661234567")
print("  • Мульті:        +380501234567  (пасажир + водій)")
print("  • Диспетчер/Адмін: +380931234567")
print()
