# -*- coding: utf-8 -*-
"""生成导入包: 把所有通过校验的 7b 曲谱 .txt 汇集到 import-bundle/scores/,
并生成 manifest.csv (来源/校验/MBID 状态)。用法: python tools/make_bundle.py"""
import csv
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

DIRS = [
    "scores-7b", "scores-7b-2", "scores-7b-3", "scores-7b-4", "scores-7b-5",
    "scores-7b-pucn", "scores-7b-pujia",
]
BUNDLE = "import-bundle"
SCORES = os.path.join(BUNDLE, "scores")


def main():
    if os.path.isdir(BUNDLE):
        shutil.rmtree(BUNDLE)
    os.makedirs(SCORES)
    rows = []
    n_ok = n_err = n_dup = 0
    seen = set()
    for d in DIRS:
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if not name.endswith(".txt"):
                continue
            base = name[:-4]
            has_err = os.path.exists(os.path.join(d, base + ".err"))
            has_ly = os.path.exists(os.path.join(d, base + ".ly"))
            src = os.path.join(d, name)
            text = open(src, encoding="utf-8").read()
            mbid = ""
            for ln in text.splitlines():
                if ln.lower().startswith("mbid="):
                    mbid = ln[5:].strip()
                    break
            if has_err:
                n_err += 1
                rows.append([name, d, "error", "有" if mbid else "无", "", ""])
                continue
            if base in seen:
                n_dup += 1
                rows.append([name, d, "dup-skip", "有" if mbid else "无", "有" if has_ly else "无",
                             "与同名文件重复, 未纳入导入包"])
                continue
            seen.add(base)
            shutil.copyfile(src, os.path.join(SCORES, name))
            n_ok += 1
            rows.append([name, d, "ok", "有" if mbid else "无", "有" if has_ly else "无", ""])
    with open(os.path.join(BUNDLE, "manifest.csv"), "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(["song", "source", "status", "mbid", "ly", "note"])
        w.writerows(rows)
    print(f"导入包: {n_ok} 首通过校验 (失败 {n_err}, 重名跳过 {n_dup})")
    print(f"目录: {BUNDLE}/scores/  (manifest.csv 见 {BUNDLE}/)")


if __name__ == "__main__":
    main()
