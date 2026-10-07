<#
.SYNOPSIS
    转写看门狗 —— 计划任务每 5 分钟唤起一次, **没在转就补一轮**(转写侧不再依赖会话)。

.DESCRIPTION
    为什么要有它(2026-10-06 实测): 转写以前是**会话内**起的, 会话一回收就没了 —— 抓取照旧在写新图,
    语料却卡在 11,876 首 **11 小时**没动。抓取侧早有 `crawl_watchdog_*.ps1` 那一套计划任务看门狗,
    转写侧一直是空的。本脚本补上这一环, 每一轮按固定次序做四件事:

      ① **磁盘闸**: 跑 `tools/crawl_disk_guard.py`(唯一实现, 止损线 25 GiB **不许下调**)。
         低于线时它**自己会先调 `tools/image_window.py --apply` 回收已转写进语料的图目录**腾空间,
         腾完还不够才退 3 —— 退 3 本轮就不转写, 只打日志。
      ② **互斥(双判, 缺一不可)**:
         a. `train-work/.transcribe.lock` 里的 PID 还活着 -> 跳过。**PID 已死 = 上次崩了留下的死锁,
            清掉再往下走**(不清就永远轮不到自己)。
         b. 全机扫一遍进程命令行, 只要还有 `transcribe_source.py` / `jp_transcribe.py` /
            `transcribe.py` 在跑 -> 跳过。
         两道都要, 因为锁文件本身可能被绕过(手工起、别的脚本起), 而"GPU 上同时只许一个转写实例"
         是硬前提: 每进程各载一份 Qwen3-VL-2B, 塞第二个就是 2026-10-01 那次**颠簸 4.5 小时零输出**
         的重演。**绝不打断抓取进程**, 本脚本一个字都不碰爬虫。
      ③ **挑目标**: 调 `tools/transcribe_backlog_pick.py` 从 `train-work/transcribe_backlog_order.txt`
         取"第一个还有剩的源目录"(清单按真新曲数排序, 见 `_analysis/transcribe_backlog_census.py`),
         再起 `tools/transcribe_source.py <目录> -Limit`。
      ④ **记账**: 数本轮前后 `batch-out/*.txt` 与 `jianpu-db/scores/*.txt` 的文件数变化, 算出
         **首/小时**与净增, 连同耗时、退出码一起**追加**进日志(不用 `-RedirectStandardOutput` —— 那是覆盖写)。

    GPU 独占期间别开别的模型; 本脚本的 `-Limit` 就是"一轮最多转几首"的闸, 默认 60 首
    (实测约 15~20 分钟, 正好让 5 分钟的调度间隔在轮内被 `MultipleInstances=IgnoreNew` 吃掉)。

.PARAMETER Limit
    一轮最多交出去几首(透传给 `transcribe_backlog_pick.py --limit`)。默认 200。

    为什么从 60 提到 200(2026-10-07 实测): 每轮 `pick` 要普查 218 个源目录, 固定花 **~20 秒**;
    一轮只有 60 首时这笔开销占比 10% 以上, 而且 60 首在"失败快"的源上 2~3 分钟就跑完了,
    接着就退出等下一次 5 分钟 tick —— 实测 01:49→12:45 这 10.9 小时真跑只有 304 分钟(46%)。
    200 首: 快源(fysongs 型)一轮约 8~10 分钟; 慢源(jianpujia 真歌 ~20 秒/首)会被
    `KillAfterMin` 截断, 剩余部分下一轮**重新交**(`--done-only`, 见下面记账口径)。

.PARAMETER KillAfterMin
    单轮硬上限(分钟), 默认 35。到点就按命令行找到本轮的 python 子进程并结束它 ——
    这只兜"某一轮卡死"的极端情况。已写完的 `batch-out/*.txt` 不会丢。
    会话中还会按"剩余时间"再收紧一次, 保证一轮不会跨过 2 小时的 `ExecutionTimeLimit`。

.PARAMETER SessionMaxMin
    **一次会话最多连跑多少分钟**, 默认 95(< 任务的 2 小时 `ExecutionTimeLimit`, 留足收尾余量)。
    会话期间 5 分钟的 tick 被任务设置 `MultipleInstances=IgnoreNew` 忽略 —— 所以始终只有一个
    看门狗、一个转写实例(硬前提)。会话收工后, 下一次 tick(≤5 分钟)自动重开。

.PARAMETER MandopopGuardMin
    离 `jp_mandopop_absorb3` 下次开跑不足这么多分钟(默认 20)时**不再起新一轮**, 把 GPU 让给它。
    它是 6 小时一次的独占任务; 老版一轮 60 首最长 40 分钟, 可能正好压在它头上。

