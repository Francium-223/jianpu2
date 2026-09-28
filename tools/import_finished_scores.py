# -*- coding: utf-8 -*-
"""把**成品目录里已转写、还没入库**的曲谱导进 `jianpu-db/scores/`。

为什么需要它: 流水线是"两段式" —— `batch-out/`(裸 token) --to_jianpu_db--> `jianpu-db-out/scores/`
(成品, **语料自己的覆盖率报告就把它标成"待入库"**) --> `jianpu-db/scores/` --> `parse_scores.py`
--> `data.jsonl`。最后那一步(成品 -> 语料目录)**原先没有通用工具**: `kugou_pipeline.import_to_db()`
只管酷狗那一批, `batch_transcribe_queue.py --stage import` 要队列文件。于是每轮 finalize 重建完成品,
新谱就躺在成品目录里等 —— 实测 2026-09-28: 成品 8573 份、语料 7816 份, **1639 份 `status=ocr` 从未入库**。

**只拷不覆盖**: 目标已存在就跳过(语料里那份可能已被人工修过, 绝不能拿成品盖回去)。
**只拷不删**: 本工具不移动、不删除任何文件。
**判据复用流水线自己的两条**(不另立一套):
  * 旋律音 **< 5** 的跳过 —— 检索下限就是 5, 这种谱永远查不到, `quarantine_short_scores.py` 的判据;
  * 念白异常: token >= 20 且 x >= 10 且 x 占比 >= 0.30 —— `quarantine_highx.py` 的判据(全库 x 占比 3.4%,
    >=30% 的实测全是误转)。
  * `status` 不在 {ok, ocr} 的跳过(白名单)。

用法:
    py -3.13 tools/import_finished_scores.py                      # 只看会导哪些(默认 dry)
    py -3.13 tools/import_finished_scores.py --apply              # 真拷
    py -3.13 tools/import_finished_scores.py --src <目录> --dry    # 换源目录
"""
import argparse
import io
import os
import re
import shutil
import sys

from guard import guard_help                     # noqa: E402  `--help` 守卫必须是**第一段实际代码**
guard_help(__doc__)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
sys.path.insert(0, HERE)
import jptok                                     # noqa: E402  唯一口径

sys.stdout.reconfigure(encoding="utf-8")
MIN_PITCH = 5          # 与 quarantine_short_scores.py 一致
MIN_TOK = 20           # 与 quarantine_highx.py 一致
XR = 0.30
NMIN_X = 10


def body_tokens(text):
    return text.partition("%--")[2].split()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(ROOT, "jianpu-db-out", "scores"),
                    help="成品目录(默认 jianpu-db-out/scores)")
    ap.add_argument("--dst", default=os.path.join(DB, "scores"))
    ap.add_argument("--apply", action="store_true", help="不给就是 dry-run")
    a = ap.parse_args()

    if not os.path.isdir(a.src):
        sys.exit("源目录不存在: %s" % a.src)
    src = sorted(f for f in os.listdir(a.src) if f.endswith(".txt"))
    skipped = {"目标已有": 0, "status 不在白名单": 0, "旋律音 < 5": 0, "念白异常": 0, "读不了": 0}
    take = []
    for fn in src:
        dstp = os.path.join(a.dst, fn)
        if os.path.exists(dstp):
            skipped["目标已有"] += 1
            continue
        try:
            t = io.open(os.path.join(a.src, fn), encoding="utf-8", errors="replace").read()
        except Exception:                                       # noqa: BLE001
            skipped["读不了"] += 1
            continue
        m = re.search(r"(?m)^status=(\S*)\s*$", t)
        if (m.group(1) if m else "") not in ("ok", "ocr"):
            skipped["status 不在白名单"] += 1
            continue
        toks = body_tokens(t)
        npitch = sum(1 for x in toks if jptok.is_pitch(x))
        if npitch < MIN_PITCH:
            skipped["旋律音 < 5"] += 1
            continue
        nx = sum(1 for x in toks if "x" in x)
        if len(toks) >= MIN_TOK and nx >= NMIN_X and nx / len(toks) >= XR:
            skipped["念白异常"] += 1
            continue
        take.append(fn)

    print("成品目录 %s: %d 份" % (a.src, len(src)))
    print("  目标已有(不覆盖) %d" % skipped["目标已有"])
    for k in ("status 不在白名单", "旋律音 < 5", "念白异常", "读不了"):
        if skipped[k]:
            print("  跳过(%s) %d" % (k, skipped[k]))
    print("  -> **可导入 %d 份** (目标 %s)" % (len(take), a.dst))
    if take:
        print("  前 8 个:", take[:8])
    if not a.apply:
        print("\n(dry-run, 没写任何东西; 加 --apply 才真拷)")
        return 0

    n = 0
    for fn in take:
        shutil.copy2(os.path.join(a.src, fn), os.path.join(a.dst, fn))
        n += 1
    print("\n已拷入 %d 份 -> %s" % (n, a.dst))
    print("下一步: cd %s && py parse_scores.py   (重建 data.jsonl)" % DB)
    return 0


if __name__ == "__main__":
    sys.exit(main())
