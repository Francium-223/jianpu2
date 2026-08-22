# -*- coding: utf-8 -*-
"""给已生成的曲谱补 copyright= 行 (谱源 + 版权归属), 依据各歌曲 song.json 的来源站点。

用法: python tools/add_copyright.py
幂等: 已有 copyright= 的文件跳过。
"""
import importlib.util
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

spec = importlib.util.spec_from_file_location('convert', 'convert.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

PAIRS = [
    ("scores-7b", "images-prep/ready"),
    ("scores-7b-2", "images-prep/ready2"),
    ("scores-7b-3", "images-prep/ready3"),
    ("scores-7b-4", "images-prep/ready4"),
    ("scores-7b-5", "images-prep/ready5"),
    ("scores-7b-pucn", "images-prep/test-jianpucn"),
    ("scores-7b-pujia", "images-prep/test-jianpujia"),
]

SITE_NAME = {"jianpucn": "歌谱简谱网", "jianpujia": "简谱之家"}


def main():
    total = changed = 0
    for out, src in PAIRS:
        if not os.path.isdir(out) or not os.path.isdir(src):
            continue
        for name in sorted(os.listdir(src)):
            p = os.path.join(src, name)
            j = os.path.join(p, "song.json")
            if not (os.path.isdir(p) and os.path.exists(j)):
                continue
            try:
                meta = json.load(open(j, encoding="utf-8"))
            except Exception:
                continue
            title = m.clean_title(meta.get("title") or name)
            base = m.sanitize(title)
            txt = os.path.join(out, base + ".txt")
            if not os.path.exists(txt):
                continue
            text = open(txt, encoding="utf-8").read()
            # 注意: jianpu-db 的 score.py 会给每个 others 键建 by_<键>/<值> 目录,
            # 值必须文件系统安全 (不能含 : / 等), 且会被 ,|，|、 拆分。
            site = meta.get("site", "")
            site_n = SITE_NAME.get(site, site)
            line = f"copyright={site_n},版权归原作者及原网站"
            m2 = re.search(r"(?m)^copyright=(.*)$", text)
            if m2 and m2.group(1).strip() == line.split("=", 1)[1]:
                continue
            if m2:
                text = re.sub(r"(?m)^copyright=.*$", line, text, count=1)
            else:
                idx = text.find("%--")
                pos = idx if idx >= 0 else len(text)
                text = text[:pos] + line + "\n" + text[pos:]
            open(txt, "w", encoding="utf-8").write(text)
            total += 1
            changed += 1
    print(f"copyright 补录完成: {changed} 个文件")


if __name__ == "__main__":
    main()
