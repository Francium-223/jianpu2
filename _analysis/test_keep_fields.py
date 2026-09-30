# -*- coding: utf-8 -*-
"""验 `to_jianpu_db.py` 的"重建时保留人工元数据"三条修正（隔离测试，用真实形态的样本）。

背景（都在 2026-09-30 实测踩到）：
  ① 保留字段要含页面上可编辑的元数据（usertag/artist/alias/link/MBID），不能只有 todo/preferred；
  ② "旧文件"要**两处都看**（本轮已写过的 `OUTDIR/{safe}.txt` 与 `scores-prev/{safe}.txt`）——
     原来"前者不存在才看后者"，于是本轮写过一次(空 usertag)后就再也读不到 scores-prev，标签照样丢；
  ③ 判重必须**按字段**：新文件里本来就有 `usertag=`(空)这一行，拿"整行在不在"当判据永远误判"已有"。
"""
import re


def merge_meta(txt, olds):
    """复刻 to_jianpu_db.py 里那段（同步改代码时记得同步这里）。"""
    for old in olds:
        for m in re.finditer(r"^((?:todo|usertag|artist|alias|link|MBID)=.*|preferred=\d+)\r?$", old, re.M):
            line = m.group(1).rstrip("\r")          # 旧文件可能是 CRLF -> 别把 \r 带出来
            fld, val = line.split("=", 1)
            if not val.strip():
                continue
            if re.search(r"(?m)^" + fld + r"=[ \t]*\S", txt):
                continue
            if re.search(r"(?m)^" + fld + r"=[ \t]*\r?$", txt):
                txt = re.sub(r"(?m)^" + fld + r"=[ \t]*\r?$", line, txt, count=1)
            else:
                txt = txt.replace("%--", line + "\n%--", 1)
    return txt


NEW = "title=17\ntag=\nusertag=\ntagroute=\nstatus=ocr\nsource=jianpucn-448053\n%--\n4/4\n1 2 3\n"
PREV = "title=17\nusertag=毛不易\ntodo=add tags\npreferred=2\n%--\n1 2 3\n"
PREV_LF = PREV.replace("\n", "\r\n")          # CRLF 形态也要过

CASES = [
    ("只有 scores-prev 有标签", NEW, [PREV]),
    ("CRLF 的 scores-prev", NEW, [PREV_LF]),
    ("本轮已写过(空 usertag) + scores-prev 有标签 -> 两个都看", NEW, [NEW, PREV]),
    ("新文件已经有值 -> 不动", NEW.replace("usertag=\n", "usertag=邓丽君\n"), [PREV]),
    ("正文不能被改", NEW, [PREV]),
]


def main():
    for label, new, olds in CASES:
        out = merge_meta(new, olds)
        got = dict(re.findall(r"(?m)^(usertag|todo|preferred)=(.*)$", out))
        body_ok = out.split("%--", 1)[-1].strip() == "4/4\n1 2 3".strip() or \
            out.split("%--", 1)[-1].strip().endswith("1 2 3")
        print(f"  {label:<42} usertag={got.get('usertag','')!r:<10} todo={got.get('todo','')!r:<12} "
              f"preferred={got.get('preferred','')!r:<4} 正文完好={body_ok}")


if __name__ == "__main__":
    main()
