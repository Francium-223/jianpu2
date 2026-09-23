# -*- coding: utf-8 -*-
# 等所有链跑完 -> 生成"检索演示图": 用查询片段找到歌, 再把谱里命中的那一行放大裁出来。
# 产物: train-work/demo_match.png (Skill 演示/复核用)
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\demo.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 检索演示图 等待开始 ================"
$waited = 0
while ($waited -lt 360) {
    $busy = @(Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
              Where-Object { $_.CommandLine -match 'finalize|transcribe_source|crawl_qupu123|melody_retrieval|to_jianpu_db|gt_transcribe|source_map' }).Count
    # 等 GT 复评那条链收尾(它排在最后), 免得抢 GPU
    $done = (Select-String -Path "train-work\gt_eval.log" -Pattern '手写GT复评 结束' -Quiet -ErrorAction SilentlyContinue)
    if ($busy -eq 0 -and $done) { Say "所有链已结束, 开始做演示图"; break }
    Say "  还有 $busy 个 python 在跑(GT链结束标记 $done), 等 60 秒"
    Start-Sleep -Seconds 60
    $waited += 1
}

$FRAG = "51223323323531"
Say "查询片段 $FRAG"
py -3.13 tools/melody_query.py $FRAG --top 3 *>> $log
$json = py -3.13 tools/melody_query.py $FRAG --top 1 --json 2>> $log | Out-String
try {
    $o = $json | ConvertFrom-Json
    $name = $o.results[0].score_file
    $title = $o.results[0].title
    Say "命中: $title  ($name)"
    $dir = (Get-ChildItem "images-prep" -Recurse -Directory -Filter $name -ErrorAction SilentlyContinue |
            Select-Object -First 1).FullName
    if ($dir) {
        $page = py -3.13 -c "import sys; sys.path.insert(0,'tools'); import batch_transcribe as BT; print(BT.pick_page(sys.argv[1]))" $dir
        Say "谱页: $page"
        if ($page) {
            py -3.13 tools/zoom_phrase.py "$page" $FRAG "train-work/demo_match.png" *>> $log
            Say "退出码 $LASTEXITCODE -> train-work/demo_match.png"
        }
    } else {
        Say "没找到图片目录: $name"
    }
} catch {
    Say "解析 JSON 失败: $($_.Exception.Message)"
}
Say "================ 检索演示图 结束 ================"
