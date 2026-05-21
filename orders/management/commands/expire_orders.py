"""
Management command: expire_orders — Скасування PENDING замовлень з таймаутом.
Використання: python manage.py expire_orders
"""

from django.core.management.base import BaseCommand

from orders.timeout_service import expire_pending_orders


class Command(BaseCommand):
    help = "Скасувати PENDING-замовлення, що перевищили таймаут пошуку водія"

    def handle(self, *args, **options):
        count = expire_pending_orders()
        self.stdout.write(
            self.style.SUCCESS(f"Скасовано {count} замовлень з таймаутом")
        )
