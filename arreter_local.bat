@echo off
title BAOU Finance - Arret des services
cd /d "%~dp0"
docker compose down
taskkill /F /IM ngrok.exe >nul 2>&1 && echo Tunnel Ngrok arrete.
echo Services arretes. Les donnees PostgreSQL restent dans le volume pgdata.
pause
