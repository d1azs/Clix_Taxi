"""
orders/urls.py — URL-маршрути для замовлень.
"""

from django.urls import path

from . import views

app_name = "orders"

urlpatterns = [
    # ── Пасажир ──
    path(
        "passenger/orders/",
        views.PassengerOrderCreateView.as_view(),
        name="passenger-order-create",
    ),
    path(
        "passenger/orders/active/",
        views.PassengerActiveOrderView.as_view(),
        name="passenger-order-active",
    ),
    path(
        "passenger/orders/<uuid:pk>/cancel/",
        views.PassengerCancelOrderView.as_view(),
        name="passenger-order-cancel",
    ),
    path(
        "passenger/orders/<uuid:pk>/dismiss-rating/",
        views.DismissRatingView.as_view(),
        name="passenger-order-dismiss-rating",
    ),
    # ── Nearby Drivers (для маркерів на карті) ──
    path(
        "drivers/nearby/",
        views.NearbyDriversView.as_view(),
        name="drivers-nearby",
    ),
    # ── Водій ──
    path(
        "driver/orders/active/",
        views.DriverActiveOrderView.as_view(),
        name="driver-order-active",
    ),
    path(
        "orders/available/",
        views.AvailableOrdersView.as_view(),
        name="orders-available",
    ),
    path(
        "orders/<uuid:pk>/accept/",
        views.AcceptOrderView.as_view(),
        name="order-accept",
    ),
    path(
        "orders/<uuid:pk>/reject/",
        views.RejectOrderView.as_view(),
        name="order-reject",
    ),
    path(
        "orders/<uuid:pk>/status/",
        views.UpdateOrderStatusView.as_view(),
        name="order-status-update",
    ),
    # ── Диспетчер ──
    path(
        "dispatcher/orders/",
        views.DispatcherOrderCreateView.as_view(),
        name="dispatcher-order-create",
    ),
    path(
        "dispatcher/orders/list/",
        views.DispatcherOrderListView.as_view(),
        name="dispatcher-order-list",
    ),
    path(
        "dispatcher/orders/<uuid:pk>/",
        views.DispatcherOrderDetailView.as_view(),
        name="dispatcher-order-detail",
    ),
    path(
        "dispatcher/complaints/",
        views.DispatcherComplaintsView.as_view(),
        name="dispatcher-complaints",
    ),
    path(
        "dispatcher/orders/<uuid:pk>/force-assign/",
        views.DispatcherForceAssignView.as_view(),
        name="dispatcher-force-assign",
    ),
    path(
        "dispatcher/orders/<uuid:pk>/override/",
        views.DispatcherFareOverrideView.as_view(),
        name="dispatcher-fare-override",
    ),
    path(
        "dispatcher/drivers/",
        views.DispatcherDriverListView.as_view(),
        name="dispatcher-drivers",
    ),
    path(
        "dispatcher/queues/",
        views.DispatcherQueueView.as_view(),
        name="dispatcher-queues",
    ),
    path(
        "dispatcher/queues/<uuid:pk>/entries/",
        views.DispatcherQueueView.as_view(),
        name="dispatcher-queue-entries",
    ),
    # ── Спільне ──
    path(
        "orders/history/",
        views.OrderHistoryView.as_view(),
        name="orders-history",
    ),
    path(
        "orders/<uuid:pk>/review/",
        views.CreateReviewView.as_view(),
        name="order-review",
    ),
    # ── Ціноутворення ──
    path(
        "orders/quote/",
        views.PriceQuoteView.as_view(),
        name="price-quote",
    ),
]
