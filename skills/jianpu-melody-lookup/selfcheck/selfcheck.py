# -*- coding: utf-8 -*-
"""检索脚本的**自检门**: 已知答案用例必须过, 否则不许出结果。

为什么要这个: 今天同类事故两次 ——
  ① 前端 `metaRows` 引用未定义的 `siteUrl` -> 结果区永远空白;
  ② `lookup_norm` 的解析器逐字符抠数字, 把 231 个音符膨胀成 377 个, 凭空造出
     "33565653253 在 th10_06 位置 0 完全一致" 的**假命中**。
两次都是"改完没验证就宣布完成"。这里把验证固化成函数, 供脚本启动时调用。

用例(全部人工核对过):
  * `63731232`   应在 神々が恋した幻想郷 / th10_06 里 0 错命中
  * `33565653253` **不应**有 0 错命中(它不在库里; 之前的"命中"是解析器造的)
  * 解析器口径: `4/4`、`q3`、`5s`、`6c.` 里的字母/拍号**不得**被当成音符
    (th10_06 的真实音符数是 231, 不是 377)
"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))          # jptok 在上一层
sys.stdout.reconfigure(encoding="utf-8")
import jptok  # noqa: E402


def load(data_path):
    return [json.loads(l) for l in io.open(data_path, encoding="utf-8") if l.strip()]


def pitch_of(score):
    return "".join(str(d) for d, _a, _o in jptok.seq(score or ""))


def check(data_path=None):
    """返回 (ok: bool, 报告: list[str])"""
    data_path = data_path or os.path.join(os.path.dirname(HERE), "data.jsonl")
    rep = []
    ok = True
    if not os.path.exists(data_path):
        return False, [f"找不到数据: {data_path}"]
    rows = load(data_path)
    rep.append(f"数据 {len(rows)} 首")

    # ① 解析器口径: th10_06 音符数必须是 231(不是被膨胀后的 377)
    th = [r for r in rows if r["file"][0] == "th10_06.txt"]
    if th:
        n = len(pitch_of(th[0].get("score")))
        good = (n == 231)
        ok &= good
        rep.append(f"{'OK ' if good else '**FAIL**'} th10_06 音符数 = {n} (期望 231; 377 说明把时值/拍号当成了音符)")
    else:
        rep.append("  (th10_06.txt 不在数据里, 跳过该用例)")

    # ② 63731232 必须 0 错命中 th10_06 / 神々
    hit = any("63731232" in pitch_of(r.get("score")) for r in rows)
    ok &= hit
    rep.append(f"{'OK ' if hit else '**FAIL**'} 63731232 应 0 错命中(神々が恋した幻想郷)")

    # ③ 33565653253 不应有 0 错命中(之前那次"完全一致"是解析器造的)
    bad = [r["file"][0] for r in rows if "33565653253" in pitch_of(r.get("score"))]
    good = (len(bad) == 0)
    ok &= good
    rep.append(f"{'OK ' if good else '**FAIL**'} 33565653253 不应有 0 错命中, 实际 {bad[:3]}")

    return ok, rep


def main():
    ok, rep = check()
    print("\n".join(rep))
    print("自检", "通过" if ok else "**未通过** —— 不要相信本脚本的检索结果")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
