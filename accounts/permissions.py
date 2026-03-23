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
