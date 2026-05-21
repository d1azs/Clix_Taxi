"""
ASGI config for CLIX Backend.

Exposes the ASGI application including HTTP + WebSocket protocol routing.
"""

import os

from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import AllowedHostsOriginValidator
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "clix_backend.settings")

django_asgi_app = get_asgi_application()

from accounts.middleware import JWTAuthMiddleware  # noqa: E402
from orders.routing import websocket_urlpatterns  # noqa: E402

application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        "websocket": AllowedHostsOriginValidator(
            JWTAuthMiddleware(URLRouter(websocket_urlpatterns))
        ),
    }
)
