from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from accounts.models import DriverProfile, Role, User
from vehicles.models import Vehicle


@pytest.mark.django_db
class TestVehicleAPI:
    def setup_method(self):
        self.client = APIClient()
        # Створюємо водія
        self.driver_user = User.objects.create_user(
            phone_number="+420111222333", 
            roles=[Role.DRIVER]
        )
        self.profile = DriverProfile.objects.create(user=self.driver_user)
        self.client.force_authenticate(user=self.driver_user)

    def test_create_vehicle(self):
        """Тест додавання нового автомобіля водієм."""
        url = reverse('vehicles:vehicle-list')
        data = {
            "make_model": "Skoda Octavia",
            "license_plate": "ABC-123",
            "color": "White",
            "vehicle_class": "ECONOMY",
            "is_active": True
        }
        response = self.client.post(url, data)
        assert response.status_code == status.HTTP_201_CREATED
        assert Vehicle.objects.filter(license_plate="ABC-123").exists()

    def test_list_driver_vehicles(self):
        """Тест отримання списку автомобілів водія (з пагінацією)."""
        Vehicle.objects.create(
            driver_profile=self.profile,
            make_model="Toyota Camry",
            license_plate="XYZ-987",
            vehicle_class="PREMIUM"
        )
        url = reverse('vehicles:vehicle-list')
        response = self.client.get(url)
        assert response.status_code == status.HTTP_200_OK
        # Результати знаходяться у полі 'results' через пагінацію
        assert len(response.data['results']) == 1
        assert response.data['results'][0]['license_plate'] == "XYZ-987"
