@echo off
title BAOU Finance - Logs en direct
cd /d "%~dp0"
docker compose logs -f
