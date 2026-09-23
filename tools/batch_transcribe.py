# -*- coding: utf-8 -*-
"""批量转写: 遍历 images-prep/ready/*/001.jpg, 用 jp_transcribe 出 txt + 标注图.
带断点续传(已完成的跳过) + 进度文件 batch-out/progress.txt.
用法: py -3.13 tools/batch_transcribe.py [起始序号] [数量]
"""
import os, sys, glob, time, traceback, re
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
import jp_transcribe as JP

OUT = "batch-out"
os.makedirs(OUT, exist_ok=True)
PROG = f"{OUT}/progress.txt"

def split_pages(page, max_h=2200):
    """超长图(如 1140x7922 的多页长条) 按"行边界"切成若干页, 避免切断行。
    返回页图路径列表(单页图直接返回原路径)。"""
    import numpy as np
    from PIL import Image
    import transcribe as T
    im = Image.open(page)
    W, H = im.size
    if H <= max_h * 1.3:
        return [page]
    arr = np.asarray(im.convert("L"))
    content = arr < T.TOL
    rows = T.fine_rows(content, T.ROW_GAP)
    if not rows:
        return [page]
    bounds = [rows[0][0]]
    for s, e in rows:
        if e - bounds[-1] > max_h:
            bounds.append(s)
    bounds.append(H)
    # 去重/排序, 生成切片
    bounds = sorted(set(bounds))
    out = []
    base = os.path.splitext(page)[0]
    for i in range(len(bounds) - 1):
        y0, y1 = bounds[i], bounds[i + 1]
        if y1 - y0 < 40:
            continue
        p = f"{base}__pg{i}.jpg"
        im.crop((0, y0, W, y1)).convert("RGB").save(p, quality=95)
        out.append(p)
    return out or [page]


def transcribe_paged(page, txt, png):
    """超长图 -> 切页 -> 逐页转写 -> 合并 token(图只画第一页, 避免混乱)。"""
    import jp_transcribe as JP
    pages = split_pages(page)
    if len(pages) == 1:
        return JP.render(page, png)
    all_toks, all_meta = [], []
    for i, p in enumerate(pages):
        try:
            toks, meta = JP.render(p, png if i == 0 else f"{png[:-4]}_p{i}.png")
            all_toks += toks
        except Exception as ex:
            print(f"    第{i+1}页失败 {type(ex).__name__}", flush=True)
    return all_toks, all_meta


def pick_page(d):
    """目录里挑"谱页"。
    病根1: 按"文件最大"挑会挑到五线谱页(墨多、文件大)。qupu123 的"双谱/对照"目录里
    001.jpg=标题条(750x55), 002.jpg=简谱首页, 004/006/008=五线谱页; 按文件大小必错
    (实测 5/5 全挑到五线谱页, 整批"双谱"转写对象就错了)。
    病根2: jianpujia 目录里除乐谱外还有插图/历史照片(600x400、1080x831 等横版小图),
    照片文件常比线稿乐谱大 -> 按大小会挑到照片(实测《两只老虎》挑到一张人群老照片,
    《卖报歌》《找朋友》《上学歌》同病)。
    谱页特征 = **竖版大幅面**(h/w >= 1.3)。故取"第一张竖版页"; qupu123 再优先 002.jpg。

    **图片后缀不能只认 .jpg**(2026-09-22 修): qupu123 有的曲子只发 `.png`
    (实测《领悟》`领悟（李宗盛词曲）__qupu123-261725/001.png`), 只找 jpg 会让这些谱
    **静默跳过**、基准集永远差那一首 ✗。现在 jpg/jpeg/png 一起收。"""
    cands = [f for f in glob.glob(os.path.join(d, "*"))
             if os.path.splitext(f)[1].lower() in (".jpg", ".jpeg", ".png")
             and "__pg" not in os.path.basename(f)]
    if not cands:
        return None
    from PIL import Image as _Img
    info = []
    for f in cands:
        try:
            w, h = _Img.open(f).size
        except Exception:
            continue
        info.append((f, w, h))
    if not info:
        return None

    def _idx(t):
        m = re.search(r"(\d+)", os.path.basename(t[0]))
        return int(m.group(1)) if m else 9999

    real = [t for t in info if t[2] > 100 and t[1] > 100]
    if not real:
        return None  # 全是不合格页(标题条/损坏图) -> 跳过, 不要硬挑损坏文件
    if "qupu123" in d:
        n2 = [t[0] for t in real if os.path.splitext(os.path.basename(t[0]))[0].lower() == "002"]
        if n2:
            return n2[0]
    best = max(real, key=lambda t: os.path.getsize(t[0]))
    # 最小覆盖: 只有"最大文件"是横版小图(插图/照片, h < 1.3w)时才改用竖版谱页。
    # 谱页是竖版大幅面; 线上乐谱库的目录里常混有插图和历史照片, 它们文件更大。
    if best[2] < 1.3 * best[1]:
        port = sorted([t for t in real if t[2] >= 1.3 * t[1]], key=_idx)
        if port:
            return port[0][0]
    return best[0]


