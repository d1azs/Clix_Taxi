"""
orders/pricing.py — Fixed Pricing Computation Engine.

Розрахунок upfront price з прозорою розбивкою для пасажира.
"""

import math

# ── Тарифна сітка (Kč) ──
TARIFFS = {
    "ECONOMY": {"base": 45, "per_km": 12, "per_min": 4, "min_fare": 45},
    "PREMIUM": {"base": 65, "per_km": 17, "per_min": 6, "min_fare": 65},
    "BUSINESS": {"base": 90, "per_km": 22, "per_min": 8, "min_fare": 90},
    "MINIVAN": {"base": 70, "per_km": 15, "per_min": 5, "min_fare": 70},
}

# Комісія платформи
COMMISSION_RATE = 0.10  # 10%


def haversine_km(lat1, lng1, lat2, lng2):
    """Відстань між двома точками в км (Haversine)."""
    R = 6371
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def estimate_duration_min(distance_km):
    """Оцінка часу поїздки (хвилини). ~30 км/год середня в місті."""
    return distance_km / 30 * 60


def compute_fixed_price(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, vehicle_class="ECONOMY"):
    """
    Повна розбивка ціни:
    {
        "distance_km": 8.5,
        "estimated_duration_min": 17,
        "base_fare": 45,
        "distance_charge": 102,
        "time_charge": 68,
        "subtotal": 215,
        "commission": 21.5,
        "upfront_price": 215,
        "vehicle_class": "ECONOMY"
    }
    """
    tariff = TARIFFS.get(vehicle_class, TARIFFS["ECONOMY"])
    distance_km = haversine_km(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
    duration_min = estimate_duration_min(distance_km)

    base = tariff["base"]
    distance_charge = round(distance_km * tariff["per_km"], 2)
    time_charge = round(duration_min * tariff["per_min"], 2)
    subtotal = round(base + distance_charge + time_charge, 2)
    upfront = max(subtotal, tariff["min_fare"])
    commission = round(upfront * COMMISSION_RATE, 2)

    return {
        "distance_km": round(distance_km, 2),
        "estimated_duration_min": round(duration_min),
        "base_fare": base,
        "distance_charge": distance_charge,
        "time_charge": time_charge,
        "subtotal": subtotal,
        "commission": commission,
        "upfront_price": upfront,
        "vehicle_class": vehicle_class,
    }


def compute_all_classes(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng):
    """Повертає прайс для всіх класів авто одночасно (для UI-карток вибору)."""
    return {
        cls: compute_fixed_price(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, cls)
        for cls in TARIFFS
    }
