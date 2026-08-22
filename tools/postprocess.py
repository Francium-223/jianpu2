# -*- coding: utf-8 -*-
"""草稿后处理 (jianpu-db 规范): 给所有草稿添加
  1) 元数据区注释 %TODO:revise
  2) usertag=to_be_revised (由 parse_scores.py 自动展开为 tag)
用法: python tools/postprocess.py
"""
import os
import re

DIRS = [
    "scores-draft", "scores-draft2", "scores-draft3", "scores-draft4",
    "scores-draft5", "scores-draft-pucn", "scores-draft-pujia",
    "scores-7b", "scores-7b-2", "scores-7b-3", "scores-7b-4", "scores-7b-5",
    "scores-7b-pucn", "scores-7b-pujia",
]

TAG = "to_be_revised"
COMMENT = "%TODO:revise"


def process(path):
    text = open(path, encoding="utf-8").read()
    idx = text.find("%--")
    if idx < 0:
        return False  # 结构异常, 跳过
    meta = text[:idx]
    body = text[idx:]

    # 1) 注释 (不重复添加)
    if COMMENT not in meta:
        meta = meta.rstrip("\n") + "\n" + COMMENT + "\n"

    # 2) usertag: 追加 to_be_revised (不重复)
    usertag_re = re.compile(r"(?m)^usertag=(.*)$")
    m = usertag_re.search(meta)
    if m:
        tags = [t.strip() for t in m.group(1).split(",") if t.strip()]
        if TAG not in tags:
            tags.append(TAG)
            meta = usertag_re.sub(lambda mm: f"usertag={','.join(tags)}", meta, count=1)
    else:
        meta = meta.rstrip("\n") + "\n" + f"usertag={TAG}\n"

    new = meta + body
    if new != text:
        open(path, "w", encoding="utf-8").write(new)
        return True
    return False


def main():
    total = changed = 0
    for d in DIRS:
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if not name.endswith(".txt"):
                continue
            p = os.path.join(d, name)
            total += 1
            if process(p):
                changed += 1
    print(f"处理完成: {total} 个文件, 修改 {changed} 个")


if __name__ == "__main__":
    main()
