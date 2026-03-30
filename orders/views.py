"""
orders/views.py — Views для замовлень: пасажир, водій, диспетчер.
"""

import math

from django.db import transaction
from django.db.models import Avg
from django.utils import timezone

from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import DriverStatus, User
from accounts.permissions import IsDispatcher, IsDriver, IsPassenger
from vehicles.models import Vehicle

from .models import Order, OrderStatus, Review
from .serializers import (
    DispatcherOrderCreateSerializer,
    OrderSerializer,
    PassengerOrderCreateSerializer,
    ReviewSerializer,
)


def _calculate_price(
    pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, required_class="ECONOMY"
):
    """Розрахунок ціни на основі відстані (Haversine) та класу авто."""
    R = 6371  # Радіус Землі, км
    lat1, lat2 = math.radians(pickup_lat), math.radians(dropoff_lat)
    dlat = math.radians(dropoff_lat - pickup_lat)
    dlng = math.radians(dropoff_lng - pickup_lng)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(dlng / 2) ** 2
    )
    distance_km = R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    # Базова ціна: 45₴ + 12₴/км
    base = 45 + distance_km * 12

    # Множники класів
    multipliers = {
        "ECONOMY": 1.0,
        "PREMIUM": 1.4,
        "BUSINESS": 1.8,
        "MINIVAN": 1.5,
    }
    multiplier = multipliers.get(required_class, 1.0)
    price = round(base * multiplier, 2)
    return max(price, 45)  # Мінімальна ціна 45₴


# ╔═════════════════════════════════════════════════════════════════════════╗
# ║                        ПАСАЖИР (Passenger)                            ║
# ╚═════════════════════════════════════════════════════════════════════════╝


class PassengerOrderCreateView(generics.CreateAPIView):
    """
    POST /api/passenger/orders/ — Пасажир створює замовлення.
    """

    serializer_class = PassengerOrderCreateSerializer
    permission_classes = [IsPassenger]

    def perform_create(self, serializer):
        order = serializer.save(passenger=self.request.user, status=OrderStatus.PENDING)
        if not order.estimated_price:
            order.estimated_price = _calculate_price(
                order.pickup_lat,
                order.pickup_lng,
                order.dropoff_lat,
                order.dropoff_lng,
                order.required_class,
            )
            order.save(update_fields=["estimated_price"])


