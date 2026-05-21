"""
orders/ranking_service.py — Automatic Driver Ranking Engine.

Обчислює composite_score на основі:
  - acceptance_rate (вага: 0.3)
  - rating (вага: 0.4)
  - avg_response_time (вага: 0.3, інверсна — менший час = кращий скор)
"""

from django.db.models import Avg, Count, Q

from accounts.models import DriverProfile, DriverRanking

from .models import Order, OrderStatus


def recalculate_driver_ranking(driver_profile: DriverProfile):
    """
    Перерахунок ранкінгу для одного водія.
    Виклик: після завершення/відхилення замовлення.
    """
    # 1. Acceptance Rate — прийняті / (прийняті + відхилені)
    total_offered = (
        Order.objects.filter(Q(driver=driver_profile) | Q(status=OrderStatus.PENDING))
        .filter(
            driver=driver_profile,
        )
        .count()
    )

    accepted = Order.objects.filter(
        driver=driver_profile,
        status__in=[
            OrderStatus.ACCEPTED,
            OrderStatus.EN_ROUTE,
            OrderStatus.IN_PROGRESS,
            OrderStatus.COMPLETED,
        ],
    ).count()

    acceptance_rate = (accepted / max(total_offered, 1)) * 100

    # 2. Rating — безпосередньо з профілю
    rating = float(driver_profile.rating)

    # 3. Average response time — мок (у реальності з accepted_at - created_at)
    recent_orders = Order.objects.filter(
        driver=driver_profile,
        accepted_at__isnull=False,
        created_at__isnull=False,
    ).order_by("-created_at")[:20]

    if recent_orders:
        response_times = [
            (o.accepted_at - o.created_at).total_seconds()
            for o in recent_orders
            if o.accepted_at and o.created_at
        ]
        avg_response = (
            sum(response_times) / len(response_times) if response_times else 0
        )
    else:
        avg_response = 0

    # 4. Composite Score (0-100)
    # Нормалізація: rating (1-5) → 0-100, response_time → 0-100 (інверсно)
    rating_score = (rating / 5) * 100
    response_score = max(0, 100 - avg_response / 3)  # 300с → 0 балів
    acceptance_score = acceptance_rate

    composite = round(
        acceptance_score * 0.3 + rating_score * 0.4 + response_score * 0.3,
        2,
    )

    ranking, _ = DriverRanking.objects.update_or_create(
        driver=driver_profile,
        defaults={
            "acceptance_rate": round(acceptance_rate, 2),
            "avg_response_time": round(avg_response, 2),
            "composite_score": composite,
        },
    )
    return ranking


def recalculate_all_rankings():
    """Пакетний перерахунок ранкінгів усіх водіїв."""
    for profile in DriverProfile.objects.all():
        recalculate_driver_ranking(profile)