def safe_name(name):
    """输出文件名规范化。
    病根: jianpujia 的部分目录名是"UTF-8 被按 latin-1 解码"的 mojibake, 其中含
    C1 控制字符(U+0080..U+009F) -> Windows 不允许此类文件名 -> 写 txt 直接失败,
    整谱静默丢失(实测 44/1531 个谱因此没有输出)。这里先尝试把 mojibake 还原成
    UTF-8, 再去掉所有 Windows 非法字符。"""
    try:
        dec = name.encode("latin-1").decode("utf-8")
        if dec and not any(ord(c) < 32 or 127 <= ord(c) <= 159 for c in dec):
            name = dec
    except Exception:
        pass
    return re.sub(r'[\\/:*?"<>|\x00-\x1f\x7f-\x9f]', "_", name).strip() or "unnamed"


def main():
    import json
    ranked_files = sorted(glob.glob("rank-out/ranked*.jsonl"))
    if ranked_files:
        # 汇总所有热度排序文件 -> 全局按播放量降序 -> 最可能被搜的优先
        rows = []
        for rf in ranked_files:
            for l in open(rf, encoding="utf-8"):
                try:
                    rows.append(json.loads(l))
                except Exception:
                    pass
        rows.sort(key=lambda r: r.get("play", 0), reverse=True)
        seen, dirs = set(), []
        for r in rows:
            d = os.path.dirname(r["img"])
            if d in seen:
                continue
            seen.add(d)
            dirs.append(d)
        scores = [p for p in (pick_page(d) for d in dirs) if p]
        print(f"按热度顺序(B站播放量, 汇总 {len(ranked_files)} 个排序文件): {len(scores)} 张", flush=True)
    else:
        dirs = sorted(glob.glob("images-prep/*/*/"))
        scores = [p for p in (pick_page(d) for d in dirs) if p]
    start = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else len(scores)
    scores = scores[start:start + limit]
    print(f"待转写 {len(scores)} 张 (从 {start})", flush=True)
    done = 0
    for i, img in enumerate(scores):
        name = safe_name(os.path.basename(os.path.dirname(img)))
        txt = f"{OUT}/{name}.txt"
        png = f"{OUT}/{name}.png"
        if os.path.exists(txt):
            done += 1
            continue
        # 跳过"超长图"(多页拼合的长条): 转出来是一大坨(2000+音), 且极慢(20+分钟/张)
        try:
            from PIL import Image as _I
            _w, _h = _I.open(img).size
        except Exception:
            _w = _h = 0
        if _h > int(os.environ.get("JP_MAX_H", "3000")):
            with open(f"{OUT}/skipped.txt", "a", encoding="utf-8") as sf:
                sf.write(f"{name}\t{_w}x{_h}\n")
            print(f"[{i+1}/{len(scores)}] 跳过(超高 {_h}px): {name[:34]}", flush=True)
            continue
        t0 = time.time()
        try:
            toks, meta = transcribe_paged(img, txt, png)
            with open(txt, "w", encoding="utf-8") as f:
                f.write(" ".join(toks))
            msg = f"[{i+1}/{len(scores)}] {name}: 音{len(toks)} ({time.time()-t0:.0f}s)"
        except Exception as ex:
            msg = f"[{i+1}/{len(scores)}] {name}: 失败 {type(ex).__name__} {str(ex)[:60]}"
            with open(f"{OUT}/errors.log", "a", encoding="utf-8") as f:
                f.write(f"{name}\t{type(ex).__name__}\t{ex}\n{traceback.format_exc()}\n")
        print(msg, flush=True)
        with open(PROG, "w", encoding="utf-8") as f:
            f.write(f"{i+1}/{len(scores)}  已完成:{done+ (0 if 'toks' not in dir() else 1)}\n最后: {msg}\n")
    print("全部完成", flush=True)

if __name__ == "__main__":
    main()
