# -*- coding: utf-8 -*-
"""抓"正文里有音符、解析出来却是空/少一大截"的谱 —— 专治**静默丢数据**这一类。**只读。**

为什么要有它(2026-09-28 的 bug 就是它抓的那一类):
`score.py:to_record()` 里 `%END` 判定原来写成 `startswith('%end')`, 而每个文件首行都是
`%<文件名>.txt` 注释 —— 文件名以 `end` 开头的谱(`Endless_Love_无尽的爱.txt`)
**在第一行就 break**, 整首旋律变成空 score; 又因为 `parse_scores.py` 的准入是
`status ∈ {ok,ocr} and score 非空`, 它连 data.jsonl 都进不去, 日志里只留一句"待整理已跳过"。
**三道自检都看不见**: 不变量查的是进了库的数据、自检门查的是库内一致性、CI 查的是产物。

判据(全部走唯一实现: `jianpu-db/score.py` 的 `Score` + `skills/.../jptok.py`):
  ① **全丢**: 正文(第一条 `%--` 之后)里有 >= MIN_PITCH 个有音高的 token, 但 `to_record()['score']`
     里一个都没有 -> 一定是解析/标记判定出错(不是"歌本来就短")。
  ② **准入缺口**: status ∈ {ok, ocr}、正文有 >= MIN_PITCH 个音, 但**不在 data.jsonl 里**。
  ③ 提醒项: 没有**精确的** `%END` 行(只有近似行, 如 `%Endless_...`)。

用法:
    py -3.13 tools/qa_parse_loss.py                 # 只读扫全库
    py -3.13 tools/qa_parse_loss.py --min 5
"""
import argparse
import io
import json
import os
import re
import sys

from guard import guard_help                # noqa: E402  `--help` 守卫必须是**第一段实际代码**
guard_help(__doc__)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
sys.path.insert(0, DB)                      # jianpu-db 的 score.py = 唯一解析实现
sys.path.insert(0, HERE)
import jptok                                # noqa: E402
sys.stdout.reconfigure(encoding="utf-8")

OK_STATUS = ("ok", "ocr")
EXACT_END = re.compile(r"%end\s*$", re.I)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--min", type=int, default=5, help="判定'有音'的下限(默认 5, 与检索下限一致)")
    a = ap.parse_args()

    import score as S                      # noqa: E402  唯一解析实现

    # score.py 假定自己在 jianpu-db 里跑(要读 tags.json 等); 本工具从 jianpu2 跑, 所以切过去,
    # 路径一律用**绝对路径**(相对路径会按 CWD 解析 -> "file not found")。
    os.chdir(DB)

    in_jsonl = set()
    jp = os.path.join(DB, "data.jsonl")
    if os.path.isfile(jp):
        for ln in io.open(jp, encoding="utf-8"):
            if ln.strip():
                in_jsonl.add(json.loads(ln)["file"][0])

    SC = os.path.join(DB, "scores")
    files = sorted(f for f in os.listdir(SC)
                   if f.endswith(".txt") and not f.endswith(("_expand.txt", "_buf.txt")))
    lost, gap, noend, skipped = [], [], [], 0
    for fn in files:
        p = os.path.join(SC, fn)
        try:
            text = io.open(p, encoding="utf-8", errors="replace").read()
        except Exception:                                        # noqa: BLE001
            skipped += 1
            continue
        body = text.partition("%--")[2]
        n_body = sum(1 for t in body.split() if jptok.is_pitch(t))
        st = re.search(r"(?m)^status=(\S*)\s*$", text)
        st = st.group(1) if st else ""
        # ③ 精确 %END
        if not any(EXACT_END.search(l.strip()) and l.strip().replace(" ", "").lower() == "%end"
                   for l in text.splitlines()):
            noend.append(fn)
        if n_body < a.min:
            continue
        try:
            sc = S.Score(p)
            sc.parse()
            rec = sc.to_record()
            n_score = sum(1 for t in (rec.get("score") or "").split() if jptok.is_pitch(t))
        except Exception as e:                                   # noqa: BLE001
            lost.append((fn, "解析抛异常 %s: %s" % (type(e).__name__, str(e)[:60])))
            continue
        if n_score == 0:
            lost.append((fn, "正文 %d 个音 -> score 0 个" % n_body))
        if st in OK_STATUS and fn not in in_jsonl:
            gap.append((fn, "status=%s, 正文 %d 个音, 不在 data.jsonl" % (st, n_body)))

    print("扫描 %s: %d 份谱(data.jsonl %d 首)" % (SC, len(files), len(in_jsonl)))
    print("\n① 全丢(正文有音、score 为空): %d" % len(lost))
    for fn, why in lost[:12]:
        print("     %-40s %s" % (fn, why))
    print("\n② 准入缺口(status 合格、有音、却不在 data.jsonl): %d" % len(gap))
    for fn, why in gap[:12]:
        print("     %-40s %s" % (fn, why))
    # ⚠ 这里别用 `%` 格式化: 文案里有 `%END`, 其中 `%E` 会被当成浮点格式符
    #   (`TypeError: %d format: a real number is required, not str`)。f-string 躲开这类。
    ex = ("  例: " + ", ".join(noend[:4])) if noend else ""
    print(f"\n③ 没有**精确** `%END` 行的: {len(noend)}{ex}")
    if skipped:
        print("\n(读不了/跳过的: %d)" % skipped)
    return 1 if (lost or gap) else 0


if __name__ == "__main__":
    sys.exit(main())
