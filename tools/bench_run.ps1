# -*- coding: utf-8 -*-
# 基准集(华流金曲100)收尾链: 等 GPU 空 -> 补转 9 首缺的谱 -> 收尾(纯度/择优/重建DB) -> 检索评测。
# 等待条件用**进程**判断(不用日志 sentinel, 之前白等过一小时)。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\bench_run.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 基准集收尾链 等待开始 ================"

$waited = 0
while ($waited -lt 180) {          # 最多等 90 分钟
    $busy = @(Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
              Where-Object { $_.CommandLine -match 'refine_titles_llm|to_jianpu_db|run\.py|finalize' }).Count
    if ($busy -eq 0) { Say "GPU 空闲, 开始补转基准集缺的谱"; break }
    Say "  还有 $busy 个 python 在跑(占 GPU), 等 30 秒"
    Start-Sleep -Seconds 30
    $waited += 0.5
}
if ($waited -ge 180) { Say "等待超时(90 分钟), 仍开始"; }

Say "--- 1) 补转 train-work/bench_todo.txt ---"
py -3.13 tools/transcribe_source.py train-work/bench_todo.txt *>> $log
Say "补转退出码 $LASTEXITCODE"

Say "--- 2) 收尾(重扫纯度 -> 过滤 -> 择优 -> 重建 DB) ---"
py -3.13 tools/finalize.py *>> $log
Say "finalize 退出码 $LASTEXITCODE"

Say "--- 3) 复查基准集覆盖 ---"
py -3.13 tools/bench_pick.py 3 *>> $log

Say "--- 4) 旋律片段检索评测(扫描表) ---"
py -3.13 tools/melody_retrieval_eval.py --sweep *>> $log
Say "评测退出码 $LASTEXITCODE"

Say "================ 基准集收尾链 结束 ================"
