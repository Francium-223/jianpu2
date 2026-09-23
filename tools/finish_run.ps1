# -*- coding: utf-8 -*-
# 收尾(不等待版): 直接跑"重扫 -> 补转 -> finalize -> stats -> verify -> 重扫"。
# 为什么要这个版本: finish_backlog.ps1 里的 WaitFor 依赖日志 sentinel, 实测会卡在等待里
# (2026-09-21: 两个 sentinel 其实都已具备, 但实例从 18:00 起一行没写)。两个前置任务都已经
# 结束的情况下, 直接跑更可靠。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\finish_run.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 收尾(不等待版)开始 ================"
Say "--- 1) 重扫 backlog ---"
py -3.13 tools/scan_backlog.py *>> $log
Say "scan 退出码 $LASTEXITCODE   待转 $((Get-Content train-work/backlog_pure.txt | Where-Object { $_ -match '\S' }).Count) 条"

Say "--- 2) 补转 ---"
py -3.13 tools/transcribe_source.py train-work/backlog_pure.txt *>> $log
Say "转写退出码 $LASTEXITCODE"

foreach ($step in @("finalize", "stats", "verify")) {
    Say "--- 3) $step ---"
    py -3.13 run.py $step *>> $log
    Say "$step 退出码 $LASTEXITCODE"
}

Say "--- 4) 最终再扫一次 ---"
py -3.13 tools/scan_backlog.py *>> $log
Say "scan 退出码 $LASTEXITCODE"
Say "================ 收尾(不等待版)结束 ================"
