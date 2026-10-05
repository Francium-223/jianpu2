<#
.SYNOPSIS
    qupu123 / jianpu.cn **剩余存量**的分轮抓取器 + 看门狗(带硬止损)。

.DESCRIPTION
    ⚠ 2026-10-06 实测结论: 本机只有**一块物理盘**(C: 350GiB + D: 602.6GiB 同一块 NVMe),
      D: 空闲 41.38 GiB、C: 10.54 GiB, 且盘上同跑一条转写流水线。两站剩余存量合计要
      126~222 GiB —— 止损后(留 25 GiB)可支配的 16.38 GiB **连一个站的零头都不够**。
      所以本脚本**默认不抓**(-WhatIf) —— 先把空间腾出来再谈。

    本脚本做三件事:
      ① 每一轮开始前用 tools/crawl_disk_guard.py 查空闲空间, 低于 JIANPU_MIN_FREE_GIB
         (默认 25 GiB)就**拒绝启动**并写日志;
      ② 一轮跑完后**再查一次**, 低于止损线立即收工(不等下一轮);
      ③ 全部输出带时间戳落到日志, 状态文件交给爬虫自己维护(断点续爬)。

    断点续爬的两份状态:
      * qupu123  : train-work/qupu123_sweep_state.tsv   (页号; 爬虫自己写)
      * jianpu.cn: D:\Documents_D\_analysis\crawl_state_jianpucn.json (队列 + 已访问; 爬虫自己写)

.PARAMETER Site
    qupu123 | jianpucn | both (默认 both)

.PARAMETER Round
    每轮推进多少首(传给爬虫)。默认 qupu123 400 / jianpucn 400。

.PARAMETER Rounds
    本次跑几轮。默认 1(单轮, 方便人工看结果)。看门狗模式用 -Watch -Rounds 0(无限)。

.PARAMETER Watch
    看门狗模式: 每 -IntervalMin 分钟检查一次"进程在不在", 不在就补一轮。

.PARAMETER WhatIf
    只做磁盘检查 + 打印将要执行的命令, **不真的抓**。默认**开启**(要先腾空间)。

.EXAMPLE
    # 只体检, 不抓(默认)
    pwsh -File tools/crawl_stock_round.ps1
    # 真的抓一轮 jianpu.cn(空间够才会启动)
    pwsh -File tools/crawl_stock_round.ps1 -Site jianpucn -NoWhatIf
    # 注册看门狗(每 30 分钟) —— 必须先腾空间再注册!
    schtasks /Create /TN "jianpu2-crawl-stock" /SC MINUTE /MO 30 ^
      /TR "pwsh -NoProfile -File D:\Documents_D\jianpu2\tools\crawl_stock_round.ps1 -Site jianpucn -Watch -Rounds 0 -NoWhatIf" ^
      /F
#>
[CmdletBinding()]
param(
    [ValidateSet('qupu123', 'jianpucn', 'both')]
    [string]$Site = 'both',
    [int]$Round = 400,
    [int]$Rounds = 1,
    [int]$IntervalMin = 30,
    [switch]$Watch,
    [switch]$NoWhatIf
)

$ErrorActionPreference = 'Continue'
$Root = 'D:\Documents_D\jianpu2'
$Analysis = 'D:\Documents_D\_analysis'
$LogDir = Join-Path $Analysis 'crawl_stock'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Log = Join-Path $LogDir ('crawl_stock_{0:yyyyMMdd}.log' -f (Get-Date))

function Say([string]$m) {
    $line = '[{0:yyyy-MM-dd HH:mm:ss}] {1}' -f (Get-Date), $m
    Write-Host $line
    Add-Content -Path $Log -Value $line -Encoding UTF8
}

# ── 磁盘闸门: 不够就直接退出(退出码 3) ───────────────────────────────────────
function Test-Disk {
    $out = & python (Join-Path $Root 'tools\crawl_disk_guard.py') 2>&1
    $out | ForEach-Object { Say "  $_" }
    return ($LASTEXITCODE -eq 0)
}

function Invoke-Round([string]$which) {
    if ($which -eq 'qupu123') {
        $args = @((Join-Path $Root 'tools\crawl_qupu123_sweep.py'), "$Round")
    }
    else {
        $args = @((Join-Path $Root 'tools\crawl_jianpucn.py'), "$Round", '--max-artists', '400')
    }
    $cmdline = "python " + ($args -join ' ')
    Say "  >> $cmdline"
    Push-Location $Root
    try {
        # 分离进程 + 追加日志; 状态由爬虫自己落盘, 支持断点续爬
        $p = Start-Process -FilePath 'python' -ArgumentList $args -WorkingDirectory $Root `
            -RedirectStandardOutput (Join-Path $LogDir "out_$which.log") `
            -RedirectStandardError (Join-Path $LogDir "err_$which.log") `
            -NoNewWindow -PassThru
        Say "     进程 PID $($p.Id) 已启动"
        $p.WaitForExit()
        Say "     PID $($p.Id) 退出码 $($p.ExitCode)"
    }
    finally { Pop-Location }
}

Say "=== 抓取轮次开始 site=$Site round=$Round rounds=$Rounds watch=$Watch whatif=$(-not $NoWhatIf) ==="
Say "日志: $Log"

if (-not (Test-Disk)) {
    Say "!! 磁盘低于止损线, 拒绝启动(退出码 3)。先腾空间再跑。"
    exit 3
}

$sites = if ($Site -eq 'both') { @('jianpucn', 'qupu123') } else { @($Site) }
Say "顺序: $($sites -join ' -> ')  (jianpu.cn 在前: 空间效率 5,969 首/GiB 对 1,353 首/GiB)"

$n = 0
while ($true) {
    $n++
    foreach ($s in $sites) {
        if (-not (Test-Disk)) { Say "!! 低于止损线, 立即收工"; exit 3 }
        if ($NoWhatIf) { Invoke-Round $s }
        else { Say "  (WhatIf) 将要执行: python tools\crawl_$s*.py $Round —— 未真的抓" }
        if (-not (Test-Disk)) { Say "!! 本轮后低于止损线, 立即收工"; exit 3 }
    }
    if (-not $Watch) { if ($n -ge $Rounds) { break } }
    Say "轮次 $n 结束, 等 $IntervalMin 分钟"
    Start-Sleep -Seconds ($IntervalMin * 60)
}
Say "=== 全部结束 ==="
