# -*- coding: utf-8 -*-
"""下载**基座模型**到 `models/<名字>`（走 hf-mirror，支持断点续传）。

## 为什么单独一个脚本

`models/` 里的基座模型（Qwen3-VL-2B / Qwen2.5-VL-3B / Qwen3-1.7B …）都是公开权重，
体积大（3–9 GB），而且这台机器直连 huggingface.co 不稳 —— 之前下模型走的都是
`HF_ENDPOINT=https://hf-mirror.com`（现有脚本 `fetch_text_lm.ps1`、`check_qwen3_visual.py`
里也能看到同样的做法）。把它固化成一条命令，比"记得当时是怎么下的"靠谱。

**注意**：这个脚本只下**公开基座**。自训产物（LoRA 适配器、分类头 `heads.pt` 等）**没有公开源**
—— 那些删了就只剩重训这一条路（见 `models删除记录_20261001.md`）。

用法:
    py -3.13 tools/fetch_base_model.py Qwen/Qwen2.5-VL-3B-Instruct
    py -3.13 tools/fetch_base_model.py Qwen/Qwen3-VL-4B-Instruct --name Qwen3-VL-4B-Instruct
    py -3.13 tools/fetch_base_model.py Qwen/Qwen2.5-VL-3B-Instruct --no-mirror   # 直连官方
"""
from __future__ import annotations

import argparse
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "models")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("repo_id", help="HuggingFace 仓库，如 Qwen/Qwen2.5-VL-3B-Instruct")
    ap.add_argument("--name", default="", help="落到 models/ 下的目录名（默认取仓库名）")
    ap.add_argument("--no-mirror", action="store_true", help="不走 hf-mirror（直连官方）")
    a = ap.parse_args()

    name = a.name or a.repo_id.split("/")[-1]
    dest = os.path.join(MODELS, name)
    if not a.no_mirror:
        os.environ.setdefault("HF_ENDPOINT", "https://hf-mirror.com")
    os.makedirs(dest, exist_ok=True)

    print(f"  仓库   : {a.repo_id}")
    print(f"  落到   : {dest}")
    print(f"  端点   : {os.environ.get('HF_ENDPOINT', 'https://huggingface.co')}")

    from huggingface_hub import snapshot_download  # 延迟导入：只用得到时才需要它

    t0 = time.time()
    try:
        path = snapshot_download(repo_id=a.repo_id, local_dir=dest,
                                 max_workers=8, resume_download=True)
    except Exception as e:                       # 网络中断也给个明确说法（续传再跑一次即可）
        print(f"  ! 下载中断: {type(e).__name__}: {e}")
        print("    再跑一次同一条命令会**断点续传**（已下好的分片不会重下）")
        return 1

    files = [f for f in os.listdir(path) if not f.startswith(".")]
    total = sum(os.path.getsize(os.path.join(dp, f))
                for dp, _dn, fn in os.walk(path) for f in fn)
    print(f"  ✓ {len(files)} 个顶层文件 / 共 {total / 1e9:.2f} GB / 用时 {time.time() - t0:.0f}s")
    for f in sorted(files)[:12]:
        print(f"      {f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
