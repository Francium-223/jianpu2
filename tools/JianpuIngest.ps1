<#
.SYNOPSIS
    语料入库看门狗 —— 计划任务每 1 小时唤起一次, 把 `batch-out/` 的新产物**真的并进语料**。

.DESCRIPTION
    为什么要有它(2026-10-06 实测): 转写侧已经把产物写进 `batch-out/`, 抓取与转写两条链都有看门狗,
    **唯独"入库"这一环没人跑** —— 于是 `jianpu-db/scores` 停在 12,368 份、`data.jsonl` 停在 11,876 首,
    新谱全躺在 `jianpu-db-out/scores/`(覆盖率报告里叫"待入库")里没人管。

    入库是三段(缺一不可, 顺序也不能换):
      ① `tools/finalize.py`           纯度重扫 -> 移出非纯/高念白/空谱 -> pick_best 择优 ->
                                      `to_jianpu_db` 把 `batch-out/` 重建成 `jianpu-db-out/scores/`
      ② `tools/import_finished_scores.py --apply`   成品 -> `jianpu-db/scores/`(**只拷不覆盖、只拷不删**)
      ③ `parse_scores.py`(在 jianpu-db 里跑)       重出 `data.jsonl`
    然后**提交并推远端**(作者 Francium-223, 末行 Co-authored-by: deepseek-ai)。

    ⚠ **③ 从"等 CI 重出"改成"本机直接出 data.jsonl"**(2026-10-06 深夜, 实测):
      * 旧说法"本机 Windows 跑不完 parse_scores"**已过期** —— 病根是 `by_title` 拿"带反斜杠的曲名"
        当目录名(`os.mkdir("by_title\\A\\C\\A Chinese Aire \\ John...")`), 兄弟仓库 jianpu-db 的
        `e90937aa7 链接路径逐段清洗` 修掉之后, 本机实测 **exit 0 / 631.8 秒 / 12,085 行**,
        与 CI 的 `243ee546d` 版 **逐行全同(12085/12085)**。
      * 所以本轮的 `data.jsonl` 是**本机 ③ 亲手重出的**, CI 退成两层角色: ①**交叉核对**(它重出一版,
        与本机那版逐字节比对, 见下面 git 段里的 `data.jsonl` blob 核对); ②**兜底**(本机 ③ 万一又失败).
      * ⚠ **本机绝不 push `by_*`**: Windows 上有 9 条"只差大小写"的路径是**平台固有**的, 本机建出来的
        与 CI 的不逐字节相同 —— 提交那步只 `git add -- scores data.jsonl`, `by_*` 留给 CI 重建。

    ⚠ **为什么 ① 要独占机器**(这是本脚本一半篇幅的由来, 全是实测):
      * `finalize.py` 的 5) 会调 `to_jianpu_db.py --meter`。它**绝大多数**成品名能在
        `jianpu-db-out/scores-prev/` 里认回旧拍号(实测 2026-10-06 20:50: 9,784 份 batch-out 里
        9,582 份直接复用, **149 份**没有旧拍号)—— 但那 149 份会 `import jp_transcribe` 并
        `_model.to("cuda")`, 也就是**往 cuda:0 载第二份 Qwen3-VL-2B**。
      * 这台机器的硬前提: 显存 7,937 / 8,188 MiB(只剩 ~250 MiB)、内存空闲 0.2~0.8 GiB。
        `from_pretrained` 先把权重读进内存 —— 5 GB 进 0.5 GiB = 整机换页, 转写会被拖死;
        显存那一步大概率 CUDA OOM, 而 OOM 被 `to_jianpu_db` 的 `except` 吞成"拍号识别失败",
        新谱拍号被默默写成 4/4, 而且会被 `scores-prev` 复用**固化**下去(下一轮再也不认)。
      * 所以 ① **必须**在没有转写进程、且显存空闲时跑; ②③ 是纯 CPU/IO, 随时可跑。
      * `transcribe_source.py` 写 `batch-out/*.txt` 用的是 `open(w)` 直写(不是临时文件 + 改名),
        并发时 `kind_detect2` 可能读到写了一半的谱, 判成"非纯简谱"移进 `batch-out-bad/` —— 又一条
        必须等转写停下的理由。

    ⚠ **与 `jp_mandopop_absorb3` 的分工**(两条链都会 finalize, 绝不许同时跑):
      策略 = "**看它在不在跑, 在跑就本轮不做 ①**"(用户 2026-10-06 指定的方案 A):
        * `jp_mandopop_absorb3` 是 Running -> 本轮不跑 ①(它自己收尾时就会 finalize, 且它的
          收尾还带 coverage/qa/flag_odd_names, 那些也会动成品目录, 撞上就是两个全库重建撞车);
        * 它不在跑、但**离下次触发不足 `-HoldoffMin`(默认 90 分钟)** -> 也不跑 ①
          (实测它的"整片"轮 1h21m~6h41m, 从启动到它自己 finalize 最短 28 分钟;
           我们的 ① 实测 48~91 分钟 —— 留 90 分钟起步的余量, 就不会把尾巴拖进它的 finalize);
        * 依据: 实测 `jp_mandopop_absorb3` 完成时刻与下次启动之间有 2min~5h59m 的空档,
          所以"只挑空档跑 ①"是能跑到的, 不需要去改动那条正在跑的链(更不该去抢它的 GPU)。
      ②③ 不受这个闸限制 —— 它只读成品目录、只往语料里**新增**文件, 与 mandopop 的转写/finalize
      没有共享写点(且 ②③ 与 `finalize.py` 之间的互斥由下面的"DB 写者"闸保证)。

    ⚠ **它不能打断转写**: 拿到 `train-work/ingest.lock` 之后, 若还有转写进程在场, 就**等它自己跑完**
    (上限 `-WaitTranscribeMin`, 默认 45 分钟; 转写看门狗单轮硬上限 40 分钟, 所以等得到)。
    与此同时 `tools/transcribe_watchdog.ps1` 里加了一道"入库闸": 见到 `ingest.lock` 的 PID 还活着
    就让路 —— 否则我们在跑 ① 时它会照旧起转写, 又把 GPU 抢回去。

