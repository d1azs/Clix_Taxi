"""
accounts/views.py — Views для аутентифікації, реєстрації, профілю.
"""

from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView

from .models import DriverProfile, DriverStatus, User
from .permissions import IsDriver
from .serializers import (CLIXTokenObtainPairSerializer,
                          DriverProfileSerializer, RegisterSerializer,
                          UserSerializer)


# ---------------------------------------------------------------------------
# JWT Логін — повертає токени + ролі
# ---------------------------------------------------------------------------
class LoginView(TokenObtainPairView):
    """POST /api/auth/login/ — JWT логін з ролями у відповіді."""

    serializer_class = CLIXTokenObtainPairSerializer


# ---------------------------------------------------------------------------
# Реєстрація
# ---------------------------------------------------------------------------
class RegisterView(generics.CreateAPIView):
    """POST /api/auth/register/ — Реєстрація нового користувача."""

    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]


# ---------------------------------------------------------------------------
# Поточний користувач
# ---------------------------------------------------------------------------
class MeView(generics.RetrieveAPIView):
    """GET /api/users/me/ — Данi поточного користувача."""

    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user


# ---------------------------------------------------------------------------
# Статус водія (ONLINE / OFFLINE)
# ---------------------------------------------------------------------------
class DriverStatusView(APIView):
    """PATCH /api/driver/status/ — Зміна статусу водія."""

    permission_classes = [IsDriver]

    def get(self, request):
        profile = request.user.driver_profile
        return Response(DriverProfileSerializer(profile).data)

    def patch(self, request):
        profile = request.user.driver_profile
        new_status = request.data.get("status")
        if new_status not in [DriverStatus.ONLINE, DriverStatus.OFFLINE]:
            return Response(
                {"error": "Допустимі статуси: ONLINE, OFFLINE"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        profile.status = new_status
        # Оновити координати, якщо водій виходить онлайн
        if new_status == DriverStatus.ONLINE:
            profile.current_lat = request.data.get("lat", profile.current_lat)
            profile.current_lng = request.data.get("lng", profile.current_lng)
        profile.save()
        return Response(DriverProfileSerializer(profile).data)


# ---------------------------------------------------------------------------
# Оновлення геолокації водія
# ---------------------------------------------------------------------------
class DriverLocationUpdateView(APIView):
    """POST /api/driver/location/ — Оновлення GPS-координат водія."""

    permission_classes = [IsDriver]

    def post(self, request):
        profile = request.user.driver_profile
        lat = request.data.get("lat")
        lng = request.data.get("lng")
        if lat is None or lng is None:
            return Response(
                {"error": "Необхідні поля: lat, lng"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        profile.current_lat = float(lat)
        profile.current_lng = float(lng)
        profile.save(update_fields=["current_lat", "current_lng"])
        return Response({"status": "ok"})
