# -*- coding: utf-8 -*-
# 第三轮: "整片抓"的分类谱入库。等第二轮(jp_mandopop_absorb2)跑完, 再转写 images-prep/jianpujia-cat*,
# 然后 finalize -> 覆盖率 -> 评测 -> 抽检 -> verify -> 文档同步。
#
# 为什么单独一轮: 第二轮启动时就把待转写目录列表列好了(qupu123-mp9*/qupu123-title*/jianpucn-title*/
# jianpujia-art*), **不含** jianpujia-cat*(分类整片抓的), 所以必须再来一次; 而 finalize 是整库重建,
# 不宜频繁跑 —— 攒够一批(这里是整个分类)再入一次。
# 用法: pwsh -File tools\mandopop_absorb3.ps1
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$env:JP_PURITY2 = "1"
$log = "train-work\mandopop_absorb3.log"
function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}
function Step([string]$label, [scriptblock]$body) {
    Say "--- $label ---"
    $t0 = Get-Date
    & $body *>> $log
    Say "    $label 用时 $([int]((Get-Date)-$t0).TotalSeconds)s 退出码 $LASTEXITCODE"
}

Say "================ 第三轮(整片分类入库) 开始 ================"
Say "等待第二轮 jp_mandopop_absorb2 结束(轮询兜底上限 10 小时)..."
$t0 = Get-Date
while ($true) {
    $st = (Get-ScheduledTask -TaskName 'jp_mandopop_absorb2' -ErrorAction SilentlyContinue).State
    $done = (Select-String -Path train-work\mandopop_absorb2.log -Pattern '第二轮\(补捞入库\) 完成' -Quiet -ErrorAction SilentlyContinue)
    if ($done -or $st -ne 'Running') { break }
    if (((Get-Date) - $t0).TotalHours -gt 10) { Say "等待超过兜底上限, 继续执行"; break }
    Start-Sleep -Seconds 60
}
Say "第二轮状态: $st / 完成标记 $done"

$dirs = @()
foreach ($pat in 'jianpujia-art*', 'jianpujia-cat*', 'qupu123-title*', 'jianpucn-title*',
                 'qupu123-sweep*', 'qupu123-hk*', 'qupu123-kw*', 'qupu123-crawl*') {
    $dirs += Get-ChildItem images-prep -Directory -Filter $pat -ErrorAction SilentlyContinue
}
# transcribe_source.py 会跳过已有 txt 的谱, 所以重复列目录是幂等的
Say "待转写目录 $($dirs.Count) 个: $(($dirs | Select-Object -ExpandProperty Name) -join ', ')"
$i = 0
foreach ($d in $dirs) {
    $i++
    $sheets = (Get-ChildItem $d.FullName -Directory -ErrorAction SilentlyContinue).Count
    Say "[$i/$($dirs.Count)] $($d.Name)  谱目录 $sheets"
    py -3.13 tools/transcribe_source.py $d.FullName *>> $log
}

Step "入库收尾(finalize)" { py -3.13 tools/finalize.py }
Step "覆盖率 + 数字 + 文档同步" {
    py -3.13 tools/coverage_report.py
    py -3.13 tools/numbers_digest.py
    py -3.13 tools/sync_docs.py
}
Step "抽检 + 交付物" {
    py -3.13 tools/qa_corpus.py
    py -3.13 tools/qa_sample.py 40
    py -3.13 tools/flag_odd_names.py --apply
    py -3.13 tools/verify_deliverable.py
    py -3.13 tools/delivery_report.py
}
Say "================ 第三轮(整片分类入库) 完成 ================"
