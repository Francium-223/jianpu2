# -*- coding: utf-8 -*-
"""token→JSON 解析: 把 jianpu-ly token(如 q,5.) 解析成结构化 JSON。
验证解析正确性。
"""
import json, sys, re
sys.stdout.reconfigure(encoding="utf-8")

# 时值前缀
BEAM = {"": 0, "q": 1, "s": 2, "d": 3, "h": 4}


def token_to_json(tok):
    """解析 jianpu-ly token。

    **两种写法都要认**: jianpu-ly 官方说明"字符顺序无所谓, s1 与 1s 等价"。
    本管线的输出用**前置**(`q,5.`), 但人手写的 GT / jianpu-ly 谱面常用**后置**(`,5q.`)。
    早先只认前置, 导致 GT 评测把 GT 的 `3q` 解析成 digit='3q'/beam=0,
    与我方 token 永远匹配不上 —— 实测把匹配率压到 31.5%(虚低, 不是转写差)。
    """
    # 去除附点
    dotted = tok.count(".")
    body = tok.replace(".", "")
    # 升号
    acc = ""
    if "#" in body:
        acc = "#"; body = body.replace("#", "")
    elif "b" in body:
        acc = "b"; body = body.replace("b", "")
    # 时值: 先试前置(h/d/s/q 开头), 再试后置(...q/s/d/h 结尾)
    # c = crotchet(四分) —— jianpu-ly 的 KeepLength 写法(如 `6c.`), 必须认,
    # 否则 `6c.` 整块解析失败, 数字串错位(实测检索失配)
    beam = 0
    for p, b in [("h", 4), ("d", 3), ("s", 2), ("q", 1), ("c", 0)]:
        if body.startswith(p):
            beam = b; body = body[len(p):]; break
    if beam == 0:
        for p, b in [("h", 4), ("d", 3), ("s", 2), ("q", 1), ("c", 0)]:
            if body.endswith(p):
                beam = b; body = body[:-len(p)]; break
    # 高八度: 撇号在数字前或后都算
    voice = "'" * body.count("'")
    body = body.replace("'", "")
    # 低八度: 逗号个数
    low = body.count(",")
    body = body.replace(",", "")
    digit = body
    return {
        "digit": digit,
        "accidental": acc,
        "voice": voice,
        "low": low,
        "beam": beam,
        "dotted": dotted,
    }


def json_to_token(j):
    """JSON→jianpu-ly token(组装)。"""
    dur = {0: "", 1: "q", 2: "s", 3: "d", 4: "h"}[j["beam"]]
    acc = j["accidental"]
    low = "," * j["low"]
    voice = j["voice"]
    digit = j["digit"]
    dotted = "." * j["dotted"]
    return dur + acc + low + voice + digit + dotted


# ---------------------------------------------------------------- 结构符号处理
# jianpu-ly 里除了音符还有"结构符号", 它们**不是音符**, 但会混进 token 流:
#   `3[` `]`      三连音标记(小号 3 + 方括号) —— 那个 3 **不能当音符**
#   `~`           连音线(tie): 两侧**同一个音**合并成一个音, 不是两个音
#   `( )` `{ }`   圆滑线/反复等 —— 只是分句, 两侧音符都保留
#   `|`           小节线
# 这是用户明确指出的两条记谱规则(GT 里就写着 `2s ~ 2q` 和 `3[ q1 q1 q1 ]`)。
STRUCT_CHARS = "[](){}~|"
TUPLET_NUM = re.compile(r"^([0-9])\s*\[$")      # "3[" -> 三连音标记


def is_marker(tok):
    """是不是纯结构符号(不是音符)。"""
    return bool(tok) and all(c in STRUCT_CHARS for c in tok)


def is_tuplet_marker(tok):
    """`3[` `5[` 这种: 数字+左方括号 = 三连音标记, 数字不是音符。"""
    return bool(TUPLET_NUM.match(tok.replace(" ", "")))


def normalize_tokens(toks, merge_ties=True):
    """把 token 流规范化成**实际发声的音符序列**:
      * 丢掉三连音标记(`3[`)、右括号、圆滑线、小节线等结构符号
      * merge_ties=True 时, `X ~ X` 两侧同音高的音符合并成一个音
        (连音线表示一个音被延长, 不是两个音)
    返回 token 列表。默认保留原 token 文本, 便于人工核对。
    """
    out = []
    pending_tie = False
    for t in toks:
        if is_tuplet_marker(t):
            continue                      # `3[` 的 3 不是音符
        if is_marker(t):
            if "~" in t:
                pending_tie = True        # 下一个音与上一个合并
            continue
        out.append(t)
        if merge_ties and pending_tie and len(out) >= 2:
            # 连音线两端音高相同才是延长(tie); 不同则是圆滑线, 不动
            if _pitch(out[-1]) == _pitch(out[-2]):
                out.pop()
            pending_tie = False
        elif pending_tie:
            pending_tie = False
    return out


def _pitch(tok):
    """取"音高"部分(数字+八度+升降), 忽略时值与附点 —— 判连音线用。"""
    j = token_to_json(tok)
    return (j["digit"], j["low"], j["voice"], j["accidental"])


# 自测: **必须放在 __main__ 里** —— 否则任何 import 本模块的脚本
# (eval_gt / melody_find ...) 都会先打印这 10 行, 污染工具输出
if __name__ == "__main__":
    tests = ["1", "q5", "s2.", ",5", "q,5", "5-", "3[", "q,5.", "'1", ",,7"]
    for t in tests:
        j = token_to_json(t)
        back = json_to_token(j)
        print(f"{t:6s} -> {json.dumps(j, ensure_ascii=False)} -> {back}")
    print("\n结构符号:")
    for t in ["3[", "]", "~", "(", ")"]:
        kind = ("三连音标记" if is_tuplet_marker(t) else
                "结构符号" if is_marker(t) else "音符")
        print(f"   {t!r:6s} {kind}")
    print("\n连音线合并(规则1):")
    for s in ["1 ~ 1", "1 ~ 2", "3 ~ 3 ~ 3"]:
        print(f"   {s:12s} merge=True -> {normalize_tokens(s.split(), True)}")
        print(f"   {'':12s} merge=False-> {normalize_tokens(s.split(), False)}")
