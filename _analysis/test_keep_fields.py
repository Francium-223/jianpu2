# -*- coding: utf-8 -*-
"""验 `to_jianpu_db.py` 里"重建时保留哪些字段"的正则（隔离测试，不跑真转换）。

2026-09-30 扩过一次：原先是 `todo=`/`preferred=`，现在把页面上可人工编辑的元数据
（`usertag=`/`artist=`/`alias=`/`link=`/`MBID=`）也一起保留 —— 否则一次 finalize
就把标签器写的 7,475 份 usertag 全冲掉。
"""
import re

PAT = r"^((?:todo|usertag|artist|alias|link|MBID)=.*|preferred=\d+)$"

OLD = """title=某歌
tag=
usertag=分类/民歌
tagroute=
artist=邓丽君
alias=另一个名
link=https://example.com/p/1
MBID=11111111-2222-3333-4444-555555555555
todo=add tags
preferred=2
transcriber=jianpu2-auto
status=ocr
%--
4/4
"""


def main():
    txt = "title=某歌\n%--\n4/4\n"
    hits = [m.group(1) for m in re.finditer(PAT, OLD, re.M)]
    print("会保留的字段:", hits)
    for h in hits:
        if h not in txt:
            txt = txt.replace("%--", h + "\n%--", 1)
    print("拼进新文件后:")
    for line in txt.splitlines():
        print("   " + line)
    want = {"usertag=分类/民歌", "artist=邓丽君", "alias=另一个名",
            "link=https://example.com/p/1", "todo=add tags", "preferred=2"}
    got = set(hits)
    print("\n期望保留的都抓到了吗:", want.issubset(got), " 缺失:", want - got)
    print("不该保留的(conf/status 之类)有没有混进来:", [h for h in hits if h.startswith(("conf", "status"))])


if __name__ == "__main__":
    main()