.PARAMETER LogDir
    日志目录(默认 `D:\Documents_D\_analysis\transcribe_stock`)。

.PARAMETER Python
    解释器绝对路径。默认自动找(与 `crawl_watchdog_jianpujia.ps1` 同一套找法)。

.EXAMPLE
    pwsh -NoProfile -File tools\transcribe_watchdog.ps1                 # 跑一轮(计划任务就是这么调)
    pwsh -NoProfile -File tools\transcribe_watchdog.ps1 -Status         # 只报现状, 不转写
    pwsh -NoProfile -File tools\transcribe_watchdog.ps1 -Limit 100      # 一轮多转点
#>
[CmdletBinding()]
param(
    [int]$Limit = 300,
    [int]$KillAfterMin = 60,
    [int]$SessionMaxMin = 110,
    [int]$MandopopGuardMin = 20,
    [string]$LogDir = 'D:\Documents_D\_analysis\transcribe_stock',
    [string]$Python = '',
    [switch]$Status
)

$ErrorActionPreference = 'Continue'
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
}
catch { }
$env:PYTHONIOENCODING = 'utf-8'

$Root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $Root 'tools\transcribe_source.py'))) { $Root = 'D:\Documents_D\jianpu2' }
$SrcPy = Join-Path $Root 'tools\transcribe_source.py'
$PickPy = Join-Path $Root 'tools\transcribe_backlog_pick.py'
$GuardPy = Join-Path $Root 'tools\crawl_disk_guard.py'
$Prep = Join-Path $Root 'images-prep'
$OutDir = Join-Path $Root 'batch-out'
$Lock = Join-Path $Root 'train-work\.transcribe.lock'
$Scores = 'D:\Documents_D\jianpu-db\scores'

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Log = Join-Path $LogDir ('transcribe_watchdog_{0:yyyyMMdd}.log' -f (Get-Date))

function Say([string]$m) {
    $line = '[{0:yyyy-MM-dd HH:mm:ss}] {1}' -f (Get-Date), $m
    Write-Host $line
    Add-Content -Path $Log -Value $line -Encoding utf8      # 追加, 绝不覆盖
}

# ⚠ **转写必须用装了 torch/transformers 的那个解释器** —— 2026-10-06 的血案就在这里:
#   本函数原来照抄抓取看门狗(`crawl_watchdog_jianpujia.ps1`), 让 PATH 上的 `python` 优先。
#   抓取不需要 torch, 所以那边没事; 但 PATH 上的 `python` 是 **Python 3.14**, 它**没装 torch**,
#   于是转写每一首都 `失败 ModuleNotFoundError`(真因: `tools/jp_transcribe.py:47 import torch`)。
#   而 `transcribe_source.py` 把这个异常吞成一行 "失败 <类型>" 并**照常退出 0** —— 29 轮全空转,
#   还把 1512 个目录误记成"已检查"(见 train-work/transcribe_examined.txt 的撤回记录)。
#   历史口径(证据): 仓库里所有转写脚本都是 `py -3.13` —— `tools/transcribe_source.py` 第 3 行、
#   `tools/transcribe_backlog.ps1` 第 22 行、`tools/transcribe_backlog_pick.py` 第 33 行;
#   `py -3.13` 解析到的就是下面第一个路径(`...\Programs\Python\Python313\python.exe`)。
#   并且**不再靠猜**: 逐个候选实测 `import torch, transformers`, 猜错的代价是整轮静默报废。
function Test-TranscribePython([string]$exe) {
    if (-not $exe -or -not (Test-Path $exe)) { return $false }
    try {
        & $exe -c "import torch, transformers" 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    }
    catch { return $false }
}

function Resolve-Python {
    if ($Python) { return $Python }
    $cands = @((Join-Path $env:LOCALAPPDATA 'Programs\Python\Python313\python.exe'))
    $c = Get-Command python -ErrorAction SilentlyContinue
    if ($c -and $c.Source) { $cands += $c.Source }
    $cands += @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python314\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Python\pythoncore-3.14-64\python.exe'))
    foreach ($p in $cands) {
        if (Test-TranscribePython $p) { return $p }
    }
    return ''
}
$Py = Resolve-Python
if (-not $Py) {
    Say "!! 找不到能 `import torch/transformers` 的 Python —— 转写必然全失败, 本轮**不起**(解释器先修)。"
    Say "=== 看门狗结束(退出码 3) ==="
    exit 3
}

