# -*- coding: utf-8 -*-
# 夜间第三条链: 等交付链跑完 -> 扩库(qupu123 抓 59 首名人名曲) -> 转写 -> 自检 -> 收尾 -> 重测。
# 顺序刻意这样排:
#   ① 先把"基准集还缺的 14 首 + 45 首候补名人名曲"抓下来(纯网络, 不占 GPU)
#   ② 重新挑基准集缺的目录(这时能看到新抓的 qupu123 通俗简谱, 比 jianpucn 的吉他版干净)
#   ③ 转写(新抓的 + 基准集要补的)
#   ④ 自检(CPU): 空谱/极少/异常多/格式异常 token + 新批纯度审计
#   ⑤ 收尾重建 -> 重跑检索评测 -> 刷新交付物
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\night_extend.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 夜间扩库链 等待开始 ================"

$waited = 0
while ($waited -lt 720) {          # 最多等 6 小时
    $busy = @(Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
              Where-Object { $_.CommandLine -match 'refine_titles_llm|finalize|transcribe_source|melody_retrieval|to_jianpu_db|source_map' }).Count
    $done = (Select-String -Path "train-work\deliver_run.log" -Pattern '交付收尾 结束' -Quiet -ErrorAction SilentlyContinue)
    if ($busy -eq 0 -and $done) { Say "交付链已结束, 开始扩库"; break }
    Say "  交付链还在跑(python $busy, 结束标记 $done), 等 60 秒"
    Start-Sleep -Seconds 60
    $waited += 1
}
if ($waited -ge 720) { Say "等待超时(6 小时), 仍开始扩库"; }

Say "--- 1) 抓取 train-work/crawl_keywords_night.txt 里的关键词 ---"
$titles = Get-Content "train-work\crawl_keywords_night.txt" |
    Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' } |
    ForEach-Object { ($_ -split '\|')[0].Trim() }
$before = (Get-ChildItem "images-prep\*\*" -Directory -ErrorAction SilentlyContinue).Count
Say "关键词 $($titles.Count) 个   爬前谱目录 $before"
$i = 0
foreach ($t in $titles) {
    $i++
    Say "[$i/$($titles.Count)] $t"
    py -3.13 tools/crawl_qupu123.py "$t" 3 nb *>> $log
}
$after = (Get-ChildItem "images-prep\*\*" -Directory -ErrorAction SilentlyContinue).Count
Say "爬后谱目录 $after (新增 $($after-$before))"

Say "--- 2) 重新挑基准集缺的谱 ---"
py -3.13 tools/bench_pick.py 3 *>> $log

Say "--- 3) 转写新抓的谱 ---"
if (Test-Path "images-prep\qupu123-nb") {
    py -3.13 tools/transcribe_source.py images-prep/qupu123-nb *>> $log
    Say "转写(新抓) 退出码 $LASTEXITCODE"
} else {
    Say "images-prep/qupu123-nb 不存在(一个都没抓到?), 跳过"
}
if ((Get-Item "train-work\bench_todo.txt" -ErrorAction SilentlyContinue).Length -gt 0) {
    Say "--- 3b) 转写基准集补谱 ---"
    py -3.13 tools/transcribe_source.py train-work/bench_todo.txt *>> $log
    Say "转写(基准补谱) 退出码 $LASTEXITCODE"
}

Say "--- 4) 自我抽检(CPU) ---"
py -3.13 tools/qa_corpus.py *>> $log
Say "qa_corpus 退出码 $LASTEXITCODE"
py -3.13 tools/audit_purity2.py *>> $log
Say "audit_purity2 退出码 $LASTEXITCODE"

Say "--- 5) 收尾重建 ---"
py -3.13 tools/finalize.py *>> $log
Say "finalize 退出码 $LASTEXITCODE"

Say "--- 6) 重跑检索评测 ---"
py -3.13 tools/melody_retrieval_eval.py --sweep *>> $log
Say "评测退出码 $LASTEXITCODE"

Say "--- 7) 刷新交付物 ---"
py -3.13 tools/flag_odd_names.py --apply *>> $log
Say "flag_odd 退出码 $LASTEXITCODE"
py -3.13 tools/source_map.py *>> $log
py -3.13 tools/source_map_html.py *>> $log
py -3.13 tools/verify_deliverable.py *>> $log
Say "verify 退出码 $LASTEXITCODE"
py -3.13 tools/delivery_report.py *>> $log
Say "report 退出码 $LASTEXITCODE"

Say "================ 夜间扩库链 结束 ================"
