@echo off
setlocal
cd /d "%~dp0"
title HANDLER DIAGNOSE
echo ==== HANDLER diagnose ====
echo.
where godot 2>nul
echo.
set "GODOT=D:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" for %%F in ("D:\Godot\Godot_v4*_win64.exe") do set "GODOT=%%~fF"
echo Godot: %GODOT%
if not exist "%GODOT%" goto noGodot
echo Project: %~dp0
echo.
echo ---- importing (safe) ----
"%GODOT%" --headless --path "%~dp0" --editor --quit
echo.
echo ---- run verbose (this window stays open) ----
"%GODOT%" --verbose --path "%~dp0"
echo.
echo ---- exited: %ERRORLEVEL% ----
pause
exit /b 0
:noGodot
echo [ERROR] Godot not found. Edit this file.
pause
exit /b 1
