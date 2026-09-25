#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""给 `todo=refine the filename` 的曲**提议官方曲名**(从原谱站页面标题里取)。

背景: 语料里有一批曲名是"文件名式"的 ASCII 化写法(如 `Because_of_You`、
`I_will_carry_you钢琴谱当王者荣耀遇到五月天骨灰级玩家`)或干脆是个调号(`1=F4_4_深`),
前端就照这个显示 —— 而原谱站页面上写的是**官方曲名**(`1=F4_4_深` 其实是《牧羊姑娘》)。
这一批在源文件里都带着 `todo=refine the filename` 标记, 共 381 首, 其中 373 首有核对过的原谱页。

抽取规则(都由页面 <title> 而来, 不猜):
  * qupu123 : `<歌名> _<制谱者>园地_中国曲谱网` / `<歌名> _<栏目>曲谱_中国曲谱网` -> 取第一个 `_` 之前
  * jianpujia: `<歌名><调式>_<情绪>简谱_<歌手>演唱_…` -> 取 `1=` / `钢琴简谱` / `简谱` 之前
  * jianpucn : 语料里的曲名本来就是站点曲名, 一般不用改 -> 跳过

⚠ **只出提案, 不自动改名**: 改文件名会改 `data.jsonl`/HF 里的 `file` 标识(下游按它对齐),
属于你的取舍。审完用 `--apply` 一条命令落地(改名同时改 `title=`, 并重新生成索引)。

用法:
  python3 jianpu2/tools/refine_titles_from_pages.py            # 抓页面 + 出提案 TSV
  python3 jianpu2/tools/refine_titles_from_pages.py --apply    # 按 TSV 里 accepted=1 的行改名

另一类曲名病灶(全离线, 与上面的"文件名式曲名"无关):
  python3 tools/refine_titles_from_pages.py --strip-dangling --plan    # 只打印计划
  python3 tools/refine_titles_from_pages.py --strip-dangling --apply   # 去掉尾巴 + 改名
