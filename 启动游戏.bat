@echo off
setlocal
title HANDLER
set "GODOT=D:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" for %%F in ("D:\Godot\Godot_v4*_win64.exe") do set "GODOT=%%~fF"
if not exist "%GODOT%" goto noGodot
set "PROJ=%~dp0"
if "%PROJ:~-1%"=="\" set "PROJ=%PROJ:~0,-1%"
echo  Project : %PROJ%
echo  Godot   : %GODOT%
if not exist "%PROJ%\.godot" (
  echo  First run: importing project, please wait...
  "%GODOT%" --headless --path "%PROJ%" --editor --quit >nul 2>&1
  echo  Import done.
)
echo  Launching...
echo.
"%GODOT%" --path "%PROJ%"
set "RC=%ERRORLEVEL%"
echo.
echo  [HANDLER] exited with code %RC%
if not "%RC%"=="0" pause
exit /b %RC%
:noGodot
echo.
echo  [ERROR] Godot not found at: %GODOT%
echo  Edit this .bat and set GODOT to your Godot 4.7 executable.
echo.
pause
exit /b 1
