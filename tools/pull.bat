@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pull.ps1" %*
if errorlevel 1 pause
