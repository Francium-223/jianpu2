# -*- coding: utf-8 -*-
# 吸收链的**后验清理**: 等 jp_purity_absorb 跑完 -> 把吸收批里"数字占比 <50%"的混排页移出
# (只移不删) -> 收尾重建 -> 全部评测重跑 -> 刷新交付物。
# 依据: 吸收批数字占比中位 77.3%(原有 78.7%) 但 <50% 的占 4.0%(原有 1.5%) —— 有一小撮混排页。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\lowdigits_cleanup.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 吸收批后验清理 等待开始 ================"
$waited = 0
while ($waited -lt 480) {
    $busy = @(Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
              Where-Object { $_.CommandLine -match 'transcribe_source|finalize|melody_retrieval|to_jianpu_db|dedupe_by_content|source_map' }).Count
    $done = (Select-String -Path "train-work\purity_absorb.log" -Pattern '吸收完成' -Quiet -ErrorAction SilentlyContinue)
    if ($busy -eq 0 -and $done) { Say "吸收链已结束, 开始后验清理"; break }
    Say "  吸收链还在跑(python $busy, 结束标记 $done), 等 60 秒"
    Start-Sleep -Seconds 60
    $waited += 1
}
if ($waited -ge 480) { Say "等待超时(8 小时), 仍开始" }

Say "--- 1) 移出数字占比过低的混排页(只移不删) ---"
py -3.13 tools/quarantine_lowdigits.py 2>&1 | Tee-Object -FilePath $log -Append
py -3.13 tools/quarantine_lowdigits.py --apply *>> $log
Say "退出码 $LASTEXITCODE"
py -3.13 tools/compare_batch_quality.py *>> $log

Say "--- 2) 收尾重建 ---"
py -3.13 tools/finalize.py *>> $log
Say "finalize 退出码 $LASTEXITCODE"

Say "--- 3) 全部评测重跑 ---"
py -3.13 tools/melody_retrieval_eval.py --sweep *>> $log
Copy-Item train-work\retrieval_eval.tsv train-work\retrieval_eval_rand.tsv -Force
py -3.13 tools/melody_retrieval_eval.py --sweep --errmode neighbor *>> $log
Copy-Item train-work\retrieval_eval.tsv train-work\retrieval_eval_neighbor.tsv -Force
Remove-Item train-work\retrieval_holdout.tsv,train-work\retrieval_indel.tsv -Force -ErrorAction SilentlyContinue
py -3.13 tools/melody_retrieval_holdout.py --len 11 --err 0 --n 2 --multi 1 *>> $log
py -3.13 tools/melody_retrieval_holdout.py --len 11 --err 0 --n 2 --multi 5 *>> $log
py -3.13 tools/melody_retrieval_holdout.py --len 15 --err 0 --n 2 --multi 5 *>> $log
py -3.13 tools/melody_retrieval_indel.py --len 13 --sub 1 --err 0 --n 1 *>> $log
Say "评测退出码 $LASTEXITCODE"

Say "--- 4) 抽检 + 刷新交付物 ---"
py -3.13 tools/qa_corpus.py *>> $log
py -3.13 tools/qa_sample.py 40 *>> $log
py -3.13 tools/flag_odd_names.py --apply *>> $log
py -3.13 tools/source_map.py *>> $log
py -3.13 tools/source_map_html.py *>> $log
py -3.13 tools/verify_deliverable.py *>> $log
Say "verify 退出码 $LASTEXITCODE"
py -3.13 tools/delivery_report.py *>> $log
Say "report 退出码 $LASTEXITCODE"
py -3.13 tools/expand_yield.py train-work/purity_absorb.log *>> $log

Say "================ 吸收批后验清理 结束 ================"
