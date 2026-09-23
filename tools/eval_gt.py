# -*- coding: utf-8 -*-
"""可靠评测: 复现 spring=83 (口径一致), 再测新谱。
GT 过滤: 去 () [] {} | ~ 等标记, 取 数字token(含时值/八度/杠, 含独立'-')。
输出 token 从 'N 音' 行之后取。
"""
import re, sys
from difflib import SequenceMatcher
from token_json import (token_to_json as t2j, normalize_tokens,
                        is_marker, is_tuplet_marker)
def load_out(file):
    t=open(file,encoding="utf-8",errors="replace").read()
    m=re.search(r"\d+\s*音\s*\n?\s*(.+)$",t,re.S)
    toks=[x for x in (m.group(1) if m else t).split() if re.match(r"^[,']*[qsdhc#b]*[,']*[1-7x0-][.,'qsdh#b-]*$",x)]
    # merge_ties=False: 我方转写不输出 `~` 连音线标记(两个音就是两个 token),
    # 评测时若把 GT 的 `2s ~ 2q` 并成一个音, 两边结构就不一致了(实测反而掉 3 个点)
    return normalize_tokens(toks, merge_ties=False)

def load_gt(file):
    t=open(file,encoding="utf-8",errors="replace").read()
    # 只取音符行(含数字/时值/杠)
    lines=[l for l in t.splitlines() if re.search(r"[0-9x\-]",l) and not re.match(r"^\s*(title|MBID|type|copyright|OctavesAfter|1=|2/4|4/4|%|$)",l)]
    NOTE=re.compile(r"^[,']*[qsdhc#b]*[,']*[1-7x0-][.,'qsdh#b-]*$")
    # 注意: **不能**把 [](){}~ 直接替换成空格 —— 那样 `3[` 会剩下 `3` 被当音符
    # (实测 GT 里三连音标记被当成音符, 污染音符数)。必须按 token 保留结构符号再规范化:
    #   规则2: `3[` 是三连音标记, 那个 3 不是音符  -> 去掉 ✓
    #   规则1: 同数字且用 ~ 连接 = 一个音 -> 这里**不合并**(见 load_out 的说明)
    toks=[]
    for tok in " ".join(lines).split():
        if NOTE.match(tok) or tok == "-" or is_marker(tok) or is_tuplet_marker(tok):
            toks.append(tok)
    return normalize_tokens(toks, merge_ties=False)
def key(t):
    j=t2j(t); return (j["digit"],j["low"],len(j["voice"]),j["beam"],j["dotted"],j["accidental"])
def score(gt_file,out_file):
    OUT=load_out(out_file); GT=load_gt(gt_file)
    jo=[key(x) for x in OUT]; jg=[key(x) for x in GT]
    sm=SequenceMatcher(None,[(k[0],k[1],k[2]) for k in jo],[(k[0],k[1],k[2]) for k in jg]); ok=0
    for tag,i1,i2,j1,j2 in sm.get_opcodes():
        if tag=="equal": ok+=i2-i1
    return ok,len(OUT),len(GT)

def score_bag(gt_file,out_file):
    """**对错位不敏感**的口径: 音高袋(bag of notes) 重合数。

    为什么需要它 ✗: score() 用 SequenceMatcher 做**序列对齐**, 而序列对齐对插入/删除
    **极敏感** —— 输出开头多一个 `0` 就会让后面**整段**被判成错 ✗。实测 2026-09-20:
    《兄弟抱一下》序列口径 20.9% ✗, 而音高袋 98.6% ✓ —— 同一份转写 ✗。
    序列口径只能反映"结构对齐度", 不能当"读对多少音" ✗。

    口径: 只比 (数字, 低八度点数) 的多重集合, 不管顺序/错位 ✓;
          连音杠 `-`、休止 `0` 也各自计一"音", 故漏/多都会体现 ✓。
    返回 (重合数, GT 数)。
    """
    from collections import Counter
    OUT=load_out(out_file); GT=load_gt(gt_file)
    co=Counter((key(x)[0],key(x)[1]) for x in OUT)
    cg=Counter((key(x)[0],key(x)[1]) for x in GT)
    return sum((co & cg).values()), len(GT)

def bag_detail(gt_file,out_file):
    """音高袋的明细: (漏读 Counter, 多读 Counter)。"""
    from collections import Counter
    OUT=load_out(out_file); GT=load_gt(gt_file)
    co=Counter((key(x)[0],key(x)[1]) for x in OUT)
    cg=Counter((key(x)[0],key(x)[1]) for x in GT)
    return cg-co, co-cg
def main(args):
    name=args[0]
    ok,o,g=score(args[1],args[2])
    print(f"{name}: 输出{o}音 GT{g}音 OK={ok} 宽松匹配率={100*ok/max(g,1):.1f}%")
if __name__=="__main__":
    main(sys.argv[1:])
