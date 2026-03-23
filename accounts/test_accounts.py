from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from accounts.models import DriverProfile, DriverStatus, Role, User


@pytest.mark.django_db
class TestUserModel:
    def test_create_user_with_phone_number(self):
        """Тест створення користувача з номером телефону."""
        user = User.objects.create_user(phone_number="+420123456789", password="password123")
        assert user.phone_number == "+420123456789"
        assert user.check_password("password123")
        assert user.is_active is True

    def test_user_roles(self):
        """Тест перевірки ролей користувача."""
        user = User.objects.create_user(
            phone_number="+420987654321", 
            roles=[Role.PASSENGER, Role.DRIVER]
        )
        assert user.is_passenger is True
        assert user.is_driver is True
        assert user.is_dispatcher is False

    def test_create_superuser(self):
        """Тест створення суперкористувача."""
        admin = User.objects.create_superuser(phone_number="+420000000000", password="adminpassword")
        assert admin.is_staff is True
        assert admin.is_superuser is True

@pytest.mark.django_db
class TestAccountAPI:
    def setup_method(self):
        self.client = APIClient()

    def test_register_user(self):
        """Тест реєстрації нового користувача через API."""
        url = reverse('accounts:register')
        data = {
            "phone_number": "+420111222333",
            "password": "strong_password_123",
            "first_name": "Ivan",
            "last_name": "Test"
        }
        response = self.client.post(url, data)
        assert response.status_code == status.HTTP_201_CREATED
        assert User.objects.filter(phone_number="+420111222333").exists()

    def test_login_user(self):
        """Тест входу та отримання JWT токенів."""
        # Створюємо користувача
        User.objects.create_user(phone_number="+420555666777", password="testpassword123")
        
        url = reverse('accounts:login')
        data = {
            "phone_number": "+420555666777",
            "password": "testpassword123"
        }
        response = self.client.post(url, data)
        assert response.status_code == status.HTTP_200_OK
        assert 'access' in response.data
        assert 'refresh' in response.data

    def test_me_endpoint_authenticated(self):
        """Тест отримання даних про себе для залогіненого користувача."""
        user = User.objects.create_user(phone_number="+420777888999", first_name="Me")
        self.client.force_authenticate(user=user)
        
        url = reverse('accounts:me')
        response = self.client.get(url)
        assert response.status_code == status.HTTP_200_OK
        assert response.data['phone_number'] == "+420777888999"

@pytest.mark.django_db
class TestDriverAPI:
    def setup_method(self):
        self.client = APIClient()
        # Створюємо водія
        self.driver_user = User.objects.create_user(
            phone_number="+420444555666", 
            roles=[Role.DRIVER]
        )
        self.profile = DriverProfile.objects.create(user=self.driver_user)
        self.client.force_authenticate(user=self.driver_user)

    def test_update_driver_status(self):
        """Тест зміни статусу водія (ONLINE/OFFLINE)."""
        url = reverse('accounts:driver-status')
        data = {"status": "ONLINE", "lat": 50.08, "lng": 14.43}
        response = self.client.patch(url, data)
        
        assert response.status_code == status.HTTP_200_OK
        self.profile.refresh_from_db()
        assert self.profile.status == DriverStatus.ONLINE
        assert self.profile.current_lat == 50.08

    def test_update_location(self):
        """Тест оновлення геолокації водія."""
        url = reverse('accounts:driver-location')
        data = {"lat": 50.123, "lng": 14.456}
        response = self.client.post(url, data)
        
        assert response.status_code == status.HTTP_200_OK
        self.profile.refresh_from_db()
        assert self.profile.current_lat == 50.123
        assert self.profile.current_lng == 14.456
