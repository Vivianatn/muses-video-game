@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0disable.ps1" %*
if errorlevel 1 pause
