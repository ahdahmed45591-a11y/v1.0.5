"""Cree le compte admin et le ticket de demonstration, comme data/store.js.

Idempotent : relancable a chaque demarrage sans dupliquer ni ecraser.
"""

import datetime as dt
import os

from django.core.management.base import BaseCommand

from api.models import Ticket, User
from api.views import hash_password


class Command(BaseCommand):
    help = "Cree l'administrateur par defaut et les donnees de demonstration."

    def handle(self, *args, **options):
        email = os.environ.get("ADMIN_EMAIL", "admin@elephantbourse.ci")
        password = os.environ.get("ADMIN_PASSWORD", "admin2024")

        admin, created = User.objects.get_or_create(
            id="ADMIN-001",
            defaults={
                "name": "M. Cissé",
                "email": email,
                "password": hash_password(password),
                "role": "admin",
                "level": 4,
                "avatar": "MK",
                "joined_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            },
        )
        self.stdout.write(f"Admin {'cree' if created else 'deja present'} : {admin.email}")

        Ticket.objects.get_or_create(
            id="TKT-1002",
            defaults={
                "client_name": "Mamadou Konaté",
                "client_id": "mamadou.konate@email.ci",
                "subject": "Assistance Inscription",
                "message": "Bonjour, j'ai besoin d'aide pour valider mon contrat.",
                "status": "OUVERT",
                "date_string": "Aujourd'hui, 10:15",
            },
        )
