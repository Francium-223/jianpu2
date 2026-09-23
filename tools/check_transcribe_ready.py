# -*- coding: utf-8 -*-
"""转写环境"差什么"清单 —— 换机器/睡觉前跑一下就知道还缺哪几块。

**为什么需要**: 2026-09-24 我一度报告"models/ 是空的、这台机器不能转写" —— 只看了
`jianpu2/models/`，没看**工作区根**的 `models/`（那里其实躺着 1.1GB 的 LoRA 适配器与
网格检测器，从 `06_模型_adapters.tar` 解出来的）。这类"以为缺、其实有 / 以为有、其实缺"
的判断，应该由脚本给，而不是靠人翻目录。

检查项:
  1. **基座 VLM**(`Qwen2.5-VL-3B-Instruct`，约 7GB) —— 六件套里唯一**不在**抢救包中的大件；
  2. **LoRA 适配器**(`jianpu-lora-v15` 等) + `adapter_config.json`；
  3. **网格检测器** `grid_detect.pt` / `grid_detect32.pt`；
  4. **token 白名单** `train-work/whitelist.txt`（转写时用 outlines 做正则约束，必须有）；
  5. Python 依赖: torch / transformers / peft / outlines / bitsandbytes / accelerate；
  6. 硬件: CUDA 可用性、内存、磁盘余量（4bit 量化下 3B 模型也建议 >=8GB 内存/显存）。

用法: python3 tools/check_transcribe_ready.py
"""
import glob
import importlib
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)                     # 工作区根（三个仓库的上一层）
MODEL_DIRS = [os.path.join(ROOT, "models"), os.path.join(WS, "models")]

ok = warn = miss = 0


def line(sym, what, detail=""):
    global ok, warn, miss
    ok += sym == "✓"
    warn += sym == "!"
    miss += sym == "✗"
    print(f"  {sym} {what}" + (f"  —— {detail}" if detail else ""))


def find_model(name):
    for d in MODEL_DIRS:
        p = os.path.join(d, name)
        if os.path.isdir(p):
            return p
    return ""


def main():
    print("=== 转写环境清单 ===")
    print(f"  工作区: {WS}")

    # ① 基座
    base = find_model("Qwen2.5-VL-3B-Instruct")
    if base:
        has_w = glob.glob(os.path.join(base, "*.safetensors")) or glob.glob(os.path.join(base, "*.bin"))
        line("✓" if has_w else "!", "基座 VLM Qwen2.5-VL-3B-Instruct", f"{base}（权重 {'有' if has_w else '没看到'}）")
    else:
        line("✗", "基座 VLM Qwen2.5-VL-3B-Instruct（约 7GB，**抢救包里没有，要下**）",
             "huggingface-cli download Qwen/Qwen2.5-VL-3B-Instruct --local-dir "
             + os.path.join(MODEL_DIRS[1], "Qwen2.5-VL-3B-Instruct"))

    # ② LoRA
    for name in ("jianpu-lora-v15", "jianpu-lora-v17", "jianpu-lora-v12"):
        p = find_model(name)
        if p:
            have = [f for f in ("adapter_config.json", "adapter_model.safetensors") if os.path.isfile(os.path.join(p, f))]
            line("✓" if len(have) == 2 else "!", f"LoRA {name}", f"{p}（{', '.join(have) or '空的'}）")
            break
    else:
        line("✗", "LoRA 适配器", "06_模型_adapters.tar 没解出来？")

    # ③ 网格检测器
    for name in ("grid_detect.pt", "grid_detect32.pt"):
        p = [os.path.join(d, name) for d in MODEL_DIRS if os.path.isfile(os.path.join(d, name))]
        line("✓" if p else "✗", f"网格检测器 {name}", p[0] if p else "缺")

    # ④ 白名单
    wl = os.path.join(ROOT, "train-work", "whitelist.txt")
    line("✓" if os.path.isfile(wl) else "✗", "token 白名单 train-work/whitelist.txt",
         f"{os.path.getsize(wl)} 字节" if os.path.isfile(wl) else "缺（outlines 约束要用）")

    # ⑤ 依赖
    need = ["torch", "transformers", "peft", "outlines", "bitsandbytes", "accelerate"]
    have, lack = [], []
    for m in need:
        try:
            importlib.import_module(m)
            have.append(m)
        except Exception:
            lack.append(m)
    line("✓" if not lack else "✗", "Python 依赖",
         ("全有: " + ", ".join(have)) if not lack else ("缺: " + ", ".join(lack) + "   -> pip install torch transformers peft outlines bitsandbytes accelerate"))

    # ⑥ 硬件
    if "torch" in have:
        try:
            import torch
            cuda = torch.cuda.is_available()
            line("✓" if cuda else "!", "CUDA", (torch.cuda.get_device_name(0) if cuda else "不可用（CPU 也能跑 3B-4bit，但很慢）"))
        except Exception as e:
            line("!", "CUDA", f"判断失败: {e}")
    else:
        line("!", "CUDA", "没装 torch，无法判断（本机是核显 + Radeon，基本可认为无 CUDA）")
    mem = os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES") / 2**30
    free = shutil.disk_usage(WS).free / 2**30
    line("✓" if mem >= 8 else "!", "内存", f"{mem:.1f} GB（4bit 3B 建议 >=8GB；不足时靠 swap，会非常慢）")
    line("✓" if free >= 20 else "!", "磁盘余量", f"{free:.0f} GB 可用（基座约 7GB + 缓存）")

    print(f"\n小结: 就绪 {ok} 项 / 需注意 {warn} 项 / **缺 {miss} 项**")
    if miss:
        print("转写还跑不了。缺的那几项的补法见上面每行的提示（最主要是下基座模型 + 装依赖）。")
    else:
        print("看上去可以跑: python3 tools/transcribe.py <图片或目录>")
    return 0


if __name__ == "__main__":
    sys.exit(main())
