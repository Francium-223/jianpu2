# -*- coding: utf-8 -*-
# 吸收"被旧纯度判据误杀"的 667 个谱（试点已证明质量不比现有语料差: x 率 2.69% vs 2.98%, 0 率 4.95% vs 7.25%）。
#
# 关键: **整条链都要带 JP_PURITY2=1** —— 转写时 is_impure 用新判据才不会当场再拒一遍;
#       finalize 里的纯度重扫（kind_detect2）也要用新判据, 否则刚吸收的又会被移进 batch-out-bad。
# 可逆性: 名单就在 train-work/purity2_admit.txt, 后悔了把这批 move 回 batch-out-bad 即可（只移不删）。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$env:JP_PURITY2 = "1"
$log = "train-work\purity_absorb.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 吸收'新判据放行'的谱 开始 (JP_PURITY2=1) ================"
Say "名单 $((Get-Content train-work\purity2_admit.txt | Where-Object {$_ -match '\S'}).Count) 个"
$before = (Get-ChildItem "batch-out\*.txt" | Measure-Object).Count
Say "吸收前 batch-out $before"

Say "--- 1) 转写这批(用新纯度判据, 否则会被当场拒) ---"
py -3.13 tools/transcribe_source.py train-work/purity2_admit.txt *>> $log
Say "转写退出码 $LASTEXITCODE"

Say "--- 2) 收尾重建(新判据重扫纯度) ---"
py -3.13 tools/finalize.py *>> $log
Say "finalize 退出码 $LASTEXITCODE"
$after = (Get-ChildItem "batch-out\*.txt" | Measure-Object).Count
Say "吸收后 batch-out $after (新增 $($after-$before))"

Say "--- 3) 内容级去重(新谱也会带重复) ---"
py -3.13 tools/dedupe_by_content.py --apply *>> $log
py -3.13 tools/audit_dupes.py *>> $log

Say "--- 4) 全部评测重跑 ---"
py -3.13 tools/melody_retrieval_eval.py --sweep *>> $log
Copy-Item train-work\retrieval_eval.tsv train-work\retrieval_eval_rand.tsv -Force
py -3.13 tools/melody_retrieval_eval.py --sweep --errmode neighbor *>> $log
Copy-Item train-work\retrieval_eval.tsv train-work\retrieval_eval_neighbor.tsv -Force
Remove-Item train-work\retrieval_holdout.tsv,train-work\retrieval_indel.tsv -Force -ErrorAction SilentlyContinue
py -3.13 tools/melody_retrieval_holdout.py --len 11 --err 0 --n 2 --multi 1 *>> $log
py -3.13 tools/melody_retrieval_holdout.py --len 11 --err 0 --n 2 --multi 5 *>> $log
py -3.13 tools/melody_retrieval_holdout.py --len 15 --err 0 --n 2 --multi 5 *>> $log
py -3.13 tools/melody_retrieval_indel.py --len 13 --sub 1 --err 0 --n 1 *>> $log
py -3.13 tools/melody_retrieval_contour.py --len 11 --n 2 --multi 1 *>> $log
py -3.13 tools/expand_yield.py train-work/purity_absorb.log *>> $log
Say "评测退出码 $LASTEXITCODE"

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

Say "================ 吸收完成 ================"
