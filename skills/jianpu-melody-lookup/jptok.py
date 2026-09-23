# -*- coding: utf-8 -*-
"""简谱 token 的**唯一**解析实现(全项目只此一份, 不许再复制粘贴)。

为什么必须唯一: 同一个白名单正则原来散在 score.py / show_hit.py / lookup_*.py / 前端 search.js
里, 结果"升降号"这一处口径在三份代码里各不相同 —— 实测造成 **全库带 `#` 的音在 data.jsonl 里
被整段丢掉**(18 首受影响), 检索永远匹配不上, 而我查了三轮才定位到。教训: 口径只能有一份。

token 形态(记谱习惯, 变音记号写在数字**前**, 时值/八度前后都可能):
    [时值 qsdh]* [,']* [#b♯♭]? [1-7x0] [,']* [.]*
变音: # ♯ -> +1;  b ♭ -> -1;  无 -> 0
八度: 逗号 -1, 撇 +1, 逐字累加
休止 0 / 念白 x 不参与音高(但算 token)
"""
import re

TOKEN = re.compile(r"^([qsdh]*)([,']*)([#b♯♭]?)([1-7x0])([,']*)[.]*$")
# 放宽备用: 变音也可能写在数字后(q5# 之类), 或者纯记号 token
TOKEN_LOOSE = re.compile(r"^([qsdh]*)([,']*)([#b♯♭]?)([1-7x0])([,']*)([#b♯♭]?)[.]*$")
BAR = ("-", "|", "~")


def parse_token(t):
    """-> (音级 int|None, 变音 -1/0/1, 八度 int) ; 不是音符返回 None。

    音级对 0(休止)/x(念白) 返回 None(音高层面忽略), 但调用方仍可用 is_note() 判断它是不是 token。
    """
    m = TOKEN.match(t) or TOKEN_LOOSE.match(t)
    if not m:
        return None
    g = m.groups()
    pre, octs, acc, dig, post = g[0], g[1], g[2], g[3], g[4]
    acc2 = g[5] if len(g) > 5 else ""
    a = 1 if (acc in ("#", "♯") or acc2 in ("#", "♯")) else (-1 if (acc in ("b", "♭") or acc2 in ("b", "♭")) else 0)
    off = (octs + post).count(",") - (octs + post).count("'")
    if dig in "0x":
        return (None, a, off)
    return (int(dig), a, off)


def is_note(t):
    return parse_token(t) is not None


def is_pitch(t):
    """是音符(有音高), 排除休止/念白。"""
    p = parse_token(t)
    return p is not None and p[0] is not None


def seq(score):
    """整份谱 -> [(音级, 变音, 八度)]，只保留有音高的 token(与检索口径一致)。"""
    out = []
    for t in (score or "").split():
        p = parse_token(t)
        if p and p[0] is not None:
            out.append(p)
    return out


def query(raw):
    """用户输入(可自由加空格/标点) -> [(音级, 变音, 八度)]。"""
    out = []
    for m in re.finditer(r"([#b♯♭]?)([,']*)([1-7])([,']*)([#b♯♭]?)", raw):
        acc, pre, dig, post, acc2 = m.groups()
        a = 1 if (acc in ("#", "♯") or acc2 in ("#", "♯")) else (-1 if (acc in ("b", "♭") or acc2 in ("b", "♭")) else 0)
        off = (pre + post).count(",") - (pre + post).count("'")
        out.append((int(dig), a, off))
    return out


def show(notes):
    """[(音级,变音,八度)] -> 可读串(如 `6 3 7 #5`)"""
    return " ".join(("#" if a == 1 else "b" if a == -1 else "") + str(d) for d, a, _o in notes)

# ---------------- 时值 / 小节线恢复(唯一实现) ----------------
# 为什么放这里: 拍值表一度在 score.py 里又写了一份(第五个"复制口径"), 而它同时被
# 前端、评测、小节线恢复共用 —— 只能有一份。
BEAT = {"h": 2.0, "": 1.0, "q": 0.5, "s": 0.25, "d": 0.125}
DEFAULT_BEATS_PER_BAR = 4.0


def beat(tok):
    """一个 token 占几拍。h=2, 无前缀=1(四分), q=.5, s=.25, d=.125; 附点 x1.5。
    未知前缀按最短算(宁可多落线, 不要漏)。"""
    m = re.match(r"^([qsdh]*)", tok or "")
    v = BEAT.get(m.group(1) if m else "", None)
    if v is None:
        v = 0.0625
    return v * 1.5 if (tok or "").endswith(".") else v


def beats_per_bar_from(text, default=DEFAULT_BEATS_PER_BAR):
    """从谱面文本里找拍号(独立成行的 `n/d`), 返回每小节拍数。找不到用默认 4/4。"""
    m = re.search(r"(?m)^\s*(\d+)\s*/\s*(\d+)\s*$", text or "")
    if not m:
        return default
    try:
        return int(m.group(1)) * 4.0 / int(m.group(2))
    except ZeroDivisionError:
        return default


def recover_bars(sections, beats_per_bar, keep_explicit=True):
    """按拍号+时值恢复小节线。

    sections: [{'score': '音符 token 串'}, ...]  —— 已展开(时值显式)
    返回 [音符下标], 语义: 第 i 个音符**之前**有一条小节线。
    源里已有的 `|` 当强小节线(累加器强制归零), 处理弱起/不规则小节。
    """
    bars, n, acc = [], 0, 0.0
    for sec in sections or []:
        for t in (sec.get("score") or "").split():
            if t == "|":
                if keep_explicit:
                    bars.append(n)
                acc = 0.0
                continue
            if t == "-":
                acc += 1.0
                continue
            p = parse_token(t)
            if not p or p[0] is None:
                continue                      # 休止/念白: 保守不计时
            acc += beat(t)
            n += 1
            if acc >= beats_per_bar - 1e-9:
                bars.append(n)
                acc = 0.0
    return bars
