"""
orders/consumers.py — WebSocket consumers для CLIX Taxi.

Consumers:
  - TelemetryConsumer: GPS-координати від водіїв → dispatcher + passengers.
  - OrderConsumer: Нові замовлення → водіям, оновлення статусів → пасажирам.
"""

import json

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer


# ═══════════════════════════════════════════════════════════════════════════
# GPS Telemetry — /ws/telemetry/
# ═══════════════════════════════════════════════════════════════════════════
class TelemetryConsumer(AsyncJsonWebsocketConsumer):
    """
    Водій надсилає GPS-координати:
      {"lat": 50.0755, "lng": 14.4378}

    Координати зберігаються в DriverProfile та ретранслюються:
      - Group 'fleet' → для dispatcher panel (всі водії)
      - Group 'tracking_<order_id>' → для пасажира, який чекає на водія
    """

    async def connect(self):
        self.user = self.scope.get("user")
        if not self.user or not self.user.is_authenticated:
            await self.close(code=4001)
            return

        is_driver = await self._check_driver_role()
        if not is_driver:
            await self.close(code=4003)
            return

        self.driver_id = str(self.user.id)

        # Підключаємося до group для fleet-трекінгу (dispatcher)
        await self.channel_layer.group_add("fleet", self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard("fleet", self.channel_name)

    async def receive_json(self, content, **kwargs):
        """Отримуємо GPS від водія, зберігаємо та ретранслюємо."""
        lat = content.get("lat")
        lng = content.get("lng")

        if lat is None or lng is None:
            await self.send_json({"error": "lat та lng обов'язкові"})
            return

        # Зберегти в БД
        await self._update_driver_location(lat, lng)

        # Отримати active order для ретрансляції пасажиру
        active_order_id = await self._get_active_order_id()

        payload = {
            "type": "driver.location",
            "driver_id": self.driver_id,
            "lat": lat,
            "lng": lng,
        }

        # Ретрансляція на fleet group (dispatcher бачить всіх)
        await self.channel_layer.group_send("fleet", payload)

        # Ретрансляція на tracking group (пасажир бачить свого водія)
        if active_order_id:
            await self.channel_layer.group_send(f"tracking_{active_order_id}", payload)

    async def driver_location(self, event):
        """Відправити оновлення координат клієнтам у group."""
        await self.send_json(
            {
                "type": "location_update",
                "driver_id": event["driver_id"],
                "lat": event["lat"],
                "lng": event["lng"],
            }
        )

    @database_sync_to_async
    def _check_driver_role(self):
        return self.user.has_role("DRIVER") and hasattr(self.user, "driver_profile")

    @database_sync_to_async
    def _update_driver_location(self, lat, lng):
        profile = self.user.driver_profile
        profile.current_lat = float(lat)
        profile.current_lng = float(lng)
        profile.save(update_fields=["current_lat", "current_lng"])

    @database_sync_to_async
    def _get_active_order_id(self):
        from orders.models import Order, OrderStatus

        active_statuses = [
            OrderStatus.ACCEPTED,
            OrderStatus.EN_ROUTE,
            OrderStatus.IN_PROGRESS,
        ]
        order = (
            Order.objects.filter(
                driver=self.user.driver_profile,
                status__in=active_statuses,
            )
            .values_list("id", flat=True)
            .first()
        )
        return str(order) if order else None


# ═══════════════════════════════════════════════════════════════════════════
# Order Feed — /ws/orders/
# ═══════════════════════════════════════════════════════════════════════════
class OrderConsumer(AsyncJsonWebsocketConsumer):
    """
    Real-time order feed:
      - Водії отримують нові PENDING замовлення
      - Пасажири підписуються на tracking_<order_id> для оновлень статусу
    """

    async def connect(self):
        self.user = self.scope.get("user")
        if not self.user or not self.user.is_authenticated:
            await self.close(code=4001)
            return

        # Водій підключається до загальної черги замовлень
        is_driver = await self._is_driver()
        if is_driver:
            await self.channel_layer.group_add("orders_feed", self.channel_name)

        # Пасажир підключається до трекінгу свого замовлення
        is_passenger = await self._is_passenger()
        if is_passenger:
            order_id = await self._get_passenger_active_order_id()
            if order_id:
                self.tracking_group = f"tracking_{order_id}"
                await self.channel_layer.group_add(
                    self.tracking_group, self.channel_name
                )
            else:
                self.tracking_group = None
        else:
            self.tracking_group = None

        await self.accept()

    async def disconnect(self, close_code):
        is_driver = await self._is_driver()
        if is_driver:
            await self.channel_layer.group_discard("orders_feed", self.channel_name)
        if hasattr(self, "tracking_group") and self.tracking_group:
            await self.channel_layer.group_discard(
                self.tracking_group, self.channel_name
            )

    async def receive_json(self, content, **kwargs):
        """Пасажир може підписатися на трекінг конкретного замовлення."""
        action = content.get("action")

        if action == "subscribe_tracking":
            order_id = content.get("order_id")
            if order_id:
                group = f"tracking_{order_id}"
                await self.channel_layer.group_add(group, self.channel_name)
                self.tracking_group = group
                await self.send_json({"type": "subscribed", "order_id": order_id})

    # ── Group message handlers ──

    async def new_order(self, event):
        """Нове замовлення з'являється у водія на радарі."""
        await self.send_json(
            {
                "type": "new_order",
                "order": event["order"],
            }
        )

    async def order_status_update(self, event):
        """Оновлення статусу замовлення."""
        await self.send_json(
            {
                "type": "order_status_update",
                "order_id": event["order_id"],
                "status": event["status"],
            }
        )

    async def driver_location(self, event):
        """Координати водія для tracking group пасажира."""
        await self.send_json(
            {
                "type": "location_update",
                "driver_id": event["driver_id"],
                "lat": event["lat"],
                "lng": event["lng"],
            }
        )

    @database_sync_to_async
    def _is_driver(self):
        return self.user.has_role("DRIVER")

    @database_sync_to_async
    def _is_passenger(self):
        return self.user.has_role("PASSENGER")

    @database_sync_to_async
    def _get_passenger_active_order_id(self):
        from orders.models import Order, OrderStatus

        active_statuses = [
            OrderStatus.PENDING,
            OrderStatus.ACCEPTED,
            OrderStatus.EN_ROUTE,
            OrderStatus.IN_PROGRESS,
        ]
        order = (
            Order.objects.filter(
                passenger=self.user,
                status__in=active_statuses,
            )
            .values_list("id", flat=True)
            .first()
        )
        return str(order) if order else None


# ═══════════════════════════════════════════════════════════════════════════
# Dispatcher Fleet Feed — /ws/dispatcher/fleet/
# ═══════════════════════════════════════════════════════════════════════════
class DispatcherFleetConsumer(AsyncJsonWebsocketConsumer):
    """
    Глобальний macro-state push для диспетчерської панелі:
      - GPS всіх водіїв (fleet group)
      - Оновлення статусів замовлень
      - Нові замовлення
    """

    async def connect(self):
        self.user = self.scope.get("user")
        if not self.user or not self.user.is_authenticated:
            await self.close(code=4001)
            return

        is_dispatcher = await self._is_dispatcher()
        if not is_dispatcher:
            await self.close(code=4003)
            return

        await self.channel_layer.group_add("fleet", self.channel_name)
        await self.channel_layer.group_add("orders_feed", self.channel_name)
        await self.channel_layer.group_add("dispatcher_events", self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard("fleet", self.channel_name)
        await self.channel_layer.group_discard("orders_feed", self.channel_name)
        await self.channel_layer.group_discard("dispatcher_events", self.channel_name)

    # ── Усі events з fleet/orders groups ──

    async def driver_location(self, event):
        await self.send_json(
            {
                "type": "driver_location",
                "driver_id": event["driver_id"],
                "lat": event["lat"],
                "lng": event["lng"],
            }
        )

    async def new_order(self, event):
        await self.send_json(
            {
                "type": "new_order",
                "order": event["order"],
            }
        )

    async def order_status_update(self, event):
        await self.send_json(
            {
                "type": "order_status_update",
                "order_id": event["order_id"],
                "status": event["status"],
            }
        )

    async def dispatcher_event(self, event):
        """Загальний канал для подій диспетчера."""
        await self.send_json(event["data"])

    @database_sync_to_async
    def _is_dispatcher(self):
        return self.user.has_role("DISPATCHER")
