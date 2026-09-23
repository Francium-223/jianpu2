# -*- coding: utf-8 -*-
# 基准链跑完之后的**交付收尾**: 标 todo= / 重建来源表 / 生成 HTML / 校验 / 写交付说明。
# 等 bench_run.log 出现结束标记(且没有相关 python 在跑)再开始。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\deliver_run.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 交付收尾 等待开始 ================"

$waited = 0
while ($waited -lt 480) {          # 最多等 4 小时
    $busy = @(Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
              Where-Object { $_.CommandLine -match 'finalize|transcribe_source|melody_retrieval|to_jianpu_db' }).Count
    $done = (Select-String -Path "train-work\bench_run.log" -Pattern '基准集收尾链 结束' -Quiet -ErrorAction SilentlyContinue)
    if ($busy -eq 0 -and $done) { Say "基准链已结束, 开始交付收尾"; break }
    Say "  基准链还在跑(python $busy, 结束标记 $done), 等 60 秒"
    Start-Sleep -Seconds 60
    $waited += 1
}
if ($waited -ge 480) { Say "等待超时(4 小时), 仍开始收尾"; }

Say "--- 1) 标 todo=refine the filename(文件名仍不达标的) ---"
py -3.13 tools/flag_odd_names.py --apply *>> $log
Say "退出码 $LASTEXITCODE"

Say "--- 2) 重建来源表 source_map.tsv ---"
py -3.13 tools/source_map.py *>> $log
Say "退出码 $LASTEXITCODE"

Say "--- 3) 生成 source_map.html ---"
py -3.13 tools/source_map_html.py *>> $log
Say "退出码 $LASTEXITCODE"

Say "--- 4) 校验交付物 ---"
py -3.13 tools/verify_deliverable.py *>> $log
Say "退出码 $LASTEXITCODE"

Say "--- 5) 写交付说明 ---"
py -3.13 tools/delivery_report.py *>> $log
Say "退出码 $LASTEXITCODE"

Say "================ 交付收尾 结束 ================"
