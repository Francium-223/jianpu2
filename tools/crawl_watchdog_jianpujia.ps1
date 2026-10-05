<#
.SYNOPSIS
    jianpujia(简谱之家)**按 id 分片**抓取的计划任务看门狗 —— 每 5 分钟唤起一次, 没在跑就补一轮。

.DESCRIPTION
    为什么要有它: jianpujia 的 id 空间 ≈45 万, 现在只抓了 1,390 个 (0.46%) —— 这是四站里**最大的
    存量**, 而 `tools/crawl_jianpujia.py` 只能一次吃一个 id 列表、没有分片/状态文件/磁盘止损。
    所以抓取部分交给 `tools/crawl_jianpujia_shard.py`, 本脚本只负责"让它一直活着":

      ① **互斥**: 同一分片只要已有 `crawl_jianpujia_shard.py ... --shard k` 在跑, 或上一个看门狗
         实例还握着锁, 就只打一行"跳过"并退出 0 —— 绝不起第二个同片 worker。
         (限速 >=1 秒/请求是按**进程**算的, 多起一个等于把站点限速毁掉, 两边还会抢同一个状态文件)
      ② **磁盘闸**: 跑 `tools/crawl_disk_guard.py` 里那**同一个** `check()`(止损线 25 GiB, 不重写、
         不许下调); 低于止损线就退出 3 —— 宁可空转一轮, 也绝不把盘写满拖死转写流水线。
      ③ **抓一轮**: `python -u tools/crawl_jianpujia_shard.py --shard k --shards N ... --quota Q`,
         输出逐行加时间戳**追加**进看门狗日志(不用 Start-Process 重定向 —— 那是覆盖写)。
      ④ **收工**: 记退出码 + 用时, 之后再查一次磁盘。

    **不要**给这条命令加 `-Watch`(那是脚本内无限循环, 会变孤儿); "每 5 分钟一次"由计划任务负责。

.PARAMETER Shard
    第几片(0-based)。第 k 片走 id ≡ k (mod Shards) 的那些 id —— 各片互不相交, 各写各的状态文件。

.PARAMETER Shards
    共几片。纪律: **单站并发 worker <=3**, 所以这个值默认且建议 <=3(提并行靠多 IP/多机器, 不靠加压)。

.PARAMETER Quota
    本片本轮最多新下几首。默认 150(实测约 3~5 分钟, 正好塞进 5 分钟的调度间隔)。

.EXAMPLE
    pwsh -NoProfile -File tools\crawl_watchdog_jianpujia.ps1 -Shard 0 -Shards 3 -Quota 150
    pwsh -NoProfile -File tools\crawl_watchdog_jianpujia.ps1 -Shard 1 -Status
#>
[CmdletBinding()]
param(
    [int]$Shard = 0,
    [int]$Shards = 3,
    [int]$Quota = 150,
    [int]$StartId = 7000,
    [int]$EndId = 450000,
    [int]$CheckSec = 60,
    [string]$LogDir = 'D:\Documents_D\_analysis\crawl_stock',
    [string]$Python = '',
    [switch]$Status
)

$ErrorActionPreference = 'Continue'
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
}
catch { }

$Root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $Root 'tools\crawl_jianpujia_shard.py'))) { $Root = 'D:\Documents_D\jianpu2' }
$ShardPy = Join-Path $Root 'tools\crawl_jianpujia_shard.py'
$Analysis = 'D:\Documents_D\_analysis'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Log = Join-Path $LogDir ('watchdog_jianpujia_s{0}_{1:yyyyMMdd}.log' -f $Shard, (Get-Date))
$Lock = Join-Path $LogDir ('watchdog_jianpujia_s{0}.lock' -f $Shard)

