@echo off
title BAOU Finance - Lanceur v1.0.5 (Docker)
cls
cd /d "%~dp0"
set "PATH=C:\Users\ABOU CISSE\ngrok;C:\Users\ABOU CISSE\git\cmd;%PATH%"

echo ========================================================
echo        BAOU FINANCE v1.0.5 - Django + PostgreSQL 16
echo ========================================================
echo.

docker info >nul 2>&1 || (echo Docker Desktop n'est pas demarre. Lancez-le puis relancez ce script. & pause & exit /b 1)

echo [1/3] Construction et demarrage des conteneurs...
docker compose up --build -d || (echo Echec du demarrage. Voir : docker compose logs & pause & exit /b 1)

echo.
echo [2/3] Attente du backend sur http://localhost:3001 ...
for /l %%i in (1,1,60) do (
  curl -s -o nul http://localhost:3001/health && goto :pret
  ping -n 3 127.0.0.1 >nul
)
echo Le backend ne repond toujours pas. Diagnostic : docker compose logs backend
pause
exit /b 1

:pret
echo Backend pret.

echo.
echo [3/3] Tunnel NGROK pour l'application mobile...
start "BAOU Ngrok Tunnel" cmd /k "ngrok http 3001"

start http://localhost:3000

echo.
echo ========================================================
echo  PORTAIL ADMIN : http://localhost:3000
echo    admin@elephantbourse.ci / admin2024
echo.
echo  API BACKEND   : http://localhost:3001
echo  POSTGRESQL 16 : conteneur baou_finance_db (volume pgdata)
echo.
echo  APPLICATION MOBILE ANDROID :
echo    Emulateur       : http://10.0.2.2:3001/api/
echo    Telephone Wi-Fi : http://[VOTRE_IP]:3001/api/
echo    Via Ngrok       : copiez l'URL de la fenetre Ngrok + /api/
echo    (engrenage sur l'ecran de connexion, puis Enregistrer)
echo.
echo  Verifier le parcours complet : python backend_django\test_api.py
echo  Logs en direct               : docker compose logs -f
echo  Arreter                      : arreter_local.bat
echo ========================================================
echo.
pause
