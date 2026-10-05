@echo off
rem Launcher for the jianpu.cn crawl watchdog scheduled task: locate pwsh, then hand off to the .ps1.
rem
rem Why this thin layer exists: a scheduled task action needs ONE absolute executable path, but pwsh on
rem this box is not in a stable location --
rem   C:\Program Files\PowerShell\7\pwsh.exe                                          does NOT exist
rem   %LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe                                  app-exec alias (version independent)
rem   %ProgramFiles%\WindowsApps\Microsoft.PowerShell_7.6.6.0_x64__8wekyb3d8bbwe\pwsh.exe  real binary, version in path
rem so pick in order: alias -> standard install -> real binary -> Windows PowerShell 5.1 (the .ps1 is
rem 5.1 compatible and aligns its own UTF-8 console encoding). Missing pwsh is never a silent failure.
setlocal
set "PWSH="
if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe" set "PWSH=%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe"
if not defined PWSH if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not defined PWSH for /d %%D in ("%ProgramFiles%\WindowsApps\Microsoft.PowerShell_*_x64__8wekyb3d8bbwe") do if exist "%%~fD\pwsh.exe" set "PWSH=%%~fD\pwsh.exe"
if not defined PWSH set "PWSH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

"%PWSH%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0crawl_watchdog_jianpucn.ps1" %*
exit /b %ERRORLEVEL%
