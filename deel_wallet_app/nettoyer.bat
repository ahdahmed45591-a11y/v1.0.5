@echo off
title BAOU Finance - Nettoyage build Flutter
cd /d "%~dp0"
flutter clean
flutter pub get
echo.
echo Nettoyage termine. Relancez depuis Android Studio (bouton Run, pas Debug).
pause
