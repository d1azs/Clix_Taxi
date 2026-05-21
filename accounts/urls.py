"""
accounts/urls.py — URL-маршрути для аутентифікації, профілю, KYC.
"""

from django.urls import path

from rest_framework_simplejwt.views import TokenRefreshView

from . import views

app_name = "accounts"

urlpatterns = [
    # Автентифікація
    path("auth/login/", views.LoginView.as_view(), name="login"),
    path("auth/register/", views.RegisterView.as_view(), name="register"),
    path("auth/send-otp/", views.SendOTPView.as_view(), name="send-otp"),
    path("auth/verify-otp/", views.VerifyOTPView.as_view(), name="verify-otp"),
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
    # KYC — Водій
    path("driver/kyc/upload", views.KYCUploadView.as_view(), name="kyc-upload"),
    path("driver/kyc/status", views.KYCStatusView.as_view(), name="kyc-status"),
    # KYC — Диспетчер
    path(
        "dispatcher/kyc/pending/",
        views.KYCPendingListView.as_view(),
        name="kyc-pending",
    ),
    path(
        "dispatcher/kyc/<uuid:pk>/review/",
        views.KYCReviewView.as_view(),
        name="kyc-review",
    ),
    # Earnings
    path(
        "driver/earnings/ledger",
        views.DriverEarningsView.as_view(),
        name="driver-earnings",
    ),
    # Пошук клієнта диспетчером
    path(
        "dispatcher/users/",
        views.DispatcherUserSearchView.as_view(),
        name="dispatcher-user-search",
    ),
]
