"""
accounts/urls.py — URL-маршрути для аутентифікації та профілю.
"""

from django.urls import path

from rest_framework_simplejwt.views import TokenRefreshView

from . import views

urlpatterns = [
    # Автентифікація
    path("auth/login/", views.LoginView.as_view(), name="login"),
    path("auth/register/", views.RegisterView.as_view(), name="register"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    # Профіль
    path("users/me/", views.MeView.as_view(), name="me"),
    # Водій
    path("driver/status/", views.DriverStatusView.as_view(), name="driver-status"),
    path(
        "driver/location/",
        views.DriverLocationUpdateView.as_view(),
        name="driver-location",
    ),
]