.PARAMETER Status
    只报现状(计划任务状态、锁、各目录份数、上次记账、日志尾巴), 什么都不写。

.PARAMETER DryRun
    只跑判据并打印"本轮会做什么", 不写文件、不拿锁、不提交。

.PARAMETER Force
    忽略"batch-out 没有变化"的秒退判据, 强行走完一轮(调试用)。

.PARAMETER WaitTranscribeMin
    拿到锁之后, 等在场转写自然结束的上限(分钟)。默认 45。

.PARAMETER HoldoffMin
    离 `jp_mandopop_absorb3` 下次触发至少留这么多分钟才敢跑 ①。默认 90。0 = 不设这道闸。

.PARAMETER LogDir
    日志目录(默认 `D:\Documents_D\_analysis\ingest_stock`)。按天一个文件, **只追加**。

.EXAMPLE
    pwsh -NoProfile -File tools\JianpuIngest.ps1                 # 跑一轮(计划任务就是这么调)
    pwsh -NoProfile -File tools\JianpuIngest.ps1 -Status         # 只看现状
    pwsh -NoProfile -File tools\JianpuIngest.ps1 -DryRun         # 只判据, 不写
    pwsh -NoProfile -File tools\JianpuIngest.ps1 -Force          # 忽略"没变化"的秒退
#>
[CmdletBinding()]
param(
    [switch]$Status,
    [switch]$DryRun,
    [switch]$Force,
    [int]$WaitTranscribeMin = 45,
    [int]$HoldoffMin = 90,
    [int]$FinalizeMinBacklog = 600,
    [int]$FinalizeStaleHours = 8,
    [string]$LogDir = 'D:\Documents_D\_analysis\ingest_stock',
    [string]$Python = ''
)

$ErrorActionPreference = 'Continue'
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
}
catch { }
$env:PYTHONIOENCODING = 'utf-8'

$Root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $Root 'tools\finalize.py'))) { $Root = 'D:\Documents_D\jianpu2' }
$BatchOut = Join-Path $Root 'batch-out'
$FinScores = Join-Path $Root 'jianpu-db-out\scores'
$PrevScores = Join-Path $Root 'jianpu-db-out\scores-prev'
$Lock = Join-Path $Root 'train-work\ingest.lock'
$StateFile = Join-Path $Root 'train-work\ingest_state.json'
$DB = 'D:\Documents_D\jianpu-db'
$DBScores = Join-Path $DB 'scores'
$Remote = 'Francium-223'
$Branch = 'master'
$Author = 'Francium-223 <wizardofyendor@outlook.com>'
$CoAuthor = 'Co-authored-by: deepseek-ai <service@deepseek.com>'

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Log = Join-Path $LogDir ('ingest_{0:yyyyMMdd}.log' -f (Get-Date))

function Say([string]$m) {
    $line = '[{0:yyyy-MM-dd HH:mm:ss}] {1}' -f (Get-Date), $m
    Write-Host $line
    Add-Content -Path $Log -Value $line -Encoding utf8      # 追加, 绝不覆盖
}

