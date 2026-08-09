@echo off
title BAOU Finance - Test du parcours API
cd /d "%~dp0"

curl -s -o nul http://localhost:3001/health || (
  echo Backend injoignable sur http://localhost:3001
  echo Lancez d'abord demarrer_local.bat, puis reessayez.
  pause
  exit /b 1
)

python backend_django\test_api.py
if errorlevel 9009 py backend_django\test_api.py
pause