# 在跑的转写进程(排除自己)。判据只看命令行里的脚本名, 不认进程名。
function Get-Transcriber {
    Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='py.exe' OR Name='pythonw.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -and $_.ProcessId -ne $PID -and
            $_.CommandLine -match '(transcribe_source|jp_transcribe|batch_transcribe|transcribe)\.py'
        }
}

# 本看门狗自己的直接子进程(= 本轮那个 python)。**轮中让路**与**单轮硬上限**只许动这些,
# 绝不许误伤别人的转写进程。
function Get-MyKidPids {
    @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$PID" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^python' } | Select-Object -ExpandProperty ProcessId)
}

# 显卡实际占用(MiB)。问不到返回 $null(调用方要按"问不到=不赌"处理)。
function Get-GpuUsedMiB {
    try {
        $q = & nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $q) { return $null }
        $n = 0
        if ([int]::TryParse(("$q".Trim() -split "`n")[0].Trim(), [ref]$n)) { return $n }
        return $null
    }
    catch { return $null }
}

function Get-LockPid {
    if (-not (Test-Path $Lock)) { return 0 }
    $txt = (Get-Content $Lock -Raw -ErrorAction SilentlyContinue)
    if ($txt) { $txt = $txt.Trim() }
    $n = 0
    if ([int]::TryParse($txt, [ref]$n)) { return $n }
    return 0
}

function Count-Files([string]$Dir, [string]$Filter) {
    if (-not (Test-Path $Dir)) { return 0 }
    return (Get-ChildItem -Path $Dir -File -Filter $Filter -ErrorAction SilentlyContinue).Count
}

# `jp_mandopop_absorb3` 还有几分钟开跑(负数=已过点/正在跑)。读不到返回 $null(调用方按"不赌"处理)。
# 为什么要它: 那个任务 6 小时一次、独占 GPU, 而本看门狗一轮可能跑几十分钟 —— 得保证一轮不会
# 跨过它的窗口。只读它的**下次运行时间**, 不认它的 Status —— 实测那个任务会卡在收尾里
# 一直显示 Running(幻觉 Running, 见下面 ③b 的说明), 按 Status 判会永远让路。
function Get-MinutesToMandopop {
    try {
        $out = & schtasks /query /tn 'jp_mandopop_absorb3' /fo list 2>$null
        $line = @($out | Where-Object { "$_" -match 'Next Run Time' })[0]
        if (-not $line) { return $null }
        $s = ("$line" -split ':', 2)[1].Trim()
        foreach ($fmt in @('yyyy/M/d HH:mm:ss', 'yyyy-MM-dd HH:mm:ss', 'M/d/yyyy h:mm:ss tt')) {
            try {
                $t = [datetime]::ParseExact($s, $fmt, [System.Globalization.CultureInfo]::InvariantCulture)
                return [math]::Round(($t - (Get-Date)).TotalMinutes, 1)
            }
            catch { }
        }
    }
    catch { }
    return $null
}

if ($Status) {
    $run = Get-Transcriber
    if ($run) { $run | ForEach-Object { '在跑: PID {0}  {1}' -f $_.ProcessId, $_.CommandLine } }
    else { '没有转写进程在跑' }
    $lp = Get-LockPid
    if ($lp) {
        $alive = [bool](Get-Process -Id $lp -ErrorAction SilentlyContinue)
        '锁 {0} -> PID {1} ({2})' -f $Lock, $lp, $(if ($alive) { '活着' } else { '**已死 = 死锁**' })
    }
    else { '锁 {0} -> 不存在或不是 PID' -f $Lock }
    'batch-out txt: {0} · 语料 scores txt: {1}' -f (Count-Files $OutDir '*.txt'), (Count-Files $Scores '*.txt')
    if (Test-Path $Log) { '--- 日志尾巴 ---'; Get-Content $Log -Tail 15 }
    exit 0
}

Say "=== 转写看门狗唤起: PID $PID · Limit=$Limit · 单轮上限 ${KillAfterMin} 分钟 · 会话上限 ${SessionMaxMin} 分钟 · python=$Py (已实测 import torch/transformers OK) ==="

