# -*- coding: utf-8 -*-
# 收尾: 等"存量+港乐那轮转写"和"西方爬虫"都结束之后, 再扫一次、把新抓到的补转一遍,
# 最后跑 finalize -> stats -> verify, 让语料落到稳定状态。
# 为什么单独一个任务: 转写和爬虫用不同资源(GPU / 网络), 但**两轮转写不能重叠**(单卡),
# 而且爬虫结尾自己会跑 scan_backlog 重写 backlog_pure.txt —— 得等它写完再读。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\finish_backlog.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

function WaitFor([string]$file, [string]$pattern, [int]$maxMin, [string]$what) {
    $t0 = Get-Date
    while (((Get-Date) - $t0).TotalMinutes -lt $maxMin) {
        if (Test-Path $file) {
            # 看最后 5 行 —— sentinel 不一定在最后一行(脚本结尾常有别的提示行)
            $tail = (Get-Content $file -Tail 5 -Encoding UTF8) -join "`n"
            if ($tail -match $pattern) { Say "$what 已完成"; return $true }
        }
        Start-Sleep -Seconds 60
    }
    Say "$what 等待超时($maxMin 分钟), 继续下一步"
    return $false
}

Say "================ 收尾任务开始 ================"
WaitFor "train-work\transcribe_backlog.log" "扩张转写\(backlog\) 结束" 600 "存量+港乐转写" | Out-Null
WaitFor "train-work\expand_west.log" "西方扩张结束" 240 "港乐+西方爬虫" | Out-Null
Start-Sleep -Seconds 180   # 等爬虫最后一次 scan_backlog 落盘

Say "--- 1) 重扫 backlog ---"
py -3.13 tools/scan_backlog.py *>> $log
Say "scan 退出码 $LASTEXITCODE"

Say "--- 2) 补转新抓到的 ---"
py -3.13 tools/transcribe_source.py train-work/backlog_pure.txt *>> $log
Say "转写退出码 $LASTEXITCODE"

foreach ($step in @("finalize", "stats", "verify")) {
    Say "--- 3) $step ---"
    py -3.13 run.py $step *>> $log
    Say "$step 退出码 $LASTEXITCODE"
}

Say "--- 4) 最终再扫一次 ---"
py -3.13 tools/scan_backlog.py *>> $log
Say "scan 退出码 $LASTEXITCODE"
Say "================ 收尾任务结束 ================"
