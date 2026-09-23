# -*- coding: utf-8 -*-
# 关键词扩张: 按歌名去 qupu123 搜, 把库里没有的谱抓下来。
#
# 为什么走这条路: 三个源的"艺人清单/整站列表"路线已经爬干净了(2026-09-21 重爬只 +2 ✗),
# 而按歌名搜还能挖到漏网的名曲 —— 《云宫迅音》就是这么找到的 ✓。
# 种子歌单是 tools 之外的 train-work/crawl_keywords.txt(我凭常识列的搜索关键词, 不是数据断言)。
#
# 用计划任务启动(跑在 harness job 之外, 退出会话不会杀)。网络 IO, 不占 GPU。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\expand_keywords.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

$titles = Get-Content "train-work\crawl_keywords.txt" |
    Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' }
Say "================ 关键词扩张开始: $($titles.Count) 个关键词 ================"
$before = (Get-ChildItem "images-prep\*\*" -Directory -ErrorAction SilentlyContinue).Count
Say "爬前谱目录: $before"

$i = 0
foreach ($t in $titles) {
    $i++
    Say "[$i/$($titles.Count)] $t"
    py -3.13 tools/crawl_qupu123.py "$t" 4 *>> $log
}

$after = (Get-ChildItem "images-prep\*\*" -Directory -ErrorAction SilentlyContinue).Count
Say "================ 关键词扩张结束: $before -> $after (新增 $($after-$before)) ================"

Say "--- 刷新 backlog 名单(纯 CPU) ---"
py -3.13 tools/scan_backlog.py *>> $log
Say "scan 退出码 $LASTEXITCODE"
Say "新抓到的页要等下一次转写才会进语料 ✓"
