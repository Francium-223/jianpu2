# -*- coding: utf-8 -*-
"""旋律检索: 按数字串反查"这是哪首歌" —— 给机器人/命令行用。

口径(与前端检索、技能 lookup.py 的"只比音高数字"这一层一致):
  * 只看**音高数字 1-7**; 时值(`q`/`s`/`c`/`d`/`h` 前后缀)、八度(`'`/`,`)、附点 `.`、
    变音记号(`#`/`b`)一律**不看**;
  * 休止/念白(`0`/`x`/`q0`/`sx`)、延长线 `-`/`~`、调号 `1=C` **不进**数字串;
  * 连续子串匹配: 查的这串数字必须在歌里**连着出现**(休止不算断开, 因为休止不进数字串)。
  * **token 口径只有一份**: 用 `skills/jianpu-melody-lookup/jptok.py`(全库唯一实现)切 token,
    不再自己写正则 —— 自写的窄正则会静默丢掉 `b7`(降号)与 `6c.`(后缀时值)这类 token,
    正是 2026-09-23 "索引丢音" 事故同一类坑。实测: jptok 解出 **1,301,430** 个音,
    与前端索引 `stats.json` 的 notes 数**完全一致**。

⚠ 2026-09-24 换掉语料来源: 老版本搜的是 `batch-out/*.txt`(旧流水线的中间产物,
  8495 个文件, 里面**没有 th10_06**, 连 `33565653253` 这种确定存在的查询都返回"命中 0 首")。
  现在直接搜 `jianpu-db/data.jsonl`(唯一真源, 7321 首, status ∈ {ok,ocr})——顺带能给出
  曲名/歌手/出处/记谱文件, 机器人回话才有用。

速度: 冷启(读 13MB jsonl + jptok 切 130 万个 token)约 6 秒; 所以默认在
  `~/.cache/jianpu/melody_index.json` 存一份数字索引, 用 `data.jsonl` 的 size+mtime_ns
  + `TOKVER` 做指纹 —— 语料一变就自动重建(不做"看着像"的过期缓存), 之后每次查询约 0.3 秒。
  `--no-cache` 可强制不用缓存。

用法:
  python3 tools/melody_search.py 33565653253
  python3 tools/melody_search.py 33565653253 --fuzzy 1 --top 5
  python3 tools/melody_search.py 63731232 --json          # 给机器人解析
  python3 tools/melody_search.py "63731232 1765"          # 多段(空格/逗号/竖线分隔): 每段都要出现
"""
import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                      # jianpu2
WS = os.path.dirname(ROOT)                        # 工作区(三个仓库的上一层)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
DATA = os.path.join(DB, "data.jsonl")
OK_STATUS = ("ok", "ocr")                         # 与 parse_scores 的白名单同一份口径
TOKVER = 2                                        # 切 token 的口径改了就 +1(缓存自动失效)
CACHE = os.environ.get("JIANPU_MELODY_CACHE") or os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache"),
    "jianpu", "melody_index.json")

sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
try:
    import jptok                                   # 唯一 token 实现
except Exception:                                  # 独立部署时可能没有 -> 兜底正则(同口径)
    jptok = None
# 兜底: 与 jptok 同口径 —— 变音记号在数字**前面**, 后缀时值(`6c.`)也要认出来
TOK = re.compile(r"^[,']*[cqsdh]*[,']*[#b♯♭]?([1-7])")


def digits_of(text):
    """token 流 -> 纯数字串(丢掉时值/八度/附点/变音/休止/调号)。"""
    return "".join(d for d, _o in _tokens(text))


def _tokens(text):
    """token 流 -> [(音高数字, 八度偏移), ...]"""
    out = []
    for t in (text or "").split():
        if jptok is not None:
            if jptok.is_pitch(t):
                tok = jptok.parse_token(t)
                out.append((str(tok[0]), int(tok[2])))
            continue
        if "=" in t:                              # 调号 `1=C` 里的 1 不是音符
            continue
        m = TOK.match(t)
        if m:
            out.append((m.group(1), 0))
    return out


def digits_of_file(path):
    """老接口(收的是文件路径), 保留给外部脚本用。"""
    with open(path, encoding="utf-8", errors="replace") as f:
        return digits_of(f.read())


