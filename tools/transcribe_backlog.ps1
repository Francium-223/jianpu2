# -*- coding: utf-8 -*-
# 扩张线: 转写 scan_backlog.py 找出来的 2709 页纯简谱, 然后接 finalize/stats/verify。
#
# 用计划任务启动(跑在 harness job 之外, 退出会话不会杀)。GPU 独占, 期间别开别的模型。
# 说明: 这批页是"纯度门判为纯简谱、但还没有转写结果"的 —— 等于白捡的语料增量。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\transcribe_backlog.log"
$env:JP_DASHMINW = "8"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 扩张转写(backlog) 开始 ================"
if (-not (Test-Path "train-work/backlog_pure.txt")) { Say "名单不存在, 退出"; exit 1 }
Say ("名单: " + (Get-Content "train-work/backlog_pure.txt").Count + " 页")

Say "--- 1) 转写 ---"
py -3.13 tools/transcribe_source.py train-work/backlog_pure.txt *>> $log
Say "转写退出码 $LASTEXITCODE"

foreach ($step in @("finalize", "stats", "verify")) {
    Say "--- 2) $step ---"
    py -3.13 run.py $step *>> $log
    Say "$step 退出码 $LASTEXITCODE"
}

Say "--- 3) 再扫一次 backlog（看爬虫新加了多少还没转）---"
py -3.13 tools/scan_backlog.py *>> $log
Say "scan 退出码 $LASTEXITCODE"

Say "结果摘要(另存, 不回写日志):"
Get-Content $log | Where-Object { $_.Length -lt 300 } |
    Select-Object -Last 60 | Set-Content "train-work\transcribe_backlog_摘要.txt" -Encoding utf8
Say "================ 扩张转写 结束 ================"