function Resolve-Python {
    if ($Python) { return $Python }
    $c = Get-Command python -ErrorAction SilentlyContinue
    if ($c -and $c.Source) { return $c.Source }
    foreach ($p in @(
            (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python313\python.exe'),
            (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python314\python.exe'),
            (Join-Path $env:LOCALAPPDATA 'Python\pythoncore-3.14-64\python.exe'))) {
        if (Test-Path $p) { return $p }
    }
    return 'python'
}
$Py = Resolve-Python

function Say([string]$m) {
    $line = '[{0:yyyy-MM-dd HH:mm:ss}] s{1} {2}' -f (Get-Date), $Shard, $m
    Write-Host $line
    Add-Content -Path $Log -Value $line -Encoding utf8
}

# 在跑的**同片** worker(排除自己)。判据: 命令行含 crawl_jianpujia_shard.py 且 `--shard <k>`。
function Get-ShardCrawler {
    Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='py.exe' OR Name='pwsh.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -and $_.ProcessId -ne $PID -and
            $_.CommandLine -match 'crawl_jianpujia_shard\.py' -and
            $_.CommandLine -match ('--shard\s+' + $Shard + '(\s|$)')
        }
}

if ($Status) {
    $c = Get-ShardCrawler
    if ($c) { $c | ForEach-Object { 'PID {0}  {1}' -f $_.ProcessId, $_.CommandLine } }
    else { "分片 $Shard 没有 jianpujia 抓取进程在跑" }
    if (Test-Path $Log) { '--- 日志尾巴 ---'; Get-Content $Log -Tail 12 }
    exit 0
}

Say "=== 看门狗唤起: PID $PID · 分片 $Shard/$Shards · Quota=$Quota · id $StartId..$EndId · python=$Py ==="

# ── 互斥(1/2): 同片已有 worker -> 跳过 ──────────────────────────────────────
$run = Get-ShardCrawler
if ($run) {
    foreach ($p in $run) { Say "跳过: 同片已有抓取在跑 PID $($p.ProcessId) —— $($p.CommandLine)" }
    exit 0
}

# ── 互斥(2/2): 上一个看门狗还没退(独占文件锁; 进程一死 OS 自动放锁) ──────────
try {
    $lock = [System.IO.File]::Open($Lock, [System.IO.FileMode]::OpenOrCreate,
        [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
}
catch {
    Say "跳过: 另一个看门狗实例还握着锁 $Lock"
    exit 0
}

$guardSnip = @"
import sys
sys.path.insert(0, r'$Root\tools')
from crawl_disk_guard import check
bad = []
for p in (r'$Root\images-prep', r'$Analysis'):
    ok, f, m = check(p)
    print('[disk-guard] %s -> %.2f GiB (%s)' % (p, f, m))
    if not ok:
        bad.append(p)
sys.exit(3 if bad else 0)
"@

function Test-Disk([string]$tag) {
    $out = & $Py -c $guardSnip 2>&1
    $script:diskCode = $LASTEXITCODE
    foreach ($l in $out) { Say "  $l" }
    if ($script:diskCode -ne 0) { Say "  磁盘闸[$tag]: **未过**(退出码 $script:diskCode)" }
    return ($script:diskCode -eq 0)
}

$code = 1
try {
    if (-not (Test-Disk '启动前')) {
        Say "!! 低于止损线, 拒绝抓取(退出码 3)。止损线 25 GiB 不许调低。"
        exit 3
    }

    $pyArgs = @('-u', $ShardPy, '--start', "$StartId", '--end', "$EndId",
        '--shard', "$Shard", '--shards', "$Shards", '--quota', "$Quota", '--tag', "s$Shard")
    Say "  >> $Py $($pyArgs -join ' ')   (工作目录 $Root; 轮中每 $CheckSec 秒查一次磁盘闸)"
    $t0 = Get-Date
    $lastCheck = Get-Date
    $diskStop = $false
    Push-Location $Root
    try {
        & $Py @pyArgs 2>&1 | ForEach-Object {
            Say "  | $_"
            # 轮中硬止损(与 crawl_watchdog_jianpucn.ps1 同形): 一轮可能跑几分钟到十几分钟,
            # 只在轮前/轮后查闸等于这段窗口无人看守 —— 盘写满会把转写流水线一起拖死。
            # ⚠ 不能用 `$pid`: 那是 PowerShell 的自动只读变量。
            if (((Get-Date) - $lastCheck).TotalSeconds -ge $CheckSec) {
                $lastCheck = Get-Date
                if (-not (Test-Disk '轮中')) {
                    $stopPid = $child.Id
                    if ($stopPid) { try { Stop-Process -Id $stopPid -Force -ErrorAction Stop } catch { } }
                    $diskStop = $true
                    Say "!! 轮中触发止损: 已强制结束分片 $Shard 抓取 PID $stopPid, 本轮不重启(退出码 3)"
                }
            }
        }
        $code = $LASTEXITCODE
    }
    finally { Pop-Location }
    $mins = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
    Say "  << 分片 $Shard 退出码 $code, 用时 $mins 分钟"
    if ($diskStop) { exit 3 }

    if (-not (Test-Disk '收工前')) {
        Say "!! 本轮后低于止损线, 立即收工(退出码 3)"
        exit 3
    }
    Say "=== 看门狗结束(退出码 $code) ==="
    exit $code
}
finally {
    if ($lock) { $lock.Dispose() }
}
