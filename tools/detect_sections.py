#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""用"重复结构"给没有人工分段的曲子估一个段落权重 —— 让 option B(副歌加权)不再只覆盖 37 首。

背景
----
`data.jsonl` 里只有 **37 首**带人工 `sections`(源文件里手写 `subtitle=` + `NextScore`),
其余 7,281 首整首都是 `score`(权重 1.0)。所以"副歌权重更高、发狂钢琴更低"这条排序规则
目前只对 37 首生效 —— 这是 option B 最大的空洞。

思路(不猜段落名, 只算"这一段重复了几次")
----------------------------------------
副歌之所以是副歌, 最硬的客观特征是**它在整首里反复出现**; 前奏/间奏/发狂钢琴通常只出现一次。
所以不必给段落起名字, 只要给**每个音**算一个"它所在的一小段在别处还出现过几次"的分数,
把它当成段落权重即可 —— 位置局部、无需切分、对没分段的曲子也能算。

算法
----
窗 W(默认 16 个音高音)按 stride(默认 4)滑动, 把窗内的 (音高, 八度) 串成 key:
  * 同一个 key 出现 m>=2 次 -> 每次出现给覆盖到的每个位置 +（m-1) 分;
  * 每个位置最终得分为覆盖它的所有"重复窗"里的最大值。
分数越高 = 该处越像副歌。最后归一化到 1.0 基准, 得到 `rep_w`(≈ 段落权重)。

验证(这是本工具存在的理由)
--------------------------
拿 37 首人工分段的曲子当标准答案, 看 `rep_w` 能不能把 `chorus` 和
`verse/intro/outro/crazy-piano` 分开。跑 `check` 子命令, 输出:
  * chorus 段平均重复度 vs 其他段平均重复度(逐段对比 + 逐首对比);
  * chorus 是不是全曲重复度最高的段(命中率);
  * 如果分不开, 就**明确报告分不开** —— 不拿它去改排序。

结论: 分不开, 不要拿它改排序(2026-09-26 实测, 全部参数都试过)
------------------------------------------------------------
| 窗/步长   | 有重复的曲 | chorus 均 | intro 均 | 逐首 chorus>其他 |
|-----------|-----------|-----------|----------|------------------|
| 8 / 2     | 35/37     | 0.45      | **1.55** | 7 胜 / 19 负     |
| 8 / 4     | 26/37     | 0.29      | **1.06** | 4 胜 / 22 负     |
| 12 / 3    | 30/37     | 0.14      | **0.70** | 4 胜 / 22 负     |
| 16 / 4    | 23/37     | 0.17      | **0.88** | 4 胜 / 22 负     |
| 24 / 6    | 14/37     | 0.07      | **0.42** | 2 胜 / 24 负     |
| 32 / 8    | 8/37      | 0.00      | 0.24     | 0 胜 / 26 负     |

**每一个参数下 intro 的重复度都高于 chorus**, 也就是重复度不但挑不出副歌, 方向还是反的。
原因: 这批标注曲(ZUN 的东方原曲)的前奏大量使用**短小动机的原地反复**(如 `,6 3 2 1 ,7`
来回), 而副歌是通谱写下去的、逐音不重复 —— 于是"重复"在这份语料里标记的是"伴奏型前奏",
不是"副歌"。而且 37 首里有 0 首存在"两段内容逐字相同"的情形, 说明重复全部发生在段落**内部**。

反例也不是全无: 逐首看有些曲子确实对(如 `th01_01.txt` 的 chorus 重复分 1.00、intro 0.00),
但整体命中率太低(最好 7/26), 不能当兜底权重用。

顺带测的"位置先验"(同样只在这 37 首上成立, 样本有偏 —— 全是东方原曲、全是流行曲式):
intro 起点中位 0.00(37/37 首都是 intro 开头)、chorus 起点中位 0.56 且相对位置中位 1.00,
即副歌基本在**最后一段**。这看着比重复度好用, 但"37 首全是同一作者、同一曲式"撑不起
7,281 首的泛化, 所以**没有**拿它改排序。真要让段落权重覆盖更多曲子, 可靠的路子还是人工在
源文件里写 `subtitle=`。

用法
----
    python3 tools/detect_sections.py check                 # 37 首验证 + 汇总
    python3 tools/detect_sections.py check --verbose       # 逐首逐段明细
    python3 tools/detect_sections.py profile th01_01.txt   # 看一首的重复度曲线
