"""
vehicles/serializers.py — Серіалайзери для автомобілів.
"""

from rest_framework import serializers
from .models import Vehicle


class VehicleSerializer(serializers.ModelSerializer):
    """Серіалайзер автомобіля."""

    vehicle_class_display = serializers.CharField(
        source="get_vehicle_class_display", read_only=True
    )

    class Meta:
        model = Vehicle
        fields = [
            "id",
            "make_model",
            "license_plate",
            "vehicle_class",
            "vehicle_class_display",
            "color",
            "is_pet_friendly",
            "has_child_seat",
            "is_wheelchair_accessible",
            "is_active",
        ]
        read_only_fields = ["id"]
