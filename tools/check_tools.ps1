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
    'detect_sections', 'propose_title_cleanup', 'fix_image_dir_entities',
    'check_tools', 'check_sideeffects', 'check_jptok_parity', 'verify_taglogic_all',
    'audit_dupes', 'audit_purity2', 'qa_corpus', 'experiment_impure_sample'
)

$all = Get-ChildItem -LiteralPath $Here -File -Filter *.py |
    Where-Object { $_.BaseName -notlike '_*' } | ForEach-Object { $_.BaseName }
$names = if ($args -contains '-All') { $all } else { $Curated | Where-Object { $all -contains $_ } }

$fail = @()
$ok = 0
foreach ($n in ($names | Sort-Object)) {
    $out = & py -3.13 "tools/$n.py" --help 2>&1 | Out-String
    $code = $LASTEXITCODE
    # --help 正常退出是 0; 有的工具用 SystemExit(0) 也是 0。非 0 或输出里带 Traceback 都算坏。
    if ($code -ne 0 -or $out -match 'Traceback|ModuleNotFoundError|ImportError') {
        $first = ($out -split "`n" | Where-Object { $_ -match 'Error|error' } | Select-Object -First 1)
        $fail += [pscustomobject]@{ tool = $n; code = $code; why = ("$first").Trim() }
    } else { $ok++ }
}

Write-Host ("工具冒烟: 通过 {0} / 检查 {1}" -f $ok, @($names).Count)
if ($fail.Count) {
    Write-Host "**坏了这些:**"
    $fail | Format-Table -AutoSize | Out-String | Write-Host
    exit 1
}
Write-Host "全部能 import 并打出 --help"
exit 0
