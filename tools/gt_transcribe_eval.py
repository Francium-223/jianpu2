# -*- coding: utf-8 -*-
"""手写 GT 复评(配对无歧义): GT 的**谱图本身**就在 train-work/gt/*.jpg, 直接重转再比对。

为什么这才是对的做法:
  之前去语料里按文件名找"同一首歌"的转写 —— 同名多版本时会配错(实测《小星星》配到
  319 音的另一个版本, 而手写 GT 是 286 音那份 -> 算出 1.6% 的假数字 ✗)。
  GT 图就在本地, **转它自己**就没有任何配对歧义。

两种口径都给(eval_gt.py 里同一套键):
  * 序列口径: SequenceMatcher 对齐, 对插入/删除极敏感(开头多一个 `0` 会带偏整段)
  * **音高袋口径**: 只比 "数字+低八度点数" 的多重集合, 对错位不敏感, 更能代表"读对多少音"

用法: py -3.13 tools/gt_transcribe_eval.py
产物: train-work/gt_rerun/*.txt + train-work/gt_rerun/*.png, 报告打到 stdout
"""
import glob
import os
import sys
import time

sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from eval_gt import load_gt, score, score_bag

OUT = "train-work/gt_rerun"
os.makedirs(OUT, exist_ok=True)

pairs = {}
for f in sorted(glob.glob("train-work/gt/*")):
    name, ext = os.path.splitext(os.path.basename(f))
    if ext.lower() not in (".jpg", ".jpeg", ".png", ".pdf"):
        continue
    gt = f"train-work/gt/{name}.txt"
    if not os.path.exists(gt):
        print(f"跳过 {name}: 没有手写 GT txt")
        continue
    # **同名只留一个**: 扫描件(jpg/png)优先于排版 PDF —— 否则同一首歌会被算两次
    kind = "扫描件" if ext.lower() != ".pdf" else "排版PDF"
    if name in pairs and pairs[name][3] == "扫描件":
        continue
    pairs[name] = (name, f, gt, kind)
pairs = list(pairs.values())
if not pairs:
    sys.exit("train-work/gt 下没有 (图/PDF + txt) 成对的样本")

print(f"GT 样本 {len(pairs)} 首, 开始重转(用当前管线)\n")
import batch_transcribe as BT

# PDF: 用 PyMuPDF 渲染成图再转(有些 GT 只存了 PDF, 春天在哪里/小星星/澎湖湾/Lemon 都是)
# 多页 PDF 逐页转写后**拼接 token**(GT 是整首歌, 不能只比第一页)
DPI = int(os.environ.get("GT_DPI", "200"))


def pdf_pages(pdf, name):
    import pymupdf
    doc = pymupdf.open(pdf)
    outs = []
    for i, page in enumerate(doc):
        pix = page.get_pixmap(dpi=DPI)
        p = f"{OUT}/{name}_p{i}.png"
        pix.save(p)
        outs.append(p)
    doc.close()
    return outs


rows = []
for i, (name, img, gt, kind) in enumerate(pairs, 1):
    txt, png = f"{OUT}/{name}.txt", f"{OUT}/{name}.png"
    t0 = time.time()
    try:
        if kind == "排版PDF":
            pages = pdf_pages(img, name)
            toks = []
            for j, p in enumerate(pages):
                t2, _m = BT.transcribe_paged(p, txt, png if j == 0 else f"{OUT}/{name}_p{j}.png")
                toks += t2
        else:
            toks, _meta = BT.transcribe_paged(img, txt, png)
        with open(txt, "w", encoding="utf-8") as f:
            f.write(" ".join(toks))
    except Exception as ex:
        print(f"[{i}/{len(pairs)}] {name}: 转写失败 {type(ex).__name__} {ex}")
        continue
    ok, o, g = score(gt, txt)
    bag, g2 = score_bag(gt, txt)
    rows.append((name, o, g, ok, bag, kind))
    print(f"[{i}/{len(pairs)}] {name:<12} [{kind}] 输出 {o:>4} 音 / GT {g:>4} 音   "
          f"序列 {100*ok/max(g,1):5.1f}%   音高袋 {100*bag/max(g2,1):5.1f}%   ({time.time()-t0:.0f}s)")

if rows:
    O = sum(r[1] for r in rows)
    G = sum(r[2] for r in rows)
    S = sum(r[3] for r in rows)
    B = sum(r[4] for r in rows)
    print("\n" + "=" * 76)
    print(f"GT 复评合计 {len(rows)} 首: 输出 {O} 音 vs 手写 GT {G} 音")
    print(f"  序列口径   {S}/{G} = {100*S/max(G,1):.1f}%")
    print(f"  音高袋口径 {B}/{G} = {100*B/max(G,1):.1f}%   <- 宣传用这个, 并注明样本量")
    # **必须分两组**: 站点扫描件和 jianpu-ly 排版 PDF 不是一个分布 ——
    # 排版件用的是衬线数字 + 下划线当减时线, 我们管线没针对它调过, 拉低整体是正常的,
    # 混在一起报会让人以为"扫描件也才 89%"(实际上扫描件 ~95%+)。
    for k in ("扫描件", "排版PDF"):
        sub = [r for r in rows if r[5] == k]
        if not sub:
            continue
        o2 = sum(r[1] for r in sub)
        g2 = sum(r[2] for r in sub)
        s2 = sum(r[3] for r in sub)
        b2 = sum(r[4] for r in sub)
        print(f"  其中 {k} {len(sub)} 首: 输出 {o2} 音 vs GT {g2} 音  "
              f"序列 {100*s2/max(g2,1):.1f}%  音高袋 {100*b2/max(g2,1):.1f}%")
    print(f"\n明细 {OUT}/  (每首的 txt + 标注图 png, 可逐首人工核对)")
    with open("train-work/gt_report.txt", "w", encoding="utf-8") as f:
        f.write(f"手写 GT 复评 {len(rows)} 首 (谱图取自 train-work/gt/, 用当前管线重转)\n")
        f.write(f"输出 {O} 音 vs 手写 GT {G} 音\n")
        f.write(f"序列口径 {S}/{G} = {100*S/max(G,1):.1f}%\n")
        f.write(f"音高袋口径 {B}/{G} = {100*B/max(G,1):.1f}%\n")
        for k in ("扫描件", "排版PDF"):
            sub = [r for r in rows if r[5] == k]
            if not sub:
                continue
            o2 = sum(r[1] for r in sub)
            g2 = sum(r[2] for r in sub)
            s2 = sum(r[3] for r in sub)
            b2 = sum(r[4] for r in sub)
            f.write(f"  其中 {k} {len(sub)} 首 ({g2} 音): 序列 {100*s2/max(g2,1):.1f}%  "
                    f"音高袋 {100*b2/max(g2,1):.1f}%\n")
        f.write("口径: 音高袋只比(数字+低八度点数)的多重集合, 对错位不敏感; 序列口径对插入/删除极敏感。\n")
        f.write("注意: 排版PDF 是 jianpu-ly/LilyPond 的输出(衬线数字+下划线当减时线), 与语料的\n"
                "      站点扫描件不是一个分布; 引用转写准确率时**用扫描件那组**。\n")
        for name, o, g, ok, bag, kind in rows:
            f.write(f"  {name}\t[{kind}]\t输出{o}\tGT{g}\t序列{100*ok/max(g,1):.1f}%\t"
                    f"音高袋{100*bag/max(g,1):.1f}%\n")
    print("-> train-work/gt_report.txt")
