@echo off
chcp 65001 >nul
rem Extended nightly QA (read-only, seconds) -- complements the existing "夜班 QA 监视".
rem
rem Why a .cmd: the project convention is "no PowerShell dependency on target machines".
rem Why it is safe to run while transcription is running: it only reads data.jsonl and the
rem site index -- it does NOT parse scores or load models (the pipeline keeps ~6 GB VRAM).
rem Checks a different angle than the existing monitor:
rem   existing: 全丢 / 准入缺口 / %END 行 / 磁盘水位
rem   this one: corpus<->index consistency / fragment scores / low confidence / dup groups / 24h delta
setlocal
set ROOT=%~dp0..
set SITE=%ROOT%\..\jianpu-db.github.io
set ANA=%ROOT%\..\_analysis
set LOG=%ANA%\night_qa_ext.log
set PY=py -3.13

echo. >> "%LOG%"
echo ================ %DATE% %TIME% ================ >> "%LOG%"
cd /d "%ROOT%"

rem (1) lightweight sweep: consistency, fragments, low confidence, 24h delta (git history)
%PY% -u tools\qa_night_sweep.py --lists "%ANA%" >> "%LOG%" 2>&1

rem (2) fragment triage: which ones really lost pages (writes a redo list for transcribe_source.py)
%PY% -u tools\triage_fragments.py --in "%ANA%\qa_fragments.txt" --out "%ANA%\qa_fragments_triaged.txt" --redo-out "%ROOT%\train-work\redo_fragments_v1.txt" >> "%LOG%" 2>&1

rem (3) duplicate melodies (exact note-sequence fingerprint) -- feeds the title-cleanup tasks
if exist "%SITE%\tools\check_dup_melody.mjs" (
  node "%SITE%\tools\check_dup_melody.mjs" "%ANA%\dup_melody.txt" >> "%LOG%" 2>&1
) else (
  echo   (skip: check_dup_melody.mjs not found) >> "%LOG%"
)

rem (4) duplicate groups (user-visible); mapping table feeds build_web_data.py's grouping rule
if exist "%SITE%\tools\check_dup_groups.mjs" (
  node "%SITE%\tools\check_dup_groups.mjs" "%ANA%\group_merge_map.txt" >> "%LOG%" 2>&1
) else (
  echo   (skip: check_dup_groups.mjs not found) >> "%LOG%"
)

echo ---- done exit=%ERRORLEVEL% ---- >> "%LOG%"
endlocal
