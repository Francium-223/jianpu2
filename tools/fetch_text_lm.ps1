# -*- coding: utf-8 -*-
# 下载**纯文本**小模型(Qwen3-1.7B)到 D:, 专供"名字清洗/曲名提取"这类语言任务。
#
# 为什么不走 ollama: 它只装了 VL 模型(qwen2.5vl:7b/3b) ✗, 而且默认存 C: —— C: 只剩 1 GB ✗。
# 为什么不用现成的 VL 模型做文本: 高射炮打蚊子(用户 2026-09-22 原话) —— 名字清洗是纯语言任务 ✓。
# 落点: models/Qwen3-1.7B  + HF 缓存 .hf-cache(都在 D:, 不碰 C:)。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\fetch_text_lm.log"

function Say([string]$m) {
    $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Say "================ 下载 Qwen3-1.7B(纯文本) 开始 ================"
$env:HF_HOME = "$root\.hf-cache"
$env:HF_HUB_CACHE = "$root\.hf-cache\hub"
# huggingface.co 直连在国内会 SSL 失败(`tlsv1 alert no application protocol` ✗, 实测),
# 走 hf-mirror 镜像 —— 库里已有的 Qwen 模型也是这么下来的。
$env:HF_ENDPOINT = "https://hf-mirror.com"
Say "HF_ENDPOINT=$env:HF_ENDPOINT"
Say "HF_HOME=$env:HF_HOME"
py -3.13 -c "from huggingface_hub import snapshot_download; p = snapshot_download('Qwen/Qwen3-1.7B', local_dir='models/Qwen3-1.7B', allow_patterns=['*.json','*.txt','*.safetensors','*.jinja']); print('OK', p)" *>> $log
Say "下载退出码 $LASTEXITCODE"
if (Test-Path "models\Qwen3-1.7B") {
    $sz = (Get-ChildItem "models\Qwen3-1.7B" -Recurse -File | Measure-Object Length -Sum).Sum
    Say ("模型大小 {0:N2} GB" -f ($sz / 1GB))
    Say ("文件: " + ((Get-ChildItem "models\Qwen3-1.7B" -File | Select-Object -ExpandProperty Name) -join ', '))
}
Say "================ 结束 ================"
