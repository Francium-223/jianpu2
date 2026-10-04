# -*- coding: utf-8 -*-
# 命令行工具的冒烟自检(Windows 原生版, 与 tools/check_tools.sh 同一目的)。
#
# 为什么要它: 工具都 import jianpu-db/score.py 或 linkurl.py, 那两份是"唯一实现";
# 改了它们很容易把整个工具链 import 崩, 而平时没人跑。本机没有 bash, 原来那份 .sh 跑不了
# —— 2026-09-28 实测 `bash` 不在 PATH, 于是"工具链能不能 import"这件事在 Windows 上
# 一直没人验, 而我这一晚改了 17 个工具(正是最该验的时候)。
#
# 用法:
#   pwsh -File tools/check_tools.ps1              # 跑清单里那些
#   pwsh -File tools/check_tools.ps1 -All         # 跑 tools/*.py 全部(慢, 会拉起 torch 等重依赖)
$ErrorActionPreference = 'Continue'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $Here
Set-Location $Root

# 与 check_tools.sh 同一份清单(2026-09-25 换成了真实存在的文件名)
$Curated = @(
    'add_link', 'propose_tags', 'harvest_artists', 'refine_titles_from_pages', 'audit_corpus_quality',
    'quarantine_short_scores', 'audit_arrangements', 'verify_source_urls', 'corpus_fingerprint',
    'coverage_gap', 'verify_crawl_matches', 'slice_systems', 'audit_melody_clones',
    'check_transcribe_ready', 'audit_meter', 'check_images', 'set_artists',
    'mbid_lookup', 'transcribe', 'melody_search',
    'crawl_jianpujia', 'crawl_jianpucn', 'crawl_qupu123', 'crawl_batch_jianpujia',
    'crawl_jianpucn_by_title', 'crawl_jianpujia_search', 'check_source_links',
    'queue_from_crawl', 'batch_transcribe_queue', 'fix_residual_titles',
    'corpus_index', 'check_corpus_index',
    'detect_sections', 'propose_title_cleanup', 'fix_image_dir_entities',
    'check_tools', 'check_sideeffects', 'check_jptok_parity', 'verify_taglogic_all',
    'audit_dupes', 'audit_purity2', 'qa_corpus', 'experiment_impure_sample'
)

$all = Get-ChildItem -LiteralPath $Here -File -Filter *.py |
    Where-Object { $_.BaseName -notlike '_*' } | ForEach-Object { $_.BaseName }
$names = if ($args -contains '-All') { $all } else { $Curated | Where-Object { $all -contains $_ } }

$fail = @()
$ok = 0
$skipped = @()
$timeoutSec = 25          # 每个工具最多给 25 秒
foreach ($n in ($names | Sort-Object)) {
    $path = Join-Path $Here "$n.py"
    # ---- 第一步: **静态**语法检查(永远安全) ----
    $syn = & py -3.13 -c "import ast,sys; ast.parse(open(sys.argv[1],encoding='utf-8').read())" $path 2>&1
    if ($LASTEXITCODE -ne 0) {
        $fail += [pscustomobject]@{ tool = $n; code = 'SYNTAX'; why = ("$syn" -split "`n" | Select-Object -Last 1) }
        continue
    }
    # ---- 第二步: 只有**声明了 --help 的工具**才真的执行 ----
    # ⚠ 2026-09-28 血案: 原来对所有工具都跑 `--help`。而有一批工具**没有 argparse、也没有 --help 保护**,
    #   于是 `--help` 被当成正常参数、**工具真的跑起来**:
    #     * `autopilot.py` 进入"等没有 python 进程"的循环 -> 空等一小时, 把整条冒烟自检卡死;
    #     * `add_copyright.py` 真跑了一遍 -> **改写了 266 个草稿**的 copyright 行;
    #     * `bench_batch.py` 真跑起来 -> 会加载模型重转写(和转写流水线抢 GPU)。
    #   "用 --help 探测工具链"这个做法本身就是**有副作用**的, 只能对声明支持它的工具用。
    $src = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    $dq = [char]34
    # 声明了"只读入口"的三种写法都算: argparse / 自己的 --help 判断 / 统一的 guard_help(__doc__)
    # (2026-09-28 起 497 个工具都接了 guard.py, 所以现在几乎不会再跳过。)
    $declaresHelp = ($src -match 'argparse') -or ($src.Contains("'--help'")) -or
        ($src.Contains($dq + '--help' + $dq)) -or ($src -match 'guard_help\(')
    if (-not $declaresHelp) {
        $skipped += $n
        continue
    }
    $so = Join-Path $env:TEMP ("ctool_" + $n + ".out")
    $se = Join-Path $env:TEMP ("ctool_" + $n + ".err")
    $p = Start-Process -FilePath 'py' -ArgumentList '-3.13', "tools/$n.py", '--help' `
        -WorkingDirectory $Root -RedirectStandardOutput $so -RedirectStandardError $se `
        -NoNewWindow -PassThru
    if (-not $p.WaitForExit($timeoutSec * 1000)) {
        try { $p.Kill($true) } catch { }
        $fail += [pscustomobject]@{ tool = $n; code = 'TIMEOUT'; why = "超过 $timeoutSec 秒没退出" }
        Remove-Item $so, $se -Force -EA SilentlyContinue
        continue
    }
    $out = (Get-Content -LiteralPath $so -Raw -EA SilentlyContinue) + (Get-Content -LiteralPath $se -Raw -EA SilentlyContinue)
    $code = $p.ExitCode
    Remove-Item $so, $se -Force -EA SilentlyContinue
    if ($code -ne 0 -or $out -match 'Traceback|ModuleNotFoundError|ImportError') {
        $first = ($out -split "`n" | Where-Object { $_ -match 'Error|error' } | Select-Object -First 1)
        $fail += [pscustomobject]@{ tool = $n; code = $code; why = ("$first").Trim() }
    } else { $ok++ }
}

Write-Host (("工具冒烟: 语法 OK 且 --help 正常 {0} / 检查 {1}; 跳过(没有 --help 保护) {2}") -f $ok, @($names).Count, @($skipped).Count)
if (@($skipped).Count) {
    Write-Host ("  跳过的: " + (($skipped | Sort-Object) -join ', '))
    Write-Host "  (这些工具没有 argparse/--help 保护, 用 --help 探测会让它们真跑起来 —— 见脚本里的血案注释)"
}
if ($fail.Count) {
    Write-Host "**坏了这些:**"
    $fail | Format-Table -AutoSize | Out-String | Write-Host
    exit 1
}
Write-Host "全部通过(语法 + 声明了 --help 的那些)"

# 功能自测: 爬虫"避抓"判据(与 check_tools.sh 里那条同一目的) —— 临时语料里验
# "已存在->跳过 / 不存在->抓"。2026-10-04 之前只看 images/ 目录, 一轮 1764 条转写队列
# 几乎全是语料里早有的曲子(净增 1 首), 所以把这条判据钉在冒烟自检里。
if (Test-Path (Join-Path $Here 'check_corpus_index.py')) {
    Write-Host ""
    Write-Host "=== 功能: 爬虫避抓判据(临时语料) ==="
    $c = & py -3.13 (Join-Path $Here 'check_corpus_index.py') 2>&1
    ($c | Select-Object -Last 1) | Write-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Host "**避抓判据自检失败**"
        $c | Select-Object -Last 8 | Write-Host
        exit 1
    }
}
exit 0
