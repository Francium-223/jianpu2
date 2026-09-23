# -*- coding: utf-8 -*-
# 纯度门回收接力: 等"全量重转写"结束 -> finalize -> stats -> verify -> 响铃报警。
#
# 为什么要接力: 转写约 1.7 小时、finalize 还要扫全库约 1 小时, 用户不在旁边,
# 所以跑完必须**自动响铃**叫他 (TeamViewer 上能听到/看到)。
#
# 用法: pwsh -File tools/finish_purity2.ps1   (通常作为后台任务启动)
$ErrorActionPreference = "Continue"
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$runLog = "train-work\purity2_run.log"
$sumLog = "train-work\purity2_finish.log"
$env:JP_PURITY2 = "1"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $sumLog -Value $line -Encoding utf8
}

Say "===== 接力开始: 等全量重转写结束 ====="
$deadline = (Get-Date).AddHours(5)
while ((Get-Date) -lt $deadline) {
    if (Test-Path $runLog) {
        $doneLine = Select-String -Path $runLog -Pattern '^完成 \d+/\d+' -ErrorAction SilentlyContinue |
                    Select-Object -Last 1
        if ($doneLine) { break }
    }
    Start-Sleep -Seconds 30
}
$doneLine = Select-String -Path $runLog -Pattern '^完成 \d+/\d+' -ErrorAction SilentlyContinue |
            Select-Object -Last 1
Say ("转写结束: " + $(if ($doneLine) { $doneLine.Line } else { "（超时未见'完成'行, 仍继续）" }))

foreach ($step in @("finalize", "stats", "verify")) {
    $stepLog = "train-work\purity2_$step.log"
    $ok = $false
    for ($try = 1; $try -le 2 -and -not $ok; $try++) {
        Say "--- $step 开始 (第 $try 次) ---"
        py -3.13 run.py $step *> $stepLog
        $code = $LASTEXITCODE
        Say "$step 退出码 $code"
        if ($code -eq 0) { $ok = $true }
        elseif ($try -lt 2) { Say "  -> 失败, 60 秒后重试"; Start-Sleep -Seconds 60 }
    }
}

Say "===== 汇总 ====="
foreach ($f in @("train-work\purity2_finalize.log", "train-work\purity2_stats.log", "train-work\purity2_verify.log")) {
    if (-not (Test-Path $f)) { continue }
    Say "### $f"
    Get-Content $f -Tail 25 | ForEach-Object { Say "    $_" }
}

Say "===== 全部完成 (按用户要求: **不响铃**, 只写日志) ====="
Say "结果见 train-work\purity2_finish.log 与 purity2_{finalize,stats,verify}.log"
