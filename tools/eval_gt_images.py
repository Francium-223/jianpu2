# -*- coding: utf-8 -*-
"""正确的 GT 评测: 转写 train-work/gt/ 里 GT 自带的那张图, 再与同名 .txt 比。
(之前按标题在 batch-out 里找是错的 —— 会配到别的编排版本, 毫无意义。)
用法: py tools/eval_gt_images.py
"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from eval_gt import score, score_bag
import jp_transcribe as JP

pairs = []
for img in sorted(glob.glob("train-work/gt/*.jpg")):
    base = img[:-4]
    if os.path.exists(base + ".txt"):
        pairs.append((os.path.basename(base), img, base + ".txt"))
if not pairs:
    print("train-work/gt/ 里没有'图+同名txt'的配对")
    sys.exit(0)

os.makedirs("train-work/gt_eval", exist_ok=True)
print("（序列=SequenceMatcher 对齐口径, 会被一处错位整段带偏 ✗; "
      "音高袋=对错位不敏感的真实读对率 ✓, 两个都要看）")
print(f"{'曲目':<16}{'输出':>6}{'GT':>6}{'序列OK':>8}{'序列%':>8}{'袋OK':>7}{'袋%':>8}")
print("-" * 62)
rows = []
for name, img, gt in pairs:
    out = f"train-work/gt_eval/{name}.txt"
    try:
        toks, meta = JP.render(img, f"train-work/gt_eval/{name}.png")
    except Exception as e:
        print(f"{name:<16}  转写失败 {type(e).__name__}")
        continue
    open(out, "w", encoding="utf-8").write(" ".join(toks))
    try:
        ok, o, g = score(gt, out)
        bok, bg = score_bag(gt, out)
    except Exception as e:
        print(f"{name:<16}  评测失败 {type(e).__name__}")
        continue
    rows.append((name, o, g, ok, bok, bg))
    print(f"{name:<16}{o:>6}{g:>6}{ok:>8}{100*ok/max(g,1):>7.1f}%{bok:>7}{100*bok/max(bg,1):>7.1f}%")
if rows:
    print("-" * 62)
    O = sum(r[1] for r in rows); G = sum(r[2] for r in rows)
    K = sum(r[3] for r in rows); B = sum(r[4] for r in rows)
    print(f"{'合计':<16}{O:>6}{G:>6}{K:>8}{100*K/max(G,1):>7.1f}%{B:>7}{100*B/max(G,1):>7.1f}%")
