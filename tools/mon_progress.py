# -*- coding: utf-8 -*-
"""监视 lora_v2_err.log 的训练进度条, 每 5 秒更新 train-work/progress.txt 为易读格式."""
import os, re, time
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOG="train-work/lora_v2_err.log"; OUT="train-work/progress.txt"
while True:
    try:
        txt=open(LOG,encoding="utf-8",errors="replace").read()
        # 匹配 'NN%|...| step/total [elapsed<remain, s/it]'
        m=re.search(r"(\d+)%\|[^|]*\|\s*(\d+)/(\d+)\s*\[([\d:]+)<([\d:]+)", txt)
        if m:
            pct=int(m.group(1)); step=int(m.group(2)); total=int(m.group(3))
            elap=m.group(4); remain=m.group(5)
            content=(f"端到端 Qwen3-VL-2B LoRA 训练\n进度: {step}/{total} 步 ({pct}%)\n"
                     f"已跑: {elap}\n剩余: {remain}\n")
        else:
            # 可能用剩余不含elapsed, 退而读最后一行
            last=[l for l in txt.splitlines() if "%" in l and "/" in l]
            content=("训练进行中...\n"+("最后行: "+last[-1] if last else "等待首步..."))
        open(OUT,"w",encoding="utf-8").write(content)
    except Exception as ex:
        open(OUT,"w",encoding="utf-8").write(f"监视出错: {ex}")
    time.sleep(5)
