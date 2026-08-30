"""Verifie que les actions sensibles sont bien journalisees (voir AuditLog).
Pur Python, ni serveur ni base de donnees.

    python backend_django/test_audit.py

Le risque reel n'est pas que audit() calcule mal -- il fait trois lignes.
C'est qu'une action sensible n'appelle PAS audit() : une nouvelle route
admin ajoutee dans six mois, ou un appel supprime par erreur lors d'un
remaniement. Rien ne casse, les tests passent, et le trou n'apparait qu'au
controle, quand il est trop tard pour reconstituer l'historique.

Ce test verifie donc que chaque vue sensible contient son appel a audit().
"""

import re
import sys
from pathlib import Path

VIEWS = Path(__file__).resolve().parent / "api" / "views.py"

# Vue sensible -> action attendue dans son corps.
# Ajouter une ligne ici quand une nouvelle operation sensible apparait.
EXPECTED = {
    "login": ("login.success", "login.failed"),
    "reset_password": ("password.reset",),
    "upload_document": ("kyc.upload",),
    "validate_transaction": ("order.validate",),
    "reject_transaction": ("order.reject",),
    "admin_user_kyc": ("kyc.change",),
    "admin_user_suspend": ("account.suspend",),
}


def function_bodies(src):
    """Decoupe le fichier par definition de fonction de premier niveau."""
    bodies, current, name = {}, [], None
    for line in src.split("\n"):
        m = re.match(r"^def (\w+)\(", line)
        if m:
            if name:
                bodies[name] = "\n".join(current)
            name, current = m.group(1), []
        elif name:
            current.append(line)
    if name:
        bodies[name] = "\n".join(current)
    return bodies


def test_sensitive_views_are_audited():
    bodies = function_bodies(VIEWS.read_text(encoding="utf-8"))
    for view, actions in EXPECTED.items():
        assert view in bodies, f"vue « {view} » introuvable : renommee ou supprimee ?"
        for action in actions:
            assert f'"{action}"' in bodies[view], (
                f"{view}() ne journalise pas « {action} ». "
                "Une action sensible non tracee est invisible a l'audit."
            )


def test_audit_never_raises():
    """audit() est appele apres des mouvements d'argent deja commits : s'il
    levait, il renverrait une erreur au client sur une operation pourtant
    reussie."""
    body = function_bodies(VIEWS.read_text(encoding="utf-8"))["audit"]
    assert "except Exception" in body, (
        "audit() doit avaler ses erreurs : un journal qui plante ne doit pas "
        "casser l'operation qu'il observe."
    )


def main():
    test_sensitive_views_are_audited()
    test_audit_never_raises()
    print(f"OK — {sum(len(a) for a in EXPECTED.values())} actions sensibles journalisées, "
          "audit() ne peut pas casser une opération")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as e:
        print(f"ECHEC : {e}")
        sys.exit(1)
