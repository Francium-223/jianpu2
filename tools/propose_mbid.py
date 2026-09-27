# -*- coding: utf-8 -*-
"""给没有 MBID 的曲**提议** MusicBrainz 标识符（只出 TSV, 绝不写语料）。

背景: 语料 7,318 首里只有 **36 首**有 MBID, 而且全是 `status=ok`、手工转写的东方谱;
OCR 来的 7,281 首**一个都没有**。MBID 是这套语料的主键与外链锚点(README 口径),
所以这是个明显的大口子。

为什么**不自己写匹配**: `convert.py` 里那套 `musicbrainz_lookup()` 早就把口径定死了 ——
  high   标题精确 + 歌手匹配 + score>=90     -> 直接填
  medium 标题精确但无歌手佐证/歌手对不上, 或近似标题(繁简) -> 填但标复核
  low    标题只是近似                        -> 不填
原则「错配比没有更糟」。本脚本**只调用它**, 不复制逻辑(口径只能有一份)。

用法:
    py -3.13 tools/propose_mbid.py --limit 60          # 先小样看分布
    py -3.13 tools/propose_mbid.py --with-artist       # 全量跑"有歌手"的那批(可佐证, 能到 high)
    py -3.13 tools/propose_mbid.py --all               # 全量(7,281 首, 会很慢)
输出: _analysis/mbid_proposal.tsv + 可断点续跑的缓存 train-work/mbid_cache.json
"""
import argparse
import io
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
OUT_DIR = os.path.join(WS, "_analysis")
CACHE = os.path.join(ROOT, "train-work", "mbid_cache.json")
sys.path.insert(0, HERE)
sys.path.insert(0, ROOT)          # convert.py 在仓库根, 不在 tools/ —— 只加 HERE 会 ModuleNotFoundError
os.chdir(ROOT)
import convert                                              # noqa: E402  唯一口径在这里


def load_rows():
    return [json.loads(l) for l in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8")
            if l.strip()]


def _matched_bits(m):
    """`musicbrainz_lookup` 的第四个返回值**有两种形状**, 别只按一种解:
       * 命中 -> {'title':…, 'artists':[…]}          (dict)
       * 未命中 -> candidates[:3] = [(kind, cand), …] (list of tuple)
    一开始我只写了 list 分支, 命中时 `(m or [{}])[0]` 就 KeyError: 0。
    """
    if isinstance(m, dict):
        return (m.get("title", ""), " / ".join(m.get("artists") or []), "")
    if isinstance(m, (list, tuple)) and m:
        first = m[0]
        c = None
        if isinstance(first, (list, tuple)) and len(first) >= 2 and isinstance(first[1], dict):
            c = first[1]
        elif isinstance(first, dict):
            c = first
        if c:
            return (c.get("title", ""), " / ".join(c.get("artists") or []), str(c.get("score", "")))
    return ("", "", "")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--with-artist", action="store_true", help="只跑有 artist= 的(能靠歌手佐证)")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--interval", type=float, default=1.2, help="每次查询之间的间隔秒(礼貌)")
    ap.add_argument("--out", default=os.path.join(OUT_DIR, "mbid_proposal.tsv"))
    a = ap.parse_args()

    rows = [r for r in load_rows() if not (r.get("MBID") or "").strip()]
    if a.with_artist:
        rows = [r for r in rows if (r.get("artist") or [])]
    if a.limit:
        rows = rows[:a.limit]
    print("待查 %d 首(没 MBID 的总数按筛选条件)" % len(rows), flush=True)

    cache = {}
    if os.path.isfile(CACHE):
        try:
            cache = json.load(io.open(CACHE, encoding="utf-8"))
        except Exception:
            cache = {}
    print("缓存里已有 %d 条" % len(cache), flush=True)

    out = []
    t0 = time.time()
    for i, r in enumerate(rows):
        f = r["file"][0]
        title = (r.get("title") or "").strip()
        artist = ((r.get("artist") or [""])[0] or "").strip()
        key = f
        if key not in cache:
            try:
                mbid, kind, conf, matched = convert.musicbrainz_lookup(title, artist)
            except Exception as e:                          # noqa: BLE001
                mbid, kind, conf, matched = None, None, "error:" + type(e).__name__, []
            cache[key] = {"title": title, "artist": artist, "mbid": mbid or "",
                          "kind": kind or "", "conf": conf or "", "matched": matched or []}
            if len(cache) % 25 == 0:
                json.dump(cache, io.open(CACHE, "w", encoding="utf-8"), ensure_ascii=False)
            time.sleep(a.interval)
        c = cache[key]
        mt, ma, sc = _matched_bits(c["matched"])
        out.append((f, c["title"], c["artist"], c["mbid"], c["kind"], c["conf"], mt, ma, sc))
        if (i + 1) % 50 == 0:
            print("  ...%d/%d (%.1f 分钟)" % (i + 1, len(rows), (time.time() - t0) / 60), flush=True)
    json.dump(cache, io.open(CACHE, "w", encoding="utf-8"), ensure_ascii=False)

    os.makedirs(OUT_DIR, exist_ok=True)
    with io.open(a.out, "w", encoding="utf-8", newline="\n") as g:
        g.write("file\ttitle\tartist\tmbid\tkind\tconfidence\tmatched_title\tmatched_artists\tscore\n")
        for x in out:
            g.write("\t".join(x) + "\n")

    from collections import Counter
    c = Counter(x[5] for x in out)
    print("\n提案: %s (%d 条, 用时 %.1f 分钟)" % (a.out, len(out), (time.time() - t0) / 60))
    for k, v in c.most_common():
        print("   %-10s %d" % (k, v))
    hi = [x for x in out if x[5] == "high"]
    print("   high 里前 5 例:")
    for x in hi[:5]:
        print("      %-28s -> %s  (%s / %s, score %s)" % (x[1][:28], x[3][:36], x[6][:20], x[7][:18], x[8]))
    print("   (只出提案, 没写任何语料; 要落地得先人工看 high 的准确率)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
