@echo off
setlocal
set "GODOT=D:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot not found at %GODOT%
  echo Edit this bat file and set GODOT to your Godot 4.7 executable.
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0" 
exit /b 0