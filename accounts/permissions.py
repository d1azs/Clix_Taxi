"""
accounts/permissions.py — Кастомні DRF-права доступу (RBAC).
"""

from rest_framework.permissions import BasePermission


class IsPassenger(BasePermission):
    """Доступ лише для ролі PASSENGER."""

    message = "Доступ дозволено лише пасажирам."

    def has_permission(self, request, view):
        return (
            request.user
            and request.user.is_authenticated
            and request.user.has_role("PASSENGER")
        )


class IsDriver(BasePermission):
    """Доступ лише для ролі DRIVER."""

    message = "Доступ дозволено лише водіям."

    def has_permission(self, request, view):
        return (
            request.user
            and request.user.is_authenticated
            and request.user.has_role("DRIVER")
        )


class IsDispatcher(BasePermission):
    """Доступ лише для ролі DISPATCHER."""

    message = "Доступ дозволено лише диспетчерам."

    def has_permission(self, request, view):
        return (
            request.user
            and request.user.is_authenticated
            and request.user.has_role("DISPATCHER")
        )


class IsDispatcherOrAdmin(BasePermission):
    """Доступ для диспетчерів та адміністраторів (високий рівень допуску)."""

    message = "Ця дія потребує прав диспетчера або адміністратора."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.has_role("DISPATCHER") or request.user.is_staff


class IsKYCApproved(BasePermission):
    """Блокує доступ водіїв без затвердженої KYC-верифікації."""

    message = "Ваші документи ще не верифіковані. Завершіть KYC-процес."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if not request.user.has_role("DRIVER"):
            return True
        if not hasattr(request.user, "driver_profile"):
            return False
        from .models import KYCDocument, KYCStatus

        return KYCDocument.objects.filter(
            driver=request.user.driver_profile,
            status=KYCStatus.APPROVED,
        ).exists()
