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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--offline", action="store_true", help="不联网, 只用缓存重新出提案")
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--interval", type=float, default=0.25)
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()

    sp = json.load(open(os.path.join(DB, "source_pages.json"), encoding="utf-8"))
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
    io.open(a.out, "w", encoding="utf-8", newline="\n").write(
        "file\tcurrent_title\tproposed_title\taccepted\tsite\tpage_title\n" +
        "\n".join("\t".join(x) for x in rows) + "\n")
    print("提案: %s (%d 条, 其中建议改名 %d 条)"
          % (a.out, len(rows), sum(1 for r in rows if r[3] == "1")))

    if a.apply:
        n = 0
        for fn, cur, new, acc, _s, _pt in rows:
            if acc != "1":
                continue
            p = os.path.join(SCORES, fn)
            if not os.path.isfile(p):
                continue
            raw = open(p, "rb").read()
            nl = b"\r\n" if b"\r\n" in raw else b"\n"
            text = raw.decode("utf-8")
            new = clean_title(new.replace("\\", ""))      # 纵深防御: 落盘前再清一遍
            if not new:
                continue
            text = re.sub(r"(?m)^title=.*$", lambda m: "title=" + new, text, count=1)
            text = re.sub(r"(?m)^todo=refine the filename\s*$", "", text)
            text = re.sub(r"\n{3,}", "\n\n", text)
            # 文件名: 去掉 ASCII 化, 用官方名(仍保证唯一)
            base = re.sub(r'[\\/:*?"<>|]', "_", new).strip() or fn[:-4]
            tgt = base + ".txt"
            i = 2
            while os.path.exists(os.path.join(SCORES, tgt)) and tgt != fn:
                tgt = "%s_%d.txt" % (base, i); i += 1
            open(p, "wb").write(text.encode("utf-8"))
            if tgt != fn:
                os.rename(p, os.path.join(SCORES, tgt))
            n += 1
        print("已按 accepted=1 改名 %d 首。记得跑 parse_scores.py 重建索引。" % n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
