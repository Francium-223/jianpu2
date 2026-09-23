# -*- coding: utf-8 -*-
"""旋律反查(面向普通用户版): **只输数字**就能查, 模糊匹配, 段落加权。

为什么需要这个:
  * 用户不懂 jianpu-ly —— 不需要输 q/时值/八度/附点, 只要哼出来的音级数字
  * 转写/记谱都有错 —— 必须容忍少量不一致(模糊匹配), 而不是整串精确相等
  * 段落有轻重 —— 副歌(chorus)是"记得住的那句", 匹配到副歌比匹配到前奏更该靠前

输入: 任意含数字的串, 标点/空格/汉字一律忽略
    py tools/melody_find.py "3356 5653253"
    py tools/melody_find.py 33565653253 --fuzzy 2 --top 15
    py tools/melody_find.py 33565653253 --intervals    # 按音程比, 换调也能查到

段落权重(JIANPU 里 subtitle= 的值, 见 survey_sections.py 普查):
    chorus 1.6 · verse 1.25 · pre-chorus/bridge/interlude 1.1
    intro/outro/layer/crazy-piano 0.8 · score(未分段) 1.0
    组合标签(如 "intro,chorus")取最大权
"""
import glob
import io
import os
import re
import sys

sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from token_json import normalize_tokens, is_marker, is_tuplet_marker

# ---- 段落权重(可调) ----
SECTION_W = {
    "chorus": 1.60, "refrain": 1.60,
    "verse": 1.25,
    "pre-chorus": 1.10, "prechorus": 1.10, "bridge": 1.10, "interlude": 1.10,
    "score": 1.00,
    "intro": 0.80, "outro": 0.80, "layer": 0.80, "crazy-piano": 0.80,
}
SECTION_CN = {"chorus": "副歌", "verse": "主歌", "intro": "前奏", "outro": "尾奏",
              "pre-chorus": "预副歌", "bridge": "桥段", "interlude": "间奏",
              "layer": "叠加层", "crazy-piano": "钢琴华彩", "score": "整曲"}


def section_weight(name):
    """段落名 -> 权重。组合标签取最大。"""
    if not name:
        return 1.0
    parts = [p.strip().lower() for p in re.split(r"[,/|+]", name) if p.strip()]
    if not parts:
        return 1.0
    return max(SECTION_W.get(p, 1.0) for p in parts)


def section_label(name):
    return SECTION_CN.get((name or "").strip().lower(), name or "整曲")


# ---- 取每个文件的"段落 -> 数字串" ----
def meta_of(path):
    """读 title= / alias= —— 给用户看歌名, 而不是 th10_06 这种内部 ID。"""
    title = alias = ""
    try:
        for l in io.open(path, encoding="utf-8", errors="replace"):
            if not title:
                m = re.match(r"^\s*title\s*=\s*(.+)$", l.strip(), re.I)
                if m:
                    title = m.group(1).strip()
            if not alias:
                m = re.match(r"^\s*alias\s*=\s*(.+)$", l.strip(), re.I)
                if m:
                    alias = m.group(1).strip()
            if title and alias:
                break
    except Exception:
        pass
    return title, alias


def sections_of(path):
    """返回 [(段落名, 数字串, 起始位置序号)]。兼容 jianpu-db 格式与纯 token 文件。"""
    try:
        txt = io.open(path, encoding="utf-8", errors="replace").read()
    except Exception:
        return []
    lines = [l.strip() for l in txt.splitlines()]
    # jianpu-db 格式: 音符在第一个 %-- 之后; 段落由 subtitle= 标记
    start = 0
    for i, l in enumerate(lines):
        if l.lower().startswith("%--"):
            start = i + 1
            break
    cur = "score"
    secs = []
    buf = []
    def flush():
        if buf:
            # 关键: 先把 token 规范化再取数字 ——
            #   规则1: `1 ~ 1`(同音+连音线) 要合并成一个音, 否则检索时多算一个音
            #   规则2: `3[` 里的 3 是三连音标记, 不是音符, 否则会多出一个假音
            norm = normalize_tokens(buf, merge_ties=True)
            secs.append((cur, "".join(re.match(r"^[,']*[qsdh]*[,']*([1-7])", t).group(1)
                                      for t in norm if re.match(r"^[,']*[qsdh]*[,']*[1-7]", t)), 0))
    for l in lines[start:]:
        if not l:
            continue
        m = re.match(r"^subtitle\s*=\s*(.*)$", l, re.I)
        if m:
            flush(); buf = []
            cur = m.group(1).strip() or "score"
            continue
        if l.startswith("%"):
            continue
        for t in l.split():
            if re.match(r"^[,']*[qsdh]*[,']*[1-7]", t) or is_marker(t) or is_tuplet_marker(t):
                buf.append(t)
    flush()
    return secs


def to_intervals(digits):
    """音级串 -> 音程串(相对前一个音的半音差), 用于换调匹配。"""
    step = {"1": 0, "2": 2, "3": 4, "4": 5, "5": 7, "6": 9, "7": 11}
    if not digits:
        return ""
    out = []
    for a, b in zip(digits, digits[1:]):
        d = (step.get(b, 0) - step.get(a, 0)) % 12
        if d > 6:
            d -= 12
        out.append(chr(ord("a") + d + 6))     # -6..+6 -> a..m
    return "".join(out)


