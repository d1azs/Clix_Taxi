"""
orders/admin.py — Реєстрація моделей у Django Admin.
"""

from django.contrib import admin

from .models import Order, Review


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = [
        "id",
        "status",
        "required_class",
        "passenger",
        "driver",
        "pickup_address",
        "created_at",
    ]
    list_filter = ["status", "required_class"]
    search_fields = ["pickup_address", "dropoff_address"]
    readonly_fields = ["created_at", "accepted_at", "completed_at"]


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ["id", "order", "author", "target_driver", "rating", "is_complaint"]
    list_filter = ["is_complaint", "rating"]
