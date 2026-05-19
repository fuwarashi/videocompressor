@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0VideoCompressorGUI.ps1"
if errorlevel 1 (
    echo.
    echo Failed to launch VideoCompressor GUI.
    pause
)