class PassengerActiveOrderView(APIView):
    """
    GET /api/passenger/orders/active/ — Поточне активне замовлення пасажира.
    """

    permission_classes = [IsPassenger]

    def get(self, request):
        active_statuses = [
            OrderStatus.PENDING,
            OrderStatus.ACCEPTED,
            OrderStatus.EN_ROUTE,
            OrderStatus.IN_PROGRESS,
            OrderStatus.COMPLETED,
        ]

        order = (
            Order.objects.filter(
                passenger=request.user,
                status__in=active_statuses,
            )
            # Виключаємо COMPLETED якщо: вже є відгук або пасажир натиснув "Пропустити"
            .exclude(
                status=OrderStatus.COMPLETED,
                review__isnull=False,
            )
            .exclude(
                status=OrderStatus.COMPLETED,
                passenger_dismissed_rating=True,
            )
            .select_related("driver", "driver__user")
            .order_by("-created_at")
            .first()
        )

        if not order:
            return Response(
                {"detail": "Немає активних замовлень"},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(OrderSerializer(order).data)


class DismissRatingView(APIView):
    """
    POST /api/passenger/orders/<id>/dismiss-rating/ —
    Пасажир натискає "Пропустити" в діалозі оцінки.
    """

    permission_classes = [IsPassenger]

    def post(self, request, pk):
        try:
            order = Order.objects.get(
                pk=pk,
                passenger=request.user,
                status=OrderStatus.COMPLETED,
            )
        except Order.DoesNotExist:
            return Response(
                {"error": "Замовлення не знайдено"},
                status=status.HTTP_404_NOT_FOUND,
            )
        order.passenger_dismissed_rating = True
        order.save(update_fields=["passenger_dismissed_rating"])
        return Response({"detail": "Оцінку пропущено"})


class PassengerCancelOrderView(APIView):
    """
    POST /api/passenger/orders/<id>/cancel/ — Пасажир скасовує своє замовлення.
    Дозволено лише для статусів PENDING та ACCEPTED (водій ще не виїхав).
    """

    permission_classes = [IsPassenger]

    def post(self, request, pk):
        cancellable = [OrderStatus.PENDING, OrderStatus.ACCEPTED]
        try:
            order = Order.objects.get(
                pk=pk,
                passenger=request.user,
                status__in=cancellable,
            )
        except Order.DoesNotExist:
            return Response(
                {"error": "Замовлення не знайдено або не може бути скасоване"},
                status=status.HTTP_404_NOT_FOUND,
            )
        order.status = OrderStatus.CANCELLED
        order.save(update_fields=["status"])
        return Response({"detail": "Замовлення скасовано"})


# ╔═════════════════════════════════════════════════════════════════════════╗
# ║                          ВОДІЙ (Driver)                               ║
# ╚═════════════════════════════════════════════════════════════════════════╝


class DriverActiveOrderView(APIView):
    """
    GET /api/driver/orders/active/ — Поточне активне замовлення водія.
    Повертає замовлення зі статусом ACCEPTED, EN_ROUTE або IN_PROGRESS.
    """

    permission_classes = [IsDriver]

    def get(self, request):
        active_statuses = [
            OrderStatus.ACCEPTED,
            OrderStatus.EN_ROUTE,
            OrderStatus.IN_PROGRESS,
        ]
        driver_profile = request.user.driver_profile
        order = (
            Order.objects.filter(
                driver=driver_profile,
                status__in=active_statuses,
            )
            .select_related("passenger", "driver", "driver__user")
            .first()
        )

        if not order:
            return Response(
                {"detail": "Немає активних замовлень"},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(OrderSerializer(order).data)


class AvailableOrdersView(generics.ListAPIView):
    """
    GET /api/orders/available/ — Радар: доступні PENDING-замовлення для водія.
    Фільтрує за класом авто та опціями водія.
    """

    serializer_class = OrderSerializer
    permission_classes = [IsDriver]

    def get_queryset(self):
        driver_profile = self.request.user.driver_profile
        # Отримуємо всі активні авто водія
        driver_vehicles = Vehicle.objects.filter(
            driver_profile=driver_profile, is_active=True
        )
        if not driver_vehicles.exists():
            return Order.objects.none()

        # Збираємо доступні класи та опції
        available_classes = list(
            driver_vehicles.values_list("vehicle_class", flat=True).distinct()
        )
        has_pet = driver_vehicles.filter(is_pet_friendly=True).exists()
        has_child = driver_vehicles.filter(has_child_seat=True).exists()
        has_wheelchair = driver_vehicles.filter(is_wheelchair_accessible=True).exists()

        # Фільтр: PENDING замовлення, що підходять водію
        qs = Order.objects.filter(
            status=OrderStatus.PENDING,
            required_class__in=available_classes,
        )
        # Фільтруємо за опціями
        if not has_pet:
            qs = qs.exclude(is_pet_friendly=True)
        if not has_child:
            qs = qs.exclude(needs_child_seat=True)
        if not has_wheelchair:
            qs = qs.exclude(needs_wheelchair_access=True)

        return qs.order_by("created_at")


class AcceptOrderView(APIView):
    """
    POST /api/orders/<id>/accept/ — Водій приймає замовлення.
    Критичний ендпоінт: використовує select_for_update() для уникнення race conditions.
    """

    permission_classes = [IsDriver]

    def post(self, request, pk):
        driver_profile = request.user.driver_profile

        # Перевіряємо, чи водій онлайн
        if driver_profile.status != DriverStatus.ONLINE:
            return Response(
                {"error": "Спочатку перейдіть в режим ONLINE"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            with transaction.atomic():
                # Блокуємо рядок замовлення — інші водії зачекають
                order = Order.objects.select_for_update().get(
                    pk=pk, status=OrderStatus.PENDING
                )
                order.status = OrderStatus.ACCEPTED
                order.driver = driver_profile
                order.accepted_at = timezone.now()
                order.save()
        except Order.DoesNotExist:
            return Response(
                {"error": "Замовлення вже прийняте або не існує"},
                status=status.HTTP_409_CONFLICT,
            )

        return Response(OrderSerializer(order).data, status=status.HTTP_200_OK)


class RejectOrderView(APIView):
    """
    POST /api/orders/<id>/reject/ — Водій відмовляється від замовлення.
    Повертає статус у PENDING.
    """

    permission_classes = [IsDriver]

    def post(self, request, pk):
        driver_profile = request.user.driver_profile
        try:
            order = Order.objects.get(
                pk=pk, driver=driver_profile, status=OrderStatus.ACCEPTED
            )
        except Order.DoesNotExist:
            return Response(
                {"error": "Замовлення не знайдено або ви не можете його відхилити"},
                status=status.HTTP_404_NOT_FOUND,
            )
        order.status = OrderStatus.PENDING
        order.driver = None
        order.accepted_at = None
        order.save()
        return Response({"detail": "Замовлення повернуто в чергу"})


class UpdateOrderStatusView(APIView):
    """
    PATCH /api/orders/<id>/status/ — Водій змінює статус замовлення.
    Допустимі переходи:
      ACCEPTED → EN_ROUTE → IN_PROGRESS → COMPLETED
    """

    permission_classes = [IsDriver]

    # Допустимі переходи статусів
    TRANSITIONS = {
        OrderStatus.ACCEPTED: OrderStatus.EN_ROUTE,
        OrderStatus.EN_ROUTE: OrderStatus.IN_PROGRESS,
        OrderStatus.IN_PROGRESS: OrderStatus.COMPLETED,
    }

    def patch(self, request, pk):
        driver_profile = request.user.driver_profile
        new_status = request.data.get("status")

        try:
            order = Order.objects.get(pk=pk, driver=driver_profile)
        except Order.DoesNotExist:
            return Response(
                {"error": "Замовлення не знайдено"},
                status=status.HTTP_404_NOT_FOUND,
            )

        expected_next = self.TRANSITIONS.get(order.status)
        if not expected_next or new_status != expected_next:
            return Response(
                {"error": f"Неможливий перехід: {order.status} → {new_status}"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        order.status = new_status
        if new_status == OrderStatus.COMPLETED:
            order.completed_at = timezone.now()
            # Оновлюємо статистику водія
            driver_profile.total_trips += 1
            if order.estimated_price:
                driver_profile.total_earnings += order.estimated_price
            driver_profile.save()

        order.save()
        return Response(OrderSerializer(order).data)


# ╔═════════════════════════════════════════════════════════════════════════╗
# ║                       ДИСПЕТЧЕР (Dispatcher)                          ║
# ╚═════════════════════════════════════════════════════════════════════════╝


class DispatcherOrderCreateView(generics.CreateAPIView):
    """
    POST /api/dispatcher/orders/ — Диспетчер створює замовлення від імені клієнта.
    """

    serializer_class = DispatcherOrderCreateSerializer
    permission_classes = [IsDispatcher]

    def perform_create(self, serializer):
        phone = serializer.validated_data.pop("passenger_phone", None)
        passenger = None
        if phone:
            passenger = User.objects.filter(phone_number=phone).first()
        order = serializer.save(
            dispatcher=self.request.user,
            passenger=passenger,
            status=OrderStatus.PENDING,
        )
        if not order.estimated_price:
            order.estimated_price = _calculate_price(
                order.pickup_lat,
                order.pickup_lng,
                order.dropoff_lat,
                order.dropoff_lng,
                order.required_class,
            )
            order.save(update_fields=["estimated_price"])


class DispatcherOrderListView(generics.ListAPIView):
    """
    GET /api/dispatcher/orders/ — Моніторинг всіх замовлень для диспетчера.
    """

    serializer_class = OrderSerializer
    permission_classes = [IsDispatcher]
    filterset_fields = ["status", "required_class"]

    def get_queryset(self):
        return Order.objects.all().select_related("driver", "driver__user", "passenger")


class DispatcherOrderDetailView(generics.RetrieveUpdateAPIView):
    """
    GET/PATCH /api/dispatcher/orders/<id>/ — Деталі / редагування / скасування.
    """

    serializer_class = OrderSerializer
    permission_classes = [IsDispatcher]

    def get_queryset(self):
        return Order.objects.all()

    def perform_update(self, serializer):
        # Дозволяємо диспетчеру скасувати замовлення
        new_status = self.request.data.get("status")
        if new_status == OrderStatus.CANCELLED:
            serializer.save(status=OrderStatus.CANCELLED)
        else:
            serializer.save()


class DispatcherComplaintsView(generics.ListAPIView):
    """
    GET /api/dispatcher/complaints/ — Перегляд скарг (is_complaint=True).
    """

    serializer_class = ReviewSerializer
    permission_classes = [IsDispatcher]

    def get_queryset(self):
        return Review.objects.filter(is_complaint=True).select_related(
            "order", "author", "target_driver"
        )


# ╔═════════════════════════════════════════════════════════════════════════╗
# ║                       СПІЛЬНЕ (Shared)                                ║
# ╚═════════════════════════════════════════════════════════════════════════╝


class OrderHistoryView(generics.ListAPIView):
    """
    GET /api/orders/history/ — Історія завершених/скасованих замовлень.
    Результат залежить від ролі користувача.
    """

    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        finished = [OrderStatus.COMPLETED, OrderStatus.CANCELLED]

        if user.has_role("DISPATCHER"):
            return Order.objects.filter(status__in=finished)
        elif user.has_role("DRIVER"):
            return Order.objects.filter(driver=user.driver_profile, status__in=finished)
        else:  # PASSENGER
            return Order.objects.filter(passenger=user, status__in=finished)


class CreateReviewView(generics.CreateAPIView):
    """
    POST /api/orders/<id>/review/ — Пасажир залишає відгук (або скаргу).
    """

    serializer_class = ReviewSerializer
    permission_classes = [IsPassenger]

    def perform_create(self, serializer):
        order_id = self.kwargs["pk"]
        try:
            order = Order.objects.get(
                pk=order_id,
                passenger=self.request.user,
                status=OrderStatus.COMPLETED,
            )
        except Order.DoesNotExist:
            from rest_framework.exceptions import ValidationError

            raise ValidationError("Замовлення не знайдено або ще не завершено")

        serializer.save(
            order=order,
            author=self.request.user,
            target_driver=order.driver,
        )

        # Перерахунок середнього рейтингу водія
        # Зважений — початкове 5.0 враховується як 5 «віртуальних» оцінок
        driver = order.driver
        reviews = Review.objects.filter(target_driver=driver)
        review_count = reviews.count()
        review_sum = sum(r.rating for r in reviews)
        # 5 віртуальних оцінок по 5.0 + реальні оцінки
        weighted_avg = (5 * 5.0 + review_sum) / (5 + review_count)
        driver.rating = round(weighted_avg, 2)
        driver.save(update_fields=["rating"])
