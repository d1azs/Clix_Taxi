"""
orders/urls.py — URL-маршрути для замовлень.
"""

from django.urls import path
from . import views

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
]
