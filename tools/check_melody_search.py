# -*- coding: utf-8 -*-
"""melody_search.py 的自检 —— 查歌这条链路(机器人 `<数字>是什么歌` 靠它)不许悄悄坏掉。

为什么值得单列:
  * 2026-09-24 之前的 melody_search.py 搜的是旧流水线的 `batch-out/*.txt`, 里面**没有 th10_06**,
    `33565653253` 这种确定存在的查询返回"命中 0 首" —— 而它不报错, 只是永远查不到。
    换成语料唯一真源 `jianpu-db/data.jsonl` 之后, 这里把"已知答案"钉住。
  * token 口径必须是 `jptok`(唯一实现)。自写窄正则的教训: 静默丢掉 `b7`(降号)与 `6c.`(后缀时值),
    正是 2026-09-23 "索引丢音" 事故同一类坑。这里用一条**交叉验证**把它锁住:
    melody_search 解出的音数必须等于前端索引 `stats.json` 里的 notes(同一套 jptok, 两条独立链路)。

用法: python3 tools/check_melody_search.py
"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
sys.path.insert(0, HERE)
sys.stdout.reconfigure(encoding="utf-8")
import melody_search as ms                                     # noqa: E402

fail = 0


def ok(c, m):
    global fail
    print(("✓ " if c else "✗ ") + m)
    if not c:
        fail += 1


def main():
    if not os.path.isfile(ms.DATA):
        sys.exit("找不到语料 %s（JIANPU_DB 指定一下）" % ms.DATA)

    rows = ms.load_corpus(use_cache=False)                     # 自检不用缓存, 免得缓存掩盖问题
    ok(len(rows) == 7321 or len(rows) > 7000, "语料 %d 首(应为 7321 左右)" % len(rows))
    ok(all(r["digits"] for r in rows), "每首都解出了数字串")
    total = sum(len(r["digits"]) for r in rows)
    print("   解出音符总数: %d" % total)
    stats = os.path.join(WS, "jianpu-web", "data", "stats.json")
    if os.path.isfile(stats):
        want = json.load(io.open(stats, encoding="utf-8")).get("notes")
        ok(total == want, "与前端索引 stats.notes 一致(%s == %s) —— token 口径=jptok" % (total, want))
    else:
        print("   (没有前端 stats.json, 跳过交叉验证)")

    def top(q, fuzzy=0, segs=None):
        hits = ms.search(rows, segs or ms.split_query(q), fuzzy, 3)
        return hits

    h = top("33565653253")
    ok(bool(h) and h[0]["title"] == "神々が恋した幻想郷",
       "33565653253 -> %s（老版本这里永远命中 0 首）" % (h[0]["title"] if h else "无"))
    ok(bool(h) and h[0]["file"] == "th10_06.txt" and h[0]["pos"] == 0, "命中位置 0 / th10_06.txt")

    h = top("63731232")
    ok(len(h) >= 2 and any(x["title"] == "神々が恋した幻想郷" for x in h),
       "63731232 -> %s" % "、".join(x["title"] for x in h))

    h = top("33565653254", fuzzy=1)
    ok(bool(h) and h[0]["diff"] == 1, "末位写错 -> 容错 1 处仍能查到")
    ok(not top("33565653254"), "不容错时同一个错串查不到(说明 diff 是真在比)")

    h = top("63731232 1765")
    ok(len(h) >= 1 and all(len(x["positions"]) == 2 for x in h), "多段查询: 每段都要命中")

    ok(not top("77717771777177") and not top("77717771777177", fuzzy=1), "真没有的片段查不到")

    # 数字提取的几个坑(都是实测踩过的): 降号/后缀时值/休止/调号/八度
    ok(ms.digits_of("b7 7 6c. q3") == "7763", "`b7` 不被丢掉, 后缀时值 `6c.` 也认")
    ok(ms.digits_of("x 0 q0 s0 1 2") == "12", "休止/念白不进数字串")
    ok(ms.digits_of("1=C 1 2 3") == "123", "调号 `1=C` 不进数字串")
    ok(ms.digits_of(",5 5' q,6") == "556", "八度记号不影响音高")
    ok(ms.digits_of("") == "" and ms.split_query("abc") == [], "空/无数字输入不炸")

    print("\n查歌自检 " + ("通过" if not fail else "失败 %d 项" % fail))
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
