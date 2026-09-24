# -*- coding: utf-8 -*-
"""多任务 CNN 转写的**精度闸门**: 拿"图 + 库里已有转写"的**同源样本**量一次真实精度。

为什么要它: `infer_multitask.py` 2026-09-25 才被复原(原来全仓库只有引用、没有实现),
而"这个 CNN 到底能不能用"不能靠感觉。这里用**最硬的对照**: 同一首谱既在 `images-prep/`
里有扫描/渲染图、又在 `data.jsonl` 里有当年 VLM 转好的 `score` —— 按 `source=jianpujia-<id>`
精确配对(不靠曲名模糊匹配), 比数字串。

用法:
    .venv-cnn/bin/python tools/check_cnn_accuracy.py            # 默认 8 首
    N=30 .venv-cnn/bin/python tools/check_cnn_accuracy.py       # 多量几首
    JIANPU_CNN_MODEL=models/multitask-v1 .venv-cnn/bin/python tools/check_cnn_accuracy.py

判据(2026-09-25 实测): 相似度 ~0.05、前 20 音命中 ~26%(7 个数字盲猜 14%) -> **不可用**。
结论: 这条路要复活必须**重新训练**(且要有真实音符图), 不是接个线就能用。
"""
import argparse
import difflib
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                       # jianpu2
WS = os.path.dirname(ROOT)
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))

import infer_multitask as Q                        # noqa: E402
import jptok                                       # noqa: E402

IMG = re.compile(r"\.(jpg|jpeg|png|gif|webp)$", re.I)


def digits_of(text):
    return "".join(str(jptok.parse_token(t)[0]) for t in (text or "").split() if jptok.is_pitch(t))


def ground_truth(db):
    """source(jianpujia-<id>) -> (曲名, 库里那份转写的数字串)。"""
    gt = {}
    with open(os.path.join(db, "data.jsonl"), encoding="utf-8") as f:
        for ln in f:
            r = json.loads(ln)
            for s in (r.get("source") or []):
                if s.startswith("jianpujia-"):
                    gt[s.split("-", 1)[1]] = (r.get("title") or "?", digits_of(r.get("score")))
    return gt


def samples(db, img_root):
    gt = ground_truth(db)
    out = []
    for d in glob.glob(os.path.join(img_root, "**", "*__jianpujia-*"), recursive=True):
        m = re.search(r"__jianpujia-(\d+)$", os.path.basename(d))
        if not m or m.group(1) not in gt:
            continue
        imgs = sorted(x for x in glob.glob(os.path.join(d, "*")) if IMG.search(x))
        if imgs:
            out.append((m.group(1), gt[m.group(1)][0], gt[m.group(1)][1], imgs[0]))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=os.path.join(WS, "jianpu-db"))
    ap.add_argument("--images", default=os.path.join(WS, "images-prep"))
    ap.add_argument("-n", type=int, default=int(os.environ.get("N", "8")))
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

    cands = samples(a.db, a.images)
    print(f"同源样本 {len(cands)} 个（图 + 库里已有转写）· 模型 {Q.MODEL_DIR}")
    if not cands:
        sys.exit("!! 找不到同源样本（图库或语料不在预期位置）")

    sims, heads = [], []
    for sid, title, g, img in cands[:a.n]:
        try:
            toks = Q.transcribe_image(img)
        except Exception as e:                     # 单首炸了不该拖垮整轮测量
            print(f"  ✗ {title[:20]}: {type(e).__name__} {e}")
            continue
        got = "".join(c for c in " ".join(toks) if c.isdigit())
        sim = difflib.SequenceMatcher(None, g[:200], got[:200]).ratio()
        k = max(1, min(len(g), 20))
        head = sum(1 for x, y in zip(g[:20], got[:20]) if x == y) / k
        sims.append(sim); heads.append(head)
        print(f"  {title[:18]:<20} GT {len(g):>4} 音 | CNN {len(got):>4} 音 | 相似 {sim:.2f} | 前20音命中 {head:.0%}")

    if not sims:
        sys.exit("!! 一个样本都没跑成")
    avg_s, avg_h = sum(sims) / len(sims), sum(heads) / len(heads)
    print(f"\n平均: 相似度 {avg_s:.2f}, 前20音命中率 {avg_h:.0%}  (n={len(sims)})")
    ok = avg_h >= 0.80                             # 可用门槛: 前 20 音至少八成对
    print("判定:", "可用 ✓" if ok else "不可用 ✗（别拿它批量转写, 会污染语料）")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