def best_match(q, text, fuzzy):
    """在 text 里找与 q 最接近的等长窗口。
    返回 (不同处数, 起点, 匹配段) 或 None。
    先精确找(快), 找不到再用"允许 fuzzy 处不同"的滑窗。"""
    n, m = len(q), len(text)
    if m < n:
        return None
    pos = text.find(q)
    if pos >= 0:
        return (0, pos, q)
    if fuzzy <= 0:
        return None
    best = None
    for i in range(m - n + 1):
        diff = 0
        for a, b in zip(q, text[i:i + n]):
            if a != b:
                diff += 1
                if diff > fuzzy:
                    break
        if diff <= fuzzy and (best is None or diff < best[0]):
            best = (diff, i, text[i:i + n])
            if diff == 0:
                break
    return best


SOURCES = [
    ("用户仓库(人工校对)", "D:/Documents_D/jianpu-db/scores/*.txt"),
    ("我转换的", "jianpu-db-out/scores/*.txt"),
    # 必须包含 batch-out: 新爬新转的谱在这里, 要等收尾才进 jianpu-db-out/scores。
    # 漏了它会导致"刚转完的歌搜不到" —— 实测《甜蜜蜜》《浮夸》都被漏掉过。
    ("我转写的(最新)", "batch-out/*.txt"),
]


def parse_args(argv):
    """解析命令行: 位置参数(查询)与 --flag value 分开。
    坑: 不能简单地"过滤掉以 -- 开头的", 那样 `--top 12` 的 12 会被当成查询数字
    (实测把 12 音的查询污染成 14 音)。"""
    VALUE_FLAGS = {"--fuzzy", "--top", "--min"}
    pos, opts = [], {}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in VALUE_FLAGS:
            opts[a] = argv[i + 1] if i + 1 < len(argv) else ""
            i += 2
            continue
        if a.startswith("--"):
            opts[a] = True
            i += 1
            continue
        pos.append(a)
        i += 1
    return pos, opts


def main():
    pos, opts = parse_args(sys.argv[1:])
    if not pos:
        print(__doc__)
        return
    # 用户可能把数字分开打(`3 3 5 6 5 6 5 3 2 5 3`), 也可能带空格/竖线/汉字 -> 全拼起来再抽数字
    q = re.sub(r"[^1-7]", "", " ".join(pos))
    if len(q) < 3:
        print("查询太短(至少 3 个音), 容易匹配到一大堆")
        return
    fuzzy = int(opts.get("--fuzzy", 1))
    top = int(opts.get("--top", 15))
    use_iv = "--intervals" in opts

    qq = to_intervals(q) if use_iv else q
    print(f"查询: {q}  ({len(q)} 音)   模糊容差 {fuzzy} 处"
          + ("   [按音程比, 换调也能查]" if use_iv else ""))

    rows = []
    for label, pat in SOURCES:
        for f in glob.glob(pat):
            if not f.endswith(".txt") or os.path.basename(f) in ("progress.txt", "skipped.txt"):
                continue
            name = os.path.basename(f)[:-4]
            title, alias = meta_of(f)
            disp = title or name
            if alias and alias not in disp:
                disp = f"{disp}（{alias}）"
            for sec, digits, _ in sections_of(f):
                d = to_intervals(digits) if use_iv else digits
                mt = best_match(qq, d, fuzzy)
                if not mt:
                    continue
                diff, pos, seg = mt
                sw = section_weight(sec)
                # 打分: 匹配长度 * 段落权 * 覆盖率(整段里匹配占比) - 错音惩罚
                cover = len(qq) / max(len(d), 1)
                score = len(qq) * sw * (0.5 + 0.5 * min(cover * 20, 1)) - diff * len(qq) * 0.25
                rows.append((score, label, disp, name, sec, diff, pos, digits, sw))
    # 同一首歌(同名)的 _expand 与原始版本会重复 -> 按(歌名,段落,错数)去重, 留分高的
    seen = {}
    for r in rows:
        key = (r[2], r[4], r[5])
        if key not in seen or r[0] > seen[key][0]:
            seen[key] = r
    rows = sorted(seen.values(), key=lambda x: -x[0])
    print(f"\n命中 {len(rows)} 处" + (f" (显示前 {top})" if len(rows) > top else ""))
    print(f"{'得分':>6}  {'段落':<8}{'权':>4} {'错':>3}  {'曲名':<36}{'来源'}")
    print("-" * 88)
    for score, label, disp, name, sec, diff, pos, digits, sw in rows[:top]:
        print(f"{score:6.1f}  {section_label(sec):<8}{sw:4.1f} {diff:3d}  {disp[:36]:<36}{label}")
        # 匹配位置的前后文, 让用户能核对
        lo, hi = max(0, pos - 5), min(len(digits), pos + len(qq) + 5)
        ctx = digits[lo:pos] + "【" + digits[pos:pos + len(qq)] + "】" + digits[pos + len(qq):hi]
        print(f"{'':6}  └ 第{pos}音起  …{ctx}…")
    if not rows:
        print("   (无 —— 加大 --fuzzy, 或试 --intervals)")


if __name__ == "__main__":
    main()
