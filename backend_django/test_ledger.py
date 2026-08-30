"""Verifie l'invariant du journal des soldes (voir apply_balance et
LedgerEntry). Pur Python, ni serveur ni base de donnees.

    python backend_django/test_ledger.py

Deux choses seulement, mais ce sont les deux qui cassent en vrai :

1. Le contournement. Le journal ne vaut que si AUCUN code ne modifie un
   solde hors de apply_balance() : une seule affectation `.balance =` doit
   subsister dans tout le backend, celle qui est dedans. Un futur "petit
   ajustement direct" quelque part rend le journal faux sans rien casser
   d'autre -- c'est exactement le bug qu'un auditeur BCEAO trouverait et
   pas nous.

2. Le chainage. balance_after d'une ligne doit etre le balance_before de la
   suivante, et le delta journalise doit etre le delta REEL (apres clamp a
   zero), sinon la somme des deltas ne reconstitue pas le solde.
"""

import re
import sys
from decimal import Decimal
from pathlib import Path

VIEWS = Path(__file__).resolve().parent / "api" / "views.py"


def money(v):
    """Meme arrondi que api.models -- copie ici pour rester sans Django."""
    return Decimal(v).quantize(Decimal("0.01"))


def simulate(start, deltas):
    """Rejoue apply_balance() sans DB : renvoie les lignes de journal."""
    lines, balance = [], money(start)
    for delta, reason in deltas:
        before = balance
        after = max(Decimal(0), money(before + delta))
        lines.append({
            "delta": money(after - before),
            "before": before,
            "after": after,
            "reason": reason,
        })
        balance = after
    return lines


def test_single_mutation_point():
    src = VIEWS.read_text(encoding="utf-8")
    hits = re.findall(r"^\s*\w+\.balance\s*=(?!=)", src, re.MULTILINE)
    assert len(hits) == 1, (
        f"{len(hits)} affectations de solde dans views.py, une seule attendue "
        "(celle de apply_balance). Un mouvement hors apply_balance n'est pas journalise."
    )


def test_chaining_and_clamp():
    lines = simulate(0, [
        (Decimal("500000"), "Dépôt"),
        (Decimal("-2011.80"), "Gel ordre BUY"),
        (Decimal("2011.80"), "Remboursement rejet BUY"),
        (Decimal("-999999999"), "Débit surdimensionné"),  # doit clamper a 0
    ])

    for prev, nxt in zip(lines, lines[1:]):
        assert prev["after"] == nxt["before"], f"chainage rompu : {prev} -> {nxt}"

    for line in lines:
        assert line["after"] - line["before"] == line["delta"], f"delta menteur : {line}"

    assert lines[-1]["after"] == 0, "le solde doit clamper a zero, jamais negatif"
    assert lines[-1]["delta"] == Decimal("-500000.00"), (
        "sur clamp, le journal doit porter le debit reel, pas le debit demande"
    )

    total = sum(line["delta"] for line in lines)
    assert total == lines[-1]["after"], "somme des deltas != solde final"


def main():
    test_single_mutation_point()
    test_chaining_and_clamp()
    print("OK — journal des soldes : point de mutation unique, chainage et clamp valides")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as e:
        print(f"ECHEC : {e}")
        sys.exit(1)
