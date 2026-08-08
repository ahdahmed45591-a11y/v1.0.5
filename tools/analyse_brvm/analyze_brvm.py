import os
import sys
import json
import glob
import csv
from datetime import datetime

if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass


base_dir = r"d:\Antigravity\projet\installation\brvm-data-public\data"

print("===================================================================")
print("       📊 ANALYSE APPROFONDIE DU DÉPÔT BRVM DATA PUBLIC          ")
print("===================================================================")

# 1. Metadata
meta_path = os.path.join(base_dir, "metadata.json")
if os.path.exists(meta_path):
    with open(meta_path, "r", encoding="utf-8") as f:
        meta = json.load(f)
    print("\n📌 METADATA GLOBALES :")
    print(json.dumps(meta, indent=2, ensure_ascii=False))

# 2. Séance status
status_path = os.path.join(base_dir, "BRVM_seance_status.json")
if os.path.exists(status_path):
    with open(status_path, "r", encoding="utf-8") as f:
        status = json.load(f)
    print("\n🏛️ STATUT DE LA SÉANCE BRVM :")
    if isinstance(status, dict):
        for k, v in status.items():
            if isinstance(v, (str, int, float, bool)):
                print(f"  • {k}: {v}")
            elif isinstance(v, list):
                print(f"  • {k}: {len(v)} éléments")

# 3. Traitement des Tickers & Indices
ticker_dirs = [d for d in os.listdir(base_dir) if os.path.isdir(os.path.join(base_dir, d)) and d != 'currency_data']

indices = [t for t in ticker_dirs if t.startswith("BRVM")]
stocks = [t for t in ticker_dirs if not t.startswith("BRVM")]

print(f"\n📂 NOMBRE TOTAL D'ACTIFS/INDICES : {len(ticker_dirs)}")
print(f"  • Indices BRVM ({len(indices)}) : {', '.join(indices[:10])}...")
print(f"  • Actions d'entreprises ({len(stocks)}) : {', '.join(stocks[:10])}...")

all_dates = set()
ticker_summary = []
total_records = 0

for ticker in ticker_dirs:
    daily_file = os.path.join(base_dir, ticker, f"{ticker}.daily.csv")
    if os.path.exists(daily_file):
        with open(daily_file, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            rows = list(reader)
            if rows:
                total_records += len(rows)
                start_date = rows[0].get("Date", "")
                end_date = rows[-1].get("Date", "")
                
                try:
                    open_price = float(rows[-1].get("Open", 0) or 0)
                    close_price = float(rows[-1].get("Close", 0) or 0)
                    volume = float(rows[-1].get("Volume", 0) or 0)
                    perf_day = ((close_price - open_price) / open_price * 100) if open_price > 0 else 0
                except ValueError:
                    close_price = rows[-1].get("Close", "N/A")
                    perf_day = 0
                    volume = 0

                for r in rows:
                    if r.get("Date"):
                        all_dates.add(r["Date"])

                ticker_summary.append({
                    "ticker": ticker,
                    "records": len(rows),
                    "start": start_date,
                    "end": end_date,
                    "latest_close": close_price,
                    "volume": volume,
                    "perf_day": perf_day,
                    "is_index": ticker.startswith("BRVM")
                })

dates_sorted = sorted(list(all_dates))

print(f"\n📈 COUVERTURE TEMPORELLE ET HISTORIQUE :")
print(f"  • Nombre total de séances analysées : {len(dates_sorted)}")
if dates_sorted:
    print(f"  • Date de début de l'historique : {dates_sorted[0]}")
    print(f"  • Date de dernière mise à jour  : {dates_sorted[-1]}")
print(f"  • Total d'enregistrements CSV   : {total_records}")

# Top hausses et baisses récentes (actions uniquement)
stock_items = [t for t in ticker_summary if not t["is_index"] and isinstance(t["latest_close"], (int, float))]
stock_items_sorted = sorted(stock_items, key=lambda x: x["latest_close"], reverse=True)

print(f"\n🏆 ÉCHANTILLON DES ACTIONS LES PLUS CHÈRES (Dernier Cours) :")
for s in stock_items_sorted[:5]:
    print(f"  • {s['ticker']} : {s['latest_close']:,.2f} XOF | Période : {s['start']} -> {s['end']} ({s['records']} jours)")

# Currencies
currency_dir = os.path.join(base_dir, "currency_data")
if os.path.exists(currency_dir):
    currencies = [f.replace('.json', '') for f in os.listdir(currency_dir) if f.endswith('.json')]
    print(f"\n💱 DEVISES SUIVIES DANS LE DÉPÔT ({len(currencies)}) :")
    print(f"  • Devises principales : {', '.join(currencies[:15])}...")

print("\n===================================================================")
print("                      ANALYSE TERMINÉE                             ")
print("===================================================================")
