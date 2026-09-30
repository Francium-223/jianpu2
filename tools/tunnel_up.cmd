@echo off
rem tunnel_up.cmd -- thin wrapper: find Python, hand over to tools\tunnel_up.py
rem (No PowerShell needed. ASCII only: the .cmd is read in the console codepage,
rem  and non-ASCII comments can be mis-parsed there. All Chinese text lives in the .py.)
rem
rem Usage:  tunnel_up.cmd                       (default port 8770)
rem         tunnel_up.cmd --port 8790 --no-secret
setlocal
set HERE=%~dp0
where py >NUL 2>NUL && (set PY=py -3) || (set PY=python)
%PY% "%HERE%tunnel_up.py" %*
endlocal
