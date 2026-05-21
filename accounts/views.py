"""
accounts/views.py — Views для аутентифікації, реєстрації, профілю, KYC.
"""

import random

from django.core.cache import cache
from django.utils import timezone

from rest_framework import generics, status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from .models import DriverRanking, DriverStatus, KYCDocument, KYCStatus, User
from .permissions import IsDispatcher, IsDriver
from .serializers import (
    CLIXTokenObtainPairSerializer,
    DriverProfileSerializer,
    DriverRankingSerializer,
    KYCReviewSerializer,
    KYCUploadSerializer,
    RegisterSerializer,
    UpdateProfileSerializer,
    UserSerializer,
)


# ---------------------------------------------------------------------------
# SMS OTP Auth (Mock)
# ---------------------------------------------------------------------------
class SendOTPView(APIView):
    """POST /api/auth/send-otp/ — Генерація та імітація відправки OTP."""

    permission_classes = [AllowAny]

    def post(self, request):
        phone = request.data.get("phone_number")
        if not phone:
            return Response(
                {"error": "Вкажіть phone_number"}, status=status.HTTP_400_BAD_REQUEST
            )

        otp = str(random.randint(1000, 9999))
        cache.set(f"otp_{phone}", otp, timeout=300)  # 5 min

        print(f"\n[{'*'*20}]")
        print(f" MOCK SMS TO: {phone}")
        print(f" YOUR OTP CODE: {otp}")
        print(f"[{'*'*20}]\n")

        return Response(
            {"status": "OTP sent", "message": "Код відправлено (див. консоль сервера)"}
        )


class VerifyOTPView(APIView):
    """POST /api/auth/verify-otp/ — Перевірка OTP та видача JWT."""

    permission_classes = [AllowAny]

    def post(self, request):
        phone = request.data.get("phone_number")
        otp_input = request.data.get("otp")

        if not phone or not otp_input:
            return Response(
                {"error": "Необхідні phone_number та otp"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        cached_otp = cache.get(f"otp_{phone}")
        if not cached_otp or cached_otp != str(otp_input):
            return Response(
                {"error": "Невірний або прострочений код"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        cache.delete(f"otp_{phone}")

        # Get or create user
        user, created = User.objects.get_or_create(phone_number=phone)
        if created:
            user.roles = ["PASSENGER"]
            user.set_password(str(random.randint(10000000, 99999999)))
            user.save()

        refresh = RefreshToken.for_user(user)
        refresh["roles"] = user.roles
        refresh["phone"] = user.phone_number
        refresh["first_name"] = user.first_name

        # KYC check for JWT
        kyc_status = "NOT_SUBMITTED"
        if user.has_role("DRIVER") and hasattr(user, "driver_profile"):
            latest_kyc = (
                KYCDocument.objects.filter(driver=user.driver_profile)
                .order_by("-submitted_at")
                .first()
            )
            if latest_kyc:
                kyc_status = latest_kyc.status
        refresh["kyc_status"] = kyc_status

        return Response(
            {
                "refresh": str(refresh),
                "access": str(refresh.access_token),
                "user_id": str(user.id),
                "roles": user.roles,
                "kyc_status": kyc_status,
                "created": created,
            }
        )


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
class MeView(generics.RetrieveUpdateAPIView):
    """GET/PATCH /api/users/me/ — Дані та оновлення поточного користувача."""

    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method in ("PATCH", "PUT"):
            return UpdateProfileSerializer
        return UserSerializer

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


# ---------------------------------------------------------------------------
# KYC — Завантаження документів водієм
# ---------------------------------------------------------------------------
class KYCUploadView(APIView):
    """POST /api/driver/kyc/upload — Завантаження документів верифікації."""

    permission_classes = [IsDriver]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        profile = request.user.driver_profile
        serializer = KYCUploadSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(driver=profile)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class KYCStatusView(APIView):
    """GET /api/driver/kyc/status — Поточний статус верифікації водія."""

    permission_classes = [IsDriver]

    def get(self, request):
        profile = request.user.driver_profile
        kyc = (
            KYCDocument.objects.filter(driver=profile).order_by("-submitted_at").first()
        )
        if not kyc:
            return Response(
                {"status": "NOT_SUBMITTED", "message": "Документи не подано"},
            )
        return Response(KYCUploadSerializer(kyc).data)


# ---------------------------------------------------------------------------
# KYC — Перевірка диспетчером
# ---------------------------------------------------------------------------
class KYCPendingListView(generics.ListAPIView):
    """GET /api/dispatcher/kyc/pending/ — Список документів на перевірку."""

    serializer_class = KYCReviewSerializer
    permission_classes = [IsDispatcher]

    def get_queryset(self):
        return KYCDocument.objects.filter(status=KYCStatus.PENDING).select_related(
            "driver", "driver__user"
        )


class KYCReviewView(APIView):
    """PATCH /api/dispatcher/kyc/<id>/review/ — Затвердити або відхилити."""

    permission_classes = [IsDispatcher]

    def patch(self, request, pk):
        try:
            kyc = KYCDocument.objects.get(pk=pk)
        except KYCDocument.DoesNotExist:
            return Response(
                {"error": "Документ не знайдено"},
                status=status.HTTP_404_NOT_FOUND,
            )

        new_status = request.data.get("status")
        if new_status not in [KYCStatus.APPROVED, KYCStatus.REJECTED]:
            return Response(
                {"error": "Допустимі статуси: APPROVED, REJECTED"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        kyc.status = new_status
        kyc.feedback_note = request.data.get("feedback_note", "")
        kyc.reviewed_at = timezone.now()
        kyc.save()
        return Response(KYCReviewSerializer(kyc).data)


# ---------------------------------------------------------------------------
# Earnings — Ledger водія
# ---------------------------------------------------------------------------
class DriverEarningsView(APIView):
    """GET /api/driver/<id>/earnings/ledger — Заробіток водія."""

    permission_classes = [IsDriver]

    def get(self, request):
        from orders.models import Order, OrderStatus

        profile = request.user.driver_profile
        completed = Order.objects.filter(
            driver=profile, status=OrderStatus.COMPLETED
        ).order_by("-completed_at")

        # Базова статистика
        total = profile.total_earnings
        trips = profile.total_trips

        ledger = [
            {
                "order_id": str(o.id),
                "date": o.completed_at.isoformat() if o.completed_at else None,
                "fare": str(o.upfront_price or o.estimated_price or 0),
                "commission": str(o.commission_deduction),
                "net": str(
                    (o.upfront_price or o.estimated_price or 0) - o.commission_deduction
                ),
                "route": f"{o.pickup_address} → {o.dropoff_address}",
            }
            for o in completed[:50]
        ]

        # Ранкінг
        ranking_data = None
        ranking = getattr(profile, "ranking", None)
        if ranking:
            ranking_data = DriverRankingSerializer(ranking).data

        return Response(
            {
                "total_earnings": str(total),
                "total_trips": trips,
                "ranking": ranking_data,
                "ledger": ledger,
            }
        )


# ---------------------------------------------------------------------------
# Пошук користувача диспетчером (для створення замовлення)
# ---------------------------------------------------------------------------
class DispatcherUserSearchView(APIView):
    """GET /api/dispatcher/users/?phone=+380... — Пошук клієнта за номером."""

    permission_classes = [IsDispatcher]

    def get(self, request):
        phone = request.query_params.get("phone", "").strip()
        if len(phone) < 4:
            return Response(
                {"error": "Мінімум 4 символи для пошуку"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        users = User.objects.filter(phone_number__icontains=phone).values(
            "id", "phone_number", "first_name", "last_name"
        )[:10]

        return Response(list(users))
