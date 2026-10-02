# -*- coding: utf-8 -*-
# 等"文本模型下完" + "scores 重建结束" 之后, 自动跑全量曲名清洗(16219 条)。
#
# 等待条件刻意用**文件/进程**判断, 不用日志 sentinel —— 之前用 sentinel 卡过一次(实例白等一小时) ✓
#   ① 模型: 出现 *.safetensors、没有 *.incomplete、且 20 秒内大小不变(下完的标志)
#   ② 重建: 没有 to_jianpu_db / run.py / finalize 的 python 在跑(避免抢 GPU 与文件)
#   ③ **转写**: 也别有 transcribe_source / batch_transcribe / jp_transcribe —— 2026-10-02 晚补:
#      实测转写在跑时显存已占 5.1/8.2 GB, 而 1.7B 模型约 3.5 GB -> 会抢显存甚至 OOM。
#      原来只挡"重建", 于是最常见的忙(转写)漏掉了, 判据等于没拦住。
$busyPat = 'to_jianpu_db|run\.py|finalize|transcribe_source|batch_transcribe|jp_transcribe'
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\refine_titles.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 曲名清洗(全量) 等待开始 ================"

$waited = 0
while ($waited -lt 120) {
    $shards = @(Get-ChildItem "models\Qwen3-1.7B\*.safetensors" -ErrorAction SilentlyContinue)
    $inc = @(Get-ChildItem "models\Qwen3-1.7B" -Recurse -Filter "*.incomplete" -ErrorAction SilentlyContinue)
    if ($shards.Count -ge 1 -and $inc.Count -eq 0) {
        $s1 = ($shards | Measure-Object Length -Sum).Sum
        Start-Sleep -Seconds 20
        $s2 = (@(Get-ChildItem "models\Qwen3-1.7B\*.safetensors" -ErrorAction SilentlyContinue) |
               Measure-Object Length -Sum).Sum
        if ($s1 -eq $s2 -and $s2 -gt 2GB) { Say ("模型就绪 {0:N2} GB" -f ($s2 / 1GB)); break }
    }
    Start-Sleep -Seconds 30
    $waited += 0.5
}
# ⚠ 这个写法是 0.5/轮 × 30 秒 = **2 小时**上限，原来的提示写"60 分钟"是错的（2026-10-03 实测核对）
if ($waited -ge 120) { Say "等模型超时(实为 2 小时), 放弃"; exit 1 }

# 等流水线空闲: 上限 8 小时（480 轮 × 60 秒）。与 tools/lowdigits_cleanup.ps1 同一套口径。
# ⚠ 到点**不硬开**：显存里还有转写时，1.7B 模型(~3.5GB)叠上去就是 OOM，
#   宁可退出让人/看护再点一次（转写批之间总有空档），也不要一份 OOM 掉一半的输出。
$waited = 0
while ($waited -lt 480) {
    $busy = @(Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
              Where-Object { $_.CommandLine -match $busyPat }).Count
    if ($busy -eq 0) { Say "重建/转写都已结束, 开始清洗"; break }
    Say "  还在跑($busy 个进程: 重建或转写), 等 60 秒"
    Start-Sleep -Seconds 60
    $waited += 1
}
if ($waited -ge 480) {
    Say "等空闲超时(8 小时), 转写仍在跑 —— 为免 OOM **不开始**；等它结束再跑一次本任务"
    exit 1
}

Say "--- 跑 refine_titles_llm.py (单条并行批 par=48) ---"
py -3.13 tools/refine_titles_llm.py --par 48 --resume *>> $log
Say "退出码 $LASTEXITCODE"
if (Test-Path "train-work\title_clean.tsv") {
    $n = (Get-Content "train-work\title_clean.tsv" | Measure-Object -Line).Lines - 1
    Say "结果行数 $n -> train-work/title_clean.tsv (只出建议, 未改谱子)"
}
Say "================ 结束 ================"
