"""
orders/routing.py — WebSocket URL маршрути для CLIX Taxi.
"""

from django.urls import re_path

from . import consumers

websocket_urlpatterns = [
    re_path(r"ws/telemetry/$", consumers.TelemetryConsumer.as_asgi()),
    re_path(r"ws/orders/$", consumers.OrderConsumer.as_asgi()),
    re_path(r"ws/dispatcher/fleet/$", consumers.DispatcherFleetConsumer.as_asgi()),
]
