"""Verifie les paliers de verrouillage du login (voir apply_lockout_tier
dans api/views.py). Pur Python, pas de serveur ni de base de donnees --
evite de consommer le quota AuthThrottle (10/min) deja sollicite par
test_api.py.

    python backend_django/test_lockout.py
"""

import datetime as dt
import os
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
os.environ.setdefault("JWT_SECRET", "test-only")  # exige par settings.py, jamais utilise ici

import django  # noqa: E402

django.setup()

from api.views import apply_lockout_tier  # noqa: E402


@dataclass
class FakeUser:
    failed_login_attempts: int = 0
    locked_until: object = None
    must_reset_password: bool = False


def main():
    now = dt.datetime.now(dt.timezone.utc)
    user = FakeUser()

    for _ in range(4):
        apply_lockout_tier(user, now)
    assert user.locked_until is None and not user.must_reset_password, "verrouille avant 5 echecs"

    apply_lockout_tier(user, now)  # 5e echec
    assert user.locked_until == now + dt.timedelta(minutes=10), "pas de verrou de 10 min au 5e echec"
    assert not user.must_reset_password

    for _ in range(4):
        apply_lockout_tier(user, now)  # 6..9
    assert user.locked_until == now + dt.timedelta(minutes=10), "le palier 10 min n'aurait pas du bouger"

    apply_lockout_tier(user, now)  # 10e echec
    assert user.locked_until == now + dt.timedelta(hours=1), "pas de verrou de 1h au 10e echec"

    for _ in range(4):
        apply_lockout_tier(user, now)  # 11..14
    assert not user.must_reset_password, "reset declenche trop tot"

    apply_lockout_tier(user, now)  # 15e echec
    assert user.must_reset_password, "pas de reset obligatoire au 15e echec"

    print("OK — paliers de verrouillage valides (5 -> 10min, 10 -> 1h, 15 -> reset)")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as e:
        print(f"ECHEC : {e}")
        sys.exit(1)
