"""Cours BRVM : liste de reference enrichie par les CSV locaux.

Identique au comportement Node (data/store.js + utils/brvmDataReader.js) :
les cours ne sont pas en base, ils sont charges au demarrage depuis
brvm_data/<TICKER>/<TICKER>.daily.csv quand le fichier existe.
"""

import csv
import os
from functools import lru_cache

BRVM_DATA_DIR = os.environ.get("BRVM_DATA_DIR", "/data/brvm_data")

TICKER_MAP = {
    "ETI": "ETIT",
    "SIB": "SIBC",
    "BICI": "BICC",
    "CBIB": "CBIBF",
    "SAPC": "SPHC",
}

SEED = [
    {"ticker": "SNTS", "company": "Sonatel CI", "sector": "Télécoms", "price": 16850, "prevClose": 16450, "change": 2.45, "volume": 124200, "marketCap": "985 Mrd", "high52": 18500, "low52": 14200, "pe": 12.4, "dividend": 850, "yield": 5.17},
    {"ticker": "ORAC", "company": "Orange CI", "sector": "Télécoms", "price": 10450, "prevClose": 10540, "change": -0.85, "volume": 98700, "marketCap": "512 Mrd", "high52": 11200, "low52": 9100, "pe": 15.1, "dividend": 380, "yield": 4.42},
    {"ticker": "ONTBF", "company": "Onatel BF", "sector": "Télécoms", "price": 2695, "prevClose": 2745, "change": -1.82, "volume": 32100, "marketCap": "98 Mrd", "high52": 3800, "low52": 2500, "pe": 11.2, "dividend": 120, "yield": 2.82},
    {"ticker": "SGBC", "company": "Société Générale CI", "sector": "Banque", "price": 37995, "prevClose": 38010, "change": -0.04, "volume": 41200, "marketCap": "284 Mrd", "high52": 42500, "low52": 31000, "pe": 9.8, "dividend": 1450, "yield": 3.82},
    {"ticker": "ETI", "company": "Ecobank Transnational", "sector": "Banque", "price": 73, "prevClose": 78, "change": -6.41, "volume": 841000, "marketCap": "1.2 Trd", "high52": 95, "low52": 60, "pe": 10.5, "dividend": 6, "yield": 3.80},
    {"ticker": "BOAB", "company": "BOA Bénin", "sector": "Banque", "price": 8780, "prevClose": 8765, "change": 0.17, "volume": 58400, "marketCap": "142 Mrd", "high52": 9800, "low52": 7200, "pe": 8.2, "dividend": 400, "yield": 4.55},
    {"ticker": "BOAC", "company": "BOA Côte d'Ivoire", "sector": "Banque", "price": 7200, "prevClose": 7100, "change": 1.41, "volume": 64200, "marketCap": "144 Mrd", "high52": 8200, "low52": 6100, "pe": 7.9, "dividend": 360, "yield": 5.00},
    {"ticker": "BOABF", "company": "BOA Burkina Faso", "sector": "Banque", "price": 6850, "prevClose": 6800, "change": 0.74, "volume": 22100, "marketCap": "102 Mrd", "high52": 7500, "low52": 5800, "pe": 8.4, "dividend": 320, "yield": 4.67},
    {"ticker": "BOAM", "company": "BOA Mali", "sector": "Banque", "price": 1850, "prevClose": 1850, "change": 0.0, "volume": 15400, "marketCap": "37 Mrd", "high52": 2400, "low52": 1500, "pe": 6.8, "dividend": 90, "yield": 4.86},
    {"ticker": "BOAN", "company": "BOA Niger", "sector": "Banque", "price": 4900, "prevClose": 4875, "change": 0.50, "volume": 11200, "marketCap": "49 Mrd", "high52": 5800, "low52": 4100, "pe": 7.5, "dividend": 210, "yield": 4.28},
    {"ticker": "BOAS", "company": "BOA Sénégal", "sector": "Banque", "price": 3200, "prevClose": 3104, "change": 3.10, "volume": 38900, "marketCap": "64 Mrd", "high52": 3900, "low52": 2700, "pe": 9.1, "dividend": 150, "yield": 4.68},
    {"ticker": "BICI", "company": "BICICI", "sector": "Banque", "price": 7800, "prevClose": 7720, "change": 1.04, "volume": 45300, "marketCap": "165 Mrd", "high52": 8900, "low52": 6800, "pe": 13.2, "dividend": 310, "yield": 3.97},
    {"ticker": "SIB", "company": "Société Ivoirienne de Banque", "sector": "Banque", "price": 5400, "prevClose": 5350, "change": 0.93, "volume": 87100, "marketCap": "270 Mrd", "high52": 6200, "low52": 4500, "pe": 8.9, "dividend": 280, "yield": 5.18},
    {"ticker": "NSBC", "company": "NSIA Banque CI", "sector": "Banque", "price": 6100, "prevClose": 6130, "change": -0.50, "volume": 32400, "marketCap": "141 Mrd", "high52": 7100, "low52": 5200, "pe": 8.1, "dividend": 300, "yield": 4.91},
    {"ticker": "CBIB", "company": "Coris Bank International BF", "sector": "Banque", "price": 10200, "prevClose": 10078, "change": 1.20, "volume": 29500, "marketCap": "326 Mrd", "high52": 11500, "low52": 8900, "pe": 9.5, "dividend": 520, "yield": 5.09},
    {"ticker": "PALC", "company": "Palm CI", "sector": "Agriculture", "price": 7100, "prevClose": 6950, "change": 2.15, "volume": 54200, "marketCap": "113 Mrd", "high52": 12500, "low52": 5900, "pe": 5.8, "dividend": 650, "yield": 9.15},
    {"ticker": "SOGC", "company": "SOGB CI", "sector": "Agriculture", "price": 4200, "prevClose": 4124, "change": 1.85, "volume": 31200, "marketCap": "91 Mrd", "high52": 5900, "low52": 3600, "pe": 6.2, "dividend": 380, "yield": 9.04},
    {"ticker": "SAPC", "company": "SAPH CI", "sector": "Agriculture", "price": 3400, "prevClose": 3425, "change": -0.75, "volume": 18900, "marketCap": "53 Mrd", "high52": 4800, "low52": 2900, "pe": 7.1, "dividend": 220, "yield": 6.47},
    {"ticker": "SLBC", "company": "Solibra CI", "sector": "Industrie", "price": 89000, "prevClose": 89000, "change": 0.0, "volume": 4200, "marketCap": "147 Mrd", "high52": 135000, "low52": 75000, "pe": 14.5, "dividend": 4200, "yield": 4.71},
    {"ticker": "UNXC", "company": "Uniwax CI", "sector": "Industrie", "price": 780, "prevClose": 790, "change": -1.25, "volume": 92400, "marketCap": "16 Mrd", "high52": 1400, "low52": 680, "pe": 11.0, "dividend": 30, "yield": 3.84},
    {"ticker": "CABC", "company": "Sicable CI", "sector": "Industrie", "price": 3625, "prevClose": 3710, "change": -2.29, "volume": 18700, "marketCap": "88 Mrd", "high52": 4500, "low52": 3100, "pe": 9.1, "dividend": 220, "yield": 6.06},
    {"ticker": "CIEC", "company": "CIE Côte d'Ivoire", "sector": "Services Publics", "price": 2150, "prevClose": 2140, "change": 0.45, "volume": 42100, "marketCap": "120 Mrd", "high52": 2600, "low52": 1850, "pe": 10.2, "dividend": 140, "yield": 6.51},
    {"ticker": "SDCC", "company": "SODECI Côte d'Ivoire", "sector": "Services Publics", "price": 5300, "prevClose": 5242, "change": 1.10, "volume": 28400, "marketCap": "47 Mrd", "high52": 6100, "low52": 4600, "pe": 8.7, "dividend": 350, "yield": 6.60},
    {"ticker": "CFAC", "company": "CFAO Motors CI", "sector": "Distribution", "price": 920, "prevClose": 920, "change": 0.0, "volume": 64100, "marketCap": "17 Mrd", "high52": 1300, "low52": 810, "pe": 12.8, "dividend": 45, "yield": 4.89},
    {"ticker": "TTLS", "company": "TotalEnergies Marketing SN", "sector": "Distribution", "price": 2500, "prevClose": 2480, "change": 0.80, "volume": 21400, "marketCap": "67 Mrd", "high52": 2900, "low52": 2100, "pe": 9.9, "dividend": 160, "yield": 6.40},
    {"ticker": "SDSC", "company": "AGL / Bolloré Transport CI", "sector": "Transport", "price": 1650, "prevClose": 1660, "change": -0.60, "volume": 142000, "marketCap": "92 Mrd", "high52": 2400, "low52": 1350, "pe": 8.3, "dividend": 110, "yield": 6.66},
]


