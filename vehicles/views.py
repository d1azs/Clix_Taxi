"""
vehicles/views.py — Views для управління автомобілями водія.
"""

from rest_framework import generics
from accounts.permissions import IsDriver
from .models import Vehicle
from .serializers import VehicleSerializer


class VehicleListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/driver/vehicles/ — Список автомобілів поточного водія.
    POST /api/driver/vehicles/ — Додати новий автомобіль.
    """

    serializer_class = VehicleSerializer
    permission_classes = [IsDriver]

    def get_queryset(self):
        return Vehicle.objects.filter(driver_profile=self.request.user.driver_profile)

    def perform_create(self, serializer):
        serializer.save(driver_profile=self.request.user.driver_profile)


class VehicleDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET/PUT/PATCH/DELETE /api/driver/vehicles/<id>/ — Деталі автомобіля.
    """

    serializer_class = VehicleSerializer
    permission_classes = [IsDriver]

    def get_queryset(self):
        return Vehicle.objects.filter(driver_profile=self.request.user.driver_profile)
