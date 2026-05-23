"""
accounts/serializers.py — Серіалайзери для аутентифікації та профілю.
"""

from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .models import DriverProfile, DriverRanking, KYCDocument, User


# ---------------------------------------------------------------------------
# JWT: додаємо ролі до токена
# ---------------------------------------------------------------------------
class CLIXTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Кастомний серіалайзер — додає roles, kyc_status до JWT-відповіді."""

    username_field = "phone_number"

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token["roles"] = user.roles
        token["phone"] = user.phone_number
        token["first_name"] = user.first_name

        # KYC статус для водія — клієнт може перевірити без запиту
        if user.has_role("DRIVER") and hasattr(user, "driver_profile"):
            from .models import KYCDocument

            latest_kyc = (
                KYCDocument.objects.filter(driver=user.driver_profile)
                .order_by("-submitted_at")
                .first()
            )
            token["kyc_status"] = latest_kyc.status if latest_kyc else "NOT_SUBMITTED"
        else:
            token["kyc_status"] = None

        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        data["roles"] = self.user.roles
        data["user_id"] = str(self.user.id)
        data["phone_number"] = self.user.phone_number
        data["first_name"] = self.user.first_name

        # KYC статус у відповіді логіну
        if self.user.has_role("DRIVER") and hasattr(self.user, "driver_profile"):
            from .models import KYCDocument

            latest_kyc = (
                KYCDocument.objects.filter(driver=self.user.driver_profile)
                .order_by("-submitted_at")
                .first()
            )
            data["kyc_status"] = latest_kyc.status if latest_kyc else "NOT_SUBMITTED"

        return data


# ---------------------------------------------------------------------------
# Реєстрація
# ---------------------------------------------------------------------------
class RegisterSerializer(serializers.ModelSerializer):
    """Реєстрація нового користувача CLIX."""

    password = serializers.CharField(write_only=True, min_length=6)
    roles = serializers.ListField(
        child=serializers.ChoiceField(choices=["PASSENGER", "DRIVER", "DISPATCHER"]),
        default=["PASSENGER"],
    )

    class Meta:
        model = User
        fields = ["phone_number", "password", "first_name", "last_name", "roles"]

    def create(self, validated_data):
        roles = validated_data.pop("roles", ["PASSENGER"])
        user = User.objects.create_user(
            phone_number=validated_data["phone_number"],
            password=validated_data["password"],
            first_name=validated_data.get("first_name", ""),
            last_name=validated_data.get("last_name", ""),
            roles=roles,
        )
        # Якщо роль DRIVER — створюємо порожній DriverProfile
        if "DRIVER" in roles:
            DriverProfile.objects.create(user=user)
        return user


# ---------------------------------------------------------------------------
# Профіль користувача
# ---------------------------------------------------------------------------
class UserSerializer(serializers.ModelSerializer):
    """Серіалайзер поточного користувача."""

    kyc_status = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "phone_number",
            "first_name",
            "last_name",
            "roles",
            "kyc_status",
            "created_at",
        ]
        read_only_fields = fields

    def get_kyc_status(self, obj):
        if obj.has_role("DRIVER") and hasattr(obj, "driver_profile"):
            from .models import KYCDocument

            latest_kyc = (
                KYCDocument.objects.filter(driver=obj.driver_profile)
                .order_by("-submitted_at")
                .first()
            )
            return latest_kyc.status if latest_kyc else "NOT_SUBMITTED"
        return None


# ---------------------------------------------------------------------------
# Оновлення профілю (PATCH)
# ---------------------------------------------------------------------------
class UpdateProfileSerializer(serializers.ModelSerializer):
    """Серіалайзер для редагування імені та прізвища."""

    class Meta:
        model = User
        fields = ["first_name", "last_name"]


# ---------------------------------------------------------------------------
# Профіль водія
# ---------------------------------------------------------------------------
class DriverProfileSerializer(serializers.ModelSerializer):
    """Серіалайзер профілю водія."""

    phone_number = serializers.CharField(source="user.phone_number", read_only=True)
    first_name = serializers.CharField(source="user.first_name", read_only=True)
    last_name = serializers.CharField(source="user.last_name", read_only=True)
    vehicle = serializers.SerializerMethodField()

    class Meta:
        model = DriverProfile
        fields = [
            "id",
            "phone_number",
            "first_name",
            "last_name",
            "status",
            "rating",
            "total_trips",
            "total_earnings",
            "current_lat",
            "current_lng",
            "vehicle",
        ]
        read_only_fields = ["id", "rating", "total_trips", "total_earnings"]

    def get_vehicle(self, obj):
        v = obj.vehicles.filter(is_active=True).first() or obj.vehicles.first()
        if v:
            return {
                "id": str(v.id),
                "make_model": v.make_model,
                "license_plate": v.license_plate,
                "vehicle_class": v.vehicle_class,
                "vehicle_class_display": v.get_vehicle_class_display(),
                "color": v.color,
            }
        return None


# ---------------------------------------------------------------------------
# KYC документи
# ---------------------------------------------------------------------------
class KYCUploadSerializer(serializers.ModelSerializer):
    """Серіалайзер для завантаження KYC документів водієм."""

    class Meta:
        model = KYCDocument
        fields = [
            "id",
            "id_card",
            "license",
            "registration",
            "status",
            "feedback_note",
            "submitted_at",
            "reviewed_at",
        ]
        read_only_fields = [
            "id",
            "status",
            "feedback_note",
            "submitted_at",
            "reviewed_at",
        ]


class KYCReviewSerializer(serializers.ModelSerializer):
    """Серіалайзер для перевірки KYC диспетчером."""

    driver_phone = serializers.CharField(
        source="driver.user.phone_number", read_only=True
    )
    driver_name = serializers.SerializerMethodField()

    class Meta:
        model = KYCDocument
        fields = [
            "id",
            "driver",
            "driver_phone",
            "driver_name",
            "id_card",
            "license",
            "registration",
            "status",
            "feedback_note",
            "submitted_at",
            "reviewed_at",
        ]
        read_only_fields = [
            "id",
            "driver",
            "driver_phone",
            "driver_name",
            "id_card",
            "license",
            "registration",
            "submitted_at",
        ]

    def get_driver_name(self, obj):
        u = obj.driver.user
        return f"{u.first_name} {u.last_name}".strip() or u.phone_number


# ---------------------------------------------------------------------------
# Ранкінг водія
# ---------------------------------------------------------------------------
class DriverRankingSerializer(serializers.ModelSerializer):
    """Серіалайзер алгоритмічного ранкінгу."""

    class Meta:
        model = DriverRanking
        fields = [
            "id",
            "acceptance_rate",
            "avg_response_time",
            "composite_score",
            "updated_at",
        ]
        read_only_fields = fields