# ── 解释器: 必须能 `import torch, transformers` ─────────────────────────────────
# 照抄 `transcribe_watchdog.ps1` 的血案注释: PATH 上的 `python` 是 3.14, 没装 torch;
# `finalize.py` 的 5) 可能 `import jp_transcribe`(要 torch), 猜错的代价是整轮静默报废。
function Test-IngestPython([string]$exe) {
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
    foreach ($p in $cands) { if (Test-IngestPython $p) { return $p } }
    return ''
}

function Get-LockPid([string]$path) {
    if (-not (Test-Path $path)) { return 0 }
    $txt = (Get-Content $path -Raw -ErrorAction SilentlyContinue)
    if ($txt) { $txt = $txt.Trim() }
    $n = 0
    if ([int]::TryParse($txt, [ref]$n)) { return $n }
    return 0
}
function Test-PidAlive([int]$pid_) {
    if ($pid_ -le 0) { return $false }
    return [bool](Get-Process -Id $pid_ -ErrorAction SilentlyContinue)
}
function Get-CmdProcs([string]$pattern) {
    Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='py.exe' OR Name='pythonw.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match $pattern }
}
# 转写侧(与 transcribe_watchdog.ps1 的判据一致)。
function Get-Transcriber { Get-CmdProcs '(transcribe_source|jp_transcribe|batch_transcribe|transcribe)\.py' }
# **真的会写 scores/ 与 data.jsonl** 的那些(判据抄 rebuild_when_idle.py 的 DB_WRITERS)。
function Get-DbWriter { Get-CmdProcs 'finalize|to_jianpu_db|parse_scores|import_finished|db_to_jsonl|rebuild_when_idle|kugou_pipeline' }

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

function Count-Files([string]$Dir, [string]$Filter) {
    if (-not (Test-Path $Dir)) { return 0 }
    return (Get-ChildItem -Path $Dir -File -Filter $Filter -ErrorAction SilentlyContinue).Count
}

# `batch-out` 的指纹: 文件名 + 字节数。用 **名字集合** 而不是"份数", 因为 finalize 会把非纯谱
# **移出** batch-out(份数会掉), 只数份数会把"隔离掉一批 + 转出一批"误判成没变化。
function Get-BatchHash {
    $lines = Get-ChildItem -Path $BatchOut -File -Filter '*.txt' -ErrorAction SilentlyContinue |
        Sort-Object Name | ForEach-Object { '{0}|{1}' -f $_.Name, $_.Length }
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    return ([System.BitConverter]::ToString($md5.ComputeHash($bytes)) -replace '-', '').ToLower()
}

function Read-State {
    $d = @{ batch_hash = ''; pending_push = $false; corpus = 0; fin = 0; at = ''; last_seconds = 0;
            data_blob = ''; data_lines = 0; data_ci_match = ''; pushed_head = '' }
    if (Test-Path $StateFile) {
        try {
            $j = Get-Content $StateFile -Raw -Encoding utf8 | ConvertFrom-Json
            foreach ($k in @($d.Keys)) { if ($null -ne $j.$k) { $d[$k] = $j.$k } }
        }
        catch { }
    }
    return $d
}
function Write-State($d) {
    ($d | ConvertTo-Json) | Set-Content -Path $StateFile -Encoding utf8
}

function Get-LineCount([string]$p) {
    if (-not (Test-Path $p)) { return 0 }
    $n = 0
    $r = New-Object System.IO.StreamReader($p)
    try { while ($null -ne $r.ReadLine()) { $n++ } } finally { $r.Close() }
    return $n
}

# 成品目录里"还没入库"的份数(**只读**: import_finished_scores 默认 dry-run, 一个字都不写)。
function Count-Importable {
    Push-Location $Root
    try {
        $out = & $Py -u tools\import_finished_scores.py 2>&1
        foreach ($l in $out) { if ("$l" -match '可导入\s+(\d+)\s+份') { return [int]$Matches[1] } }
        return -1
    }
    finally { Pop-Location }
}

# ── ① 的窗口闸 ────────────────────────────────────────────────────────────────
function Test-FinalizeWindow([bool]$quiet = $false) {
    $w = Get-DbWriter
    if ($w) { if (-not $quiet) { Say ("  ① 不可跑: 还有 DB 写者 {0} 个: {1}" -f @($w).Count, (@($w)[0].CommandLine).Trim()) }; return $false }
    $t = Get-ScheduledTask -TaskName 'jp_mandopop_absorb3' -ErrorAction SilentlyContinue
    if (-not $t) { if (-not $quiet) { Say '  ① 可跑(没有 jp_mandopop_absorb3 这个任务)' }; return $true }
    if ("$($t.State)" -eq 'Running') { if (-not $quiet) { Say '  ① 不可跑: jp_mandopop_absorb3 正在 Running(它收尾会自己 finalize)' }; return $false }
    if ($HoldoffMin -gt 0) {
        $next = (Get-ScheduledTaskInfo -TaskName 'jp_mandopop_absorb3' -ErrorAction SilentlyContinue).NextRunTime
        if ($next) {
            $min = [int](([datetime]$next - (Get-Date)).TotalMinutes)
            if ($min -lt $HoldoffMin) {
                if (-not $quiet) { Say ("  ① 不可跑: 离 jp_mandopop_absorb3 下次触发只剩 {0} 分钟(< {1} 分钟余量)" -f $min, $HoldoffMin) }
                return $false
            }
            if (-not $quiet) { Say ("  ① 可跑: 它没在跑, 离下次触发还有 {0} 分钟" -f $min) }
            return $true
        }
    }
    if (-not $quiet) { Say '  ① 可跑: 它没在跑, 且没有下次触发时间' }
    return $true
}

