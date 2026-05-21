"""
orders/queue_service.py — Smart Airport Queue System (FIFO).

Geofenced logic для віртуальних черг (аеропорт, вокзал тощо).
Водій автоматично потрапляє у чергу, коли знаходиться в радіусі геозони.
"""

import math

from django.db import transaction
from django.db.models import F, Max

from accounts.models import DriverProfile

from .models import VirtualQueue, VirtualQueueEntry


def haversine_distance(lat1, lng1, lat2, lng2):
    """Відстань між двома точками в метрах (Haversine)."""
    R = 6371000  # Радіус Землі, метри
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lng2 - lng1)
    a = (
        math.sin(dphi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    )
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def check_and_update_queue(driver_profile: DriverProfile):
    """
    Перевірити геолокацію водія щодо активних віртуальних черг.
    - Якщо водій у зоні → додати до черги (якщо ще немає).
    - Якщо водій вийшов із зони → видалити з черги.

    Повертає dict з інформацією про поточну чергу (або None).
    """
    lat, lng = driver_profile.current_lat, driver_profile.current_lng
    if lat is None or lng is None:
        return None

    active_queues = VirtualQueue.objects.filter(is_active=True)
    current_entry = None

    for queue in active_queues:
        distance = haversine_distance(lat, lng, queue.lat, queue.lng)
        is_inside = distance <= queue.radius_meters

        existing = VirtualQueueEntry.objects.filter(
            queue=queue, driver=driver_profile
        ).first()

        if is_inside and not existing:
            # Входить у зону — додати у чергу
            with transaction.atomic():
                max_pos = (
                    VirtualQueueEntry.objects.filter(queue=queue)
                    .aggregate(Max("position"))
                    .get("position__max")
                    or 0
                )
                current_entry = VirtualQueueEntry.objects.create(
                    queue=queue,
                    driver=driver_profile,
                    position=max_pos + 1,
                )
        elif not is_inside and existing:
            # Вийшов з зони — видалити з черги + перенумерувати
            pos = existing.position
            existing.delete()
            VirtualQueueEntry.objects.filter(queue=queue, position__gt=pos).update(
                position=F("position") - 1
            )
        elif is_inside and existing:
            current_entry = existing

    if current_entry:
        return {
            "queue_name": current_entry.queue.name,
            "position": current_entry.position,
            "total_in_queue": VirtualQueueEntry.objects.filter(
                queue=current_entry.queue
            ).count(),
        }
    return None


def get_next_driver_from_queue(queue_id):
    """Повернути водія з позицією #1 (першого в черзі)."""
    entry = (
        VirtualQueueEntry.objects.filter(queue_id=queue_id)
        .select_related("driver", "driver__user")
        .order_by("position")
        .first()
    )
    return entry.driver if entry else None


def remove_driver_from_queue(queue_id, driver_profile):
    """Видалити водія з черги після того, як він прийняв замовлення."""
    entry = VirtualQueueEntry.objects.filter(
        queue_id=queue_id, driver=driver_profile
    ).first()
    if entry:
        pos = entry.position
        entry.delete()
        # Зсунути позиції наступних водіїв
        VirtualQueueEntry.objects.filter(queue_id=queue_id, position__gt=pos).update(
            position=F("position") - 1
        )
