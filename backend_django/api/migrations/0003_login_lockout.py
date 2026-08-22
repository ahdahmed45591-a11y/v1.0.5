"""Verrouillage progressif du login : compteur d'echecs + date de deverrouillage."""

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0002_money_decimal"),
    ]

    operations = [
        migrations.AddField(model_name="user", name="failed_login_attempts", field=models.IntegerField(default=0)),
        migrations.AddField(model_name="user", name="locked_until", field=models.DateTimeField(null=True, blank=True)),
        migrations.AddField(model_name="user", name="must_reset_password", field=models.BooleanField(default=False)),
    ]
