@echo off
REM Creates a desktop shortcut to ABS Platform launcher

set SCRIPT_DIR=%~dp0
set SHORTCUT_PATH=%USERPROFILE%\Desktop\ABS Platform.lnk
set TARGET_PATH=%SCRIPT_DIR%launch_abs.bat
set ICON_PATH=%SCRIPT_DIR%build\windows\x64\runner\Release\abs_platform.exe

echo Creating desktop shortcut...

powershell -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%SHORTCUT_PATH%'); $s.TargetPath = '%TARGET_PATH%'; $s.IconLocation = '%ICON_PATH%'; $s.WorkingDirectory = '%SCRIPT_DIR%'; $s.Save()"

echo.
echo Desktop shortcut created: %SHORTCUT_PATH%
echo.
echo This shortcut will always launch the latest build from:
echo %TARGET_PATH%
echo.
pause
