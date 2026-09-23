# -*- coding: utf-8 -*-
# 续跑定向重跑(**不含 prep**) —— prep 在第一次跑时已经把 1887 个旧转写移走了,
# 且 transcribe_source 见到 txt 存在就跳过, 所以直接跑就会从断点续上。
#
# 关键: 用**计划任务**启动本脚本(见 tools/start_resume_dash.ps1)。
# 会话里的 Start-Process 子进程仍在 harness 的 Windows job 对象内, 用户退出会话时
# 会被一起杀掉(2026-09-20 实测: 跑到 360/1899 就没了 ✗); 计划任务跑在 job 之外 ✓。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\rerun_dash.log"          # 追加到同一个日志, 进度连续
$env:JP_DASHMINW = "8"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 续跑开始(计划任务, 无 prep) ================"
$total = if (Test-Path "train-work\dash_affected.txt") { (Get-Content "train-work\dash_affected.txt").Count } else { 0 }
Say "名单 $total 个; 已有 txt 的会被自动跳过(断点续跑)"

Say "--- 1) 重跑转写 ---"
py -3.13 tools/transcribe_source.py train-work/dash_affected.txt *>> $log
Say "转写退出码 $LASTEXITCODE"

foreach ($step in @("finalize", "stats", "verify")) {
    Say "--- 2) $step ---"
    py -3.13 run.py $step *>> $log
    Say "$step 退出码 $LASTEXITCODE"
}

Say "--- 3) GT 与 spring 复核 ---"
py -3.13 tools/eval_gt_images.py *>> $log
py -3.13 tools/show_spring.py *>> $log

Say "结果摘要(另存, **不再回写日志**):"
# 注意: 原先是 `Get-Content $log -Tail 40 | ForEach-Object { Say "    $_" }`,
# 那会把日志的尾巴**再写回日志** -> 自我复制指数膨胀, 实测生成过 3.6 GB 的日志 ✗。
# 改成写到独立文件(并只取短行, 避开超长行)。
$sum = "train-work\rerun_dash_摘要.txt"
Get-Content $log | Where-Object { $_.Length -lt 300 } |
    Select-Object -Last 60 | Set-Content $sum -Encoding utf8
Say "摘要 -> $sum"
Say "================ 定向重跑结束(**不响铃**) ================"

