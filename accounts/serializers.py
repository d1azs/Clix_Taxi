"""
accounts/serializers.py — Серіалайзери для аутентифікації та профілю.
"""

from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from .models import User, DriverProfile


# ---------------------------------------------------------------------------
# JWT: додаємо ролі до токена
# ---------------------------------------------------------------------------
class CLIXTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Кастомний серіалайзер — додає roles до JWT-відповіді."""

    username_field = "phone_number"

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token["roles"] = user.roles
        token["phone"] = user.phone_number
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        data["roles"] = self.user.roles
        data["user_id"] = str(self.user.id)
        data["phone_number"] = self.user.phone_number
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

    class Meta:
        model = User
        fields = [
            "id",
            "phone_number",
            "first_name",
            "last_name",
            "roles",
            "created_at",
        ]
        read_only_fields = fields


# ---------------------------------------------------------------------------
# Профіль водія
# ---------------------------------------------------------------------------
class DriverProfileSerializer(serializers.ModelSerializer):
    """Серіалайзер профілю водія."""

    phone_number = serializers.CharField(source="user.phone_number", read_only=True)
    first_name = serializers.CharField(source="user.first_name", read_only=True)
    last_name = serializers.CharField(source="user.last_name", read_only=True)

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
        ]
        read_only_fields = ["id", "rating", "total_trips", "total_earnings"]
