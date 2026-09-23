# -*- coding: utf-8 -*-
# 转写"按金曲清单缺口定向抓来"的谱: 遍历 images-prep/qupu123-mp*, 逐个交给 transcribe_source.py。
# 可续跑: transcribe_source.py 自己会跳过已有 txt 的谱。
# 用法: pwsh -File tools\transcribe_mandopop.ps1
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$env:JP_PURITY2 = "1"
$log = "train-work\mandopop_transcribe.log"
function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}
$dirs = Get-ChildItem images-prep -Directory -Filter "qupu123-mp*" | Sort-Object Name
Say "================ 定向缺口转写 开始 (JP_PURITY2=1) 目录 $($dirs.Count) 个 ================"
$i = 0
foreach ($d in $dirs) {
    $i++
    Say "[$i/$($dirs.Count)] $($d.Name)"
    py -3.13 tools/transcribe_source.py $d.FullName *>> $log
}
Say "转写结束. batch-out txt 数 $((Get-ChildItem 'batch-out\*.txt' | Measure-Object).Count)"
