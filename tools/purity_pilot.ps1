# -*- coding: utf-8 -*-
# 纯度门放宽的**试点验证**: 等前面所有链跑完 -> 抽 80 页"旧判据拒、新判据应放行"的谱真转一遍,
# 与已接受语料比质量(x 率/0 率/每页音符), 决定要不要把 667 个全放进来。
# pilot_purity2.py 输出到 train-work/pilot-purity2/, **不写 batch-out、不碰语料**。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\purity_pilot.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 纯度门试点 等待开始 ================"
$waited = 0
while ($waited -lt 720) {
    $busy = @(Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
              Where-Object { $_.CommandLine -match 'finalize|transcribe_source|melody_retrieval|to_jianpu_db|dedupe_by_content|source_map|pilot_purity' }).Count
    $done = (Select-String -Path "train-work\final_dedupe.log" -Pattern '收尾\(去重\+全量重测\) 结束' -Quiet -ErrorAction SilentlyContinue)
    if ($busy -eq 0 -and $done) { Say "收尾链已结束, 开始纯度门试点"; break }
    Say "  还在跑(python $busy, 结束标记 $done), 等 60 秒"
    Start-Sleep -Seconds 60
    $waited += 1
}
if ($waited -ge 720) { Say "等待超时(12 小时), 仍开始" }

Say "--- 试点: 抽 80 页 '旧拒新收' 的谱真转一遍(不写语料) ---"
$env:JP_PURITY2 = "1"
py -3.13 tools/pilot_purity2.py 80 *>> $log
Say "pilot 退出码 $LASTEXITCODE"
Say "--- 结论看 train-work/purity_pilot.log 里 'x 率/0 率' 与已接受语料的对比 ---"
Say "  放行名单 $((Get-Content train-work\purity2_admit.txt | Where-Object {$_ -match '\S'}).Count) 个 -> train-work/purity2_admit.txt"
Say "================ 纯度门试点 结束 ================"
