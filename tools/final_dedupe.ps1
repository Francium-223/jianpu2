# -*- coding: utf-8 -*-
# 收尾链: 等"按歌手扩库"跑完 -> 内容级去重(新转的谱也会带新重复) -> 收尾重建 -> 全部评测重跑 -> 刷新交付物。
# 为什么单开一条: 交付快照必须是**去重之后**的; 而且扩库改变了语料规模, 所有指标都要跟着刷新。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\final_dedupe.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 收尾(去重+全量重测) 等待开始 ================"

$waited = 0
while ($waited -lt 480) {          # 最多等 8 小时
    $busy = @(Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
              Where-Object { $_.CommandLine -match 'transcribe_source|finalize|crawl_artist|melody_retrieval|to_jianpu_db|source_map' }).Count
    $done = (Select-String -Path "train-work\artist_expand.log" -Pattern '第二轮扩库 结束' -Quiet -ErrorAction SilentlyContinue)
    if ($busy -eq 0 -and $done) { Say "扩库链已结束, 开始收尾"; break }
    Say "  扩库链还在跑(python $busy, 结束标记 $done), 等 60 秒"
    Start-Sleep -Seconds 60
    $waited += 1
}
if ($waited -ge 480) { Say "等待超时(8 小时), 仍开始" }

Say "--- 1) 内容级去重(只移不删) ---"
py -3.13 tools/dedupe_by_content.py --apply *>> $log
Say "去重退出码 $LASTEXITCODE"
py -3.13 tools/audit_dupes.py *>> $log

Say "--- 2) 收尾重建(纯度扫描 -> 过滤 -> 择优 -> 重建 scores -> 下游 JSONL) ---"
py -3.13 tools/finalize.py *>> $log
Say "finalize 退出码 $LASTEXITCODE"

Say "--- 3) 检索评测(自匹配: 随机错音 / 相邻音级) ---"
py -3.13 tools/melody_retrieval_eval.py --sweep *>> $log
Copy-Item train-work\retrieval_eval.tsv train-work\retrieval_eval_rand.tsv -Force
py -3.13 tools/melody_retrieval_eval.py --sweep --errmode neighbor *>> $log
Copy-Item train-work\retrieval_eval.tsv train-work\retrieval_eval_neighbor.tsv -Force
Say "评测退出码 $LASTEXITCODE"

Say "--- 4) 留一版本(凭记忆哼唱)+ 漏多唱 ---"
Remove-Item train-work\retrieval_holdout.tsv,train-work\retrieval_indel.tsv -Force -ErrorAction SilentlyContinue
py -3.13 tools/melody_retrieval_holdout.py --len 11 --err 0 --n 2 --multi 1 *>> $log
py -3.13 tools/melody_retrieval_holdout.py --len 11 --err 0 --n 2 --multi 3 *>> $log
py -3.13 tools/melody_retrieval_holdout.py --len 11 --err 0 --n 2 --multi 5 *>> $log
py -3.13 tools/melody_retrieval_holdout.py --len 15 --err 0 --n 2 --multi 5 *>> $log
py -3.13 tools/melody_retrieval_indel.py --len 13 --sub 1 --err 0 --n 1 *>> $log
Say "留一版本/漏多唱 退出码 $LASTEXITCODE"

Say "--- 5) 抽检 + 刷新交付物 ---"
py -3.13 tools/qa_corpus.py *>> $log
py -3.13 tools/qa_sample.py 40 *>> $log
py -3.13 tools/flag_odd_names.py --apply *>> $log
py -3.13 tools/source_map.py *>> $log
py -3.13 tools/source_map_html.py *>> $log
py -3.13 tools/verify_deliverable.py *>> $log
Say "verify 退出码 $LASTEXITCODE"
py -3.13 tools/delivery_report.py *>> $log
Say "report 退出码 $LASTEXITCODE"

Say "================ 收尾(去重+全量重测) 结束 ================"