# ══════════════════════════════════════════════════════════════════════════════
# **会话循环**(2026-10-07 改): 一轮跑完**当场**判断下一轮能不能起, 不再退出等下一次 tick。
# 为什么(实测 01:49->12:45 共 10.93 小时 = 656 分钟, 来自 _analysis/idle_breakdown.py):
#   真跑墙钟 304.2 分钟(46.3%) · **轮间空档 233.1 分钟(35.5%, 中位 2.2 分钟/轮)** ·
#   让路给另一个转写实例(01:54~03:41, .transcribe.lock 一直被占) 107 分钟 ·
#   让路给 jp_mandopop_absorb3 占卡 2 分钟 · 跳过 tick 自身开销 ~10 分钟。
#   -> 真正白等的就是那 233 分钟的"跑完了但没人在跑"。
# 安全性: 计划任务 `MultipleInstances=IgnoreNew` -> 会话期间 5 分钟的 tick 被忽略, 全机始终
#   只有一个看门狗、一个转写实例(硬前提)。下面每一轮都**重新**过一遍全部闸门(磁盘/入库/锁/
#   进程/mandopop 窗口/显存), 只要有一条不过就停会话, 让下一次 tick 再来。
# ══════════════════════════════════════════════════════════════════════════════
$sessionStart = Get-Date
$roundNo = 0
$sumNew = 0; $sumOk = 0; $sumItem = 0; $sumMin = 0.0
$stopReason = '未知'
while ($true) {
$elapsedMin = ((Get-Date) - $sessionStart).TotalMinutes
$leftMin = $SessionMaxMin - $elapsedMin
if ($leftMin -lt 3) {
    $stopReason = ('会话已跑 {0:N1} 分钟, 到上限 {1} 分钟 -> 收工(下一次 tick 会自动重开)' -f $elapsedMin, $SessionMaxMin)
    break
}

# ── ③b0 mandopop 窗口闸: 别让一轮长到跨过 jp_mandopop_absorb3 的窗口 ──────────
$mm = Get-MinutesToMandopop
if ($null -eq $mm) {
    Say "  ⚠ 读不到 jp_mandopop_absorb3 的下次运行时间 -> 本轮不设窗口闸(其余闸门照旧)。"
}
elseif ($mm -lt $MandopopGuardMin) {
    $stopReason = ('离 jp_mandopop_absorb3 下次开跑只剩 {0:N1} 分钟(< {1}) -> 本轮不起, 把 GPU 让给它' -f $mm, $MandopopGuardMin)
    break
}
else {
    Say ("  离 jp_mandopop_absorb3 下次开跑 {0:N1} 分钟 -> 窗口安全。" -f $mm)
}
# 本轮硬上限 = min(参数, 会话剩余-1 分钟, 离 mandopop 还剩的时间-5 分钟)。
# 第三条是关键: 光判"还有 20 分钟"不够 —— 一轮最长能跑 KillAfterMin 分钟, 起得晚了照样跨过它的窗口。
$killMin = [int][math]::Min([double]$KillAfterMin, [math]::Max(3.0, $leftMin - 1.0))
if ($null -ne $mm) {
    $room = [int][math]::Floor($mm - 5.0)
    if ($room -lt 3) {
        $stopReason = ('离 jp_mandopop_absorb3 只剩 {0:N1} 分钟, 连一轮(≥3 分钟)都放不下 -> 让路' -f $mm)
        break
    }
    $killMin = [int][math]::Min([double]$killMin, [double]$room)
}

# ── ① 磁盘闸(唯一实现 crawl_disk_guard; 低于线时它自己会先跑 image_window 腾空间) ─────
$diskOut = & $Py $GuardPy $Prep $LogDir 2>&1
$diskCode = $LASTEXITCODE
foreach ($l in $diskOut) { Say "  [disk] $l" }
if ($diskCode -ne 0) {
    Say "!! 磁盘闸未过(退出码 $diskCode) —— 本轮不转写。止损线 25 GiB 不许下调; 腾空间 = tools/image_window.py --apply。"
    $stopReason = "磁盘闸未过(退出码 $diskCode)"
    break
}

# ── ①b 入库闸: `tools/JianpuIngest.ps1` 正在跑(全库重建) -> 本轮让路 ──────────────
# 为什么必须有(2026-10-06 实测): 入库的 `finalize.py` 里有一步 `to_jianpu_db.py --meter` ——
# 它给"拍号认不回旧账本"的新谱 `_model.to("cuda")`, 也就是**往 cuda:0 载第二份 Qwen3-VL-2B**。
# 实测 9,784 份 batch-out 里有 **149 份**属于这种; 而这台机器的显存只剩 ~250 MiB、内存只剩
# 0.2~0.8 GiB —— 要么 CUDA OOM(被吞成"拍号识别失败", 新谱拍号默默写成 4/4 并被 scores-prev 固化),
# 要么整机换页把转写拖死。所以入库期间转写侧**让路**: 本闸只推迟"下一轮什么时候起",
# **不打断任何已经在跑的进程**(在场那个转写由入库侧等它自己跑完, 见 JianpuIngest.ps1)。
$ingLock = Join-Path $Root 'train-work\ingest.lock'
# ⚠ 必须**自己读这个文件**, 不能复用上面的 `Get-LockPid` —— 那个函数没有参数, 读的是
#   脚本级的 `$Lock`(=`train-work\.transcribe.lock`)。2026-10-06 21:01 实测踩过:
#   传参被忽略, 于是本闸把**转写自己的锁**当成"入库在跑", 每一轮都白跳过。
$ilp = 0
if (Test-Path $ingLock) {
    $itxt = (Get-Content $ingLock -Raw -ErrorAction SilentlyContinue)
    if ($itxt) { $itxt = $itxt.Trim() }
    $in = 0
    if ([int]::TryParse($itxt, [ref]$in)) { $ilp = $in }
}
if ($ilp) {
    if (Get-Process -Id $ilp -ErrorAction SilentlyContinue) {
        Say "跳过: 入库看门狗在跑(锁 $ingLock -> PID $ilp) —— 它正在全库重建, 本轮不抢 GPU。"
        $stopReason = "入库看门狗在跑(锁 PID $ilp)"
        break
    }
    Say "入库锁里 PID $ilp **已死** = 陈旧锁 -> 清掉 $ingLock"
    Remove-Item -Path $ingLock -Force -ErrorAction SilentlyContinue
}

# ── ② 互斥 a: 锁文件 PID ────────────────────────────────────────────────────
$lp = Get-LockPid
if ($lp) {
    if (Get-Process -Id $lp -ErrorAction SilentlyContinue) {
        Say "跳过: 锁里 PID $lp 还活着, 已有转写实例在用 GPU(硬前提: 同时只许一个)。"
        $stopReason = "别的转写实例在跑(.transcribe.lock -> PID $lp)"
        break
    }
    Say "锁里 PID $lp **已死** = 上次崩了留下的死锁 -> 清掉 $Lock"
    Remove-Item -Path $Lock -Force -ErrorAction SilentlyContinue
}

# ── ② 互斥 b: 进程扫描 ──────────────────────────────────────────────────────
$run = Get-Transcriber
if ($run) {
    foreach ($p in $run) { Say "跳过: 已有转写进程 PID $($p.ProcessId) —— $($p.CommandLine)" }
    $stopReason = "已有转写进程在跑(PID $($run[0].ProcessId)) —— 硬前提: 同时只许一个"
    break
}

# ── ③ 挑目标(名单模式: 只交"没转过、也没交出去过"的目录, 见 pick 脚本头上的两条坑) ──────
$pickOut = & $Py $PickPy --limit $Limit 2>&1
$pickCode = $LASTEXITCODE
$src = ''
$listFile = ''
$nPick = 0
foreach ($l in $pickOut) {
    if ($l -match '^PICK=(.*)$') { $src = $Matches[1].Trim() }
    elseif ($l -match '^LIST=(.*)$') { $listFile = $Matches[1].Trim() }
    elseif ($l -match '^N=(\d+)$') { $nPick = [int]$Matches[1] }
    else { Say "  $l" }
}
if ($pickCode -eq 4 -or -not $src -or $nPick -le 0) {
    Say "清单里没有还有未交付目录的源(退出码 $pickCode) —— 本轮无事可做。"
    $stopReason = "清单里没有还有未交付目录的源(积压吃干净了)"
    break
}
# ⚠ `transcribe_source.py` 的第 1 个参数可以是**目录**(相对仓库根)也可以是**名单文件**
#   (每行一个目录名)。名单模式下它按名字在 `images-prep/*/` 里找 —— 这正是我们要的:
#   只有"名单模式"才能精确指定这一轮转哪几个, 目录模式只会每轮重扫字母序开头(实测空转)。
if (-not (Test-Path $listFile)) {
    Say "!! 名单文件不存在: $listFile —— 请重跑 tools/transcribe_backlog_pick.py"
    $stopReason = "名单文件不存在: $listFile"
    break
}
Say "本轮目标: $src · 交出去 $nPick 个目录 · 名单 $listFile"

# ── ③b GPU 独占策略: 幻觉 Running 任务不许白等(**每一轮重算**) ───────────────
# 实测(2026-10-06 17:00): 计划任务 `jp_mandopop_absorb3` 的 Status **一直**是 Running ——
# 它 16:46 就把活干完了, 却卡在收尾的 `qa_sample.py` 里没退(父进程 pid 21632 至今活着)。
# 而 `transcribe_source.py` 的让路闸只看 schtasks 的 Running 字样, 于是**每轮白等满 20 分钟**
# (`JP_WAIT_MAX_MIN` 默认 20)。看卡就知道那是幻觉: 当时显存只有 44 MiB / 利用率 0%。
# 所以这里先量一次显存再决定让路策略:
#   * 显存空闲(<500 MiB)且前面两道互斥已确认没有别的转写进程 -> 设 `JP_NO_WAIT=1`, 不等;
#   * 否则保留让路闸, 但把等待上限压到 2 分钟(20 分钟太长; 进程级互斥已由 ② 两道判据保证)。
# ⚠ 这套判据**保留不动**(它是对的)。会话循环里它每一轮重算一次: 上一轮把 `JP_NO_WAIT` 设上了,
#   这一轮显卡被别人占着就得**摘掉**, 否则子进程会带着"不等"闯进别人的卡里。
$env:JP_WAIT_MAX_MIN = '2'
$gpuUsed = Get-GpuUsedMiB
if ($null -ne $gpuUsed -and $gpuUsed -lt 500) {
    $env:JP_NO_WAIT = '1'
    Say "  显卡空闲($gpuUsed MiB)且无别的转写进程 -> JP_NO_WAIT=1, 不为 schtasks 里挂着的幻觉 Running 任务空等。"
}
else {
    Remove-Item Env:\JP_NO_WAIT -ErrorAction SilentlyContinue
    if ($null -eq $gpuUsed) { Say "  显存占用问不到 -> 不赌: 保留让路闸, 等待上限 2 分钟。" }
    else { Say "  显卡已被占用($gpuUsed MiB) -> 保留让路闸, 等待上限 2 分钟。" }
}

# ── ④ 转一轮 + 记账(会话循环的第 $roundNo+1 轮) ──────────────────────────────
$roundNo++
Say ("  == 会话第 {0} 轮(已跑 {1:N1} 分钟 / 上限 {2}) · 本轮硬上限 {3} 分钟" -f $roundNo, $elapsedMin, $SessionMaxMin, $killMin)
$beforeOut = Count-Files $OutDir '*.txt'
$beforeScores = Count-Files $Scores '*.txt'
$t0 = Get-Date
Say "  >> $Py -u $SrcPy $listFile   (cwd=$Root; batch-out 起始 $beforeOut 份 · 语料 $beforeScores 份)"
$code = 1
$yielded = $false
# **环境故障不许记账**(2026-10-06 血案的事后闸): 解释器没 torch 时每一项都是
# "失败 ModuleNotFoundError", 而 transcribe_source.py 把它吞成一行、**照常退出 0** ——
# 于是 29 轮"成功"退出、1512 个目录被记进"已检查", 永远轮不到。这里数三个指标:
#   $nItem = **交出去的目录里真处理了几个**(`[i/n]` 行, 用来报"每轮处理首数");
#   $nFail = 报"失败"的目录数; $nOk = **真的干了活**的目录数(转出 token / 判为纯非简谱而跳过)。
# 只有"有失败 + 一个正常处理的都没有 + 产出 0 份"才判定环境故障 —— 正常轮次里偶发一两个失败不受影响。
# ⚠ 计数一律只看**目录级**的 `[i/n] ...` 行: 多页谱另有 `第k页失败` 行, 早先把它也当失败数,
#   一轮 60 首能数出 60+ 个"失败", 口径是错的。
#   $nRealProd / $nEmptyProd = 产物里**真有 token** / **token 0(空稿)** 的条数, 也从同一批
#   行里数(`token N 数字 M`), 用来做下面的记账防呆闸。
$nFail = 0
$nOk = 0
$nItem = 0
$nRealProd = 0
$nEmptyProd = 0
$killedByCap = $false
$lastPeek = Get-Date
Push-Location $Root
try {
    & $Py -u $SrcPy $listFile 2>&1 | ForEach-Object {
        $ln = "$_"
        Say "  | $ln"
        if ($ln -match '^\[\d+/\d+\]') {
            $nItem++
            if ($ln -match ': 失败 ') { $nFail++ }
            elseif ($ln -match 'token [1-9]\d* 数字 ') { $nOk++; $nRealProd++ }
            elseif ($ln -match 'token 0 数字 0') { $nOk++; $nEmptyProd++ }
            elseif ($ln -match '非纯简谱, 跳过' -or $ln -match '织体') { $nOk++ }
        }
        # ⚠ `transcribe_source.py` 会把每类异常汇总成一行 —— 原样转发容易看漏, 这里加前缀醒目化。
        if ($ln -match '^失败汇总|^失败样例') { Say "  !! $ln" }
        # 轮中让路(每 30 秒看一次): 别的转写进程一旦出现, **我们**让路 —— 硬前提是 GPU 上同时只许
        # 一个转写实例, 而我们是"填积压"的那一方, 让路的应该是自己。绝不打断别人。
        # 另外也盯 `to_jianpu_db.py`(`finalize` 里给新谱 `_model.to("cuda")` 的那一步): 这台机器
        # 内存只剩零点几 GiB, 别人正在往卡上载模型时我们继续跑就是 2026-10-01 那次颠簸的重演。
        if (((Get-Date) - $lastPeek).TotalSeconds -ge 30) {
            $lastPeek = Get-Date
            $kids = Get-MyKidPids
            $foreign = Get-Transcriber | Where-Object { $kids -notcontains $_.ProcessId }
            if (-not $foreign) {
                $foreign = Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='py.exe'" -ErrorAction SilentlyContinue |
                    Where-Object { $_.CommandLine -and $kids -notcontains $_.ProcessId -and $_.CommandLine -match 'to_jianpu_db\.py' }
            }
            if ($foreign) {
                foreach ($f in $foreign) { Say "!! 轮中出现别的进程 PID $($f.ProcessId) —— $($f.CommandLine)" }
                Say "!! GPU 上同时只许一个转写实例 -> 本轮立刻让路(只结束自己的子进程, 不碰别人)"
                foreach ($k in $kids) { try { Stop-Process -Id $k -Force -ErrorAction Stop } catch { } }
                $yielded = $true
            }
        }
        # 单轮硬上限(兜"某一轮卡死"): 同样只动自己的子进程。只触发一次(不然后面每行都刷一遍)。
        if (-not $killedByCap -and ((Get-Date) - $t0).TotalMinutes -ge $killMin) {
            $killedByCap = $true
            $kids = Get-MyKidPids
            foreach ($k in $kids) {
                Say "!! 单轮超过 $killMin 分钟 -> 结束本轮转写 PID $k(已写完的 batch-out 不受影响)"
                try { Stop-Process -Id $k -Force -ErrorAction Stop } catch { }
            }
        }
    }
    $code = $LASTEXITCODE
}
finally { Pop-Location }
$mins = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
$afterOut = Count-Files $OutDir '*.txt'
$afterScores = Count-Files $Scores '*.txt'
$nNew = $afterOut - $beforeOut
$nScores = $afterScores - $beforeScores

# 记账: 把本轮名单里的目录记进"已交付"状态, 否则下一轮会重复交同一批。
#   退出码 0 = transcribe_source 走完了整份名单, 整批都算交付过(含被判非纯简谱/织体而跳过的);
#   退出码非 0 = 中途出事(被杀/崩), 这时**只记真有产物的**, 其余留给下一轮重交 —— 宁可重交也不丢。
#
# ══ 记账防呆闸(2026-10-07 加, 今晚被同一类事故咬了两次) ══════════════════════════
# 两次血案都是同一个形状: **子脚本吞异常 + 退出 0 + 看门狗照常记账** -> 整批条目被永久
# 标成"已交付", 永远轮不到。
#   ① 2026-10-06 `ModuleNotFoundError`: 29 轮全空转, 1512 个目录被记掉。
#   ② 2026-10-07 `4a3dafb4` 的 `_plan` 元组回归: 04:05~13:18 共 **5213 条 TypeError**,
#      5475 个目录"没产物却记成已交付"(已用 `_analysis/rollback_bad_plan_tuple.py` 撤回)。
# 所以从记账侧堵死, 三条判据:
#   * `$allFail`  = 处理过的条目**全部**报失败;
#   * `$allEmpty` = 有产物, 但产物**全是 token 0 的空稿**(一个真 token 都没有);
#   * `$envBroken`= 旧的那条(全失败 + 零正常 + 零产出), 保留。
#   任意一条成立 -> **一个字都不记**, 这批原样留给下一轮重跑, 并停会话报警。
#   ⚠ 判据必须带"有产物"这一条: "整批非纯简谱/织体 -> 0 产物"是**正常**的, 那种批次不记账
#     会让这些目录被永远重交(它们永远不会有产物) —— 那是把防呆闸变成死循环。
#   * 另加"高失败率"档: 失败率 >= 50% 时不静默照单全收, 改用 `--done-only` 记账 —— 只把
#     **真有产物的**记成已交付, 其余全部重交。这条正好能兜住 ② 那种"一半以上条目报废但
#     每轮还剩几首成功"的形态(它不会触发上面三条)。
$commitArgs = @($PickPy, '--commit', '--src', $src, '--list', $listFile)
if ($code -ne 0) { $commitArgs += '--done-only' }
$envBroken = ($nFail -gt 0 -and $nOk -le 0 -and $nNew -le 0)
$allFail = ($nItem -gt 0 -and $nFail -ge $nItem)
$allEmpty = ($nNew -gt 0 -and $nRealProd -le 0)
$highFail = ($nItem -ge 10 -and $nFail -gt 0 -and ($nFail * 2) -ge $nItem)
$refuseCommit = ($envBroken -or $allFail -or $allEmpty)
if ($refuseCommit) {
    $why = if ($envBroken) { "环境故障(全失败+零正常+零产出)" }
           elseif ($allFail) { "处理过的 $nItem 条**全部报失败**" }
           else { "有 $nNew 份产物但**全是 token 0 空稿**" }
    Say "!! 记账防呆闸拦下: $why"
    Say "!! 这批**一个字都不记**, 原样留给下一轮重跑(记账=把这批永久跳过)。先看上面的「失败汇总/失败样例」。"
}
elseif ($highFail) {
    $commitArgs += '--done-only'
    Say ("!! 失败率过高($nFail/$nItem = {0:N0}%) -> 只把**真有产物**的记成已交付, 其余全部重交(防呆档)。" -f (100.0 * $nFail / [math]::Max($nItem, 1)))
    $commitOut = & $Py @commitArgs 2>&1
    foreach ($l in $commitOut) { Say "  $l" }
}
else {
    $commitOut = & $Py @commitArgs 2>&1
    foreach ($l in $commitOut) { Say "  $l" }
}

# 首/小时: 只认 batch-out 的净增(它就是本轮的产出), 语料净增要等 finalize/parse 才算得准 —— 分开报。
$perHour = if ($mins -gt 0.2) { [math]::Round($nNew * 60.0 / $mins, 1) } else { 0 }
Say ("  << 退出码 $code · 用时 $mins 分钟 · 本轮**处理 {0} 首** · batch-out 净增 {1} 份 ({2}/首小时) · 语料 scores 净增 {3} 份" -f `
     $nItem, $nNew, $perHour, $nScores)
Say ("     正常处理 {0} 个(真 token {1} · token0 空稿 {2}) · 失败 {3} 个 · 磁盘余量 {4:N2} GiB · batch-out 累计 {5} 份 · 语料累计 {6} 份" -f `
        $nOk, $nRealProd, $nEmptyProd, $nFail, ((Get-PSDrive D).Free / 1GB), $afterOut, $afterScores)
$sumNew += $nNew; $sumOk += $nOk; $sumItem += $nItem; $sumMin += $mins
$sessPerHour = if ($sumMin -gt 0.2) { [math]::Round($sumNew * 60.0 / $sumMin, 1) } else { 0 }
Say ("  ## 会话累计: {0} 轮 · 处理 {1} 首 · 产物 {2} 份 · 真跑 {3:N1} 分钟 · {4} 首/小时" -f `
        $roundNo, $sumItem, $sumNew, $sumMin, $sessPerHour)

if ($yielded) {
    $stopReason = "第 $roundNo 轮轮中让路给别的转写实例/别的载模型进程"
    break
}
if ($refuseCommit) {
    Say "!! 记账防呆闸已拦下整批 -> 停会话(先修故障, 别再空转)。"
    $stopReason = "记账防呆闸拦下(全失败/全空稿)"
    break
}
if ($code -ne 0) {
    # ⚠ 被**单轮硬上限**截断不算故障: 新一轮立刻接上, 未记账的条目下一轮自动重交。
    #   (老写法一律 break, 等于"轮一长就停会话", 白白丢掉循环的意义。)
    if ($killedByCap) {
        Say "!! 本轮被硬上限 $killMin 分钟截断 -> **立刻接下一轮**(未记账的自动重交), 不停会话。"
        continue
    }
    Say "!! 本轮退出码 $code(不是硬上限截断) -> 收工, 下一次 tick 重新挑目标(未记账的会自动重交)。"
    $stopReason = "本轮退出码 $code"
    break
}
}   # ← 会话循环结束

$sessMins = [math]::Round(((Get-Date) - $sessionStart).TotalMinutes, 1)
$sessPerHour = if ($sessMins -gt 0.2) { [math]::Round($sumNew * 60.0 / $sessMins, 1) } else { 0 }
Say ("=== 看门狗会话结束: {0} 轮 · 处理 {1} 首 · 产物 {2} 份 · 会话墙钟 {3} 分钟 -> {4} 首/小时 ===" -f `
        $roundNo, $sumItem, $sumNew, $sessMins, $sessPerHour)
Say ("    停因: {0}" -f $stopReason)
Say "=== 看门狗结束(退出码 0) ==="
exit 0