def read_ticker(ticker):
    folder = TICKER_MAP.get(ticker.upper(), ticker.upper())
    path = os.path.join(BRVM_DATA_DIR, folder, f"{folder}.daily.csv")
    try:
        with open(path, newline="", encoding="utf-8") as fh:
            rows = [r for r in csv.reader(fh) if r and r[0].strip()]
    except OSError:
        return None
    if len(rows) < 3:  # entete + 2 seances minimum
        return None
    close, prev = float(rows[-1][4]), float(rows[-2][4])
    change = ((close - prev) / prev * 100) if prev else 0.0
    return {
        "price": close,
        "prevClose": prev,
        "change": round(change, 2),
        "volume": int(float(rows[-1][5] or 0)),
    }


@lru_cache(maxsize=1)
def stocks():
    """Charge une fois par process, comme le module JS."""
    out = []
    for s in SEED:
        real = read_ticker(s["ticker"])
        out.append({**s, **real} if real else dict(s))
    return out


def find(ticker):
    t = (ticker or "").upper()
    return next((s for s in stocks() if s["ticker"] == t), None)


if __name__ == "__main__":
    # Verification : le parseur CSV doit rendre les memes champs que le JS.
    assert find("SNTS") is not None
    assert find("inconnu") is None
    assert len(stocks()) == len(SEED)
    for s in stocks():
        assert set(s) >= {"ticker", "price", "prevClose", "change", "volume"}
        assert isinstance(s["price"], (int, float))
    print(f"OK — {len(stocks())} titres, {sum(1 for s in SEED if read_ticker(s['ticker']))} depuis CSV")
