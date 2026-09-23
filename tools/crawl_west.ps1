# -*- coding: utf-8 -*-
# 西方曲子扩张(量小): 按歌名去 qupu123 搜。纯网络, 不占 GPU。
# 先用实测证据说明为什么"量小": 西方曲在那站几乎全是 /qiyue/ 器乐/钢琴谱, 通俗简谱 0~1/关键词。
# 关键词单: train-work/crawl_keywords_west.txt -> 结果目录 images-prep/qupu123-west
#
# **先等港乐那轮跑完再开始** —— 两个爬虫同时打同一个站不礼貌, 而且两边都会在结尾跑 scan_backlog,
# 会互相覆盖 backlog_pure.txt(竞态)。港乐脚本最后一行写 "scan 退出码 N", 以此为准。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\expand_west.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

$hklog = "train-work\expand_hk.log"
Say "================ 西方扩张: 等港乐那轮收尾 ================"
$waited = 0
while ($waited -lt 180) {
    # **必须看最后几行, 不能只看最后一行** ✗ —— 港乐脚本结尾还有 "新抓的页要等下一次转写
    # 才进语料" 这类提示行, sentinel("scan 退出码") 并不在最后一行, 只看 -Tail 1 会永远等下去
    # (2026-09-21 实测踩过: 白等了一个多小时)。
    $tail = if (Test-Path $hklog) { (Get-Content $hklog -Tail 5 -Encoding UTF8) -join "`n" } else { "" }
    if ($tail -match 'scan 退出码') { Say "港乐那轮已收尾, 开始西方"; break }
    Start-Sleep -Seconds 30
    $waited += 0.5
}
if ($waited -ge 180) { Say "等超时(>=90 分钟), 直接开跑" }

$titles = Get-Content "train-work\crawl_keywords_west.txt" |
    Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' }
Say "================ 西方扩张开始: $($titles.Count) 个关键词 ================"
$before = (Get-ChildItem "images-prep\*\*" -Directory -ErrorAction SilentlyContinue).Count
Say "爬前谱目录: $before"

$i = 0
foreach ($t in $titles) {
    $i++
    Say "[$i/$($titles.Count)] $t"
    py -3.13 tools/crawl_qupu123.py "$t" 4 west *>> $log
}

$after = (Get-ChildItem "images-prep\*\*" -Directory -ErrorAction SilentlyContinue).Count
Say "================ 西方扩张结束: $before -> $after (新增 $($after-$before)) ================"

Say "--- 刷新 backlog 名单(纯 CPU) ---"
py -3.13 tools/scan_backlog.py *>> $log
Say "scan 退出码 $LASTEXITCODE"
