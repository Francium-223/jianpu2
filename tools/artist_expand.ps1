# -*- coding: utf-8 -*-
# 第二轮扩库: 按歌手页抓新谱(44 位没抓过的华语歌手) -> 转写 -> 收尾 -> 重跑评测 -> 刷新交付物。
# 每位歌手最多抓 20 首(控制总量: 44×20 ≈ 880 张, 转写约 2-3 小时 GPU, 不会失控)。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\artist_expand.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 第二轮扩库(按歌手) 开始 ================"

$rows = Get-Content "train-work\artist_pages2.txt" | Where-Object { $_ -match '\S' }
Say "歌手页 $($rows.Count) 个"
$before = (Get-ChildItem "images-prep\*\*" -Directory -ErrorAction SilentlyContinue).Count
Say "爬前谱目录 $before"

$i = 0
foreach ($r in $rows) {
    $i++
    $p = $r -split "`t"
    $name = $p[0]; $url = $p[1]
    Say "[$i/$($rows.Count)] $name"
    py -3.13 tools/crawl_artist.py "$url" 20 *>> $log
}
$after = (Get-ChildItem "images-prep\*\*" -Directory -ErrorAction SilentlyContinue).Count
Say "爬后谱目录 $after (新增 $($after-$before))"

Say "--- 重扫 backlog(现成的图片里还有哪些没转) ---"
py -3.13 tools/scan_backlog.py *>> $log
Say "scan 退出码 $LASTEXITCODE"

Say "--- 转写 ---"
py -3.13 tools/transcribe_source.py train-work/backlog_pure.txt *>> $log
Say "转写退出码 $LASTEXITCODE"

Say "--- 收尾重建 ---"
py -3.13 tools/finalize.py *>> $log
Say "finalize 退出码 $LASTEXITCODE"

Say "--- 重跑检索评测 ---"
py -3.13 tools/melody_retrieval_eval.py --sweep *>> $log
Copy-Item train-work\retrieval_eval.tsv train-work\retrieval_eval_rand.tsv -Force
py -3.13 tools/melody_retrieval_eval.py --sweep --errmode neighbor *>> $log
Copy-Item train-work\retrieval_eval.tsv train-work\retrieval_eval_neighbor.tsv -Force
Say "评测退出码 $LASTEXITCODE"

Say "--- 抽检 + 刷新交付物 ---"
py -3.13 tools/qa_corpus.py *>> $log
py -3.13 tools/qa_sample.py 40 *>> $log
py -3.13 tools/flag_odd_names.py --apply *>> $log
py -3.13 tools/source_map.py *>> $log
py -3.13 tools/source_map_html.py *>> $log
py -3.13 tools/verify_deliverable.py *>> $log
Say "verify 退出码 $LASTEXITCODE"
py -3.13 tools/delivery_report.py *>> $log
Say "report 退出码 $LASTEXITCODE"

Say "================ 第二轮扩库 结束 ================"
