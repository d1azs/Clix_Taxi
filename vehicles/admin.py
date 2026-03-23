"""
vehicles/admin.py — Реєстрація моделей у Django Admin.
"""

from django.contrib import admin

from .models import Vehicle


@admin.register(Vehicle)
class VehicleAdmin(admin.ModelAdmin):
    list_display = [
        "make_model",
        "license_plate",
        "vehicle_class",
        "driver_profile",
        "is_active",
    ]
    list_filter = ["vehicle_class", "is_active"]
    search_fields = ["make_model", "license_plate"]
