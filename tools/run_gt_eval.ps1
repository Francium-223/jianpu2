# -*- coding: utf-8 -*-
# 等夜间扩库链跑完 -> 手写 GT 复评(转 GT 谱图 + 比对) -> 刷新交付说明。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\gt_eval.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 手写GT复评 等待开始 ================"

$waited = 0
while ($waited -lt 600) {          # 最多等 5 小时
    $busy = @(Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
              Where-Object { $_.CommandLine -match 'finalize|transcribe_source|crawl_qupu123|melody_retrieval|to_jianpu_db|source_map' }).Count
    $done = (Select-String -Path "train-work\night_extend.log" -Pattern '夜间扩库链 结束' -Quiet -ErrorAction SilentlyContinue)
    if ($busy -eq 0 -and $done) { Say "扩库链已结束, 开始 GT 复评"; break }
    Say "  扩库链还在跑(python $busy, 结束标记 $done), 等 60 秒"
    Start-Sleep -Seconds 60
    $waited += 1
}
if ($waited -ge 600) { Say "等待超时(5 小时), 仍开始" }

Say "--- 转写手写 GT 谱图并比对 ---"
py -3.13 tools/gt_transcribe_eval.py *>> $log
Say "退出码 $LASTEXITCODE"

Say "--- 刷新交付说明(把 GT 数字并进去) ---"
py -3.13 tools/delivery_report.py *>> $log
Say "退出码 $LASTEXITCODE"

Say "================ 手写GT复评 结束 ================"