"""
import argparse
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                       # jianpu2/
WS = os.path.dirname(ROOT)                         # 工作区
DATA = os.path.join(WS, "jianpu-db", "data.jsonl")

sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
import melody_search as M                          # noqa: E402  唯一口径: token/分段/权重都从它来

W = 16            # 窗长(音高音数)
STRIDE = 4        # 滑窗步长
HIGH = {"chorus"}                                  # "应该高"的段
LOW = {"intro", "outro", "crazy-piano", "crazy piano", "layer", "interlude"}


def seq_of(r):
    """(音高, 八度) 序列 —— 与检索口径一致(休止/念白不算)。"""
    return M._tokens(r.get("score") or "")


def repeat_profile(seq, w=W, stride=STRIDE):
    """每个位置的"重复分": 覆盖它的重复窗里最大的 (出现次数-1)。"""
    n = len(seq)
    prof = [0] * n
    if n < w * 2:
        return prof
    pos = {}
    starts = list(range(0, n - w + 1, stride))
    for i in starts:
        key = seq[i:i + w]                            # [(digit, oct), …] 可哈希
        pos.setdefault(tuple(key), []).append(i)
    for _key, ps in pos.items():
        m = len(ps)
        if m < 2:
            continue
        gain = m - 1
        for p in ps:
            for j in range(p, min(p + w, n)):
                if gain > prof[j]:
                    prof[j] = gain
    return prof


def sec_at(prof, sec, i0, n):
    """命中区间 [i0, i0+n) 的重复分(取该区间内位置的中位数, 抗边缘噪声)。"""
    vals = sorted(prof[i] for i in range(i0, min(i0 + n, len(prof))))
    if not vals:
        return 0.0
    mid = len(vals) // 2
    return float(vals[mid]) if len(vals) % 2 else (vals[mid - 1] + vals[mid]) / 2.0


def load_data():
    rows = []
    with io.open(DATA, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def sec_ranges(r, n_digits):
    """段名 -> 该段在 digits 里的 [起, 止); 对不上就是空。"""
    sm = M.section_map(r, n_digits)
    out = []
    for k, (start, nm) in enumerate(sm):
        end = sm[k + 1][0] if k + 1 < len(sm) else 10 ** 9
        out.append((nm, start, min(end, n_digits)))
    return out


def cmd_check(args):
    rows = load_data()
    labeled = []
    for r in rows:
        if len(r.get("sections") or []) < 2:
            continue
        n = len(M.digits_of(r.get("score") or ""))
        rr = sec_ranges(r, n)
        if len(rr) >= 2:
            labeled.append((r, n, rr))
    print("人工分段的曲子: %d 首(能从 section_map 还原出边界的 %d 首)"
          % (sum(1 for r in rows if len(r.get("sections") or []) >= 2), len(labeled)))
    print("窗长 %d 音, 步长 %d\n" % (W, STRIDE))

    hi_all, lo_all = [], []
    hit_top = 0
    per_song = []
    for r, n, rr in labeled:
        prof = repeat_profile(seq_of(r))
        if not any(prof):
            per_song.append((r, n, rr, None))
            continue
        per = [(nm, sec_at(prof, None, a, b - a), b - a) for nm, a, b in rr]
        hi = [s for nm, s, _l in per if nm in HIGH]
        lo = [s for nm, s, _l in per if nm in LOW]
        hi_all += hi
        lo_all += lo
        top_nm = max(per, key=lambda x: x[1])[0]
        if top_nm in HIGH:
            hit_top += 1
        per_song.append((r, n, per, top_nm))
        if args.verbose:
            print("%-24s" % r["file"][0])
            for nm, s, l in per:
                tag = "  <= chorus" if nm in HIGH else ("  (低)" if nm in LOW else "")
                print("    %-16s 长%4d  重复分 %6.2f%s" % (nm, l, s, tag))
            print("    最高的是: %s" % top_nm)

    scored = [p for p in per_song if p[3] is not None]
    print("=" * 68)
    print("能算出重复度的: %d / %d 首" % (len(scored), len(labeled)))
    if hi_all and lo_all:
        mh = sum(hi_all) / len(hi_all)
        ml = sum(lo_all) / len(lo_all)
        print("chorus        段平均重复分: %6.2f  (n=%d)" % (mh, len(hi_all)))
        print("前奏/尾奏/发狂钢琴 段平均: %6.2f  (n=%d)" % (ml, len(lo_all)))
        print("比值: %.2fx" % (mh / ml if ml else float("inf")))
    print("chorus 就是全曲重复分最高段的: %d / %d 首 (%.0f%%)"
          % (hit_top, len(scored), 100.0 * hit_top / len(scored) if scored else 0))
    # 逐首: chorus 是否高于该曲其他段的平均值
    win = lose = 0
    for r, n, per, top in scored:
        hi = [s for nm, s, _l in per if nm in HIGH]
        others = [s for nm, s, _l in per if nm not in HIGH]
        if not hi or not others:
            continue
        if sum(hi) / len(hi) > sum(others) / len(others):
            win += 1
        else:
            lose += 1
    print("逐首看 chorus 平均 > 该曲其他段平均: %d 胜 / %d 负" % (win, lose))
    print("=" * 68)
    if win + lose and win / (win + lose) < 0.7:
        print("结论: 重复度挑不出 chorus —— 不要拿它改排序。")
        if hi_all and lo_all and mh < ml:
            print("      而且方向是**反的**(chorus 平均低于前奏): 这批谱里重复的是伴奏型前奏的短动机。")
    elif win + lose:
        print("结论: 重复度能相当程度地把 chorus 挑出来, 可以考虑当「没分段曲子」的兜底权重。")
    return 0


def cmd_profile(args):
    rows = load_data()
    want = args.file
    for r in rows:
        if (r["file"][0] if isinstance(r["file"], list) else r["file"]) != want:
            continue
        seq = seq_of(r)
        prof = repeat_profile(seq)
        n = len(prof)
        print("%s  音高音 %d, 窗 %d/%d" % (want, n, W, STRIDE))
        rr = sec_ranges(r, n)
        if rr:
            print("人工分段:")
            for nm, a, b in rr:
                print("   %-16s [%4d,%4d)  重复分中位数 %.2f" % (nm, a, b, sec_at(prof, None, a, b - a)))
        step = 20
        print("重复度曲线(每 %d 个音高音一个点):" % step)
        for i in range(0, n, step):
            v = prof[i]
            print("   %5d %5.2f %s" % (i, v, "#" * min(int(v), 40)))
        return 0
    print("库里没有 %s" % want)
    return 1


def main():
    ap = argparse.ArgumentParser(description="用重复结构估段落权重(验证为主)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check", help="拿 37 首人工分段验证重复度能不能当段落权重")
    c.add_argument("--verbose", action="store_true", help="逐首逐段明细")
    c.set_defaults(func=cmd_check)
    p = sub.add_parser("profile", help="看一首的重复度曲线")
    p.add_argument("file", help="如 th01_01.txt")
    p.set_defaults(func=cmd_profile)
    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
