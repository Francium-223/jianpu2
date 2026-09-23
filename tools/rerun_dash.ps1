# -*- coding: utf-8 -*-
# 定向重跑: 只重跑"阈值 12->8 会新增延音杠"的谱, 然后 finalize -> stats -> verify。
#
# 为什么不定向 = 不整库重跑: 实测**模型输出不确定**(同输入同代码, 8 个谱里 4 个 token 数变了,
# 其中 3 个是"无新增 dash 候选"的页) —— 整库重跑会让几乎每页随机抖动 0.3%-5% ✗,
# 而收益只有"多出的延音杠"。所以只重跑**代码路径确实会变**的那批(见 tools/check_dash_equiv.py)。
#
# 用法: 作为**游离进程**启动, 免得会话结束把它带走:
#   Start-Process pwsh -ArgumentList '-NoProfile','-File','tools\rerun_dash.ps1' -WindowStyle Hidden
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\rerun_dash.log"
$env:JP_DASHMINW = "8"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 定向重跑开始 ================"
Say "名单: train-work\dash_affected.txt"
if (-not (Test-Path "train-work\dash_affected.txt")) { Say "名单不存在, 退出"; exit 1 }
Say ("名单条数: " + (Get-Content "train-work\dash_affected.txt").Count)

Say "--- 1) 准备(备份+移走旧转写) ---"
py -3.13 tools/prep_redash.py *>> $log
Say "prep 退出码 $LASTEXITCODE"

Say "--- 2) 重跑转写 ---"
py -3.13 tools/transcribe_source.py train-work/dash_affected.txt *>> $log
Say "转写退出码 $LASTEXITCODE"

foreach ($step in @("finalize", "stats", "verify")) {
    Say "--- 3) $step ---"
    py -3.13 run.py $step *>> $log
    Say "$step 退出码 $LASTEXITCODE"
}

Say "--- 4) GT 与 spring 复核(确认没退化) ---"
py -3.13 tools/eval_gt_images.py *>> $log
py -3.13 tools/show_spring.py *>> $log

Say "结果摘要(另存, **不再回写日志**):"
# 原先是 `Get-Content $log -Tail 40 | ForEach-Object { Say "    $_" }` —— 会把日志尾巴
# 再写回日志, 自我复制指数膨胀(实测生成过 3.6 GB 的日志 ✗)。改成写独立文件。
$sum = "train-work\rerun_dash_摘要.txt"
Get-Content $log | Where-Object { $_.Length -lt 300 } |
    Select-Object -Last 60 | Set-Content $sum -Encoding utf8
Say "摘要 -> $sum"
Say "================ 定向重跑结束(**不响铃**) ================"
