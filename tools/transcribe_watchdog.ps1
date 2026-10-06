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
    本轮最多转几首(透传给 `transcribe_source.py` 的第 2 个参数)。默认 60。

.PARAMETER KillAfterMin
    单轮硬上限(分钟), 默认 40。到点就按命令行找到本轮的 python 子进程并结束它 ——
    这只兜"某一轮卡死"的极端情况; 正常轮次远早于此结束。已写完的 `batch-out/*.txt` 不会丢。

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
    [int]$Limit = 60,
    [int]$KillAfterMin = 40,
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

Say "=== 转写看门狗唤起: PID $PID · Limit=$Limit · python=$Py (已实测 import torch/transformers OK) ==="

# ── ① 磁盘闸(唯一实现 crawl_disk_guard; 低于线时它自己会先跑 image_window 腾空间) ─────
$diskOut = & $Py $GuardPy $Prep $LogDir 2>&1
$diskCode = $LASTEXITCODE
foreach ($l in $diskOut) { Say "  [disk] $l" }
if ($diskCode -ne 0) {
    Say "!! 磁盘闸未过(退出码 $diskCode) —— 本轮不转写。止损线 25 GiB 不许下调; 腾空间 = tools/image_window.py --apply。"
    Say "=== 看门狗结束(退出码 $diskCode) ==="
    exit $diskCode
}

# ── ② 互斥 a: 锁文件 PID ────────────────────────────────────────────────────
$lp = Get-LockPid
if ($lp) {
    if (Get-Process -Id $lp -ErrorAction SilentlyContinue) {
        Say "跳过: 锁里 PID $lp 还活着, 已有转写实例在用 GPU(硬前提: 同时只许一个)。"
        Say "=== 看门狗结束(退出码 0, 未起转写) ==="
        exit 0
    }
    Say "锁里 PID $lp **已死** = 上次崩了留下的死锁 -> 清掉 $Lock"
    Remove-Item -Path $Lock -Force -ErrorAction SilentlyContinue
}

# ── ② 互斥 b: 进程扫描 ──────────────────────────────────────────────────────
$run = Get-Transcriber
if ($run) {
    foreach ($p in $run) { Say "跳过: 已有转写进程 PID $($p.ProcessId) —— $($p.CommandLine)" }
    Say "=== 看门狗结束(退出码 0, 未起转写) ==="
    exit 0
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
    Say "=== 看门狗结束(退出码 0) ==="
    exit 0
}
# ⚠ `transcribe_source.py` 的第 1 个参数可以是**目录**(相对仓库根)也可以是**名单文件**
#   (每行一个目录名)。名单模式下它按名字在 `images-prep/*/` 里找 —— 这正是我们要的:
#   只有"名单模式"才能精确指定这一轮转哪几个, 目录模式只会每轮重扫字母序开头(实测空转)。
if (-not (Test-Path $listFile)) {
    Say "!! 名单文件不存在: $listFile —— 请重跑 tools/transcribe_backlog_pick.py"
    exit 1
}
Say "本轮目标: $src · 交出去 $nPick 个目录 · 名单 $listFile"

# ── ③b GPU 独占策略: 幻觉 Running 任务不许白等 ───────────────────────────────
# 实测(2026-10-06 17:00): 计划任务 `jp_mandopop_absorb3` 的 Status **一直**是 Running ——
# 它 16:46 就把活干完了, 却卡在收尾的 `qa_sample.py` 里没退(父进程 pid 21632 至今活着)。
# 而 `transcribe_source.py` 的让路闸只看 schtasks 的 Running 字样, 于是**每轮白等满 20 分钟**
# (`JP_WAIT_MAX_MIN` 默认 20)。看卡就知道那是幻觉: 当时显存只有 44 MiB / 利用率 0%。
# 所以这里先量一次显存再决定让路策略:
#   * 显存空闲(<500 MiB)且前面两道互斥已确认没有别的转写进程 -> 设 `JP_NO_WAIT=1`, 不等;
#   * 否则保留让路闸, 但把等待上限压到 2 分钟(20 分钟太长; 进程级互斥已由 ② 两道判据保证)。
$gpuUsed = Get-GpuUsedMiB
if ($null -ne $gpuUsed -and $gpuUsed -lt 500) {
    $env:JP_NO_WAIT = '1'
    Say "  显卡空闲($gpuUsed MiB)且无别的转写进程 -> JP_NO_WAIT=1, 不为 schtasks 里挂着的幻觉 Running 任务空等。"
}
else {
    $env:JP_WAIT_MAX_MIN = '2'
    if ($null -eq $gpuUsed) { Say "  显存占用问不到 -> 不赌: 保留让路闸, 等待上限 2 分钟。" }
    else { Say "  显卡已被占用($gpuUsed MiB) -> 保留让路闸, 等待上限 2 分钟。" }
}

