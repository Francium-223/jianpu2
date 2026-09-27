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

from guard import guard_help                    # noqa: E402
guard_help(__doc__)                             # `--help` 守卫: 必须在**任何实际工作之前**

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
sys.path.insert(0, DB)
sys.stdout.reconfigure(encoding="utf-8")
import jptok                                    # noqa: E402
try:
    import linkurl                              # noqa: E402
except Exception:                               # noqa: BLE001
    linkurl = None

UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.I)
# `source` 的形状: `<站点>-<id>`。**id 允许数字 id 也允许拼音 slug**(`qupu123-guanghuisuiyue`) ——
# 权威口径是 `tools/to_jianpu_db.py` 的提取正则 `^(.*?)__([a-z0-9]+)-([0-9a-z_]+)$`, 它本来就收 slug;
# 而 `score.py:make_link()` 只要求 source 是**单个安全 token**(当目录名用), slug 同样安全。
# (2026-09-28: 原来写成 `-\d+$`, 于是新导入的那 6 首 slug 来源被误报成"形状不对"。)
SRC = re.compile(r"^[a-z0-9]+-[0-9a-z_]+$")
# `to_jianpu_db.source_of()` 兜底会认的站点 token(与那边的元组**必须同步**; 见下面 source 那一段)
SITE_TOKENS = {"21qupu", "qpcxw", "qinyipu", "gita"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    a = ap.parse_args()

    rows = [json.loads(l) for l in io.open(a.data, encoding="utf-8") if l.strip()]
    print("检查 %d 首（%s）\n" % (len(rows), a.data))

    bad = collections.Counter()
    ex = collections.defaultdict(list)
    info = collections.Counter()          # 良性、但值得知道数量的东西(不要报警, 报警要留给真问题)

    def note(kind, n=1):
        info[kind] += n

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
            # 少数目录名**没有** `__站点-id`(手工抓的 hot-crawl), 但"不能因此就不写来源" ——
            # `tools/to_jianpu_db.py:source_of()` 有**故意的三级兜底**:
            #   ① 目录里的 `_source.txt` 记的原页 URL -> 用它的 host
            #   ② 在目录名里认已知站点 token(21qupu / qpcxw / qinyipu / gita)-> `source=<token>`
            #   ③ 都没有 -> 老实写 `source=unknown`
            # (那段注释自己写着"之前这样漏出 4 份无 source= 的谱"。)
            # 所以这几个值**是设计**, 不是形状错误 —— 之前这里把它们当红报, 是假警报(2026-09-28)。
            if s == "unknown":
                note("source=unknown(兜底: 出处确实没记)", 1)
            elif s in SITE_TOKENS:
                note("source=<站点 token>(兜底: 只有站名没有页面 id)", 1)
            else:
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
        for t in toks:
            if t in STRUCTURAL or re.match(r"^[cqsdh]+-$", t or ""):
                continue
            if jptok.is_note(t):
                continue
            # 剩下两类**都不是坏东西**, 2026-09-28 定案(以前这里两档都当"可能丢音高"报警, 是假警报):
            #   ① `c~`/`q~`/`s~` = **连音线**。`~` 是 jianpu-ly 的 tie(源码第 137 行 "Ties: 1 ~ 1"),
            #      语法上可以写在短横后面(`1 - - - ~`) —— 转换器就把那个 `~` 连同前一个时值字母
            #      写成了独立的 token。四方印证: ①jianpu-ly 源码 ②manifest 压缩形 `'1q … 1 - - - ~`
            #      ③生成的 .ly 里是 `\note-mod "–" c''4` + Tie ④渲染出的 PNG 上就是一条连音弧。
            #      它**没有音高也不占拍**(recover_bars 走"不是 token"分支 -> 0 拍), 正好是 tie 该有的样子。
            #      实测: 191 个, 全在手工录入/jianpu-ly 转出的 status=ok 谱里, OCR 谱 0 个。
            #   ② `1=C` = **调号**。语料没有"调号"字段, 而前端是逐 token 原样渲染 —— 写在正文里
            #      正好把调号显示出来, 所以这不是漏, 是唯一能放它的地方(`parse_token` 认不出 ->
            #      0 拍 0 音高, 对检索与小节线都无影响)。实测: 1 个(qd1z_anthem.txt 的 intro)。
            if re.match(r"^[cqsdh]*~[cqsdh]*$", t or ""):
                note("连音线 ~ (良性)", 1)
            elif re.match(r"^\d+=[A-Ga-g#b]", t or ""):
                note("正文里的调号 (良性)", 1)
            else:
                unparseable.append(t)
        if unparseable:
            fail("score 里有解析不了的 token", f, str(unparseable[:3]))
        # 12. link 必须过唯一实现的校验
        if linkurl is not None and r.get("link"):
            try:
                linkurl.parse_link(",".join(r["link"]))
            except Exception as e:                          # noqa: BLE001
                fail("link 过不了 linkurl 校验", f, str(e)[:50])

    if info:
        print("良性记号(不报警, 只报数):")
        for k, n in info.most_common():
            print("   %-28s %5d 个" % (k, n))
        print()
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
