"""
accounts/admin.py — Реєстрація моделей у Django Admin.
"""

from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, DriverProfile


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ["phone_number", "first_name", "last_name", "roles", "is_active"]
    list_filter = ["is_active", "is_staff"]
    search_fields = ["phone_number", "first_name", "last_name"]
    ordering = ["-created_at"]

    fieldsets = (
        (None, {"fields": ("phone_number", "password")}),
        ("Персональні дані", {"fields": ("first_name", "last_name", "roles")}),
        ("Права", {"fields": ("is_active", "is_staff", "is_superuser")}),
    )
    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("phone_number", "password1", "password2", "roles"),
            },
        ),
    )


@admin.register(DriverProfile)
class DriverProfileAdmin(admin.ModelAdmin):
    list_display = ["user", "status", "rating", "total_trips", "total_earnings"]
    list_filter = ["status"]
    search_fields = ["user__phone_number"]
