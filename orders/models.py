"""
orders/models.py — Моделі замовлень, відгуків та скарг.
"""

import uuid
from django.db import models
from django.conf import settings
from accounts.models import DriverProfile


# ---------------------------------------------------------------------------
# Статуси замовлення (життєвий цикл)
# ---------------------------------------------------------------------------
class OrderStatus(models.TextChoices):
    PENDING = "PENDING", "Очікує"
    ACCEPTED = "ACCEPTED", "Прийнято"
    EN_ROUTE = "EN_ROUTE", "В дорозі до клієнта"
    IN_PROGRESS = "IN_PROGRESS", "Поїздка"
    COMPLETED = "COMPLETED", "Завершено"
    CANCELLED = "CANCELLED", "Скасовано"


# ---------------------------------------------------------------------------
# Клас авто для замовлення
# ---------------------------------------------------------------------------
class RequiredClass(models.TextChoices):
    ECONOMY = "ECONOMY", "Економ"
    PREMIUM = "PREMIUM", "Комфорт"
    BUSINESS = "BUSINESS", "Бізнес"
    MINIVAN = "MINIVAN", "Мінівен"


# ---------------------------------------------------------------------------
# Модель Order
# ---------------------------------------------------------------------------
class Order(models.Model):
    """Замовлення поїздки CLIX."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # Зв'язки з користувачами
    dispatcher = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="dispatched_orders",
        verbose_name="Диспетчер",
    )
    passenger = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="passenger_orders",
        verbose_name="Пасажир",
    )
    driver = models.ForeignKey(
        DriverProfile,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="driver_orders",
        verbose_name="Водій",
    )

    # Адреси та координати
    pickup_address = models.CharField(max_length=300, verbose_name="Адреса подачі")
    dropoff_address = models.CharField(
        max_length=300, verbose_name="Адреса призначення"
    )
    pickup_lat = models.FloatField(verbose_name="Широта подачі")
    pickup_lng = models.FloatField(verbose_name="Довгота подачі")
    dropoff_lat = models.FloatField(verbose_name="Широта призначення")
    dropoff_lng = models.FloatField(verbose_name="Довгота призначення")

    # Деталі поїздки
    pickup_time = models.DateTimeField(verbose_name="Час подачі")
    required_class = models.CharField(
        max_length=10,
        choices=RequiredClass.choices,
        default=RequiredClass.ECONOMY,
        verbose_name="Клас авто",
    )

    # Додаткові опції
    is_pet_friendly = models.BooleanField(default=False, verbose_name="З тваринами")
    needs_child_seat = models.BooleanField(default=False, verbose_name="Дитяче крісло")
    needs_wheelchair_access = models.BooleanField(
        default=False,
        verbose_name="Інвалідний візок",
    )

    # Статус та ціна
    status = models.CharField(
        max_length=15,
        choices=OrderStatus.choices,
        default=OrderStatus.PENDING,
        verbose_name="Статус",
    )
    estimated_price = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name="Орієнтовна ціна (Kč)",
    )

    # Маршрут (Polyline для побудови маршруту на карті)
    route_polyline = models.TextField(
        blank=True,
        verbose_name="Polyline маршруту",
        help_text="Encoded polyline від Google Directions API",
    )

    # Часові мітки
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Створено")
    accepted_at = models.DateTimeField(null=True, blank=True, verbose_name="Прийнято о")
    completed_at = models.DateTimeField(
        null=True, blank=True, verbose_name="Завершено о"
    )

    class Meta:
        verbose_name = "Замовлення"
        verbose_name_plural = "Замовлення"
        ordering = ["-created_at"]

    def __str__(self):
        return f"Замовлення {self.id.__str__()[:8]} — {self.get_status_display()}"


# ---------------------------------------------------------------------------
# Відгук / Скарга
# ---------------------------------------------------------------------------
class Review(models.Model):
    """Відгук пасажира про поїздку (або скарга)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    order = models.OneToOneField(
        Order,
        on_delete=models.CASCADE,
        related_name="review",
        verbose_name="Замовлення",
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="reviews_written",
        verbose_name="Автор",
    )
    target_driver = models.ForeignKey(
        DriverProfile,
        on_delete=models.CASCADE,
        related_name="reviews_received",
        verbose_name="Водій",
    )
    rating = models.PositiveSmallIntegerField(
        verbose_name="Оцінка",
        help_text="Від 1 до 5",
    )
    comment = models.TextField(blank=True, verbose_name="Коментар")
    is_complaint = models.BooleanField(default=False, verbose_name="Це скарга?")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Відгук"
        verbose_name_plural = "Відгуки"

    def __str__(self):
        kind = "Скарга" if self.is_complaint else "Відгук"
        return f"{kind} на замовлення {self.order_id.__str__()[:8]} — ★{self.rating}"
