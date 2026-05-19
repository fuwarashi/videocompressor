@echo off
setlocal DisableDelayedExpansion

:: Check if a file was dragged onto the script
if "%~1"=="" (
    echo No file argument detected.
    echo You can drag and drop a video file onto this window, then press Enter.
    set /p INPUT_FILE="Video path: "
    if not defined INPUT_FILE (
        echo CRITICAL: No video file was provided.
        pause
        exit /b 1
    )
) else (
    set "INPUT_FILE=%~1"
)

:: Remove surrounding quotes if user pasted a quoted path manually
if "%INPUT_FILE:~0,1%"=="""" if "%INPUT_FILE:~-1%"=="""" set "INPUT_FILE=%INPUT_FILE:~1,-1%"

for %%I in ("%INPUT_FILE%") do (
    set "OUTPUT_FILE=%%~dpnI_compressed.mp4"
    set "INPUT_NAME=%%~nxI"
)

set "DURATION="
set "DURATION_INT="
set "DURATION_FILE=%TEMP%\vc_duration_%RANDOM%_%RANDOM%.txt"

if not exist "%INPUT_FILE%" (
    echo CRITICAL: File not found: "%INPUT_FILE%"
    pause
    exit /b 1
)

where ffprobe >nul 2>&1
if errorlevel 1 (
    echo CRITICAL: ffprobe was not found. Install FFmpeg and add it to PATH.
    pause
    exit /b 1
)

where ffmpeg >nul 2>&1
if errorlevel 1 (
    echo CRITICAL: ffmpeg was not found. Install FFmpeg and add it to PATH.
    pause
    exit /b 1
)

echo Target File Size Tool
echo =====================
echo Processing: %INPUT_NAME%
echo.

:: Ask user for target size in MB
set /p TARGET_MB="Enter your desired file size in MB (e.g., 8, 25, 50): "
echo %TARGET_MB%| findstr /r "^[1-9][0-9]*$" >nul
if errorlevel 1 (
    echo CRITICAL: Please enter a whole number greater than 0.
    pause
    exit /b 1
)

:: Get video duration in seconds using ffprobe
ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "%INPUT_FILE%" > "%DURATION_FILE%" 2>nul
if errorlevel 1 (
    echo CRITICAL: ffprobe failed to read this video.
    del /q "%DURATION_FILE%" 2>nul
    pause
    exit /b 1
)

for /f "usebackq tokens=*" %%a in ("%DURATION_FILE%") do if not defined DURATION set "DURATION=%%a"
del /q "%DURATION_FILE%" 2>nul

:: Convert duration to an integer for simple batch math
for /f "delims=." %%a in ("%DURATION%") do set "DURATION_INT=%%a"

if not defined DURATION_INT (
    echo CRITICAL: Could not read video duration from ffprobe.
    pause
    exit /b 1
)

echo %DURATION_INT%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo CRITICAL: Invalid duration value from ffprobe: %DURATION%
    pause
    exit /b 1
)

if %DURATION_INT% LSS 1 set "DURATION_INT=1"

:: Math: (TargetMB * 8192 * 95 / 100) / Duration -> 5% safety buffer included
set /a TOTAL_BITRATE=(%TARGET_MB% * 8192 * 95 / 100) / %DURATION_INT%
set /a VIDEO_BITRATE=%TOTAL_BITRATE% - 128

if %VIDEO_BITRATE% LSS 100 (
    echo Target size is too low for this video duration. Setting video bitrate to minimum 100k.
    set "VIDEO_BITRATE=100"
)

echo.
echo Calculated Video Bitrate: %VIDEO_BITRATE%k
echo Running Pass 1 (Analysis)...
ffmpeg -y -i "%INPUT_FILE%" -c:v libx264 -b:v %VIDEO_BITRATE%k -pass 1 -an -f mp4 NUL
if errorlevel 1 (
    echo.
    echo CRITICAL: Pass 1 failed.
    pause
    exit /b 1
)

echo.
echo Running Pass 2 (Encoding)...
ffmpeg -y -i "%INPUT_FILE%" -c:v libx264 -b:v %VIDEO_BITRATE%k -pass 2 -c:a aac -b:a 128k "%OUTPUT_FILE%"
if errorlevel 1 (
    echo.
    echo CRITICAL: Pass 2 failed.
    pause
    exit /b 1
)

:: Clean up log files left behind by FFmpeg
del /q "ffmpeg2pass-0.log" 2>nul
del /q "ffmpeg2pass-0.log.mbtree" 2>nul

echo.
echo =====================
echo DONE! Saved as: %OUTPUT_FILE%
pause
