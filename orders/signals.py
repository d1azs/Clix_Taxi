"""
orders/signals.py — WebSocket broadcast helpers для замовлень.

Використовуються з REST views для push-нотифікацій через Channels layer.
"""

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer


def broadcast_new_order(order):
    """Ретрансляція нового замовлення в orders_feed (водії + диспетчер)."""
    channel_layer = get_channel_layer()
    if not channel_layer:
        return

    payload = {
        "type": "new_order",
        "order": {
            "id": str(order.id),
            "pickup_address": order.pickup_address,
            "dropoff_address": order.dropoff_address,
            "pickup_lat": order.pickup_lat,
            "pickup_lng": order.pickup_lng,
            "dropoff_lat": order.dropoff_lat,
            "dropoff_lng": order.dropoff_lng,
            "required_class": order.required_class,
            "estimated_price": str(order.estimated_price) if order.estimated_price else None,
            "upfront_price": str(order.upfront_price) if order.upfront_price else None,
            "status": order.status,
        },
    }
    async_to_sync(channel_layer.group_send)("orders_feed", payload)


def broadcast_order_status(order):
    """Ретрансляція зміни статусу замовлення."""
    channel_layer = get_channel_layer()
    if not channel_layer:
        return

    payload = {
        "type": "order_status_update",
        "order_id": str(order.id),
        "status": order.status,
    }

    # Сповістити tracking group (пасажир)
    async_to_sync(channel_layer.group_send)(
        f"tracking_{order.id}", payload
    )

    # Сповістити orders_feed (водії + диспетчер)
    async_to_sync(channel_layer.group_send)("orders_feed", payload)
