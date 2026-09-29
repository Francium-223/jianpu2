# -*- coding: utf-8 -*-
"""隔离验 `tag_ocr_scores.py --also-artist` 的插入逻辑(不碰真实 staging)。

只复刻那 3 行正则, 用 4 种真实头部形态试: ①没有 artist= 行 ②有空的 artist= 行
③artist= 已有值(不该动) ④文件里没有 `%--`(安全兜底, 不该动)。
"""
import re

NL = "\n"


def insert(raw, who):
    if re.search(r"(?m)^artist=[ \t]*\S", raw):
        return raw, False
    if re.search(r"(?m)^artist=[ \t]*$", raw):
        return re.sub(r"(?m)^artist=[ \t]*$", "artist=" + who, raw, count=1), True
    if "%--" not in raw:
        return raw, False
    return raw.replace("%--", "artist=" + who + NL + "%--", 1), True


CASES = [
    ("没有 artist= 行", "%x.txt\ntitle=借\nusertag=毛不易\nstatus=ocr\nsource=jianpujia-15338\n%--\n4/4\n", "毛不易"),
    ("空 artist= 行", "%y.txt\ntitle=某歌\nartist=\nusertag=张学友\nstatus=ocr\nsource=qupu123-1\n%--\n", "张学友"),
    ("artist= 已有值", "%z.txt\ntitle=某歌\nartist=早就有了\nusertag=王菲\n%--\n", "王菲"),
    ("没有 %--", "%w.txt\ntitle=没分隔符\nusertag=刘欢\n", "刘欢"),
]


def main():
    for label, raw, who in CASES:
        out, changed = insert(raw, who)
        m = re.search(r"(?m)^artist=(.*)$", out)
        print(f"  {label:<12} 改了={changed!s:<5} artist={m.group(1) if m else '(无)'}")


if __name__ == "__main__":
    main()
