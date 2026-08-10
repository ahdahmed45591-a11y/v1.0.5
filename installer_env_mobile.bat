@echo off
title BAOU Finance - Installation de l'environnement mobile
cls

where winget >nul 2>&1 || (
  echo winget est introuvable. Installez "App Installer" depuis le Microsoft Store,
  echo puis relancez ce script.
  pause
  exit /b 1
)

echo Ce script installe, uniquement si absents :
echo   - JDK 17 (Temurin)
echo   - Android Studio (inclut le SDK Android)
echo.
echo Chaque installation ouvre sa propre fenetre. Suivez les invites winget.
pause

where java >nul 2>&1
if errorlevel 1 (
  echo [1/2] Installation du JDK 17...
  winget install --id EclipseAdoptium.Temurin.17.JDK -e --accept-package-agreements --accept-source-agreements
) else (
  echo [1/2] Java deja present : & java -version
)

echo.
echo [2/2] Installation d'Android Studio (inclut le SDK Android)...
winget install --id Google.AndroidStudio -e --accept-package-agreements --accept-source-agreements

echo.
echo ========================================================
echo  Termine. Etapes suivantes :
echo    1. Lancez Android Studio une premiere fois pour finir
echo       la configuration du SDK (assistant au premier demarrage).
echo    2. Ouvrez ce dossier dans Android Studio :
echo       %~dp0
echo    3. Attendez la synchronisation Gradle, puis lancez l'app
echo       (Shift+F10) sur un emulateur ou votre telephone en USB.
echo.
echo  Le backend doit tourner : demarrer_local.bat
echo  L'URL a saisir dans l'app (engrenage) s'affiche a la fin
echo  de ce script.
echo ========================================================
pause
