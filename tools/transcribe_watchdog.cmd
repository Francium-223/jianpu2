@echo off
rem Launcher for the transcribe watchdog scheduled task: locate pwsh, then hand off to the .ps1.
rem Same reason as crawl_watchdog_jianpujia_s0.cmd: a scheduled task action needs ONE absolute
rem executable path, and pwsh on this box is not in a stable location. Missing pwsh is never a
rem silent failure (falls back to Windows PowerShell 5.1, which can run the .ps1 too).
setlocal
set "PWSH="
if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe" set "PWSH=%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe"
if not defined PWSH if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not defined PWSH for /d %%D in ("%ProgramFiles%\WindowsApps\Microsoft.PowerShell_*_x64__8wekyb3d8bbwe") do if exist "%%~fD\pwsh.exe" set "PWSH=%%~fD\pwsh.exe"
if not defined PWSH set "PWSH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

"%PWSH%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0transcribe_watchdog.ps1" %*
exit /b %ERRORLEVEL%
