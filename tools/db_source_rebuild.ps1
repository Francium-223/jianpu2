# -*- coding: utf-8 -*-
# 只跑"重建 scores"这一步(to_jianpu_db), 让 source= 字段落进 jianpu-db-out/scores/*.txt。
# 不动用户的人工库 jianpu-db/。纯 CPU + 少量模型调用。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\db_source_rebuild.log"
function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}
Say "================ 重建 scores(带 source=) 开始 ================"
py -3.13 tools/to_jianpu_db.py --meter --transcriber jianpu2-auto *>> $log
Say "退出码 $LASTEXITCODE"
$n = (Get-ChildItem "jianpu-db-out\scores\*.txt" -ErrorAction SilentlyContinue).Count
$withSrc = @(Select-String -Path "jianpu-db-out\scores\*.txt" -Pattern '^source=' -Encoding UTF8 -List).Count
Say "scores $n 份, 其中带 source= 的 $withSrc 份"
Say "================ 结束 ================"
