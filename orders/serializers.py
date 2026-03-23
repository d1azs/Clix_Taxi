"""
orders/serializers.py — Серіалайзери замовлень та відгуків.
"""

from rest_framework import serializers

from accounts.serializers import DriverProfileSerializer

from .models import Order, Review


# ---------------------------------------------------------------------------
# Серіалайзер відгуку
# ---------------------------------------------------------------------------
class ReviewSerializer(serializers.ModelSerializer):
    """Серіалайзер відгуку / скарги."""

    author_phone = serializers.CharField(source="author.phone_number", read_only=True)

    class Meta:
        model = Review
        fields = [
            "id",
            "order",
            "author",
            "author_phone",
            "target_driver",
            "rating",
            "comment",
            "is_complaint",
            "created_at",
        ]
        read_only_fields = ["id", "author", "author_phone", "created_at"]


# ---------------------------------------------------------------------------
# Серіалайзер замовлення (повний)
# ---------------------------------------------------------------------------
class OrderSerializer(serializers.ModelSerializer):
    """Серіалайзер замовлення з деталями водія та відгуком."""

    status_display = serializers.CharField(source="get_status_display", read_only=True)
    class_display = serializers.CharField(
        source="get_required_class_display", read_only=True
    )
    driver_info = DriverProfileSerializer(source="driver", read_only=True)
    review = ReviewSerializer(read_only=True)
    passenger_phone = serializers.CharField(
        source="passenger.phone_number", read_only=True, default=None
    )

    class Meta:
        model = Order
        fields = [
            "id",
            # Зв'язки
            "dispatcher",
            "passenger",
            "passenger_phone",
            "driver",
            "driver_info",
            # Локації
            "pickup_address",
            "dropoff_address",
            "pickup_lat",
            "pickup_lng",
            "dropoff_lat",
            "dropoff_lng",
            # Деталі
            "pickup_time",
            "required_class",
            "class_display",
            "is_pet_friendly",
            "needs_child_seat",
            "needs_wheelchair_access",
            # Статус
            "status",
            "status_display",
            "estimated_price",
            "route_polyline",
            # Час
            "created_at",
            "accepted_at",
            "completed_at",
            # Відгук
            "review",
        ]
        read_only_fields = [
            "id",
            "status",
            "driver",
            "dispatcher",
            "created_at",
            "accepted_at",
            "completed_at",
        ]


# ---------------------------------------------------------------------------
# Серіалайзер для створення замовлення пасажиром
# ---------------------------------------------------------------------------
class PassengerOrderCreateSerializer(serializers.ModelSerializer):
    """Серіалайзер для створення замовлення пасажиром."""

    class Meta:
        model = Order
        fields = [
            "pickup_address",
            "dropoff_address",
            "pickup_lat",
            "pickup_lng",
            "dropoff_lat",
            "dropoff_lng",
            "pickup_time",
            "required_class",
            "is_pet_friendly",
            "needs_child_seat",
            "needs_wheelchair_access",
            "estimated_price",
        ]


# ---------------------------------------------------------------------------
# Серіалайзер для створення замовлення диспетчером
# ---------------------------------------------------------------------------
class DispatcherOrderCreateSerializer(serializers.ModelSerializer):
    """Серіалайзер для створення замовлення диспетчером (від імені клієнта)."""

    passenger_phone = serializers.CharField(
        write_only=True,
        required=False,
        help_text="Номер телефону клієнта (необов`язково)",
    )

    class Meta:
        model = Order
        fields = [
            "passenger_phone",
            "pickup_address",
            "dropoff_address",
            "pickup_lat",
            "pickup_lng",
            "dropoff_lat",
            "dropoff_lng",
            "pickup_time",
            "required_class",
            "is_pet_friendly",
            "needs_child_seat",
            "needs_wheelchair_access",
            "estimated_price",
        ]
