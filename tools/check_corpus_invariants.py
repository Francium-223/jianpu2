# -*- coding: utf-8 -*-
"""语料结构**不变量**检查（只读）—— 用来抓"静默损坏"，不是抓内容对不对。

为什么值得单独写一份: 今晚抓到的几个真问题都是**结构**问题, 而不是"某首歌错了":
  * `score.py` 的 Windows 反斜杠让首行被写成 `%scores\\x.txt`(非幂等, 反复改脏);
  * `by_*` 里长出一层叫 `scores` 的垃圾目录;
  * 某个白名单漏字段导致整段音符消失。
这些用"抽查几首歌"是看不出来的, 用"每首都得满足的等式"一眼就能看出来。

检查项(都与 field 的真实语义对齐, 见 jianpu-db/score.py):
  1. `file` 唯一 + 在 `scores/` 里存在
  2. `title` 非空
  3. `status` 在发布白名单 `{ok, ocr}` 里
  4. `source` 形如 `<站点>-<数字>` 或空
  5. `MBID` 空或 UUID 形
  6. `tag` ⊇ `usertag`(蕴涵标签只能多不能少)
  7. `n_notes` == `score` 里 `jptok.is_note()` 为真的 token 数(**含休止/念白**, 与 score.py 一致)
  8. `bars`: 严格递增、每条都在 `1..有音高的音符数` 之间
  9. `beats_per_bar` > 0 且 <= 16
  10. `sections` 非空, 每个有 `score` 键, 且用 `" | "` 拼起来 == 本行 `score`
  11. `score` 里除 `|` 外没有 jptok 解析不了的 token(就是"静默丢音"那道闸的独立复核)
  12. `link` 每条都能过 `linkurl.parse_link`(拒收搜索页)

用法: py -3.13 tools/check_corpus_invariants.py [--data ...]
"""
import argparse
import collections
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
sys.path.insert(0, DB)
sys.stdout.reconfigure(encoding="utf-8")
import jptok                                    # noqa: E402
from guard import guard_help                    # noqa: E402
guard_help(__doc__)
try:
    import linkurl                              # noqa: E402
except Exception:                               # noqa: BLE001
    linkurl = None

UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.I)
SRC = re.compile(r"^[a-z0-9]+-\d+$")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    a = ap.parse_args()

    rows = [json.loads(l) for l in io.open(a.data, encoding="utf-8") if l.strip()]
    print("检查 %d 首（%s）\n" % (len(rows), a.data))

    bad = collections.Counter()
    ex = collections.defaultdict(list)

    def fail(kind, fn, detail=""):
        bad[kind] += 1
        if len(ex[kind]) < 4:
            ex[kind].append("%s %s" % (fn, detail))

    seen = set()
    scores_dir = os.path.join(DB, "scores")
    for r in rows:
        f = (r.get("file") or [""])[0]
        if not f:
            fail("file 为空", "(无)")
            continue
        if f in seen:
            fail("file 重复", f)
        seen.add(f)
        if not os.path.isfile(os.path.join(scores_dir, f)):
            fail("file 在 scores/ 里不存在", f)
        if not (r.get("title") or "").strip():
            fail("title 空", f)
        if r.get("status") not in ("ok", "ocr"):
            fail("status 不在白名单", f, str(r.get("status")))
        s = ((r.get("source") or [""]) or [""])[0]
        if s and not SRC.match(s):
            fail("source 形状不对", f, s)
        mb = (r.get("MBID") or "").strip()
        if mb and not UUID.match(mb):
            fail("MBID 不是 UUID", f, mb)
        ut = set(r.get("usertag") or [])
        tg = set(r.get("tag") or [])
        if ut and not ut <= tg:
            fail("tag 少了 usertag 的项", f, str(sorted(ut - tg))[:60])

        score = r.get("score") or ""
        toks = [t for t in score.split() if t != "|"]
        notes = [t for t in toks if jptok.is_note(t)]
        if r.get("n_notes") != len(notes):
            fail("n_notes 与 score 不符", f, "%s vs %s" % (r.get("n_notes"), len(notes)))
        pitch = sum(1 for d, _a, _o in jptok.seq(score) if d is not None)
        bars = r.get("bars") or []
        if any(b != b for b in bars) or list(bars) != sorted(set(bars)):
            fail("bars 不是严格递增", f, str(bars[:6]))
        if bars and (min(bars) < 0 or max(bars) > pitch):
            fail("bars 越界", f, "min=%s max=%s pitch=%s" % (min(bars), max(bars), pitch))
        bpb = r.get("beats_per_bar") or 0
        if not (0 < bpb <= 16):
            fail("beats_per_bar 离谱", f, str(bpb))
        secs = r.get("sections") or []
        if not secs:
            fail("sections 空", f)
        else:
            if any("score" not in x for x in secs):
                fail("sections 里有缺 score 的段", f)
            joined = " | ".join(x.get("score") or "" for x in secs if x.get("score"))
            if joined != score:
                fail("sections 拼起来 != score", f, "%d vs %d 字节" % (len(joined), len(score)))
        # 11. 除 `|` 与结构记号外没有解析不了的 token
        #     (`-` 延长、`~` 连音线、`[`/`]`/`{`/`}` 是结构件, **本来就不是音符** ——
        #      第一版把 `-`/`~` 当"解析不了", 于是 6850 首被误报。)
        STRUCTURAL = {"-", "~", "[", "]", "{", "}", "|"}
        unparseable = []
        fragments = []
        for t in toks:
            if t in STRUCTURAL or re.match(r"^[cqsdh]+-$", t or ""):
                continue
            if jptok.is_note(t):
                continue
            # 单独一档: **时值+连音线但没有音高**(`c~`/`q~`/`s~`)或**调号行漏进正文**(`1=C`)。
            # 它们不是"垃圾 token", 而是**很可能这里丢了一个音高** —— 自检门那条
            # "数字数==旋律数"看不见它(碎片里没有数字)。
            if re.match(r"^[cqsdh]+[~\[\]]*$", t or "") or re.match(r"^\d+=[A-Ga-g#b]", t or ""):
                fragments.append(t)
            else:
                unparseable.append(t)
        if unparseable:
            fail("score 里有解析不了的 token", f, str(unparseable[:3]))
        if fragments:
            fail("score 里有音符碎片(可能丢音高)", f, str(fragments[:3]))
        # 12. link 必须过唯一实现的校验
        if linkurl is not None and r.get("link"):
            try:
                linkurl.parse_link(",".join(r["link"]))
            except Exception as e:                          # noqa: BLE001
                fail("link 过不了 linkurl 校验", f, str(e)[:50])

    if not bad:
        print("结构不变量全部通过（%d 首）" % len(rows))
        return 0
    print("发现 %d 类问题：" % len(bad))
    for k, n in bad.most_common():
        print("   %-28s %5d 首" % (k, n))
        for x in ex[k]:
            print("        %s" % x)
    return 1


if __name__ == "__main__":
    sys.exit(main())
