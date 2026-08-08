@echo off
title BAOU Finance - Continuation v1.0.5
cd /d "%~dp0"
set "PATH=C:\Users\ABOU CISSE\git\cmd;C:\Users\ABOU CISSE\gh\bin;%PATH%"

echo [1/2] Push sur GitHub...
git push origin main

echo.
echo [2/2] Redemarrage complet...
call "%~dp0demarrer_local.bat"
