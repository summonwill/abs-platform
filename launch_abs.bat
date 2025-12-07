@echo off
REM ABS Studio Launcher - Always runs latest build
cd /d "%~dp0"
start "" "build\windows\x64\runner\Release\abs_platform.exe"
