"""
vehicles/models.py — Модель автомобіля водія.
"""

import uuid

from django.db import models

from accounts.models import DriverProfile


# ---------------------------------------------------------------------------
# Клас автомобіля
# ---------------------------------------------------------------------------
class VehicleClass(models.TextChoices):
    ECONOMY = "ECONOMY", "Економ"
    PREMIUM = "PREMIUM", "Комфорт"
    BUSINESS = "BUSINESS", "Бізнес"
    MINIVAN = "MINIVAN", "Мінівен"


# ---------------------------------------------------------------------------
# Модель Vehicle
# ---------------------------------------------------------------------------
class Vehicle(models.Model):
    """Автомобіль, прив'язаний до профілю водія."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    driver_profile = models.ForeignKey(
        DriverProfile,
        on_delete=models.CASCADE,
        related_name="vehicles",
        verbose_name="Водій",
    )
    make_model = models.CharField(
        max_length=100,
        verbose_name="Марка та модель",
        help_text="Наприклад: Škoda Octavia",
    )
    license_plate = models.CharField(
        max_length=15,
        unique=True,
        verbose_name="Номерний знак",
    )
    vehicle_class = models.CharField(
        max_length=10,
        choices=VehicleClass.choices,
        default=VehicleClass.ECONOMY,
        verbose_name="Клас авто",
    )
    color = models.CharField(max_length=50, blank=True, verbose_name="Колір")
    is_pet_friendly = models.BooleanField(
        default=False, verbose_name="Дозволені тварини"
    )
    has_child_seat = models.BooleanField(default=False, verbose_name="Дитяче крісло")
    is_wheelchair_accessible = models.BooleanField(
        default=False,
        verbose_name="Доступність для інвалідних візків",
    )
    is_active = models.BooleanField(default=True, verbose_name="Активний")

    class Meta:
        verbose_name = "Автомобіль"
        verbose_name_plural = "Автомобілі"
        ordering = ["-id"]

    def __str__(self):
        desc = f"{self.make_model} ({self.license_plate})"
        return f"{desc} — {self.get_vehicle_class_display()}"
