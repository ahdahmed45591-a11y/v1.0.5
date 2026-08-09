# BAOU Finance — Éléphant Bourse v1.0.5

Investissement sur la BRVM : application mobile, portail administrateur web,
API Django.

## Lancer

Double-cliquez sur `demarrer_local.bat` (Docker Desktop doit tourner), ou :

```
docker compose up --build -d
```

- Portail admin : http://localhost:3000 — `admin@elephantbourse.ci` / `admin2024`
- API : http://localhost:3001
- Arrêt : `arreter_local.bat` (les données PostgreSQL survivent dans le volume `pgdata`)

Vérifier que tout le parcours fonctionne :

```
python backend_django/test_api.py
```

## Application mobile

L'app mobile (Flutter, `deel_wallet_app/`) n'est pas versionnée dans ce dépôt.
Elle se connecte à l'API selon l'URL configurée dans `lib/api.dart` :

| Cas | URL |
|---|---|
| Émulateur | `http://10.0.2.2:3001` |
| Téléphone en Wi-Fi | `http://[VOTRE_IP]:3001` (`ipconfig`) |
| Téléphone via Ngrok | `https://xxxx.ngrok-free.app` |

`demarrer_local.bat` ouvre une fenêtre Ngrok qui affiche l'URL à copier.

## Structure

| Dossier | Rôle |
|---|---|
| `admin/` | Portail administrateur (React 18, Vite) |
| `backend_django/` | API REST (Django 5, DRF, PostgreSQL 16) |
| `data/brvm_data/` | Historiques de cours BRVM en CSV, montés en lecture seule |
| `data/uploads/` | Documents KYC envoyés par les clients |
| `tools/analyse_brvm/` | Scripts d'analyse BRVM, indépendants de l'API |

## Comptes de test

| Rôle | Identifiants |
|---|---|
| Admin | `admin@elephantbourse.ci` / `admin2024` |

Les comptes clients se créent depuis l'inscription de l'application mobile.

## Paiement

Dépôt via Wave CI : https://pay.wave.com/m/M_ci_XRkfDq_9M8GP/c/ci/?src=p
