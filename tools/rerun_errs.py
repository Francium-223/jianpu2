# -*- coding: utf-8 -*-
"""失败歌曲重跑: 删除各 scores-7b* 目录里 .err 对应歌曲的输出文件,
然后用最新 convert.py 重跑对应数据集 (只处理被删的歌曲, 其余跳过)。

用法: python tools/rerun_errs.py
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

PAIRS = [
    ("scores-7b", "images-prep/ready"),
    ("scores-7b-2", "images-prep/ready2"),
    ("scores-7b-3", "images-prep/ready3"),
    ("scores-7b-4", "images-prep/ready4"),
    ("scores-7b-5", "images-prep/ready5"),
    ("scores-7b-pucn", "images-prep/test-jianpucn"),
    ("scores-7b-pujia", "images-prep/test-jianpujia"),
]


def main():
    any_run = False
    for out_dir, in_dir in PAIRS:
        if not os.path.isdir(out_dir) or not os.path.isdir(in_dir):
            continue
        errs = [f[:-4] for f in sorted(os.listdir(out_dir)) if f.endswith(".err")]
        if not errs:
            continue
        for base in errs:
            for ext in (".txt", ".err", ".ly", ".trans"):
                p = os.path.join(out_dir, base + ext)
                if os.path.exists(p):
                    os.unlink(p)
        print(f"{out_dir}: 删除 {len(errs)} 首失败输出, 重跑 {in_dir}")
        any_run = True
        subprocess.run([sys.executable, "convert.py", "--input", in_dir,
                        "--out", out_dir, "--model", "qwen2.5vl:7b", "--no-strips"],
                       cwd=ROOT)
    if not any_run:
        print("没有失败歌曲需要重跑")


if __name__ == "__main__":
    main()
