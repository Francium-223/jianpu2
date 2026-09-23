# -*- coding: utf-8 -*-
# 扩张线: 重爬三个源, 找上次爬取(9/18)之后新增/漏掉的曲谱。
#
# 为什么用计划任务启动: 会跑 1-2 小时, 而会话里的子进程仍在 harness 的 Windows job
# 对象内 —— 用户退出会话会被一起杀掉(2026-09-20 实测踩过 ✗)。计划任务跑在 job 之外 ✓。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\expand_crawl.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 扩张爬取开始 ================"
$before = (Get-ChildItem "images-prep\*\*" -Directory -ErrorAction SilentlyContinue).Count
Say "爬取前 images-prep 谱目录: $before"

foreach ($t in @("crawl_artists_all.py", "crawl_qupu123_all.py", "crawl_jianpujia_all.py")) {
    Say "--- $t ---"
    py -3.13 "tools/$t" *>> $log
    Say "$t 退出码 $LASTEXITCODE"
    $n = (Get-ChildItem "images-prep\*\*" -Directory -ErrorAction SilentlyContinue).Count
    Say "  当前谱目录: $n (新增 $($n - $before))"
}

$after = (Get-ChildItem "images-prep\*\*" -Directory -ErrorAction SilentlyContinue).Count
Say "================ 爬取结束: $before -> $after (新增 $($after-$before)) ================"
Say "下一步(需要 GPU): py -3.13 tools/scan_backlog.py 找出能转的, 再喂 transcribe_source.py"
