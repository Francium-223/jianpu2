<#
.SYNOPSIS
    jianpu.cn 抓取的**计划任务看门狗** —— 每 5 分钟被 Task Scheduler 唤起一次, "没在跑"就补一轮。

.DESCRIPTION
    为什么必须换成计划任务(2026-10-06 实测): 这条流水线原来是**会话内后台作业** ——
    `pwsh-1895` 拉起启动器、`pwsh-1915` 采样, **会话一被回收启动器就没了**, 只剩当时那轮 python
    跑完就停(实测 4:41 那轮跑完 400 首后, python 于 5:04:17 退出, 之后没有任何东西会再拉起来)。
    计划任务归 Task Scheduler 服务所有, 不随任何终端/会话回收 —— 这才是"能长期活着"的形态。

    每次唤起只做四件事, 全部幂等:
      ① **互斥**(两道): 已经有一个命令行含 `crawl_jianpucn.py` / `crawl_stock_round.ps1` 的进程在跑,
         或者上一个看门狗还没退(独占文件锁), 就只打一行"跳过"并退出 0 —— **绝不起第二个爬虫**;
         (限速 >=1 秒/请求是按**进程**算的, 起两个等于把站点限速毁掉, 两边还会抢同一个状态文件)
      ② **磁盘闸**: 跑 `tools/crawl_disk_guard.py` 里那**同一个** `check()`(止损线默认 25 GiB,
         本脚本不重新实现、更不许往下调); 过不去且 `tools/image_window.py` 已交付 -> 先调它腾空间,
         腾完**复查**, 仍不过就退出 3 —— 空间不够时宁可空转一轮, 也绝不把盘写满拖死转写流水线;
      ③ **抓一轮**: `python -u tools/crawl_jianpucn.py <Round> --max-artists <MaxArtists>`,
         逐行加时间戳**追加**进看门狗日志。**不用** `Start-Process -RedirectStandardOutput`:
         那个是覆盖写, 每跑一轮就把上一轮日志清空(原启动器 `Invoke-Round` 就是这个毛病), 出事无据可查;
      ④ **收工**: 记退出码 + 用时 + 本轮之后再查一次磁盘(低于止损线 -> 退出 3)。

    两个坑, 写在这里免得下次再踩:
      * 给这条命令**不要**加 `-Watch`。启动器里 `if (-not $Watch) { ... }` 的语义是"带 -Watch 就无限
        循环", 所以 `-Watch -Rounds 1` 不是"跑一轮"而是**永不退出**; "每 5 分钟一次"这件事由计划任务
        本身负责, 不需要脚本内再套一层 while。
      * 状态文件 `_analysis\crawl_state_jianpucn.json` 由爬虫自己维护(断点续爬), 看门狗不碰它。

.PARAMETER Round
    每轮推进多少首。默认 400(实测约 25 分钟/轮, 16.0 首/分钟)。

.PARAMETER MaxArtists
    传给爬虫的 `--max-artists`。默认 400。

.PARAMETER CheckSec
    **轮中**磁盘闸的间隔(秒)。一轮实测约 25 分钟, 只在轮前/轮后查闸 = 最多 25 分钟无人看守; 所以这里
    边读子进程输出边查闸, 每 CheckSec 秒(默认 60)跑一次同一个 `crawl_disk_guard.check()`, 不过就强杀
    本轮 python 并以 3 退出(本轮不重启, 下一轮由计划任务决定)。默认 60。

.PARAMETER ReclaimTargetGib
    低于止损线时, 让 `image_window.py` 把该卷空闲**删到**多少 GiB(默认 30 = 止损线 25 上面留 5 GiB
    余量), 只腾到刚好过线。`image_window.py` 自己的口径很保守(只删"已转写进语料"的图目录、最近 7 天
    与清单点名的绝不删、正在被进程读写的绝不删, 且**先写台账再删**), 所以这一步是安全的。

.PARAMETER NoReclaim
    低于止损线时**不**调 image_window.py 腾空间, 只记日志然后退出 3。人工核查回收口径时用。

.PARAMETER Status
    只看状态: 列出在跑的抓取进程 PID + 日志尾巴, 不加锁、不抓取、不改任何文件。人工排查用。

.EXAMPLE
    # 人工补一轮(前台, 看得见输出)
    pwsh -NoProfile -File tools\crawl_watchdog_jianpucn.ps1 -Round 400
    # 看现在到底在不在跑
    pwsh -NoProfile -File tools\crawl_watchdog_jianpucn.ps1 -Status
