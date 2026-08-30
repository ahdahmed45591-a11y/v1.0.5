"""Cle d'idempotence sur les transactions (voir create_transaction)."""

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0005_audit_log"),
    ]

    operations = [
        migrations.AddField(
            model_name="transaction",
            name="idempotency_key",
            field=models.CharField(blank=True, max_length=64, null=True),
        ),
        migrations.AddConstraint(
            model_name="transaction",
            constraint=models.UniqueConstraint(
                condition=models.Q(("idempotency_key__isnull", False)),
                fields=("user", "idempotency_key"),
                name="uniq_tx_idempotency_per_user",
            ),
        ),
    ]