$Py = Resolve-Python
if (-not $Py) {
    Say '!! 找不到能 `import torch/transformers` 的 Python —— finalize 的拍号那步会静默降级, 本轮**不起**。'
    exit 3
}

if ($Status) {
    $t = Get-ScheduledTask -TaskName 'JianpuIngest' -ErrorAction SilentlyContinue
    if ($t) {
        $i = Get-ScheduledTaskInfo -TaskName 'JianpuIngest'
        '任务 JianpuIngest: {0} · Last {1} (码 {2}) · Next {3}' -f $t.State, $i.LastRunTime, $i.LastTaskResult, $i.NextRunTime
    }
    else { '任务 JianpuIngest: **还没注册**' }
    $lp = Get-LockPid $Lock
    '锁 {0} -> PID {1} ({2})' -f $Lock, $lp, $(if (Test-PidAlive $lp) { '活着' } else { '不存在/已死' })
    'batch-out txt {0} · 成品 {1} · 成品旧账本 {2} · 语料 {3} · data.jsonl {4} 行' -f `
        (Count-Files $BatchOut '*.txt'), (Count-Files $FinScores '*.txt'), (Count-Files $PrevScores '*.txt'), `
        (Count-Files $DBScores '*.txt'), (Get-LineCount (Join-Path $DB 'data.jsonl'))
    $st = Read-State
    '上次记账: at={0} corpus={1} fin={2} batch_hash={3} pending_push={4} last_seconds={5}' -f `
        $st.at, $st.corpus, $st.fin, $st.batch_hash, $st.pending_push, $st.last_seconds
    '上次 ③: data.jsonl {0} 行 · blob {1} · 与 CI 重出 {2} · 上轮推送 {3}' -f `
        $st.data_lines, $st.data_blob, $(if ($st.data_ci_match) { $st.data_ci_match } else { '(还没核对过)' }), `
        $(if ($st.pushed_head) { "$($st.pushed_head)".Substring(0, 8) } else { '(无记录)' })
    Get-Transcriber | ForEach-Object { '转写在跑: PID {0} {1}' -f $_.ProcessId, $_.CommandLine }
    Get-DbWriter | ForEach-Object { 'DB 写者在跑: PID {0} {1}' -f $_.ProcessId, $_.CommandLine }
    $g = Get-GpuUsedMiB
    '显存占用: {0} MiB' -f $(if ($null -eq $g) { '问不到' } else { $g })
    if (Test-Path $Log) { '--- 日志尾巴 ---'; Get-Content $Log -Tail 15 }
    exit 0
}

Say '=== JianpuIngest 唤起 ==='
$t00 = Get-Date
$st = Read-State
$hashNow = Get-BatchHash
$finBefore = Count-Files $FinScores '*.txt'
$dbBefore = Count-Files $DBScores '*.txt'
$linesBefore = Get-LineCount (Join-Path $DB 'data.jsonl')
$batchBefore = Count-Files $BatchOut '*.txt'
Say ("现状: batch-out {0} 份 · 成品 {1} 份 · 语料 {2} 份 · data.jsonl {3} 行 · 显存 {4} MiB" -f `
        $batchBefore, $finBefore, $dbBefore, $linesBefore, $(if ($null -eq (Get-GpuUsedMiB)) { '?' } else { Get-GpuUsedMiB }))

