# -*- coding: utf-8 -*-
"""简谱 token 的**唯一**解析实现(全项目只此一份, 不许再复制粘贴)。

为什么必须唯一: 同一个白名单正则原来散在 score.py / show_hit.py / lookup_*.py / 前端 search.js
里, 结果"升降号"这一处口径在三份代码里各不相同 —— 实测造成 **全库带 `#` 的音在 data.jsonl 里
被整段丢掉**(18 首受影响), 检索永远匹配不上, 而我查了三轮才定位到。教训: 口径只能有一份。

token 形态(变音与**时值**都前后可能, 末尾可带 `]` 分组闭记号):
    [时值 cqsdh]* [,']* [#b♯♭]? [1-7x0] [,']* [#b♯♭]? [时值 cqsdh]* [.]* \\]?
变音: # ♯ -> +1;  b ♭ -> -1;  无 -> 0
八度: 逗号 -1, 撇 +1, 逐字累加
休止 0 / 念白 x 不参与音高(但算 token)

⚠ 2026-09-23 第二次踩同一个坑: 上面的说明一直写着「时值前后都可能」, 但正则**只实现了前缀**。
   手工录入的 36 首(东方曲 + 校歌, status=ok)大量使用后缀形(`6c.` / `5s` / `3q` / `,6q` / `q3[`),
   它们 parse 返回 None, 被 seq()/toks_of() **静默跳过** —— 这些曲子索引里少了 40% 的音
   (最多的一首丢 91%), 旋律被打乱成另一首歌的样子。
   表现: th10_06 第 1 小节明明是 `3 3 5 6 5 6 5 3 2`(与用户人耳相符), 检索却看到 `3 3 5 6 3 2 5 5 6`。
   教训: **docstring 承诺的形态必须在正则里兑现**, 否则就是第二次"带 # 的音整段消失"。

⚠ 2026-09-28 第三次踩同一个坑(**三连音记号被当成音符**): jianpu-ly 的三连音写作
   `3[ 5 3 4 ]` —— 那个 `3[` 里的 3 是**连音数**(3 个音占 2 个音的时值), `[` / `]` 是分组记号,
   **都不是音符**。而本文件的白名单原来允许 token 末尾带 `[`, 于是
   `parse_token('3[')` 返回 `(3,0,0)`、`seq('3[ 5 3 4 ]')` 得到 **4 个音**(凭空多一个 3)。
   实测: 语料里有 66 处 `<时值>3[`(分在 4 首), 手抄 GT 里有 23 处 `3[` + 23 处 `]` —— 全被多算。
   修法: 末尾只允许 `]`, **不允许 `[`**(开记号永远不是音符)。
   注: 这只保证**音高/音数**正确; 连音组内部的 2/3 时值压缩没实现(那些音按各自写明的时值计时),
   影响面是那 4 首的**小节线显示**, 不影响检索。
"""
import re

# 唯一白名单(整体匹配): 前时值 + 前八度 + 前变音 + 音级 + 后八度 + 后变音 + 后时值 + 附点 + 闭记号
# ⚠ 这里**只允许 `]`**: `[` 是**三连音开记号**(写作 `3[ 5 3 4 ]`, 那个 3 是连音数, 不是音符),
#   允许它就会把开记号算成一个音(实测语料 66 处、GT 46 处)。
TOKEN = re.compile(
    r"^(?P<pre>[cqsdh]*)"
    r"(?P<oct1>[,']*)"
    r"(?P<acc>[#b♯♭]?)"
    r"(?P<dig>[1-7x0])"
    r"(?P<oct2>[,']*)"
    r"(?P<acc2>[#b♯♭]?)"
    r"(?P<post>[cqsdh]*)"
    r"(?P<dot>[.]*)"
    r"(?P<mark>\]?)$"
)
# 旧名字保留(曾有脚本引用); 口径已合并成上面唯一一份, 不再有 strict/loose 之分
TOKEN_LOOSE = TOKEN
BAR = ("-", "|", "~")


