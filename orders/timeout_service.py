"""
orders/timeout_service.py — Graceful timeout logic for orders.

Автоматичне скасування PENDING замовлень без водія після таймауту.
Призначено для виклику через Django management command або Celery.
"""

from datetime import timedelta

from django.utils import timezone

from .models import Order, OrderStatus
from .signals import broadcast_order_status


# Таймаут для пошуку водія — 5 хвилин
DRIVER_SEARCH_TIMEOUT = timedelta(minutes=5)

# Таймаут для прибуття (EN_ROUTE) — 20 хвилин
ARRIVAL_TIMEOUT = timedelta(minutes=20)


def expire_pending_orders():
    """
    Скасування всіх PENDING замовлень, які перевищили таймаут.
    Повертає кількість скасованих замовлень.
    """
    cutoff = timezone.now() - DRIVER_SEARCH_TIMEOUT
    expired_orders = Order.objects.filter(
        status=OrderStatus.PENDING,
        created_at__lt=cutoff,
    )

    count = 0
    for order in expired_orders:
        order.status = OrderStatus.CANCELLED
        order.save(update_fields=["status"])
        broadcast_order_status(order)
        count += 1

    return count


def check_stalled_enroute():
    """
    Виявити замовлення EN_ROUTE, де водій не прибув протягом таймауту.
    Повертає список замовлень для ескалації диспетчеру.
    """
    cutoff = timezone.now() - ARRIVAL_TIMEOUT
    stalled = Order.objects.filter(
        status=OrderStatus.EN_ROUTE,
        accepted_at__lt=cutoff,
    ).select_related("driver", "driver__user")

    return list(stalled)
