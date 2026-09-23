# -*- coding: utf-8 -*-
# 港乐/粤语流行扩张: 按歌名去 qupu123 搜(纯网络, 不占 GPU)。
# 依据: 实测 qupu123 的谱 ~84% 是单声部简谱(能过纯度门), 而 jianpucn 流行包只有 ~50%。
# 关键词单: train-work/crawl_keywords_hk.txt
# 结果目录: images-prep/qupu123-hk
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\expand_hk.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

$titles = Get-Content "train-work\crawl_keywords_hk.txt" |
    Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' }
Say "================ 港乐扩张开始: $($titles.Count) 个关键词 ================"
$before = (Get-ChildItem "images-prep\*\*" -Directory -ErrorAction SilentlyContinue).Count
Say "爬前谱目录: $before"

$i = 0
foreach ($t in $titles) {
    $i++
    Say "[$i/$($titles.Count)] $t"
    py -3.13 tools/crawl_qupu123.py "$t" 4 hk *>> $log
}

$after = (Get-ChildItem "images-prep\*\*" -Directory -ErrorAction SilentlyContinue).Count
Say "================ 港乐扩张结束: $before -> $after (新增 $($after-$before)) ================"

Say "--- 刷新 backlog 名单(纯 CPU) ---"
py -3.13 tools/scan_backlog.py *>> $log
Say "scan 退出码 $LASTEXITCODE"
Say "新抓的页要等下一次转写才进语料"