def parse_token(t):
    """-> (音级 int|None, 变音 -1/0/1, 八度 int) ; 不是音符返回 None。

    音级对 0(休止)/x(念白) 返回 None(音高层面忽略), 但调用方仍可用 is_note() 判断它是不是 token。
    """
    m = TOKEN.match(t or "")
    if not m:
        return None
    g = m.groupdict()
    acc, acc2 = g["acc"], g["acc2"]
    a = 1 if (acc in ("#", "♯") or acc2 in ("#", "♯")) else (-1 if (acc in ("b", "♭") or acc2 in ("b", "♭")) else 0)
    off = (g["oct1"] + g["oct2"]).count(",") - (g["oct1"] + g["oct2"]).count("'")
    if g["dig"] in "0x":
        return (None, a, off)
    return (int(g["dig"]), a, off)


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
BEAT = {"h": 0.0625, "c": 1.0, "": 1.0, "q": 0.5, "s": 0.25, "d": 0.125}
# ⚠ 2026-09-24 定案: **h = 六十四分音符(1/64 拍)**, 不是二分音符。
#   原来写成 2.0 是笔误(`expand_keep_length` 的 docstring 里也这么写, 但那份 docstring
#   在"时值可前可后"上已经错过一次, 不能当规格用)。证据:
#     ① 项目自己的 jianpu-ly(jianpulocal/mxml2jp-main/jianpu-ly_patched.py:1106)
#        写着 types={"64th":"h", "32nd":"d", ..., "half":" -", "whole":" - - -"}
#        —— 二分音符是"数字 + 破折号", 语料里确实有 32 万个 `-` 在干这件事;
#     ② 251 首 jianpu-ly 转出来的 midi 曲里, h 成串出现(平均每串 4.36 个, 最长 1804 个,
#        形如 `h,,#4 h,,#4 …` 的密集低音走句) —— 按 64 分音符是 28 拍, 按二分音符是 3608 拍;
#     ③ OCR 曲里 h 后面紧跟 `-` 的只有 0.4%(若 h 是二分音符, 简谱会写 `1 -`);
#        51.8% 的 h 邻居是 16/32 分音符, 最长 17 个连续 h;
#     ④ `convert.py` 给 OCR 模型的提示里, 二分音符明确写 `1 -`, 时值只列 q/s/d —— 从没说 h 是二分。
#   影响面: 只影响含 h 的 354 首的 `bars`(小节线显示/高亮), 不影响检索(音高与升降号)。
DEFAULT_BEATS_PER_BAR = 4.0


def duration_letter(tok):
    """取出 token 的时值字母 —— **前**置优先, 没有就取**后**置(与 parse_token 同一口径)。

    实测语料: `c` 只以后置出现(`6c.`, 前缀 0 次), 后置 `q/s/d` 也有一千多个 ——
    以前 beat() 只读前缀, 这些音在小节线恢复里被当成 1 拍, 于是它们的 `bars` 也跟着错。
    """
    t = tok or ""
    m = re.match(r"^([cqsdh]+)", t)
    if m:
        return m.group(1)
    m = re.search(r"([cqsdh]+)[.]*[\[\]]?$", t)
    return m.group(1) if m else ""


def beat(tok):
    """一个 token 占几拍。h=2, c=1, 无时值=1(四分), q=.5, s=.25, d=.125; 附点 x1.5。
    时值字母**前后都认**(与 parse_token 同口径)。未知字母组合按最短算(宁可多落线, 不要漏)。"""
    v = BEAT.get(duration_letter(tok), None)
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


def tuplet_ratio(word):
    """`3[` 这类连音开记号 -> (num, fitIn); 不是记号返回 None。

    这是**抄参考实现**, 不是自己推的: jianpu-ly_patched.py:1786 里
        fitIn = int(word[:-1]); i = 2; while i < fitIn: i *= 2
        num = int(fitIn*3/2) if i == fitIn else int(i/2)
        notehead_markup.tuplet = (num, fitIn)      # 时值 × num/fitIn
    于是 `3[` -> fitIn=3, i=4, num=int(4/2)=2 -> 时值 ×2/3, 与它输出的 `\\times 2/3 { … }` 一致
    (train-work/gt/Lemon_用户.ly 里 20 处 `\\times 2/3` 就是这段源码渲染出来的)。
    组内**音符个数** = fitIn; `]` 收尾, 或者装满 fitIn 个(语料里 MIDI 转来的写法没有 `]`)。
    """
    m = re.match(r"^([1-9][0-9]*)\[$", word or "")
    if not m:
        return None
    fit_in = int(m.group(1))
    i = 2
    while i < fit_in:
        i *= 2
    num = int(fit_in * 3 / 2) if i == fit_in else int(i / 2)
    return (num, fit_in)


