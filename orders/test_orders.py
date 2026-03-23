from django.urls import reverse
from django.utils import timezone

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from accounts.models import DriverProfile, DriverStatus, Role, User
from orders.models import Order, OrderStatus
from vehicles.models import Vehicle


@pytest.mark.django_db
class TestOrderCycle:
    def setup_method(self):
        self.client = APIClient()

        # Створюємо пасажира
        self.passenger = User.objects.create_user(
            phone_number="+420111000111", roles=[Role.PASSENGER]
        )

        # Створюємо водія з авто
        self.driver_user = User.objects.create_user(
            phone_number="+420222000222", roles=[Role.DRIVER]
        )
        self.driver_profile = DriverProfile.objects.create(
            user=self.driver_user, status=DriverStatus.ONLINE
        )
        self.vehicle = Vehicle.objects.create(
            driver_profile=self.driver_profile,
            make_model="Skoda Superb",
            license_plate="TAXI-111",
            vehicle_class="ECONOMY",
            is_active=True,
        )

    def test_passenger_creates_order(self):
        """Тест створення замовлення пасажиром."""
        self.client.force_authenticate(user=self.passenger)
        url = reverse("orders:passenger-order-create")
        data = {
            "pickup_address": "Prague Main Station",
            "dropoff_address": "Airport",
            "pickup_lat": 50.08,
            "pickup_lng": 14.43,
            "dropoff_lat": 50.10,
            "dropoff_lng": 14.26,
            "pickup_time": timezone.now().isoformat(),
            "required_class": "ECONOMY",
        }
        response = self.client.post(url, data)
        assert response.status_code == status.HTTP_201_CREATED
        assert Order.objects.filter(passenger=self.passenger).exists()

    def test_driver_accepts_order(self):
        """Тест прийняття замовлення водієм."""
        # Створюємо замовлення
        order = Order.objects.create(
            passenger=self.passenger,
            pickup_address="A",
            dropoff_address="B",
            pickup_lat=0,
            pickup_lng=0,
            dropoff_lat=1,
            dropoff_lng=1,
            pickup_time=timezone.now(),
            required_class="ECONOMY",
            status=OrderStatus.PENDING,
        )

        self.client.force_authenticate(user=self.driver_user)
        url = reverse("orders:order-accept", kwargs={"pk": order.id})
        response = self.client.post(url)

        assert response.status_code == status.HTTP_200_OK
        order.refresh_from_db()
        assert order.status == OrderStatus.ACCEPTED
        assert order.driver == self.driver_profile

    def test_order_status_flow(self):
        """Тест переходу статусів замовлення водієм."""
        order = Order.objects.create(
            passenger=self.passenger,
            driver=self.driver_profile,
            pickup_address="A",
            dropoff_address="B",
            pickup_lat=0,
            pickup_lng=0,
            dropoff_lat=1,
            dropoff_lng=1,
            pickup_time=timezone.now(),
            required_class="ECONOMY",
            status=OrderStatus.ACCEPTED,
        )

        self.client.force_authenticate(user=self.driver_user)
        url = reverse("orders:order-status-update", kwargs={"pk": order.id})

        # ACCEPTED -> EN_ROUTE
        response = self.client.patch(url, {"status": "EN_ROUTE"})
        assert response.status_code == status.HTTP_200_OK
        order.refresh_from_db()
        assert order.status == OrderStatus.EN_ROUTE

        # EN_ROUTE -> IN_PROGRESS
        response = self.client.patch(url, {"status": "IN_PROGRESS"})
        assert response.status_code == status.HTTP_200_OK

        # IN_PROGRESS -> COMPLETED
        response = self.client.patch(url, {"status": "COMPLETED"})
        assert response.status_code == status.HTTP_200_OK
        order.refresh_from_db()
        assert order.status == OrderStatus.COMPLETED


@pytest.mark.django_db
class TestDispatcherAPI:
    def setup_method(self):
        self.client = APIClient()
        self.dispatcher = User.objects.create_user(
            phone_number="+420999000999", roles=[Role.DISPATCHER]
        )
        self.client.force_authenticate(user=self.dispatcher)

    def test_dispatcher_creates_order(self):
        """Тест створення замовлення диспетчером."""
        url = reverse("orders:dispatcher-order-create")
        data = {
            "pickup_address": "Dispatcher Office",
            "dropoff_address": "Client home",
            "pickup_lat": 50.0,
            "pickup_lng": 14.0,
            "dropoff_lat": 50.1,
            "dropoff_lng": 14.1,
            "pickup_time": timezone.now().isoformat(),
            "passenger_phone": "+420123456789",
        }
        response = self.client.post(url, data)
        assert response.status_code == status.HTTP_201_CREATED
        assert Order.objects.filter(dispatcher=self.dispatcher).exists()
