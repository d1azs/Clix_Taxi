"""
accounts/models.py — Кастомна модель User та DriverProfile.
"""

import uuid

from django.contrib.auth.models import (
    AbstractBaseUser,
    BaseUserManager,
    PermissionsMixin,
)
from django.db import models


# ---------------------------------------------------------------------------
# Константи ролей
# ---------------------------------------------------------------------------
class Role(models.TextChoices):
    PASSENGER = "PASSENGER", "Пасажир"
    DRIVER = "DRIVER", "Водій"
    DISPATCHER = "DISPATCHER", "Диспетчер"


# ---------------------------------------------------------------------------
# Менеджер для кастомного User
# ---------------------------------------------------------------------------
class UserManager(BaseUserManager):
    """Менеджер кастомного User — аутентифікація за номером телефону."""

    def create_user(self, phone_number, password=None, **extra_fields):
        if not phone_number:
            raise ValueError("Номер телефону обов'язковий")
        user = self.model(phone_number=phone_number, **extra_fields)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, phone_number, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        return self.create_user(phone_number, password, **extra_fields)


# ---------------------------------------------------------------------------
# Модель User
# ---------------------------------------------------------------------------
class User(AbstractBaseUser, PermissionsMixin):
    """Кастомний користувач CLIX — аутентифікація за номером телефону."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone_number = models.CharField(
        max_length=20,
        unique=True,
        verbose_name="Номер телефону",
        help_text="Формат: +380XXXXXXXXX",
    )
    first_name = models.CharField(max_length=100, blank=True, verbose_name="Ім'я")
    last_name = models.CharField(max_length=100, blank=True, verbose_name="Прізвище")
    roles = models.JSONField(
        default=list,
        verbose_name="Ролі",
        help_text="Масив ролей: PASSENGER, DRIVER, DISPATCHER",
    )
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    USERNAME_FIELD = "phone_number"
    REQUIRED_FIELDS = []

    class Meta:
        verbose_name = "Користувач"
        verbose_name_plural = "Користувачі"

    def __str__(self):
        return f'{self.phone_number} ({", ".join(self.roles)})'

    # Хелпери для перевірки ролей
    def has_role(self, role: str) -> bool:
        return role in self.roles

    @property
    def is_passenger(self):
        return self.has_role(Role.PASSENGER)

    @property
    def is_driver(self):
        return self.has_role(Role.DRIVER)

    @property
    def is_dispatcher(self):
        return self.has_role(Role.DISPATCHER)


# ---------------------------------------------------------------------------
# Статус водія
# ---------------------------------------------------------------------------
class DriverStatus(models.TextChoices):
    ONLINE = "ONLINE", "Онлайн"
    OFFLINE = "OFFLINE", "Офлайн"


# ---------------------------------------------------------------------------
# Профіль водія
# ---------------------------------------------------------------------------
class DriverProfile(models.Model):
    """One-to-One до User. Зберігає статус та рейтинг водія."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="driver_profile",
        verbose_name="Користувач",
    )
    status = models.CharField(
        max_length=10,
        choices=DriverStatus.choices,
        default=DriverStatus.OFFLINE,
        verbose_name="Статус",
    )
    rating = models.DecimalField(
        max_digits=3,
        decimal_places=2,
        default=5.00,
        verbose_name="Рейтинг",
    )
    total_trips = models.PositiveIntegerField(
        default=0, verbose_name="Кількість поїздок"
    )
    total_earnings = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        verbose_name="Загальний заробіток (Kč)",
    )
    # Поточна геолокація водія
    current_lat = models.FloatField(null=True, blank=True, verbose_name="Широта")
    current_lng = models.FloatField(null=True, blank=True, verbose_name="Довгота")

    class Meta:
        verbose_name = "Профіль водія"
        verbose_name_plural = "Профілі водіїв"

    def __str__(self):
        return f"Водій: {self.user.phone_number} ({self.status})"
