# 看门狗: 守着整夜的转写流程。
#
# 为什么需要: transcribe_priority.py 是一条长链(逐个源转写 -> 收尾 -> 统计 -> 验收),
# 中途任何一个环节抛异常它就整体退出了, 剩下几个小时就白等。
# 本脚本每 10 分钟检查一次: 如果转写进程不在了就重新拉起(它幂等, 已转的会跳过)。
# 看到日志里的 "=== 完成 ===" 就收工, 然后补跑 GT 对比(需要 GPU, 必须在转写结束后)。
#
# 日志: train-work/watchdog.log

$ROOT = 'D:\Documents_D\jianpu2'
$LOG  = Join-Path $ROOT 'train-work\transcribe_priority.log'
$WD   = Join-Path $ROOT 'train-work\watchdog.log'
$GT   = Join-Path $ROOT 'train-work\overnight_gt.log'

function Write-Wd($msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg" | Add-Content -Path $WD -Encoding UTF8
}

Write-Wd "看门狗启动"

while ($true) {
    Start-Sleep -Seconds 600

    $tail = Get-Content $LOG -Tail 8 -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($tail -match '=== 完成 ===') {
        Write-Wd "转写流程已完成, 开始跑 GT 对比"
        Push-Location $ROOT
        "===== eval_gt_images =====" | Out-File $GT -Encoding UTF8
        & py -3.13 tools/eval_gt_images.py  *>> $GT
        "===== spring 锚点 ====="     | Out-File $GT -Append -Encoding UTF8
        & py -3.13 tools/show_spring.py     *>> $GT
        Pop-Location
        Write-Wd "GT 对比完成, 看门狗退出"
        break
    }

    $alive = Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -match 'transcribe_priority|transcribe_source|finalize\.py' }
    if (-not $alive) {
        Write-Wd "转写进程不在了 -> 重新拉起(幂等, 已转的会跳过)"
        Start-Process -FilePath 'py' `
            -ArgumentList '-3.13', 'tools/transcribe_priority.py' `
            -WorkingDirectory $ROOT -WindowStyle Hidden
    }
}