$needFinalize = ($hashNow -ne $st.batch_hash)
# ① 值不值得跑: `batch-out` 比成品多出来的部分 = "还没变成成品的新产物"。mandopop 链每一轮收尾
# **自己就会 finalize**(实测轮长 1h21m~6h41m), 所以成品平时是新的; 我们的 ① 是"它没干/落后太多"
# 时的补位。一次 ① 实测 48~91 分钟, 而这段时间 GPU 本可以转 100~200 份 —— 每小时都跑一次 ①
# 就是拿转写换"成品提前几小时变新", 不划算。所以加这道闸: 只有积压够大才跑。
$backlog = $batchBefore - $finBefore
# 兜底那一半: 万一 mandopop 链停了/被改了, "很久没人 finalize"也要能被我们兜住。
# 判据用 `train-work/pick_best.tsv` 的 mtime —— finalize 第 3 步每次都写它。
$staleH = -1
try { $staleH = ((Get-Date) - (Get-Item (Join-Path $Root 'train-work\pick_best.tsv')).LastWriteTime).TotalHours } catch { }
$finalizeWorth = ($backlog -ge $FinalizeMinBacklog) -or ($staleH -lt 0 -or $staleH -ge $FinalizeStaleHours)
$importable = Count-Importable
$needImport = ($importable -gt 0)

# ── 秒退: ① 不划算(成品还新)、成品也没有待入库的、且没有欠着的提交 ────────────────
if (-not $Force -and -not $DryRun -and -not $finalizeWorth -and -not $needImport -and -not $st.pending_push) {
    Say ("秒退: 成品还新(积压 {0} < 门槛 {1}) 且 成品可导入 0 份 且 无欠提交 —— 本轮无事。({2} 秒)" -f `
            $backlog, $FinalizeMinBacklog, [int]((Get-Date) - $t00).TotalSeconds)
    Say '=== JianpuIngest 结束(退出码 0) ==='
    exit 0
}
Say ("判据: 需要 finalize = {0} (指纹 {1} vs 记账 {2}) · 成品可导入 {3} 份 · 欠提交 = {4}" -f `
        $needFinalize, $hashNow.Substring(0, 8), "$($st.batch_hash)".PadRight(8).Substring(0, 8), $importable, $st.pending_push)
Say ("  ① 值不值得: 积压(batch-out {0} - 成品 {1}) = {2} 份(门槛 {3}) · 上次 finalize {4} 小时前(门槛 {5}h) -> {6}" -f `
        $batchBefore, $finBefore, $backlog, $FinalizeMinBacklog, `
        $(if ($staleH -lt 0) { '无记录' } else { '{0:N1}' -f $staleH }), $FinalizeStaleHours, `
        $(if ($finalizeWorth) { '值得' } else { '**不值得(成品还新)**' }))

# ── 单实例(照 `rebuild_when_idle.py` 的 .lock 先例): 两个实例同时 parse 会写坏 data.jsonl ──
$lp = Get-LockPid $Lock
if (Test-PidAlive $lp) { Say "跳过: 已有一个入库实例在跑(PID $lp) —— 两个 parse_scores 并发会写坏 data.jsonl。"; Say '=== JianpuIngest 结束(退出码 0) ==='; exit 0 }
if ($lp) { Say "锁里 PID $lp 已死 = 陈旧锁, 清掉"; Remove-Item -Path $Lock -Force -ErrorAction SilentlyContinue }

$canFinalize = $false
if (($needFinalize -and $finalizeWorth) -or $Force) {
    Say '--- 判 ① 的窗口 ---'
    $canFinalize = Test-FinalizeWindow
}
elseif ($needFinalize) { Say "① 本轮跳过: 积压 $backlog 份 < 门槛 $FinalizeMinBacklog 份(成品还新, 留给它自己的 finalize)" }
else { Say '① 本轮不需要(成品已跟上 batch-out), 只做 ②③' }

if ($DryRun) {
    Say ("[dry-run] 本轮会做: ① finalize = {0}; ② import {1} 份; ③ parse_scores; 之后提交推送。" -f `
            $canFinalize, [math]::Max($importable, 0))
    Say '=== JianpuIngest 结束(退出码 0, dry-run 没写任何东西) ==='
    exit 0
}

# ── 拿锁 ─────────────────────────────────────────────────────────────────────
Set-Content -Path $Lock -Value $PID -Encoding ascii
$t00 = Get-Date
$released = $false
function Release-Lock {
    if (-not $script:released) {
        Remove-Item -Path $Lock -Force -ErrorAction SilentlyContinue
        $script:released = $true
    }
}

