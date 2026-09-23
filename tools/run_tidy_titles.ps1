# -*- coding: utf-8 -*-
# 等"曲名清洗"跑完, 自动把书名号去掉(后处理)。
# 等待条件用**进程**判断: 没有 refine_titles_llm 在跑 + title_clean.tsv 已生成。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\tidy_titles.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 书名号后处理 等待开始 ================"

$waited = 0
while ($waited -lt 240) {   # 最多等 2 小时
    $busy = @(Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
              Where-Object { $_.CommandLine -match 'refine_titles_llm' }).Count
    if ($busy -eq 0 -and (Test-Path "train-work\title_clean.tsv")) {
        Say "曲名清洗已结束, 开始去书名号"
        break
    }
    Say "  还在清洗($busy 个进程), 等 30 秒"
    Start-Sleep -Seconds 30
    $waited += 0.5
}
if ($waited -ge 240) { Say "等待超时(2 小时), 放弃"; exit 1 }

py -3.13 tools/tidy_title_clean.py *>> $log
Say "退出码 $LASTEXITCODE"
Say "================ 结束 ================"