def recover_bars(sections, beats_per_bar, keep_explicit=True):
    """按拍号+时值恢复小节线。

    sections: [{'score': '音符 token 串'}, ...]  —— 已展开(时值显式)
    返回 [音符下标], 语义: 第 i 个音符**之前**有一条小节线。
    源里已有的 `|` 当强小节线(累加器强制归零), 处理弱起/不规则小节。

    ⚠ 2026-09-23 修正: **休止 `0` / 念白 `x` 也占拍, 必须计时**。
    原来这里是 `if not p or p[0] is None: continue  # 休止/念白: 保守不计时`,
    结果是"只数旋律音的拍子" —— 只要谱里有休止, 小节线就会**整体前漂**:
    th10_06 开头有 2.5 拍休止, 第一条线就早了 1.5 拍(用户一眼看出 `c0 q0 q3 q3 |` 不对)。
    改成计时后, th10_06 前三个小节正好各 4.0 拍:
        [c0 c- q0 q3 q3 q5] [c6. s5 s6 q5 q3 q2 q5] [c3 c- c- q3 q5] …
    即"2.5 拍休止 + 3 个八分音符弱起" —— 这才是这首曲子的真实小节。

    ⚠ 2026-09-28 补: **连音组内的时值要按 num/fitIn 缩放**(见 tuplet_ratio)。
    以前连音开记号 `3[` 被当成一个音(还占一整拍), 组内三个音按各自的字面时值计时 ——
    含连音的 4 首(th06_15 / qd1z_anthem / th10_06 / th075_34)小节线因此偏。
    现在: 开记号本身不占拍; 组内每个 token 的时值 ×num/fitIn; 装满 fitIn 个或遇 `]` 收组。
    """
    bars, n, acc = [], 0, 0.0
    ratio, left = 1.0, 0          # 连音比例与组内剩余个数
    for sec in sections or []:
        for t in (sec.get("score") or "").split():
            if t == "|":
                if keep_explicit:
                    bars.append(n)
                acc = 0.0
                continue
            if t == "]":              # 连音组收尾
                ratio, left = 1.0, 0
                continue
            tp = tuplet_ratio(t)
            if tp:                    # 连音组开头(它自己不是音符, 不占拍)
                ratio, left = tp[0] / float(tp[1]), tp[1]
                continue
            if t == "-" or re.match(r"^[cqsdh]+-$", t or ""):
                # `-` = 延长一拍; `c-`/`q-` 是 KeepLength 补时值时的写法(全库 363 个)。
                # 以前因为白名单不认被整段丢掉 -> 这些歌的小节线会往前漂。
                # ⚠ 2026-09-28: 改成 `acc += beat(t)`。原来这里写死 `+= 1.0`, **不看字母**,
                #   于是 `q-`(半拍)被当成一整拍, 那一小节之后的线全部偏移。
                #   证据是参考实现, 不是推理: jianpu-ly 把 `q-` 渲染成 `\note-mod "–" c''8`(八分),
                #   tools/check_beats_vs_lilypond.py 在 4 首带 .ly 的谱里**逐例**对上 ——
                #   分歧次数正好等于各谱的 `q-` 个数(th01_03 5 / th02_05 4 / th02_01 1),
                #   而全库共 35 个 `q-`, 分布在 6 首(th17_13 12 / th10_06 8 / th01_03 5 /
                #   th07_13 5 / th02_05 4 / th02_01 1)。
                acc += beat(t) * ratio
                continue
            p = parse_token(t)
            if not p:
                continue                      # 根本不是 token(升降号之外的记号等)
            if p[0] is not None:
                n += 1                        # 只有**有音高**的音才推进"第几个音符"
            acc += beat(t) * ratio            # 休止/念白同样占拍: 不记时会让小节线前漂
            if left > 0:
                left -= 1                     # 连音组内: 装满就自动收组(语料里没有 `]` 的写法)
                if left == 0:
                    ratio = 1.0
            if acc >= beats_per_bar - 1e-9:
                bars.append(n)
                acc = 0.0
    # ⚠ 2026-09-28: **去掉相邻重复**。休止/念白占拍但不推进 n, 所以当"一串休止跨过整小节"时,
    #   同一个音下标会被落两次线 —— 实测 101.txt 得到 [1,3,6,7,7,8,8,…](语料里 3044 首有这种
    #   重复), 前端会把它渲染成一个**空小节**。"第 i 个音符之前有两条线"没有意义, 去重是对的。
    #   (开头的 0 **保留**: 它表示"第一小节整小节是休止", 显示出来是有信息的。)
    out = []
    for b in bars:
        if not out or out[-1] != b:
            out.append(b)
    return out
