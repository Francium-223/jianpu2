# -*- coding: utf-8 -*-
"""拍号/小节能不能从语料内部验证？—— 结论：**基本不能**，本工具只给描述统计。

（2026-09-24 实测的结论，写在这里免得以后再走一遍弯路。）

* 第一版想找"拍号写错"：拿**总拍数**去比声明的拍号，余数≠0 就算可疑。
  **错**：只要有**弱起**(pickup)，余数天然不为 0 —— 任何余数都能被"弱起 p 拍"解释掉，
  所以"总拍数"这个量**根本无法判定拍号对错**（不可辨识）。
* 又试"含显式小节线就逐小节验拍数"：实测全语料 **7,321 首里只有 3 首**的正文里有 `|`,
  而且那 3 首的"小节"是 28/84/116 拍那种怪东西（多半不是小节线）—— 也没有可验对象。
* 原因很清楚：语料的 token 里**不写小节线**，小节是 `recover_bars` 按拍数**推算**出来的
  （所以网页上显示的小节是近似值，这点在记录里说明过）。

因此本工具降级为**描述统计**：给"总拍数 / 声明拍号 / 余数"的分布，并把那 3 首带 `|` 的
异常文件列出来供人看一眼。**它不下"拍号错了"的结论** —— 要判那个，只能对着原图（扫描件）看。

用法: python3 tools/audit_meter.py [--show 12]
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
DB = os.environ.get("JIANPU_DB") or os.path.join(os.path.dirname(ROOT), "jianpu-db")
SKILL = os.environ.get("JIANPU_JTOK") or os.path.join(ROOT, "skills", "jianpu-melody-lookup")
if os.path.isdir(SKILL) and SKILL not in sys.path:
    sys.path.insert(0, SKILL)
import jptok                                   # noqa: E402


def beats_of(tokens):
    """token 序列 -> [(小节拍数…)] 按显式 `|` 切；没有 `|` 就返回整体拍数。"""
    bars, cur, has = [], 0.0, False
    for t in tokens:
        if t == "|":
            has = True
            bars.append(cur)
            cur = 0.0
            continue
        if t in ("~", "%END"):
            continue
        if t == "-":
            cur += 1.0
            continue
        if jptok.is_note(t):
            cur += jptok.beat(t)
    if cur > 1e-6 or not bars:
        bars.append(cur)
    return bars, has


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    ap.add_argument("--show", type=int, default=12)
    a = ap.parse_args()

    rows = [json.loads(l) for l in io.open(a.data, encoding="utf-8") if l.strip()]
    stats = collections.Counter()
    rem = collections.Counter()
    with_bar = []
    for r in rows:
        body = []
        for sec in r.get("sections") or []:
            body += (sec.get("score") or "").split()
        bars, has = beats_of(body)
        total = sum(bars)
        bpb = r.get("beats_per_bar") or 0
        if has:
            with_bar.append((r.get("title") or "",
                             (r.get("file") or [""])[0] if isinstance(r.get("file"), list) else r.get("file"),
                             len(bars), bars[:4], bpb))
        if not bpb or total <= 0:
            stats["没有拍号或没有拍数"] += 1
            continue
        r_ = total % bpb
        stats["整除"] += int(r_ < 1e-6)
        stats["有余数"] += int(r_ >= 1e-6)
        rem[round(r_, 2)] += 1

    print(f"曲 {len(rows)} 首（**描述统计，不是错误清单**）")
    for k, v in stats.most_common():
        print(f"  {k}: {v} ({v/len(rows)*100:.1f}%)")
    print("\n余数分布（余数 = 总拍数 mod 声明拍号；弱起会让它非 0，所以非 0 不代表错）:")
    for k, v in sorted(rem.items())[:10]:
        print(f"  余 {k:<5} {v:>5} 首")
    print(f"\n正文里含显式 `|` 的文件: {len(with_bar)} 首（全语料 {len(with_bar)/len(rows)*100:.1f}%）")
    for t, f, n, head, bpb in with_bar[:a.show]:
        print(f"  「{t[:22]}」{n} 段, 前几段拍数 {head} (声明 {bpb:g})  ({f})")
    print("\n结论: **从语料内部判不了拍号/小节对不对** —— 没有显式小节线, 总拍数又被弱起混淆。")
    print("      要判只能对着原扫描件看（图片在 ../images-prep/ 与 images-prep/）。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
