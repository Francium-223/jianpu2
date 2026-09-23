# -*- coding: utf-8 -*-
# 扩张的"第二轮": 等当前 backlog 转写跑完 -> 刷新 backlog 名单 -> 把新抓到的也转了 -> 验收。
#
# 为什么需要它: transcribe_source 拿到的是**固定名单**, 所以爬虫在转写期间新抓的谱
# 不会自动进语料 ✗。这个脚本把"爬 -> 转"接成闭环, 让扩张自动循环 ✓。
# 用计划任务启动(跑在 harness job 之外, 退出会话不会杀)。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\expand_followup.log"
$env:JP_DASHMINW = "8"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

function Transcribing { (Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
    Where-Object { $_.CommandLine -match 'transcribe_source' } | Measure-Object).Count }

Say "================ 扩张第二轮: 等当前转写结束 ================"
$deadline = (Get-Date).AddHours(30)
while ((Transcribing) -gt 0 -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 300 }
Say "当前转写结束（或等待超时）; 剩余 transcribe 进程 $(Transcribing)"

Say "--- 1) 刷新 backlog 名单（爬虫新抓的会出现在这里）---"
py -3.13 tools/scan_backlog.py *>> $log
Say "scan 退出码 $LASTEXITCODE"
$n = if (Test-Path "train-work/backlog_pure.txt") { (Get-Content "train-work/backlog_pure.txt").Count } else { 0 }
Say "新名单: $n 页待转"

if ($n -gt 0) {
    Say "--- 2) 转第二轮 ---"
    py -3.13 tools/transcribe_source.py train-work/backlog_pure.txt *>> $log
    Say "转写退出码 $LASTEXITCODE"
    foreach ($step in @("finalize", "stats", "verify")) {
        Say "--- 3) $step ---"
        py -3.13 run.py $step *>> $log
        Say "$step 退出码 $LASTEXITCODE"
    }
}

Say "--- 4) 纯度新规影响: 跑一次回归测试 ---"
py -3.13 tools/test_staffhard.py 1000 *>> $log
Say "结果摘要(另存):"
Get-Content $log | Where-Object { $_.Length -lt 300 } |
    Select-Object -Last 40 | Set-Content "train-work\expand_followup_摘要.txt" -Encoding utf8
Say "================ 扩张第二轮结束 ================"
