"""
vehicles/urls.py — URL-маршрути для автомобілів.
"""

from django.urls import path
from . import views

urlpatterns = [
    path('driver/vehicles/', views.VehicleListCreateView.as_view(), name='vehicle-list'),
    path('driver/vehicles/<uuid:pk>/', views.VehicleDetailView.as_view(), name='vehicle-detail'),
]