try {
    # ⚠ **DB 写者闸**(整轮): 上面判 ① 时查过一次, 但 ② 也必须查 ——
    #   `jp_mandopop_absorb3` 的收尾 `finalize.py` 会把 `jianpu-db-out/scores/` **整体重建**
    #   (它先 rmtree scores-prev、再把成品全搬走、再重写)。实测它的收尾占它一轮的 ~25% 时间
    #   (85 分钟 / 4~6.5 小时), 而 ② 是"读成品 -> 拷进语料", 撞上就会**读到写了一半的谱**,
    #   而导入是"只拷不覆盖" -> 那份残缺谱会**永久留在语料里**。所以见到任何 DB 写者就整轮退出。
    $w = Get-DbWriter
    if ($w) {
        Say ("本轮放弃: 有 DB 写者 {0} 个正在跑, 成品目录可能正被重建 —— 现在导入会读到写了一半的谱。" -f @($w).Count)
        foreach ($p in $w) { Say ("    PID {0} {1}" -f $p.ProcessId, $p.CommandLine) }
        Say '=== JianpuIngest 结束(退出码 0, 下一轮再来) ==='
        Release-Lock
        exit 0
    }

    if ($canFinalize) {
        # 拿到锁之后转写看门狗不再起新转写; 现在等**已经在场**的那个自己跑完(绝不打断它)。
        $deadline = (Get-Date).AddMinutes($WaitTranscribeMin)
        $tWait = Get-Date
        while ((Get-Transcriber) -and (Get-Date) -lt $deadline) {
            $r = @(Get-Transcriber)
            Say ("  等在场转写自然结束: PID {0} (已等 {1} 分钟, 上限 {2} 分钟)" -f $r[0].ProcessId, [int]((Get-Date) - $tWait).TotalMinutes, $WaitTranscribeMin)
            Start-Sleep -Seconds 30
        }
        $left = @(Get-Transcriber)
        if ($left) {
            Say ("  ① 放弃: 等了 {0} 分钟仍有转写(不改它的任何东西) —— 本轮只做 ②③, 下一轮再试。" -f $WaitTranscribeMin)
            $canFinalize = $false
        }
        else {
            Say ("  在场转写已结束(等了 {0} 秒)" -f [int]((Get-Date) - $tWait).TotalSeconds)
            if (-not (Test-FinalizeWindow)) { $canFinalize = $false }
            $g = Get-GpuUsedMiB
            if ($canFinalize -and $null -ne $g -and $g -gt 3000) {
                Say "  ① 放弃: 显存仍占 $g MiB(拍号模型载不进去) —— 本轮只做 ②③"
                $canFinalize = $false
            }
        }
    }

    $t0 = Get-Date
    if ($canFinalize) {
        Say '--- ① finalize(纯度重扫 -> 移出 -> 择优 -> 重建成品) ---'
        Push-Location $Root
        try { & $Py -u tools\finalize.py 2>&1 | ForEach-Object { Say "  | $_" }; $rc1 = $LASTEXITCODE }
        finally { Pop-Location }
        Say ("  ① 退出码 {0} · 用时 {1}s" -f $rc1, [int]((Get-Date) - $t0).TotalSeconds)
        if ($rc1 -eq 0) {
            # finalize 会把非纯谱移出 batch-out -> 指纹必须**跑完之后**再取, 否则下一轮会误判"又变了"
            $st.batch_hash = Get-BatchHash
        }
        else { Say '  !! ① 没跑成功 —— 不记指纹(下一轮会重试), ②③ 照跑' }
    }

    Say '--- ② 并入语料(只拷不覆盖、只拷不删) ---'
    Push-Location $Root
    try { & $Py -u tools\import_finished_scores.py --apply 2>&1 | ForEach-Object { Say "  | $_" }; $rc2 = $LASTEXITCODE }
    finally { Pop-Location }
    Say ("  ② 退出码 {0}" -f $rc2)

    Say '--- ③ 重出 data.jsonl(本机主力; CI 只做交叉核对与兜底) ---'
    $t3 = Get-Date
    Push-Location $DB
    try {
        # 全量跑要 ~10 分钟(实测 631.8 秒 / 12,085 行), 所以**只看尾巴**别把几万行刷进日志。
        & $Py -u parse_scores.py 2>&1 | Select-Object -Last 3 | ForEach-Object { Say "  | $_" }
        $rc3 = $LASTEXITCODE
    }
    finally { Pop-Location }
    $sec3 = [int]((Get-Date) - $t3).TotalSeconds
    Say ("  ③ 退出码 {0} · 用时 {1}s" -f $rc3, $sec3)
    if ($rc3 -eq 0) {
        # ③ 成功的**证据**要当场落下来(行数 + 内容指纹), 否则几轮之后没人说得清
        # "本机这一版"和"CI 那一版"是不是同一份。
        $linesNow = Get-LineCount (Join-Path $DB 'data.jsonl')
        $sha3 = ("$(& git -C $DB hash-object data.jsonl 2>$null)").Trim()
        Say ("  << ③ 本机重出成功: data.jsonl {0} -> {1} 行 · blob {2} · 用时 {3}s" -f `
                $linesBefore, $linesNow, $sha3.Substring(0, [math]::Min(12, $sha3.Length)), $sec3)
    }
    else {
        # 兜底分支(不再是"常态", 是"万一"): 本机又跑不完时, 别去改 jianpu-db 的代码或曲谱内容"凑过"这一步,
        # 只把 parse_scores 半路 rmtree 掉的 by_* 还原, 然后如实记账 —— data.jsonl 由推送后的 CI 重出。
        Say '  !! ③ 没成功: data.jsonl/by_* 本轮没重出 —— 语料新增的 scores 照常提交, 由 CI 重出 data.jsonl。'
        Say '     (先看 $DB\parse_scores 的报错是不是又一次"路径里有反斜杠"这类 Windows 固有限制)'
        Push-Location $DB
        try { & git checkout -- . 2>&1 | Out-Null } finally { Pop-Location }
    }

    $dbAfter = Count-Files $DBScores '*.txt'
    $linesAfter = Get-LineCount (Join-Path $DB 'data.jsonl')
    $finAfter = Count-Files $FinScores '*.txt'
    $seconds = [int]((Get-Date) - $t0).TotalSeconds
    $lineTxt = if ($rc3 -eq 0) { "$linesBefore -> $linesAfter 行(本机 ③ 重出)" } else { "$linesBefore 行(本机未重出, 由 CI 重出)" }
    Say ("  << 本轮: 语料 {0} -> {1} 首(+{2}) · data.jsonl {3} · 成品 {4} -> {5} 份 · batch-out 现值 {6} 份 · 用时 {7}s" -f `
            $dbBefore, $dbAfter, ($dbAfter - $dbBefore), $lineTxt, $finBefore, $finAfter, (Count-Files $BatchOut '*.txt'), $seconds)

    # ── 提交并推远端 ──────────────────────────────────────────────────────────
    # 只 add 数据文件(scores/ 与 data.jsonl)。**绝不**碰 jianpu2 的文档(SKILL.md / 醒来汇报_v10.md
    # 在另一个仓库里, 本脚本一个字都不动它们)。不 amend、不 force; push 前 fetch + rebase。
    $pushOk = $false
    $msg = "data(scores): 语料 {0} -> {1} 首(自动入库)" -f $dbBefore, $dbAfter
    Push-Location $DB
    try {
        & git add -- scores data.jsonl 2>&1 | ForEach-Object { Say "  | git $_" }
        $staged = (& git diff --cached --name-only) -join ' '
        $pushOk = $true
        if (-not $staged) {
            # 没有新东西可提交**不等于**没有欠推的提交(上一轮 push 断网时就是这种局面)
            Say '  git: 没有可提交的数据变化(可能全是已入库过的)'
        }
        else {
            & git -c "user.name=Francium-223" -c "user.email=wizardofyendor@outlook.com" `
                commit --author $Author -m $msg -m $CoAuthor 2>&1 | ForEach-Object { Say "  | git $_" }
            $rcC = $LASTEXITCODE
            if ($rcC -ne 0) { Say "  !! git commit 失败(码 $rcC)"; $pushOk = $false }
        }
        if ($pushOk) {
            & git fetch --quiet $Remote 2>&1 | ForEach-Object { Say "  | git $_" }
            # ── ③ 的"与 CI 重出结果一致"核对: 拿**同一个 blob 哈希**比 ─────────────────
            # 比的是**上一轮**本机 ③ 那份 data.jsonl(记账里的 `data_blob`)与 CI 收到那次推送后
            # 重出的那一版: CI 每收到一次推送都会重出并用 bot 提交推回来(它 `git add -A`,
            # 而我们不推 by_*), 于是远端 HEAD 会比"我们推的那版"新 —— 这时比 blob 才有意义。
            # ⚠ **绝不能**拿"本轮刚跑出来的 blob"和推送**前**的远端比: 那两版对应的语料本来就不同
            #   (本轮 ② 刚并进新谱), 必然不等, 只会误报 —— 2026-10-07 00:58 实测踩到过。
            if ($st.data_blob -and $st.pushed_head) {
                $pushedShort = "$($st.pushed_head)".Substring(0, 8)
                $remoteHead = ("$(& git rev-parse ("{0}/{1}" -f $Remote, $Branch) 2>$null)").Trim()
                $remoteBlob = ("$(& git rev-parse ("{0}/{1}:data.jsonl" -f $Remote, $Branch) 2>$null)").Trim()
                if ($remoteHead -and $remoteHead -eq "$($st.pushed_head)") {
                    # 远端还停在我们上一轮推的那版 -> CI 还没跑完(CI 重出后一定会多一个提交)
                    $st.data_ci_match = "CI 还没重出(远端仍是上轮推的 $pushedShort)"
                    Say ("  ③ 与 CI 重出结果核对: 待定 —— 远端 HEAD 仍是上轮推的 {0}, CI 还没推回重出版" -f $pushedShort)
                }
                elseif ($remoteBlob) {
                    if ($remoteBlob -eq "$($st.data_blob)") {
                        $st.data_ci_match = "一致"
                        Say ("  ③ 与 CI 重出结果核对: **一致** —— 上轮本机 blob {0} == CI 重出 {1}(远端 HEAD {2})" -f `
                                "$($st.data_blob)".Substring(0, 8), $remoteBlob.Substring(0, 8), `
                                ("$(& git log -1 --format=%h%x20%an ("{0}/{1}" -f $Remote, $Branch) 2>$null)").Trim())
                    }
                    else {
                        $st.data_ci_match = "**不一致**"
                        Say ("  !! ③ 与 CI 重出结果核对: **不一致** —— 上轮本机 {0} vs CI {1} —— 看是不是 jptok 口径漂了" -f `
                                "$($st.data_blob)".Substring(0, 8), $remoteBlob.Substring(0, 8))
                    }
                }
            }
            $behind = 0
            $rv = ("$(& git rev-list --count "$Branch..$Remote/$Branch" 2>$null)").Trim()
            if ($rv -match '^\d+$') { $behind = [int]$rv }
            if ($behind -gt 0) {
                Say "  远端领先 $behind 个提交 -> git rebase $Remote/$Branch"
                & git rebase --autostash "$Remote/$Branch" 2>&1 | ForEach-Object { Say "  | git $_" }
                if ($LASTEXITCODE -ne 0) {
                    # 生成物(data.json / data.jsonl / by_*)两边都被重出过, 冲突几乎必然。
                    # 它们**由 CI 在推送后自动重出**, 所以退一步: 只提交真正的新增 scores, 让 CI 重出生成物。
                    Say '  !! rebase 冲突(生成物两边都重出过) -> 退回"只提交新增 scores", 生成物交给 CI 重出'
                    & git rebase --abort 2>&1 | ForEach-Object { Say "  | git $_" }
                    & git reset --mixed HEAD~1 2>&1 | Out-Null
                    (& git diff --name-only) | ForEach-Object { & git checkout -- $_ }
                    & git add -- scores 2>&1 | Out-Null
                    & git -c "user.name=Francium-223" -c "user.email=wizardofyendor@outlook.com" `
                        commit --author $Author -m $msg -m $CoAuthor 2>&1 | ForEach-Object { Say "  | git $_" }
                    & git rebase "$Remote/$Branch" 2>&1 | ForEach-Object { Say "  | git $_" }
                }
            }
            $ahead = 0
            $av = ("$(& git rev-list --count "$Remote/$Branch..$Branch" 2>$null)").Trim()
            if ($av -match '^\d+$') { $ahead = [int]$av }
            if ($ahead -eq 0) { Say '  git: 本地没有待推提交(push 无事可做)' }
            else {
                & git push $Remote $Branch 2>&1 | ForEach-Object { Say "  | git $_" }
                if ($LASTEXITCODE -ne 0) {
                    Say '  !! push 被拒/断网 -> fetch + rebase 再推一次(不 force)'
                    & git fetch --quiet $Remote 2>&1 | Out-Null
                    & git rebase --autostash "$Remote/$Branch" 2>&1 | ForEach-Object { Say "  | git $_" }
                    & git push $Remote $Branch 2>&1 | ForEach-Object { Say "  | git $_" }
                }
                $pushOk = ($LASTEXITCODE -eq 0)
                # 记下"我们推上去的是哪个提交" —— 下一轮靠它判断远端有没有被 CI 重出过(见上面的核对)。
                if ($pushOk) { $st.pushed_head = ("$(& git rev-parse HEAD 2>$null)").Trim() }
            }
        }
        $head = ("$(& git rev-parse --short HEAD)").Trim()
        Say ("  git: HEAD {0} · push {1}" -f $head, $(if ($pushOk) { '成功/已是最新' } else { '**失败(留待下一轮重试, 不 force)**' }))
    }
    finally { Pop-Location }

    $st.pending_push = (-not $pushOk)
    $st.corpus = $linesAfter
    $st.fin = $finAfter
    $st.at = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $st.last_seconds = $seconds
    $st.data_lines = $linesAfter
    if ($sha3) { $st.data_blob = $sha3 }
    Write-State $st
    $code = if ($pushOk) { 0 } else { 4 }
    Say ("=== JianpuIngest 结束(退出码 {0}; 提交{1}; data.jsonl 与 CI 重出{2}) ===" -f `
            $code, $(if ($pushOk) { '已推' } else { '未推, 已记账待重试' }), `
            $(if ($st.data_ci_match) { $st.data_ci_match } else { '(本轮没核对)' }))
    if (-not $pushOk) { exit 4 }
}
finally {
    Release-Lock
}
