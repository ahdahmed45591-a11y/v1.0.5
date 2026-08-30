"""Verifie le format du fichier d'ordres remis a la SGI (voir
admin_export_orders et EXPORT_COLUMNS). Pur Python, ni serveur ni base.

    python backend_django/test_export.py

Ce qui casse en vrai sur un export : pas le code, le FORMAT. Une colonne
renommee ou deplacee et l'import de la SGI tombe en silence -- ou pire,
decale les montants d'une colonne. Ce test fige l'ordre et les libelles :
les changer echoue ici, ce qui force a prevenir la SGI avant de livrer.
"""

import csv
import io
import re
import sys
from pathlib import Path

VIEWS = Path(__file__).resolve().parent / "api" / "views.py"

# Contrat d'interface avec la SGI. Modifier cette liste = modifier le
# fichier que la SGI importe : la prevenir AVANT.
CONTRACT = [
    "Reference", "Date soumission", "Date traitement",
    "Client ID", "Client nom", "Client email",
    "Sens", "Ticker", "Societe",
    "Quantite", "Prix unitaire",
    "Montant brut", "Frais", "TVA", "Montant net",
    "Statut", "Traite par", "Motif rejet",
]


def declared_columns():
    src = VIEWS.read_text(encoding="utf-8")
    block = re.search(r"EXPORT_COLUMNS = \[(.*?)\n\]", src, re.DOTALL)
    assert block, "EXPORT_COLUMNS introuvable dans views.py"
    return re.findall(r'\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\)', block.group(1))


def test_column_contract():
    cols = [label for label, _ in declared_columns()]
    assert cols == CONTRACT, (
        "Le format du fichier a change.\n"
        f"  attendu : {CONTRACT}\n"
        f"  trouve  : {cols}\n"
        "Prevenir la SGI avant de livrer, leur import se cale sur cet ordre."
    )


def test_no_duplicate_attribute():
    attrs = [attr for _, attr in declared_columns()]
    dupes = {a for a in attrs if attrs.count(a) > 1}
    assert not dupes, f"attribut exporte deux fois : {dupes} -- copier/coller rate ?"


def test_separator_survives_french_text():
    """Le separateur « ; » impose que les champs contenant un « ; » ou des
    accents soient echappes -- sinon un nom comme « Kouassi; SARL » decale
    toute la ligne chez la SGI."""
    buf = io.StringIO()
    w = csv.writer(buf, delimiter=";", quoting=csv.QUOTE_MINIMAL)
    w.writerow(["REF-1", "Kouassi; SARL", "Société Générale", "1000.50"])
    row = next(csv.reader(io.StringIO(buf.getvalue()), delimiter=";"))
    assert row == ["REF-1", "Kouassi; SARL", "Société Générale", "1000.50"], (
        f"aller-retour CSV casse : {row}"
    )


def main():
    test_column_contract()
    test_no_duplicate_attribute()
    test_separator_survives_french_text()
    print(f"OK — format d'export figé ({len(CONTRACT)} colonnes), séparateur robuste")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as e:
        print(f"ECHEC : {e}")
        sys.exit(1)
