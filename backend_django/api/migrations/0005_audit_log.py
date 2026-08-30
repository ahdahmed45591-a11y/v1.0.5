"""Journal immuable des actions sensibles (voir AuditLog dans models.py)."""

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0004_ledger_entry"),
    ]

    operations = [
        migrations.CreateModel(
            name="AuditLog",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ("actor_id", models.CharField(db_index=True, max_length=64)),
                ("actor_role", models.CharField(blank=True, default="", max_length=20)),
                ("action", models.CharField(db_index=True, max_length=40)),
                ("target_id", models.CharField(blank=True, db_index=True, default="", max_length=64)),
                ("details", models.JSONField(blank=True, default=dict)),
                ("ip", models.CharField(blank=True, default="", max_length=64)),
                ("created", models.DateTimeField(auto_now_add=True)),
            ],
            options={"ordering": ["-created"]},
        ),
    ]