def _fingerprint(path):
    st = os.stat(path)
    return {"path": os.path.abspath(path), "size": st.st_size, "mtime_ns": st.st_mtime_ns}


def build_corpus(path=DATA):
    """data.jsonl -> 可检索的索引(一行一首, 带够机器人回话用的元数据)。"""
    rows = []
    with open(path, encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if not ln:
                continue
            try:
                r = json.loads(ln)
            except ValueError:
                continue
            st = r.get("status")
            st = st if isinstance(st, list) else [st]
            if not any((x or "") in OK_STATUS for x in st):
                continue
            d = digits_of(r.get("score") or "")
            if not d:
                continue
            src = r.get("source") or ""
            src = src[0] if isinstance(src, list) else src
            f0 = (r.get("file") or [""])[0]
            rows.append({
                "title": r.get("title") or "",
                "artist": list(r.get("artist") or []),
                "tag": list(r.get("tag") or []),
                "source": src,
                "site": (src.split("-")[0] if src else ""),
                "file": f0,
                "id": src or ("f-" + os.path.splitext(f0)[0]),
                "n_notes": int(r.get("n_notes") or 0),
                "status": (st[0] or ""),
                "digits": d,
                "digits_len": len(d),
            })
    return rows


def _hotmap(rows):
    """知名度代理: 某个名字(歌手/标签, 不含「分类/…」)在语料里出现在多少首里。

    公式与 jianpu-web/tools/build_web_data.py、skills/jianpu-melody-lookup/lookup.py **必须一致**。
    """
    m = {}
    for r in rows:
        names = list(r.get("artist") or []) + [t for t in (r.get("tag") or []) if not str(t).startswith("分类/")]
        for n in names:
            m[n] = m.get(n, 0) + 1
    return m


def _annotate(rows):
    """给每行补 pop(同曲名组份数) 与 hot(歌手/标签在语料里的谱数) —— 并列时按它们排序。"""
    hot = _hotmap(rows)
    pop = {}
    for r in rows:
        pop[r["title"]] = pop.get(r["title"], 0) + 1
    for r in rows:
        names = list(r.get("artist") or []) + [t for t in (r.get("tag") or []) if not str(t).startswith("分类/")]
        r["pop"] = pop.get(r["title"], 0)
        r["hot"] = max([hot.get(n, 0) for n in names] or [0])
    return rows


def load_corpus(path=DATA, use_cache=True):
    """带缓存地建索引: 指纹(size+mtime_ns+TOKVER)不符就重建 —— 绝不用过期的数字串。"""
    try:
        fp = _fingerprint(path)
    except OSError:
        return _annotate(build_corpus(path))
    if use_cache:
        try:
            with open(CACHE, encoding="utf-8") as f:
                c = json.load(f)
            if c.get("ver") == TOKVER and c.get("src") == fp and c.get("rows"):
                return c["rows"]        # 热度/知名度已随缓存存下来了
        except Exception:
            pass
    rows = build_corpus(path)
    _annotate(rows)
    if use_cache:
        try:
            os.makedirs(os.path.dirname(CACHE), exist_ok=True)
            tmp = CACHE + ".%d.tmp" % os.getpid()
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump({"ver": TOKVER, "src": fp, "rows": rows}, f, ensure_ascii=False)
            os.replace(tmp, CACHE)
        except Exception:
            pass                                     # 缓存写不了不算错(只读盘也能用)
    return rows


def find(needle, hay, fuzzy=0):
    """在 hay 里找 needle: 返回 (位置, 不同数) 或 None。fuzzy=0 就是子串查找。

    fuzzy>0 时逐窗口比。**边比边数**: 一旦超过 fuzzy 就跳出 —— 老版本每窗口都把整段
    加完再判断, 长查询会慢到不可用。
    """
    if fuzzy <= 0:
        pos = hay.find(needle)
        return (pos, 0) if pos >= 0 else None
    best = None
    n, m = len(hay), len(needle)
    for i in range(n - m + 1):
        diff = 0
        for k in range(m):
            if hay[i + k] != needle[k]:
                diff += 1
                if diff > fuzzy:
                    break
        if diff <= fuzzy and (best is None or diff < best[1]):
            best = (i, diff)
            if diff == 0:
                break
    return best


def split_query(s):
    """查询串 -> 若干段(空格/逗号/分号/竖线/顿号分隔; 每一段只留 1-7)。"""
    segs = [re.sub(r"[^1-7]", "", p) for p in re.split(r"[\s,，;；|、]+", s or "")]
    return [x for x in segs if x]


def search(rows, segs, fuzzy=0, top=20):
    """每一段都必须在同一首里找到(与前端"多段相加"同一个意思: 多给几段更准)。"""
    segs = [s for s in (segs or []) if s]
    if not segs:
        return []
    hits = []
    for r in rows:
        d = r["digits"]
        if any(len(s) > len(d) for s in segs):
            continue
        det, ok = [], True
        for s in segs:
            got = find(s, d, fuzzy)
            if not got:
                ok = False
                break
            det.append(got)
        if not ok:
            continue
        worst = max(x[1] for x in det)
        hits.append(dict(r, pos=det[0][0], diff=worst, positions=[x[0] for x in det]))
    # 越像越靠前, 与网页前端同序: 不同数少 -> 热度(同曲名组份数) -> **知名度**(歌手/标签在语料里的谱数)
    # -> 谱短 -> 曲名。热点说明: `66561232123` 精确命中《最炫民族风》(凤凰传奇, 库里 68 首) 与
    # 《时光》(无歌手信息, 0 首) —— 用户判定正确答案是前者, 而"名短优先/八度记号少优先"都判给了后者。
    hits.sort(key=lambda x: (x["diff"], -x.get("pop", 0), -x.get("hot", 0), x["n_notes"], x["title"]))
    return hits[:top] if top else hits


def fmt_hit(i, h):
    bits = [h["title"] or "(无题)"]
    if h["artist"]:
        bits.append("歌手 " + "、".join(h["artist"][:2]))
    bits.append("%d 音" % h["n_notes"])
    if h["status"]:
        bits.append(h["status"])
    if h["file"]:
        bits.append(h["file"])
    line = "%2d. %s" % (i, " ｜ ".join(bits))
    if h["diff"]:
        line += "  （差 %d 处）" % h["diff"]
    return line


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("query", nargs="?", help="要查的数字串(可多段: 空格/逗号/竖线分隔)")
    ap.add_argument("--fuzzy", type=int, default=0, help="允许几处不同(默认 0, 严格)")
    ap.add_argument("--top", type=int, default=20)
    ap.add_argument("--json", action="store_true", help="机器可读输出(机器人插件用这个)")
    ap.add_argument("--data", default=DATA, help="data.jsonl 路径(默认 jianpu-db/data.jsonl)")
    ap.add_argument("--no-cache", action="store_true", help="不用数字索引缓存(每次都重建)")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    if not a.query:
        print(__doc__)
        return 0

    segs = split_query(a.query)
    q = " ".join(segs)
    if not segs:
        print("没认出任何音高数字（只认 1-7）。", file=sys.stderr)
        return 2
    if not os.path.isfile(a.data):
        print("找不到语料: %s（用 --data 或 JIANPU_DB 指定）" % a.data, file=sys.stderr)
        return 2

    rows = load_corpus(a.data, use_cache=not a.no_cache)
    hits = search(rows, segs, a.fuzzy, a.top)
    if a.json:
        print(json.dumps({"query": q, "segments": segs, "n": sum(len(x) for x in segs),
                          "fuzzy": a.fuzzy, "corpus": a.data, "total": len(rows),
                          "count": len(hits), "hits": hits}, ensure_ascii=False))
        return 0
    print("查询 %s（%d 个音%s）· 语料 %d 首"
          % (q, sum(len(x) for x in segs), "，允许 %d 处不同" % a.fuzzy if a.fuzzy else "，精确",
             len(rows)))
    print("命中 %d 首" % len(hits) + ("（只显示前 %d）" % a.top if len(hits) >= a.top else ""))
    for i, h in enumerate(hits, 1):
        print("  " + fmt_hit(i, h))
    if not hits:
        print("   （无 —— 试 --fuzzy 1, 或换一段更完整的旋律）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
