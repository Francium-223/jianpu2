# -*- coding: utf-8 -*-
# 第二轮: 等第一轮(jp_mandopop_absorb)跑完, 再转写"补捞到的新目录" -> 入库 -> 复测 -> 评测 -> 校验。
# 为什么需要第二轮: 第一轮在启动时就把 images-prep/qupu123-mp* 的目录列好了, 之后新补的
#   qupu123-mp9xx(修了 /data2/uploads 过滤后重爬的)、jianpujia-art*(歌手页定向)、jianpucn-title*
#   都不在它的名单里, 必须再转一次; 而且 finalize 是整库重建, 一天内不宜反复跑。
# 用法: pwsh -File tools\mandopop_absorb2.ps1
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$env:JP_PURITY2 = "1"
$log = "train-work\mandopop_absorb2.log"
function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}
function Step([string]$label, [scriptblock]$body) {
    Say "--- $label ---"
    $t0 = Get-Date
    & $body *>> $log
    Say "    $label 用时 $([int]((Get-Date)-$t0).TotalSeconds)s 退出码 $LASTEXITCODE"
}

Say "================ 第二轮(补捞入库) 开始 ================"
# 注意: 下面这个"10 小时"是**等待循环的兜底上限**(轮询到第一轮结束为止; 万一它卡死, 等人的人
# 也不能无限等下去), **不是预计耗时**。实测(2026-09-22): 转写 0.83 分钟/目录, 第一轮 94 目录
# 约 78 分钟; 收尾+全部评测约 60 分钟; 第一轮整体约 2.5 小时。之前只写"最多 10 小时"被误读成
# "要跑 10 小时", 这里写清楚。
Say "等待第一轮 jp_mandopop_absorb 结束(轮询兜底上限 10 小时, 实测第一轮约 2.5 小时)..."
$t0 = Get-Date
while ($true) {
    $st = (Get-ScheduledTask -TaskName 'jp_mandopop_absorb' -ErrorAction SilentlyContinue).State
    $done = (Select-String -Path train-work\mandopop_absorb.log -Pattern '金曲缺口吸收 完成' -Quiet -ErrorAction SilentlyContinue)
    if ($done -or $st -ne 'Running') { break }
    if (((Get-Date) - $t0).TotalHours -gt 10) { Say "等待超过兜底上限(10 小时), 继续执行"; break }
    Start-Sleep -Seconds 60
}
Say "第一轮状态: $st / 完成标记 $done  (等待 $([int]((Get-Date)-$t0).TotalMinutes) 分钟)"

$new = @()
$new += Get-ChildItem images-prep -Directory -Filter 'qupu123-mp9*' -ErrorAction SilentlyContinue
$new += Get-ChildItem images-prep -Directory -Filter 'qupu123-title*' -ErrorAction SilentlyContinue
$new += Get-ChildItem images-prep -Directory -Filter 'jianpujia-art*' -ErrorAction SilentlyContinue
$new += Get-ChildItem images-prep -Directory -Filter 'jianpucn-title*' -ErrorAction SilentlyContinue
Say "待转写新目录 $($new.Count) 个: $(($new | Select-Object -ExpandProperty Name) -join ', ')"

$i = 0
foreach ($d in $new) {
    $i++
    Say "[$i/$($new.Count)] $($d.Name)"
    py -3.13 tools/transcribe_source.py $d.FullName *>> $log
}

Step "入库收尾(finalize)" { py -3.13 tools/finalize.py }
Step "覆盖率复测"        { py -3.13 tools/cover_mandopop.py }
Step "检索评测"          {
    py -3.13 tools/melody_retrieval_eval.py --sweep
    Copy-Item train-work\retrieval_eval.tsv train-work\retrieval_eval_rand.tsv -Force
    py -3.13 tools/melody_retrieval_eval.py --sweep --errmode neighbor
    Copy-Item train-work\retrieval_eval.tsv train-work\retrieval_eval_neighbor.tsv -Force
    Remove-Item train-work\retrieval_holdout.tsv, train-work\retrieval_indel.tsv, train-work\retrieval_contour.tsv -Force -ErrorAction SilentlyContinue
    py -3.13 tools/melody_retrieval_holdout.py --len 11 --err 0 --n 2 --multi 1
    py -3.13 tools/melody_retrieval_holdout.py --len 11 --err 0 --n 2 --multi 5
    py -3.13 tools/melody_retrieval_holdout.py --len 15 --err 0 --n 2 --multi 5
    py -3.13 tools/melody_retrieval_indel.py --len 13 --sub 1 --err 0 --n 1
    py -3.13 tools/melody_retrieval_contour.py --len 11 --n 2 --multi 1
    py -3.13 tools/frag_ambiguity.py 400
}
Step "抽检 + 交付物"     {
    py -3.13 tools/qa_corpus.py
    py -3.13 tools/qa_sample.py 40
    py -3.13 tools/flag_odd_names.py --apply
    py -3.13 tools/source_map.py
    py -3.13 tools/source_map_html.py
    py -3.13 tools/verify_deliverable.py
    py -3.13 tools/delivery_report.py
}
# 文档数字同步(必须是最后一步: 覆盖率报告与评测数字都要先落盘)
Step "覆盖率报告 + 文档同步" {
    py -3.13 tools/coverage_report.py
    py -3.13 tools/numbers_digest.py
    py -3.13 tools/sync_docs.py
}
Say "================ 第二轮(补捞入库) 完成 ================"
