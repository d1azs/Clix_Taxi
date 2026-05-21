"""
clix_backend/urls.py — Головний файл маршрутизації CLIX.
"""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include("accounts.urls")),
    path("api/", include("vehicles.urls")),
    path("api/", include("orders.urls")),
]

# Serve media files in development (KYC uploads)
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
