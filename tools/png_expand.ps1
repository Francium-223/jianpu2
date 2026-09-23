# -*- coding: utf-8 -*-
# 最后一条链: 等前面所有链(含 GT 复评/演示图)结束, 再补转"只有 png、从没转过"的 848 个谱,
# 然后收尾重建 -> 重跑检索评测 -> 刷新交付物。
#
# 为什么单开一条: 848 个目录要跑 1-2 小时, 不能和基准链/夜间扩库链抢 GPU;
# 而交付物(scores/source_map/DELIVERY.md)必须在**所有转写都结束之后**再生成一次,
# 不然用户看到的交付快照和语料不一致。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\png_expand.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ PNG 补转链 等待开始 ================"

$waited = 0
while ($waited -lt 600) {          # 最多等 10 小时
    $busy = @(Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
              Where-Object { $_.CommandLine -match 'finalize|transcribe_source|crawl_qupu123|melody_retrieval|to_jianpu_db|gt_transcribe|source_map|zoom_phrase|melody_query' }).Count
    $demo_done = (Select-String -Path "train-work\demo.log" -Pattern '检索演示图 结束' -Quiet -ErrorAction SilentlyContinue)
    if ($busy -eq 0 -and $demo_done) { Say "前面所有链已结束, 开始补转 PNG 谱"; break }
    Say "  还在跑(python $busy, 演示图结束标记 $demo_done), 等 60 秒"
    Start-Sleep -Seconds 60
    $waited += 1
}
if ($waited -ge 600) { Say "等待超时(10 小时), 仍开始" }

Say "--- 1) 列名单 ---"
py -3.13 tools/png_only_dirs.py *>> $log
$n = (Get-Content "train-work\png_only.txt" | Where-Object { $_ -match '\S' }).Count
Say "待补转 $n 个目录"

Say "--- 2) 补转(只认 png 的谱) ---"
py -3.13 tools/transcribe_source.py train-work/png_only.txt *>> $log
Say "转写退出码 $LASTEXITCODE"

Say "--- 3) 收尾重建 ---"
py -3.13 tools/finalize.py *>> $log
Say "finalize 退出码 $LASTEXITCODE"

Say "--- 4) 基准集覆盖 ---"
py -3.13 tools/bench_status.py *>> $log

Say "--- 5) 重跑检索评测(随机错音) ---"
py -3.13 tools/melody_retrieval_eval.py --sweep *>> $log
Say "退出码 $LASTEXITCODE"
Copy-Item train-work/retrieval_eval.tsv train-work/retrieval_eval_rand.tsv -Force
Say "--- 5b) 重跑检索评测(相邻音级错音, 更像真人) ---"
py -3.13 tools/melody_retrieval_eval.py --sweep --errmode neighbor *>> $log
Say "退出码 $LASTEXITCODE"
Copy-Item train-work/retrieval_eval.tsv train-work/retrieval_eval_neighbor.tsv -Force

Say "--- 6) 刷新交付物 ---"
py -3.13 tools/qa_corpus.py *>> $log
py -3.13 tools/flag_odd_names.py --apply *>> $log
py -3.13 tools/source_map.py *>> $log
py -3.13 tools/source_map_html.py *>> $log
py -3.13 tools/verify_deliverable.py *>> $log
Say "verify 退出码 $LASTEXITCODE"
py -3.13 tools/delivery_report.py *>> $log
Say "report 退出码 $LASTEXITCODE"

Say "================ PNG 补转链 结束 ================"
