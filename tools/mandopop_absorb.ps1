# -*- coding: utf-8 -*-
# 定向缺口(华语金曲)一次跑完: 转写 -> 入库 -> 覆盖率复测 -> 全部评测 -> 抽检 -> 交付校验。
# 可续跑: transcribe_source.py 跳过已有 txt; finalize 幂等。
# 用法: pwsh -File tools\mandopop_absorb.ps1
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$env:JP_PURITY2 = "1"
$log = "train-work\mandopop_absorb.log"
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

Say "================ 金曲缺口吸收 开始 ================"
Say "batch-out 前 $((Get-ChildItem 'batch-out\*.txt' | Measure-Object).Count) 个 txt"

# 0) 先补爬(幂等): 已爬过的歌在 train-work/mandopop_crawl.tsv 里有记录, 会跳过。
Step "0) 定向补爬(可续跑)"      { py -3.13 tools/crawl_missing_mandopop.py 4 999 }

Step "1) 定向转写(JP_PURITY2=1)" { pwsh -File tools\transcribe_mandopop.ps1 }
Say "batch-out 后 $((Get-ChildItem 'batch-out\*.txt' | Measure-Object).Count) 个 txt"

Step "2) 入库收尾(finalize)"   { py -3.13 tools/finalize.py }
Step "3) 覆盖率复测"           { py -3.13 tools/cover_mandopop.py }

Step "4) 检索评测"             {
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

Step "5) 抽检 + 交付物"        {
    py -3.13 tools/qa_corpus.py
    py -3.13 tools/qa_sample.py 40
    py -3.13 tools/flag_odd_names.py --apply
    py -3.13 tools/source_map.py
    py -3.13 tools/source_map_html.py
    py -3.13 tools/verify_deliverable.py
    py -3.13 tools/delivery_report.py
}
Say "================ 金曲缺口吸收 完成 ================"
