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

rem Secrets locaux, jamais commites. Generes une seule fois, aleatoirement.
if not exist ".env.docker" (
  echo Generation des secrets locaux dans .env.docker ...
  powershell -NoProfile -Command ^
    "$b=New-Object byte[] 48; (New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($b);" ^
    "$p=New-Object byte[] 24; (New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($p);" ^
    "Set-Content -Encoding ascii .env.docker @('POSTGRES_DB=baou','POSTGRES_USER=baou',('POSTGRES_PASSWORD='+[Convert]::ToBase64String($p).TrimEnd('=')),('JWT_SECRET='+[Convert]::ToBase64String($b).TrimEnd('=')))"
  echo Fait. Ce fichier reste sur votre machine.
)

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
ping -n 5 127.0.0.1 >nul

rem L'API locale de ngrok (port 4040) donne l'URL publique sans lire l'autre fenetre.
for /f "delims=" %%u in ('powershell -NoProfile -Command "try{(Invoke-RestMethod http://127.0.0.1:4040/api/tunnels).tunnels[0].public_url}catch{''}" 2^>nul) do set "NGROK_URL=%%u"

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
echo    Engrenage sur l'ecran de connexion, collez l'URL, Enregistrer.
echo.
if defined NGROK_URL (
  echo    ^>^>^> TELEPHONE : %NGROK_URL%/api/
) else (
  echo    Telephone : URL introuvable, lisez la fenetre "BAOU Ngrok Tunnel"
  echo                et ajoutez /api/ a la fin.
)
echo    Emulateur       : http://10.0.2.2:3001/api/
echo    Telephone Wi-Fi : http://[VOTRE_IP]:3001/api/  (ipconfig)
echo.
echo  Verifier le parcours complet : python backend_django\test_api.py
echo  Logs en direct               : docker compose logs -f
echo  Arreter                      : arreter_local.bat
echo ========================================================
echo.
pause
