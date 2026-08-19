"""Montants FCFA : FloatField -> DecimalField(14, 2).

Postgres convertit en place (double precision -> numeric(14,2)), les soldes et
transactions existants sont conserves et arrondis au centime. Sens unique en
pratique : revenir en arriere reintroduirait l'imprecision.
"""

from django.db import migrations, models

MONEY = dict(max_digits=14, decimal_places=2, default=0)


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0001_initial"),
    ]

    operations = [
        migrations.AlterField(model_name="user", name="balance", field=models.DecimalField(**MONEY)),
        migrations.AlterField(model_name="user", name="portfolio_value", field=models.DecimalField(**MONEY)),
        migrations.AlterField(model_name="transaction", name="price", field=models.DecimalField(**MONEY)),
        migrations.AlterField(model_name="transaction", name="total", field=models.DecimalField(**MONEY)),
        migrations.AlterField(model_name="transaction", name="fees", field=models.DecimalField(**MONEY)),
        migrations.AlterField(model_name="transaction", name="tva", field=models.DecimalField(**MONEY)),
        migrations.AlterField(model_name="transaction", name="grand_total", field=models.DecimalField(**MONEY)),
    ]