现场: `title=可惜没如果 —` / `title=塞纳河——` 这种**尾部悬挂分隔符**(2026-09-25 清掉 40 首)。
判据不猜: 全库 7,318 首里 `title` 含 " — " 的只有 1 首 —— 本站曲名约定就是"只有曲名",
歌手另有 `artist=` 字段, 所以是把尾巴**去掉**, 不是把歌手补进去。
⚠ 改名会同时改首行 `%<本文件名>`: 漏改的话 score.py 会把这行当**普通注释**收进 comments。
"""
import argparse
import collections
import concurrent.futures as cf
import io
import json
import os
import re
import ssl
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from safeout import default_out    # noqa: E402  隔离跑别写进真工作台
import threading
import time
import urllib.parse
import urllib.request

UA = "Mozilla/5.0 (X11; Linux x86_64) jianpu-corpus-title/1.0"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
SCORES = os.path.join(DB, "scores")
CACHE = os.path.join(ROOT, "train-work", "title_cache")
OUT = default_out(DB, "title_proposal.tsv")
sys.stdout.reconfigure(encoding="utf-8")
_lock = threading.Lock()


def fetch(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "zh-CN"})
    try:
        with urllib.request.urlopen(req, timeout=timeout,
                                    context=ssl.create_default_context()) as r:
            return r.status, r.read(300000)
    except urllib.error.HTTPError as e:
        return e.code, b""
    except Exception as e:
        return 0, str(e).encode()


def decode(raw, site):
    for enc in (("gb18030", "utf-8") if site == "jianpucn" else ("utf-8", "gb18030")):
        try:
            return raw.decode(enc, "ignore")
        except Exception:
            pass
    return raw.decode("utf-8", "ignore")


def official_title(ptitle, site):
    t = re.sub(r"\s+", " ", ptitle or "").strip()
    t = re.sub(r"\s*(歌谱简谱网|简谱之家|中国曲谱网|免费下载).*$", "", t).strip()
    if site == "qupu123":
        return t.split("_")[0].strip()
    if site == "jianpujia":
        for sep in ("1=", "钢琴简谱", "吉他简谱", "萨克斯简谱", "简谱"):
            if sep in t:
                t = t.split(sep)[0]
        return t.strip(" _-")
    return t



def confident(cur, new):
    """只对**高置信度**的改名建议标 accepted=1。页面标题常带噪音(重复、括号不配、网址残留),
    所以这里要求: 名字更干净(更短, 或当前是纯 ASCII 而新名是中文) 且没有明显的页面痕迹。"""
    if not new or len(new) > 40:
        return False
    if re.search(r"[/\\_]", new):
        return False
    for o, c in (("（", "）"), ("(", ")"), ("【", "】")):
        if new.count(o) != new.count(c):
            return False
    for L in (8, 10, 12, 16):                      # 页面标题"重复两遍"的痕迹
        for i in range(0, max(0, len(new) - 2 * L)):
            if new[i:i + L] in new[i + L:]:
                return False
    same = re.sub(r"[\s_\-]+", "", new).lower() == re.sub(r"[\s_\-]+", "", cur).lower()
    if same:
        return False
    cur_ascii = not re.search(r"[\u4e00-\u9fa5]", cur)
    return len(new) <= len(cur) + 2 or (cur_ascii and bool(re.search(r"[\u4e00-\u9fa5]", new)))


def clean_title(t):
    """页面上抓来的标题是**不可信输入**: 去换行/制表/控制字符并合并空白。

    2026-09-24 补: `--apply` 是拿 `re.sub` 直接替换 `title=` 那一行的, 如果 new 里带换行,
    就会往曲谱里**注入额外的元数据行**(与 `linkurl.parse_tag` 那个坑同一类)。
    现有 275 条提案实测干净, 但来源是网页, 必须在这里兜住。
    """
    t = re.sub(r"[\r\n\t\x00-\x1f\x7f]", " ", t or "")
    return re.sub(r"\s{2,}", " ", t).strip()


# ---------------------------------------------------------------------------
# 另一类曲名病灶: 尾部**悬挂分隔符**（2026-09-25 新发现, 与"文件名式曲名"无关）
#
# 现场: `title=可惜没如果 —` / `title=塞纳河——` / `title=托起梦中的太阳·` 共 38 首。
# 来源: 早前某版解析把歌手拼进了曲名(`曲名 — 歌手`), 后来不拼了, 于是只剩个分隔符尾巴。
# 判据(不猜): **全库 7,318 首里 `title` 含 " — " 的只有 1 首** —— 说明本站曲名约定
#   就是"只有曲名", 歌手另有 `artist=` 字段(这 38 首里 13 首有 artist、25 首没有)。
#   所以正确修法是**把尾巴去掉**, 而不是把歌手补进去。
# ---------------------------------------------------------------------------
DANGLING = re.compile(r"^(?P<core>.*?)[\s\u3000]*(?:—+|–|--|-|·|_)[\s\u3000]*$")


def strip_dangling(title):
    """`可惜没如果 —` -> `可惜没如果`; 不是这类就返回 ''(表示不该动它)。"""
    m = DANGLING.match((title or "").strip())
    if not m:
        return ""
    core = m.group("core").strip(" \u3000")
    # 去掉之后必须有东西, 否则会把整条曲名抹掉(如 title='—')
    return core if core else ""


def dangling_rows(sp):
    """扫全部曲谱, 找出 `title` 尾部悬挂分隔符的那些 -> 与主流程同格式的行。"""
    rows = []
    for fn in sorted(os.listdir(SCORES)):
        if not fn.endswith(".txt") or fn.endswith(("_expand.txt", "_buf.txt")):
            continue
        p = os.path.join(SCORES, fn)
        try:
            head = io.open(p, encoding="utf-8", errors="replace").read().split("%--", 1)[0]
        except OSError:
            continue
        m = re.search(r"(?m)^title=(.*)$", head)
        cur = m.group(1).strip() if m else ""
        new = strip_dangling(cur)
        if not new:
            continue
        s = re.search(r"(?m)^source=(\S+)", head)
        src = s.group(1) if s else ""
        site = src.split("-")[0] if src else ""
        pt = ((sp.get(src) or {}).get("t") or "")[:200]
        rows.append((fn, cur, clean_title(new), "1", site, pt))
    return rows


def artist_of(path):
    """取这份曲谱的 `artist=` 第一个值(撞名消歧要用它拼 `曲名（歌手）.txt`)。

    只在**已经撞名**时才需要它; 读不到就返回空串(退回 `_2` 的老办法, 不会因此不改名)。
    """
    try:
        head = io.open(path, encoding="utf-8", errors="replace").read().split("%--", 1)[0]
    except OSError:
        return ""
    m = re.search(r"(?m)^artist=(.*)$", head)
    if not m:
        return ""
    a = m.group(1).split(",")[0].strip()
    return re.sub(r'[\\/:*?"<>|\x00-\x1f]', "_", a).strip()


def pick_target(fn, new_title, taken):
    """新曲名 -> 目标文件名(**保证不与现有文件冲突**)。

    命名约定(用户 2026-09-24 定, 与上一轮 30 个改名一致):
        曲名.txt  ->  撞名则 `曲名（歌手）.txt`  ->  还撞则 `曲名（歌手）_2.txt`/`_3…`
        没有歌手信息 -> `曲名_2.txt`/`_3…`(老办法)
    以前只有最后那档 `_2`, 于是《草原之夜》这种通用曲名会变成没法认的 `草原之夜_2.txt`。
    """
    base = re.sub(r'[\\/:*?"<>|]', "_", new_title).strip() or fn[:-4]

    def free(b):
        t = b + ".txt"
        return t == fn or (t not in taken and not os.path.exists(os.path.join(SCORES, t)))

    if free(base):
        return base + ".txt"
    art = artist_of(os.path.join(SCORES, fn))
    if art:
        b2 = "%s（%s）" % (base, art)
        if free(b2):
            return b2 + ".txt"
        i = 2
        while not free("%s_%d" % (b2, i)):
            i += 1
        return "%s_%d.txt" % (b2, i)
    i = 2
    while not free("%s_%d" % (base, i)):
        i += 1
    return "%s_%d.txt" % (base, i)


def accepted_from_tsv(path):
    """从**已在盘上的提案 TSV** 读 `file -> accepted`。

    为什么: `--apply` 原来直接用刚算出来的 `confident()` 结果, 人改过的 `accepted` 列会被覆盖 ——
    于是"审完把同意的留 1"这句话是假的(改完再跑就没了)。现在以盘上那份为准, 新出现的文件才用新算的。
    """
    out = {}
    if not os.path.isfile(path):
        return out
    for i, ln in enumerate(io.open(path, encoding="utf-8")):
        if i == 0 or not ln.strip():
            continue
        c = ln.rstrip("\n").split("\t")
        if len(c) >= 4:
            out[c[0]] = c[3]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--plan", action="store_true", help="只打印改名计划(旧名 -> 新名 + 新曲名), 不动文件")
    ap.add_argument("--offline", action="store_true", help="不联网, 只用缓存重新出提案")
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--interval", type=float, default=0.25)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--strip-dangling", action="store_true",
                    help="另一类曲名病灶: 尾部悬挂分隔符(`可惜没如果 —`)直接去掉; 全离线")
    a = ap.parse_args()
    if a.strip_dangling and a.out == OUT:
        a.out = default_out(DB, "title_dangling_proposal.tsv")
    reviewed = accepted_from_tsv(a.out) if (a.apply or a.plan) else {}

    sp = json.load(open(os.path.join(DB, "source_pages.json"), encoding="utf-8"))

    if a.strip_dangling:                       # 离线分支: 不需要页面标题, 判据就是曲名本身
        rows = dangling_rows(sp)
        print("尾部悬挂分隔符的曲名: %d 条" % len(rows))
        return emit(a, rows, reviewed)

    os.makedirs(CACHE, exist_ok=True)
    cpath = os.path.join(CACHE, "titles.json")
    cache = json.load(open(cpath, encoding="utf-8")) if os.path.isfile(cpath) else {}

    todo = []
    for fn in sorted(os.listdir(SCORES)):
        if not fn.endswith(".txt") or fn.endswith(("_expand.txt", "_buf.txt")):
            continue
        head = io.open(os.path.join(SCORES, fn), encoding="utf-8", errors="replace").read().split("%--", 1)[0]
        if "refine the filename" not in head:
            continue
        m = re.search(r"(?m)^source=(\S+)", head)
        src = m.group(1) if m else ""
        if not src or src not in sp or src.split("-")[0] == "jianpucn":
            continue
        t = re.search(r"(?m)^title=(.*)$", head)
        todo.append((fn, src, (t.group(1).strip() if t else ""), sp[src]["url"]))
    todo = [] if a.offline else [x for x in todo if x[1] not in cache]
    print("待抓 %d 个页面(已缓存 %d)" % (len(todo), len(cache)), flush=True)

    host_last, host_lock = {}, {}
    def polite(url, interval):
        host = urllib.parse.urlsplit(url).netloc
        with _lock:
            lk = host_lock.setdefault(host, threading.Lock())
        with lk:
            w = interval - (time.time() - host_last.get(host, 0))
            if w > 0:
                time.sleep(w)
            host_last[host] = time.time()

    def work(item):
        fn, src, title, url = item
        site = src.split("-")[0]
        polite(url, a.interval)
        code, raw = fetch(url)
        rec = {"fn": fn, "src": src, "site": site, "cur": title, "page_title": "", "new": ""}
        if code == 200 and raw:
            pt = re.sub(r"\s+", " ", re.search(r"<title[^>]*>(.*?)</title>", decode(raw, site), re.S | re.I).group(1)).strip() \
                if re.search(r"<title[^>]*>(.*?)</title>", decode(raw, site), re.S | re.I) else ""
            rec["page_title"] = clean_title(pt)[:200]
            rec["new"] = clean_title(official_title(pt, site))
        with _lock:
            cache[src] = rec
            if len(cache) % 50 == 0:
                json.dump(cache, open(cpath, "w", encoding="utf-8"), ensure_ascii=False)
        return rec

    with cf.ThreadPoolExecutor(max_workers=a.workers) as ex:
        list(ex.map(work, todo))
    json.dump(cache, open(cpath, "w", encoding="utf-8"), ensure_ascii=False)

    rows = []
    for src, r in sorted(cache.items(), key=lambda x: x[1]["fn"]):
        if not r.get("new"):
            continue
        rows.append((r["fn"], r["cur"], r["new"],
                     "1" if confident(r["cur"], r["new"]) else "0", r["site"], r["page_title"]))
    return emit(a, rows, reviewed)


def emit(a, rows, reviewed):
    """写提案 TSV + 按 `--plan`/`--apply` 落地。两条分支(抓页面 / --strip-dangling)共用。"""
    io.open(a.out, "w", encoding="utf-8", newline="\n").write(
        "file\tcurrent_title\tproposed_title\taccepted\tsite\tpage_title\n" +
        "\n".join("\t".join(x) for x in rows) + "\n")
    print("提案: %s (%d 条, 其中建议改名 %d 条)"
          % (a.out, len(rows), sum(1 for r in rows if r[3] == "1")))

    todo_rows = []
    if a.apply or a.plan:
        for fn, cur, new, acc, _s, _pt in rows:
            acc = reviewed.get(fn, acc)          # 以盘上那份为准(人审过的 accepted 不被覆盖)
            if acc != "1":
                continue
            if not os.path.isfile(os.path.join(SCORES, fn)):
                continue
            new = clean_title(new.replace("\\", ""))      # 纵深防御: 落盘前再清一遍
            if not new:
                continue
            todo_rows.append((fn, cur, new))

    if a.plan:
        print(f"\n改名计划({len(todo_rows)} 首; 只打印, 不动任何文件):")
        taken = set()
        for fn, cur, new in todo_rows:
            # 必须**顺序累积** taken: 两条提案可能撞同一个新名, 打印的计划要与 --apply 的结果一致
            tgt = pick_target(fn, new, taken)
            taken.add(tgt)
            mark = "" if tgt.startswith(new) else "  <- 名字被占"
            print("  %-46s -> %-40s  title=%s%s" % (fn[:46], tgt[:40], new, mark))
        print("\n冲突规则: 曲名.txt -> 曲名（歌手）.txt -> 曲名（歌手）_2.txt -> 曲名_2.txt")

    if a.apply:
        n = 0
        taken = set()
        for fn, cur, new in todo_rows:
            p = os.path.join(SCORES, fn)
            raw = open(p, "rb").read()
            text = raw.decode("utf-8")
            text = re.sub(r"(?m)^title=.*$", lambda m: "title=" + new, text, count=1)
            text = re.sub(r"(?m)^todo=refine the filename\s*$", "", text)
            text = re.sub(r"\n{3,}", "\n\n", text)
            tgt = pick_target(fn, new, taken)
            taken.add(tgt)
            # 首行 `%<本文件名>` 是**自述**, 必须跟着改名一起改。注意它带扩展名
            # (`%可惜没如果_—.txt`) —— score.py 比的就是 `'%' + 完整文件名`。
            # 2026-09-25 实测踩过: 漏改之后 `i != '%' + 文件名` 判为不等 ->
            # 这行被当成**普通注释**收进 comments(40 首凭空多出一条旧文件名注释)。
            if tgt != fn:
                head, newhead = "%" + fn, "%" + tgt
                for nl in ("\r\n", "\n"):
                    if text.startswith(head + nl):
                        text = newhead + text[len(head):]
                        break
            open(p, "wb").write(text.encode("utf-8"))
            if tgt != fn:
                os.rename(p, os.path.join(SCORES, tgt))
            n += 1
        print("已按 accepted=1 改名 %d 首。记得跑 parse_scores.py 重建索引。" % n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
