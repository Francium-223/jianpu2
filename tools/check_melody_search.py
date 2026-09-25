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
    # 2026-09-25 起这一条改成"落在副歌": 同一个片段前奏里也有(下标 0), 但按用户的段落权重规格
    # 要选副歌那一处(下标 141)。老断言写死 pos==0, 正好说明"加权没落地时取的是第一处"。
    ok(bool(h) and h[0]["file"] == "th10_06.txt" and h[0]["pos"] == 141,
       "命中位置取副歌(下标 141), 而不是前奏的第一处(下标 0)")

    # 并列排序(用户实测): `66561232123` 精确命中《最炫民族风》与《时光》, 正确答案是前者
    # —— 靠"知名度代理 hot"(凤凰传奇在库 68 首 vs 时光无歌手信息 0 首)把顺序掰对。
    h = ms.search(rows, ["66561232123"], 0, 5)
    ok(len(h) == 2 and h[0]["title"] == "最炫民族风" and h[1]["title"] == "时光",
       "66561232123 -> %s（并列时 hot 大的先: 68 vs 0）" % "、".join(x["title"] for x in h))
    ok(all(x["diff"] == 0 for x in h), "两首都是 0 错音(纯数字串确实一样, 只能靠并列规则分)")
    ok(h[0]["hot"] > h[1]["hot"], "第一位那首的 hot 更高(知名度代理生效)")
    ok(h[0]["pop"] == h[1]["pop"], "两首的曲名组份数相同(pop 分不开, 必须靠 hot)")

    # 命中片段: 必须给"命中的音 + 包含它的**完整小节**", 而不是只给一个序号(用户口径 2026-09-24)
    h1 = top("33565653253")[0]
    seg = h1.get("seg") or ""
    print("   片段: 第 %s–%s 小节: %s" % (h1.get("bar_from"), h1.get("bar_to"), seg))
    ok(bool(seg), "命中里带了原文片段")
    ok(seg.count("【") == 1 and seg.count("】") == 1, "命中段用【】圈出来")
    inner = seg.split("【")[1].split("】")[0] if "【" in seg else ""
    ok("".join(c for c in inner if c.isdigit()) == "33565653253",
       "【】里的音正好是查询的 11 个音(含时值/八度记号原样)")
    ok("|" in seg, "片段里有小节线(不是一长串音)")
    b0, b1, nb0, nb1 = ms.bar_span(h1["bars"], h1["pos"], 11)
    ok((b0 in set(h1["bars"])) or b0 == 0, "片段从小节线开始(或全曲开头)")
    ok((b1 in set(h1["bars"])) or b1 >= len(h1["digits"]), "片段在小节线结束(或全曲结尾)")
    ok(nb0 >= 1 and nb1 >= nb0, "给了小节号: 第 %d–%d 小节" % (nb0, nb1))
    # 第二首也应有片段(全部命中都要有, 不是只给第一条)
    for x in top("1234567"):
        if not x.get("seg"):
            ok(False, "命中 %s 没有片段" % x["title"])
            break
    else:
        ok(True, "多命中时每一条都带片段")

    # 多段查询(用户实测两次): `316 316 31656564` —— 空格是"这儿我记不清", 不是"两首不同的歌"。
    # 第一次只要求"每段都要在同一首里"; 用户随后纠正: 老版本把 `316 316` 对齐到**引子**(第 2 小节)、
    # `31656564` 对齐到**副歌**(第 30 小节), 两处凑一起给人看 —— 而整句其实连着在副歌:
    # `3 1 6 | 3 1 6 | 3 1 6 5 6 5 | 6 4`(=《路灯下的小姑娘》"亲爱的 小妹妹 请你不要不要哭泣",
    # 已对原始谱图核过: `0 3 i | 6 3 i | 6 3 i | 6 5 6 5 6 4`)。现在必须按**整句**报一条。
    h3 = ms.search(rows, ms.split_query("316 316 31656564"), 0, 3)
    print("   多段: %s" % "、".join("%s(%d 段)" % (x["title"], len(x.get("segs_detail") or [])) for x in h3))
    ok(len(h3) == 1 and h3[0]["title"] == "路灯下的小姑娘",
       "316 316 31656564 -> %s" % (h3[0]["title"] if h3 else "无"))
    det = h3[0].get("segs_detail") or []
    # 2026-09-25 口径统一: 空格**不再分段**(与网页 parseQuery 一致) —— 整串就是一个连续乐句,
    # 所以只有一个片段、一个【】, 也不再逐段记 marks。原来那句"三段各圈一个【】"是旧行为。
    ok(len(det) == 1, "整串当成一整句(只回一条)")
    ok(det and det[0].get("pos") == h3[0]["positions"][0], "整句片段位置与命中位置一致")
    span = "".join(c for c in det[0]["seg"] if c.isdigit())
    ok(span == "31631631656564",
       "整句片段正好是查询的 14 个音、连着出现(不是引子+副歌两处拼的): %s" % span)
    ok(det[0]["seg"].count("【") == 1 and det[0]["seg"].count("】") == 1, "整句一个【】(连续乐句)")
    ok(det[0]["bar_from"] <= ms.bar_span(h3[0]["bars"], h3[0]["positions"][0], 14)[2] <= det[0]["bar_to"],
       "整句的小节号覆盖这 14 个音(第 %d–%d 小节)" % (det[0]["bar_from"], det[0]["bar_to"]))
    # 口径统一后"空格只是给人看的": 整串当一个连续乐句, 没有"分段"这回事了。
    ok(ms.split_query("63731232 1765") == ["637312321765"],
       "空格/逗号不分段(与网页 parseQuery 一致)")
    h4 = ms.search(rows, ms.split_query("63731232 1765"), 0, 5)
    ok(all(len(x.get("segs_detail") or []) == 1 for x in h4),
       "不连续的串不再硬凑成一句(%d 条命中, 都是单个连续片段)" % len(h4))
    # align_phrase 单测: 顺序/间隔/最小跨度/不同数优先
    ok(ms.align_phrase(["12", "34"], [[(0, 0)], [(100, 0)]]) is None, "离太远 -> 拼不成一句")
    ok(ms.align_phrase(["12", "34"], [[(0, 0)], [(3, 0)]]) == [(0, 2), (3, 2)], "挨着 -> 顺序拼上")
    ok(ms.align_phrase(["12", "34"], [[(0, 0), (50, 0)], [(3, 0), (53, 0)]]) == [(0, 2), (3, 2)],
       "几处都能拼时取**跨度最小**的")
    ok(ms.align_phrase(["12", "34"], [[(0, 0)], [(3, 1), (5, 0)]]) == [(0, 2), (5, 2)],
       "差音少的拼法优先于跨度小的")
    ok(ms.align_phrase(["12"], [[(9, 0)]]) == [(9, 2)], "单段不动用对齐(直接给这一处)")

    # 老口径的每段细节仍在(单段/退路都要能用): 一段圈一个【】, 片段从/到小节线
    h1 = top("33565653253")[0]
    ok(len(h1.get("segs_detail") or []) == 1 and not h1["segs_detail"][0].get("aligned"),
       "单段查询不算'整句对齐'(aligned=False)")


    # 段落权重(用户 2026-09 定的规格, 见 README_PIPELINE.md §六): 副歌/主歌 > 间奏 > 整曲 > 前奏/尾奏/发狂钢琴。
    # 用户当时的实测例子必须成立: 《神々が恋した幻想郷》的 `33565653253` 同时出现在**前奏(0)**与
    # **副歌(141)**, 加权后要取副歌 —— 老代码取第一处(=前奏), 就是这条把它钉住。
    ok(ms.sec_weight("chorus") == 1.6 and ms.sec_weight("verse") == 1.25
       and ms.sec_weight("interlude") == 1.10 and ms.sec_weight("score") == 1.0
       and ms.sec_weight("intro") == ms.sec_weight("crazy-piano") == 0.8,
       "权重表与规格一致(副歌1.6/主歌1.25/间奏1.10/整曲1.0/前奏=发狂钢琴0.8)")
    ok(ms.sec_weight("intro,chorus") == 1.6 and ms.sec_weight("忘了这个段") == 1.0,
       "组合标签取最大; 不认识的段落当整曲(1.0), 不乱猜")
    ok(ms.sec_label("chorus") == "副歌" and ms.sec_label("crazy-piano") == "发狂钢琴",
       "回话用中文段落名(副歌/发狂钢琴)")
    h7 = ms.search(rows, ["33565653253"], 0, 3)
    ok(bool(h7) and h7[0]["title"] == "神々が恋した幻想郷", "33565653253 -> 神々が恋した幻想郷")
    ok(h7[0]["sec"] == "chorus" and h7[0]["sec_w"] == 1.6 and h7[0]["sec_cn"] == "副歌",
       "命中取的是**副歌**那一处(而不是第一处前奏): pos=%s sec=%s" % (h7[0]["positions"], h7[0]["sec"]))
    ok(0 not in h7[0]["positions"], "前奏里那次出现没有被选中(加权生效)")
    row_th10 = next(r for r in rows if r["file"] == "th10_06.txt")
    ok(ms.sec_at(row_th10["sec"], 300, 5) == "crazy-piano",
       "发狂钢琴那一段能正确定位(下标 300 落在 crazy-piano)")
    no_sec = [x for x in ms.search(rows, ["66561232123"], 0, 2)]
    ok(all(x["sec_w"] == 1.0 and not x["sec"] for x in no_sec),
       "没分段的歌(绝大多数)不受影响: 权重 1.0、无段落名")

    h = top("63731232")
    ok(len(h) >= 2 and any(x["title"] == "神々が恋した幻想郷" for x in h),
       "63731232 -> %s" % "、".join(x["title"] for x in h))

    h = top("33565653254", fuzzy=1)
    ok(bool(h) and h[0]["diff"] == 1, "末位写错 -> 容错 1 处仍能查到")
    ok(not top("33565653254"), "不容错时同一个错串查不到(说明 diff 是真在比)")

    # 2026-09-25 口径统一: 空格不分段 -> 上面这句旧断言("每段都要命中")不再成立,
    # 整串 `637312321765` 只在**真连着**的谱里命中。
    h = top("63731232 1765")
    ok(all(len(x["positions"]) == 1 for x in h),
       "空格不分段: 整串当一个连续乐句(%d 条命中)" % len(h))

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
