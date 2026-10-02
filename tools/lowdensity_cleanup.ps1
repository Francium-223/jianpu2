# -*- coding: utf-8 -*-
# 低密度碎片守卫的**收尾脚本**（照 tools/lowdigits_cleanup.ps1 的样子写）。
#
# 干什么: 等流水线空闲 -> 跑低密度守卫(dry-run 先看一眼) -> --apply 移出语料(只移不删)
#         -> finalize 重建语料 -> 评测重跑 -> 抽检 + 刷新交付物。
# 依据: 见 tools/quarantine_lowdensity.py 顶部（133 份可疑 = 1.2%；判据「每页 <15 音 且 页数 ≥2」命中 115 份 = 1.00%）。
#
# ⚠ 这个脚本**没有被注册成计划任务**，也不会自己跑。要开就手工:
#       pwsh -NoProfile -File D:\Documents_D\jianpu2\tools\lowdensity_cleanup.ps1
#   不开 = 语料一个字节都不动。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\lowdensity_cleanup.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 低密度碎片守卫 等待开始 ================"

# 等空闲: 重建 / 转写 / 吸收链都不在跑（低密度守卫要动的就是语料文件，撞上重建会两边都乱）
$waited = 0
while ($waited -lt 480) {
    $busy = @(Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
              Where-Object { $_.CommandLine -match 'transcribe_source|batch_transcribe|jp_transcribe|to_jianpu_db|finalize|melody_retrieval|dedupe_by_content|source_map' }).Count
    if ($busy -eq 0) { Say "流水线空闲, 开始"; break }
    Say "  流水线还在跑($busy 个进程), 等 60 秒"
    Start-Sleep -Seconds 60
    $waited += 1
}
if ($waited -ge 480) { Say "等待超时(8 小时), 仍开始" }

Say "--- 1) dry-run 先看命中清单 ---"
py -3.13 tools/quarantine_lowdensity.py 2>&1 | Tee-Object -FilePath $log -Append

Say "--- 2) 真移（只移不删, 清单在 ../jianpu-db/scores-lowdensity/manifest.tsv）---"
py -3.13 tools/quarantine_lowdensity.py --apply *>> $log
Say "quarantine 退出码 $LASTEXITCODE"
if ($LASTEXITCODE -ne 0) { Say "守卫失败, 停下不动语料"; exit 1 }

Say "--- 3) 重建语料 ---"
py -3.13 tools/finalize.py *>> $log
Say "finalize 退出码 $LASTEXITCODE"

Say "--- 4) 评测重跑（与 lowdigits_cleanup 同一套）---"
py -3.13 tools/melody_retrieval_eval.py --sweep *>> $log
Copy-Item train-work\retrieval_eval.tsv train-work\retrieval_eval_rand.tsv -Force
py -3.13 tools/melody_retrieval_eval.py --sweep --errmode neighbor *>> $log
Copy-Item train-work\retrieval_eval.tsv train-work\retrieval_eval_neighbor.tsv -Force
py -3.13 tools/melody_retrieval_holdout.py --len 11 --err 0 --n 2 --multi 1 *>> $log
py -3.13 tools/melody_retrieval_holdout.py --len 15 --err 0 --n 2 --multi 5 *>> $log
Say "评测退出码 $LASTEXITCODE"

Say "--- 5) 抽检 + 刷新交付物 ---"
py -3.13 tools/qa_corpus.py *>> $log
py -3.13 tools/source_map.py *>> $log
py -3.13 tools/verify_deliverable.py *>> $log
Say "verify 退出码 $LASTEXITCODE"

Say "================ 低密度碎片守卫 结束 ================"
Say "（要回退: py -3.13 tools/quarantine_lowdensity.py --restore，然后重跑 finalize）"
