import os
import sys
import glob
import time
import json
import sqlite3
import pandas as pd
import numpy as np

# Correction encodage UTF-8 sous Windows Console
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass


def calculate_rsi(series, period=14):
    """Calcul vectorisé de l'indicateur RSI (Relative Strength Index)."""
    delta = series.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / loss.replace(0, np.nan)
    rsi = 100 - (100 / (1 + rs))
    return rsi.fillna(50)


class BRVMEngine:
    """Moteur d'analyse haute performance pour les données boursières de la BRVM."""

    def __init__(self, data_dir):
        self.data_dir = data_dir
        self.db_path = os.path.join(data_dir, "brvm_database.db")
        self.json_summary_path = os.path.join(data_dir, "brvm_summary.json")

    def run_pipeline(self):
        start_time = time.time()
        print("===================================================================")
        print("    ⚡ BRVM HIGH-PERFORMANCE DATA ENGINE & ANALYTICS PIPELINE     ")
        print("===================================================================")

        ticker_dirs = [
            d for d in os.listdir(self.data_dir)
            if os.path.isdir(os.path.join(self.data_dir, d)) and d != "currency_data"
        ]

        print(f"\n[1/4] 📥 Chargement et calculs vectorisés sur {len(ticker_dirs)} actifs...")

        all_dfs = []
        summary_list = []

        for idx, ticker in enumerate(ticker_dirs, 1):
            daily_file = os.path.join(self.data_dir, ticker, f"{ticker}.daily.csv")
            if not os.path.exists(daily_file):
                continue

            try:
                # Lecture optimisée Pandas
                df = pd.read_csv(daily_file)
                if df.empty or 'Date' not in df.columns:
                    continue

                df['Date'] = pd.to_datetime(df['Date'])
                df = df.sort_values('Date').reset_index(drop=True)
                df['Ticker'] = ticker
                df['Is_Index'] = ticker.startswith("BRVM")

                # Calculations vectorisés avec Pandas / NumPy
                df['Daily_Return'] = df['Close'].pct_change() * 100
                df['SMA_20'] = df['Close'].rolling(window=20).mean()
                df['SMA_50'] = df['Close'].rolling(window=50).mean()
                df['SMA_200'] = df['Close'].rolling(window=200).mean()
                df['RSI_14'] = calculate_rsi(df['Close'], period=14)
                df['Volatility_20d'] = df['Daily_Return'].rolling(window=20).std() * np.sqrt(252)

                all_dfs.append(df)

                # Métriques de synthèse
                latest = df.iloc[-1]
                prev_close = df.iloc[-2]['Close'] if len(df) > 1 else latest['Close']
                daily_change = ((latest['Close'] - prev_close) / prev_close * 100) if prev_close else 0.0

                # Rendements historiques (1 mois, 1 an, YTD)
                latest_date = latest['Date']
                month_ago = df[df['Date'] <= latest_date - pd.Timedelta(days=30)]
                ret_1m = ((latest['Close'] - month_ago.iloc[-1]['Close']) / month_ago.iloc[-1]['Close'] * 100) if not month_ago.empty else 0.0

                year_ago = df[df['Date'] <= latest_date - pd.Timedelta(days=365)]
                ret_1y = ((latest['Close'] - year_ago.iloc[-1]['Close']) / year_ago.iloc[-1]['Close'] * 100) if not year_ago.empty else 0.0

                summary_list.append({
                    "ticker": ticker,
                    "is_index": bool(ticker.startswith("BRVM")),
                    "last_date": latest['Date'].strftime('%Y-%m-%d'),
                    "close": float(latest['Close']),
                    "open": float(latest['Open']),
                    "high": float(latest['High']),
                    "low": float(latest['Low']),
                    "volume": float(latest['Volume']),
                    "daily_change_pct": round(float(daily_change), 2),
                    "return_1m_pct": round(float(ret_1m), 2),
                    "return_1y_pct": round(float(ret_1y), 2),
                    "sma_20": round(float(latest['SMA_20']), 2) if not np.isnan(latest['SMA_20']) else None,
                    "sma_50": round(float(latest['SMA_50']), 2) if not np.isnan(latest['SMA_50']) else None,
                    "sma_200": round(float(latest['SMA_200']), 2) if not np.isnan(latest['SMA_200']) else None,
                    "rsi_14": round(float(latest['RSI_14']), 2) if not np.isnan(latest['RSI_14']) else 50.0,
                    "volatility_annualized": round(float(latest['Volatility_20d']), 2) if not np.isnan(latest['Volatility_20d']) else 0.0,
                    "total_trading_days": len(df),
                    "first_date": df.iloc[0]['Date'].strftime('%Y-%m-%d')
                })
            except Exception as e:
                pass

        if not all_dfs:
            print("❌ Aucune donnée valide trouvée.")
            return

        combined_df = pd.concat(all_dfs, ignore_index=True)
        total_rows = len(combined_df)

        print(f"  └─ Traitement vectorisé terminé : {total_rows:,} cours analysés sur {len(summary_list)} actifs.")

        # 2. Exportation SQLite
        print("\n[2/4] 💾 Sauvegarde dans la base de données SQLite indexée...")
        conn = sqlite3.connect(self.db_path)
        combined_df.to_sql("historical_prices", conn, if_exists="replace", index=False)
        pd.DataFrame(summary_list).to_sql("tickers_summary", conn, if_exists="replace", index=False)
        
        # Création d'index SQL pour des requêtes ultra-rapides
        conn.execute("CREATE INDEX IF NOT EXISTS idx_ticker_date ON historical_prices(Ticker, Date)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_summary_ticker ON tickers_summary(ticker)")
        conn.close()

        # 3. Exportation JSON pour le Dashboard
        print("\n[3/4] 🌐 Génération du payload JSON ultra-léger pour le tableau de bord Web...")
        
        # Préparation des séries historiques des principaux indices/actions pour affichage graphique direct
        charts_data = {}
        for s in summary_list:
            t = s["ticker"]
            t_df = combined_df[combined_df['Ticker'] == t].tail(365) # Dernier an
            charts_data[t] = {
                "dates": t_df['Date'].dt.strftime('%Y-%m-%d').tolist(),
                "prices": t_df['Close'].tolist(),
                "volumes": t_df['Volume'].tolist(),
                "sma_20": t_df['SMA_20'].fillna(0).tolist(),
                "sma_50": t_df['SMA_50'].fillna(0).tolist()
            }

        summary_payload = {
            "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
            "total_records": total_rows,
            "total_tickers": len(summary_list),
            "summary": summary_list,
            "charts_data": charts_data
        }

        with open(self.json_summary_path, "w", encoding="utf-8") as f:
            json.dump(summary_payload, f, ensure_ascii=False)

        elapsed = time.time() - start_time
        print("\n[4/4] 📊 RÉSULTATS DU BENCHMARK & CLASSEMENTS :")
        print(f"  • Temps d'exécution total : {elapsed:.2f} secondes ⚡")
        print(f"  • Vitesse de traitement   : {int(total_rows / elapsed):,} lignes / seconde")
        print(f"  • Taille base SQLite       : {os.path.getsize(self.db_path) / (1024*1024):.2f} Mo")

        # Top 3 Gagnants & Perdants
        stocks_only = [s for s in summary_list if not s['is_index']]
        top_gainers = sorted(stocks_only, key=lambda x: x['daily_change_pct'], reverse=True)[:3]
        top_losers = sorted(stocks_only, key=lambda x: x['daily_change_pct'])[:3]

        print("\n🏆 Top Gagnants (Dernière séance) :")
        for g in top_gainers:
            print(f"  • {g['ticker']} : {g['close']} XOF ({g['daily_change_pct']:+}% )")

        print("\n📉 Top Perdants (Dernière séance) :")
        for l in top_losers:
            print(f"  • {l['ticker']} : {l['close']} XOF ({l['daily_change_pct']:+}% )")

        print("\n===================================================================")
        print("  🎉 MOTEUR DE DONNÉES BRVM PRÊT ET SYNC AVEC LE TABLEAU DE BORD  ")
        print("===================================================================")


if __name__ == "__main__":
    data_directory = r"d:\Antigravity\projet\installation\brvm-data-public\data"
    engine = BRVMEngine(data_directory)
    engine.run_pipeline()