# ── ④ 转一轮 + 记账 ─────────────────────────────────────────────────────────
$beforeOut = Count-Files $OutDir '*.txt'
$beforeScores = Count-Files $Scores '*.txt'
$t0 = Get-Date
Say "  >> $Py -u $SrcPy $listFile   (cwd=$Root; batch-out 起始 $beforeOut 份 · 语料 $beforeScores 份)"
$code = 1
$yielded = $false
# **环境故障不许记账**(2026-10-06 血案的事后闸): 解释器没 torch 时每一项都是
# "失败 ModuleNotFoundError", 而 transcribe_source.py 把它吞成一行、**照常退出 0** ——
# 于是 29 轮"成功"退出、1512 个目录被记进"已检查", 永远轮不到。这里数两个指标:
#   $nFail = 报"失败"的目录数; $nOk = **真的干了活**的目录数(转出 token / 判为纯非简谱而跳过)。
# 只有"有失败 + 一个正常处理的都没有 + 产出 0 份"才判定环境故障 —— 正常轮次里偶发一两个失败不受影响。
$nFail = 0
$nOk = 0
$lastPeek = Get-Date
Push-Location $Root
try {
    & $Py -u $SrcPy $listFile 2>&1 | ForEach-Object {
        $ln = "$_"
        Say "  | $ln"
        if ($ln -match '失败 ') { $nFail++ }
        elseif ($ln -match 'token \d+ 数字 \d+' -or $ln -match '非纯简谱, 跳过' -or $ln -match '织体') { $nOk++ }
        # 轮中让路(每 30 秒看一次): 别的转写进程一旦出现, **我们**让路 —— 硬前提是 GPU 上同时只许
        # 一个转写实例, 而我们是"填积压"的那一方, 让路的应该是自己。绝不打断别人。
        if (((Get-Date) - $lastPeek).TotalSeconds -ge 30) {
            $lastPeek = Get-Date
            $kids = Get-MyKidPids
            $foreign = Get-Transcriber | Where-Object { $kids -notcontains $_.ProcessId }
            if ($foreign) {
                foreach ($f in $foreign) { Say "!! 轮中出现别的转写进程 PID $($f.ProcessId) —— $($f.CommandLine)" }
                Say "!! GPU 上同时只许一个转写实例 -> 本轮立刻让路(只结束自己的子进程, 不碰别人)"
                foreach ($k in $kids) { try { Stop-Process -Id $k -Force -ErrorAction Stop } catch { } }
                $yielded = $true
            }
        }
        # 单轮硬上限(兜"某一轮卡死"): 同样只动自己的子进程。
        if (((Get-Date) - $t0).TotalMinutes -ge $KillAfterMin) {
            $kids = Get-MyKidPids
            foreach ($k in $kids) {
                Say "!! 单轮超过 $KillAfterMin 分钟 -> 结束本轮转写 PID $k(已写完的 batch-out 不受影响)"
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
$commitArgs = @($PickPy, '--commit', '--src', $src, '--list', $listFile)
if ($code -ne 0) { $commitArgs += '--done-only' }
# 环境故障(全失败且零产出) -> **一个字都不记**, 这批原样留给下一轮重跑(见上面 $nFail/$nOk 的说明)。
$envBroken = ($nFail -gt 0 -and $nOk -le 0 -and $nNew -le 0)
if ($envBroken) {
    Say "!! 本轮 $nFail 个目录**全部失败**、0 个正常处理、产出 0 份 —— 判定为环境故障, **不记账**(记账=把这批永久跳过)"
    Say "!! 先看日志里每个失败行的异常类型(如 ModuleNotFoundError = 解释器缺依赖), 修好再来。"
}
else {
    $commitOut = & $Py @commitArgs 2>&1
    foreach ($l in $commitOut) { Say "  $l" }
}

# 首/小时: 只认 batch-out 的净增(它就是本轮的产出), 语料净增要等 finalize/parse 才算得准 —— 分开报。
$perHour = if ($mins -gt 0.2) { [math]::Round($nNew * 60.0 / $mins, 1) } else { 0 }
Say ("  << 退出码 $code · 用时 $mins 分钟 · 本轮 batch-out 净增 {0} 份 ({1}/首小时) · 语料 scores 净增 {2} 份" -f $nNew, $perHour, $nScores)
Say ("     正常处理 {0} 个 · 失败 {1} 个 · 磁盘余量 {2:N2} GiB · batch-out 累计 {3} 份 · 语料累计 {4} 份" -f `
        $nOk, $nFail, ((Get-PSDrive D).Free / 1GB), $afterOut, $afterScores)
if ($yielded) {
    Say "=== 看门狗结束(退出码 0, 轮中让路给别的转写实例) ==="
    exit 0
}
if ($envBroken) {
    Say "=== 看门狗结束(退出码 3, 环境故障: 全失败零产出, 未记账) ==="
    exit 3
}
Say "=== 看门狗结束(退出码 $code) ==="
exit $code