#>
[CmdletBinding()]
param(
    [int]$Round = 400,
    [int]$MaxArtists = 400,
    [int]$CheckSec = 60,
    [string]$LogDir = 'D:\Documents_D\_analysis\crawl_stock',
    [string]$Python = '',
    [double]$ReclaimTargetGib = 30.0,
    [switch]$NoReclaim,
    [switch]$Status
)

$ErrorActionPreference = 'Continue'
# 中文不许乱码: python 子进程按 UTF-8 吐字, 这里两处编码都对齐成 UTF-8(无 BOM)。
# 计划任务下控制台代码页未必是 65001, 不显式设就会出现"锟斤拷";
# 而"以最高权限/不登录也运行"的任务**没有控制台**, 设 OutputEncoding 会抛 IOException —— 所以包起来。
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
}
catch { }

$Root = Split-Path -Parent $PSScriptRoot                     # tools/ -> jianpu2
if (-not (Test-Path (Join-Path $Root 'tools\crawl_jianpucn.py'))) { $Root = 'D:\Documents_D\jianpu2' }
$CrawlPy = Join-Path $Root 'tools\crawl_jianpucn.py'
$WindowPy = Join-Path $Root 'tools\image_window.py'          # 另一路交付的"图片滑动窗口"(可能还没有)
$Analysis = 'D:\Documents_D\_analysis'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Log = Join-Path $LogDir ('watchdog_jianpucn_{0:yyyyMMdd}.log' -f (Get-Date))
$Lock = Join-Path $LogDir 'watchdog_jianpucn.lock'

