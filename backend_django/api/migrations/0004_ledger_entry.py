"""Journal immuable des mouvements de solde (voir LedgerEntry dans models.py)."""

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0003_login_lockout"),
    ]

    operations = [
        migrations.CreateModel(
            name="LedgerEntry",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ("delta", models.DecimalField(decimal_places=2, default=0, max_digits=14)),
                ("balance_before", models.DecimalField(decimal_places=2, default=0, max_digits=14)),
                ("balance_after", models.DecimalField(decimal_places=2, default=0, max_digits=14)),
                ("reason", models.CharField(max_length=60)),
                ("created", models.DateTimeField(auto_now_add=True)),
                ("transaction", models.ForeignKey(blank=True, null=True,
                    on_delete=django.db.models.deletion.PROTECT, to="api.transaction")),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT,
                    related_name="ledger", to="api.user")),
            ],
            options={"ordering": ["-created"]},
        ),
    ]
