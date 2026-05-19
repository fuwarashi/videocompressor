@echo off
setlocal enabledelayedexpansion

:: Check if a file was dragged onto the script
if "%~1"=="" (
    echo CRITICAL: Drag and drop a video file onto this script icon to use it.
    pause
    exit /b
)

set "INPUT_FILE=%~1"
set "OUTPUT_FILE=%~dpn1_compressed.mp4"

echo Target File Size Tool
echo =====================
echo Processing: %~nx1
echo.

:: Ask user for target size in MB
set /p TARGET_MB="Enter your desired file size in MB (e.g., 8, 25, 50): "

:: Get video duration in seconds using ffprobe
for /f "tokens=*" %%a in ('ffprobe -v error -show_entries format=duration -of default^=noprint_wrappers^=1:nokey^=1 "%INPUT_FILE%"') do set "DURATION=%%a"

:: Convert duration to an integer for simple batch math
for /f "delims=." %%a in ("%DURATION%") do set "DURATION_INT=%%a"

if !DURATION_INT! LSS 1 set DURATION_INT=1

:: Math: (TargetMB * 8192 * 95 / 100) / Duration -> 5% safety buffer included
set /a TOTAL_BITRATE=(%TARGET_MB% * 8192 * 95 / 100) / %DURATION_INT%
set /a VIDEO_BITRATE=%TOTAL_BITRATE% - 128

if !VIDEO_BITRATE! LSS 100 (
    echo Target size is too low for this video duration. Setting video bitrate to minimum 100k.
    set VIDEO_BITRATE=100
)

echo.
echo Calculated Video Bitrate: %VIDEO_BITRATE%k
echo Running Pass 1 (Analysis)...
ffmpeg -y -i "%INPUT_FILE%" -c:v libx264 -b:v %VIDEO_BITRATE%k -pass 1 -an -f mp4 NUL

echo.
echo Running Pass 2 (Encoding)...
ffmpeg -y -i "%INPUT_FILE%" -c:v libx264 -b:v %VIDEO_BITRATE%k -pass 2 -c:a aac -b:a 128k "%OUTPUT_FILE%"

:: Clean up log files left behind by FFmpeg
del ffmpeg2pass-0.log
del ffmpeg2pass-0.log.mbtree

echo.
echo =====================
echo DONE! Saved as: %OUTPUT_FILE%
pause