# python 解释器: 参数 > PATH > 已知安装位置。计划任务的 PATH 与会话里未必一致, 所以解析结果每次写进日志。
function Resolve-Python {
    if ($Python) { return $Python }
    $c = Get-Command python -ErrorAction SilentlyContinue
    if ($c -and $c.Source) { return $c.Source }
    foreach ($p in @(
            (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python314\python.exe'),
            (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python313\python.exe'),
            (Join-Path $env:LOCALAPPDATA 'Python\pythoncore-3.14-64\python.exe'))) {
        if (Test-Path $p) { return $p }
    }
    return 'python'
}
$Py = Resolve-Python

function Say([string]$m) {
    $line = '[{0:yyyy-MM-dd HH:mm:ss}] {1}' -f (Get-Date), $m
    Write-Host $line
    Add-Content -Path $Log -Value $line -Encoding utf8
}

# 在跑的抓取进程(排除自己)。判据: 命令行里有 crawl_jianpucn.py 或 crawl_stock_round.ps1。
# 注意本脚本自己叫 crawl_watchdog_jianpucn.ps1, 与这两条正则都不匹配, 不会被自己挡住。
function Get-Crawler {
    Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pwsh.exe' OR Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -and $_.ProcessId -ne $PID -and
            $_.CommandLine -match 'crawl_jianpucn\.py|crawl_stock_round\.ps1'
        }
}

if ($Status) {
    $c = Get-Crawler
    if ($c) { $c | ForEach-Object { 'PID {0}  {1}' -f $_.ProcessId, $_.CommandLine } }
    else { '没有 jianpu.cn 抓取进程在跑' }
    if (Test-Path $Log) { '--- 日志尾巴 ---'; Get-Content $Log -Tail 10 }
    exit 0
}

Say "=== 看门狗唤起: 看门狗 PID $PID · Round=$Round · MaxArtists=$MaxArtists · python=$Py · 日志 $Log ==="

# ── 互斥(1/2): 已有爬虫/启动器在跑 -> 跳过, 不起第二个 ─────────────────────────
$run = Get-Crawler
if ($run) {
    foreach ($p in $run) { Say "跳过: 已有抓取在跑 PID $($p.ProcessId) —— $($p.CommandLine)" }
    exit 0
}

# ── 互斥(2/2): 上一个看门狗还没退(独占文件锁; 进程一死 OS 自动放锁) ─────────────
try {
    $lock = [System.IO.File]::Open($Lock, [System.IO.FileMode]::OpenOrCreate,
        [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
}
catch {
    Say "跳过: 另一个看门狗实例还握着锁 $Lock"
    exit 0
}

# 磁盘闸 = 直接调 crawl_disk_guard 里那**同一个** check(), 不在这里重写阈值。
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
    # ── ② 磁盘闸(过不去先腾空间) ────────────────────────────────────────────
    if (-not (Test-Disk '启动前')) {
        if ((Test-Path $WindowPy) -and (-not $NoReclaim)) {
            # image_window.py **默认干跑**, 必须显式 --no-dry-run 才真删; 目标只到 $ReclaimTargetGib(刚好过线)。
            Say "  低于止损线 -> 先调 tools/image_window.py 腾空间(--apply --target-free-gib $ReclaimTargetGib --no-dry-run)"
            $w = & $Py -u $WindowPy --apply --target-free-gib "$ReclaimTargetGib" --no-dry-run 2>&1
            $wc = $LASTEXITCODE
            foreach ($l in $w) { Say "  | $l" }
            Say "  image_window.py 退出码 $wc"
        }
        elseif ($NoReclaim) { Say "  -NoReclaim: 不腾空间, 只记日志" }
        else { Say "  tools/image_window.py 尚未交付 -> 只跑磁盘闸, 不腾空间" }
        if (-not (Test-Disk '腾空间后')) {
            Say "!! 仍低于止损线, 拒绝抓取(退出码 3)。止损线 25 GiB 不许调低。"
            exit 3
        }
    }

    # ── ③ 抓一轮(输出逐行加时间戳**追加**到本日志, 不覆盖) ──────────────────
    #    轮中硬止损(2026-10-06 加): 一轮实测约 25 分钟, 只在轮前/轮后查闸 = 最多 25 分钟无人看守,
    #    盘写满时会把同一条转写流水线一起拖死。所以在这里**边读子进程输出边查闸** —— 每 CheckSec
    #    秒(默认 60)跑一次 crawl_disk_guard.check(), 不过就 Stop-Process 子进程并以 3 退出。
    #    ⚠ 不能用 `$pid`: 那是 PowerShell 的**自动只读变量**(本进程 PID), 赋值会抛错。
    $pyArgs = @('-u', $CrawlPy, "$Round", '--max-artists', "$MaxArtists")
    Say "  >> $Py $($pyArgs -join ' ')   (工作目录 $Root; 轮中每 $CheckSec 秒查一次磁盘闸)"
    $t0 = Get-Date
    $lastCheck = Get-Date
    $diskStop = $false
    Push-Location $Root
    try {
        & $Py @pyArgs 2>&1 | ForEach-Object {
            Say "  | $_"
            if (((Get-Date) - $lastCheck).TotalSeconds -ge $CheckSec) {
                $lastCheck = Get-Date
                if (-not (Test-Disk '轮中')) {
                    # ⚠ 这里**不能**写 `$child.Id`: 抓取是用 `& $Py @pyArgs | ForEach-Object` 拉的管道,
                    # 根本没有进程对象(那段是照 Start-Process -PassThru 的写法抄来的, 一直取到 $null,
                    # 于是"轮中止损"只置了标志、**没杀到爬虫**, 却照样退出 3 把爬虫留成孤儿)。
                    # 真身 = "父进程是本看门狗 + 命令行含 crawl_jianpucn.py" 的那个 python。
                    $stopPid = (Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue |
                        Where-Object { $_.ParentProcessId -eq $PID -and $_.CommandLine -match 'crawl_jianpucn\.py' } |
                        Select-Object -First 1).ProcessId
                    if ($stopPid) {
                        try { Stop-Process -Id $stopPid -Force -ErrorAction Stop }
                        catch { Say "  (强杀 PID $stopPid 失败: $($_.Exception.Message))" }
                    }
                    else { Say "  (没查到本轮 python 子进程 PID, 杀不到; 退出后本轮自然结束)" }
                    $diskStop = $true
                    Say "!! 轮中触发止损: 已强制结束抓取 PID $stopPid, 本轮不重启(退出码 3)"
                }
            }
        }
        $code = $LASTEXITCODE
    }
    finally { Pop-Location }
    $mins = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
    Say "  << 爬虫退出码 $code, 用时 $mins 分钟"
    if ($diskStop) { exit 3 }

    # ── ④ 收工前再查一次磁盘 ────────────────────────────────────────────────
    if (-not (Test-Disk '收工前')) {
        Say "!! 本轮后低于止损线, 立即收工(退出码 3)"
        exit 3
    }
    Say "=== 看门狗结束(爬虫退出码 $code) ==="
    exit $code
}
finally {
    if ($lock) { $lock.Dispose() }
}
