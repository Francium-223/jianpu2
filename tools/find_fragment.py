# -*- coding: utf-8 -*-
"""在**原谱扫描图**上定位一串数字（"这句话在原谱哪里？"）—— 输出标注图 + 文字报告。

为什么需要它：管线只存"整页转写的 token 顺序"，**不存每个音符的坐标**，所以"第 83 个音在哪一像素"
没有现成答案。可靠的办法是**按音乐行切出来重新认一遍**：行是图天然的定位单位，认出哪一行含这串，
就把那行圈上（2026-09-29 给《你怎么说》圈 `33565653253` 就是这么做的，那次是临时脚本）。

用法：
  py -3.13 tools/find_fragment.py --file 你怎么说_2.txt --query 33565653253
  py -3.13 tools/find_fragment.py --file 你怎么说_2.txt --query 33565653253 --dry   # 只找图/不跑模型
  py -3.13 tools/find_fragment.py --img <图片或目录> --query 33565653253

输出：
  * `train-work/find/<曲名>_<片段>_标注.png`（原图 + 红框 + 页脚说明 + 放大插图）
  * 控制台/`train-work/find/<曲名>_<片段>.txt`：命中在哪一行、那一行认到的数字、以及
    **若原图没有这一串**时的最接近子串（这点很重要：假命中往往是"转写拼出来的"，纸上并不存在）
"""
import argparse
import glob
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

ROOT = r"D:\Documents_D\jianpu2"
DB = r"D:\Documents_D\jianpu-db"
OUTDIR = os.path.join(ROOT, "train-work", "find")
TMP = os.environ.get("TEMP", ROOT)
IMGRE = (".jpg", ".jpeg", ".png", ".gif", ".webp")


def digits_of(toks):
    out = []
    for t in toks:
        m = re.search(r"[1-7]", t)
        if m and not t.endswith("["):        # `3[` 是三连音开记号, 不是音符
            out.append(m.group(0))
    return "".join(out)


def lcs_len(a, b):
    """最长公共子串长度(片段 ≤ 几十个音, 直接 DP 就够)。"""
    best = 0
    prev = [0] * (len(b) + 1)
    for i in range(1, len(a) + 1):
        cur = [0] * (len(b) + 1)
        for j in range(1, len(b) + 1):
            if a[i - 1] == b[j - 1]:
                cur[j] = prev[j - 1] + 1
                best = max(best, cur[j])
        prev = cur
    return best


def score_of(name_or_file):
    """按 `file=` 或曲名在语料里找那条记录。"""
    key = name_or_file.strip()
    for line in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        d = json.loads(line)
        f = (d.get("file") or [""])[0]
        if f == key or f == key + ".txt" or (d.get("title") or "") == key:
            return d
    return None


def image_dirs_of(rec):
    """`source=site-id` -> 图库目录(可能有多页图)。"""
    src = (rec.get("source") or [""])[0] if rec.get("source") else ""
    if not src:
        return []
    pats = [os.path.join(ROOT, "images-prep", "*", "*__" + src),
            os.path.join(ROOT, "images", "*", "*__" + src)]
    out = []
    for p in pats:
        out += [d for d in glob.glob(p) if os.path.isdir(d)]
    return out


def pages_of(d):
    fs = [f for f in glob.glob(os.path.join(d, "*"))
          if os.path.splitext(f)[1].lower() in IMGRE and "__pg" not in os.path.basename(f)]
    return sorted(fs)


def music_lines(im):
    """把图按内容行块聚成"音乐行"(与 locate_phrase.py 同一套: transcribe.fine_rows)。"""
    import numpy as np
    import transcribe as T
    arr = np.asarray(im.convert("L"))
    rows = T.fine_rows(arr < T.TOL, T.ROW_GAP)
    if not rows:
        return []
    lines, cur = [], [rows[0]]
    for s, e in rows[1:]:
        if s - cur[-1][1] > 16:
            lines.append((cur[0][0], cur[-1][1]))
            cur = [(s, e)]
        else:
            cur.append((s, e))
    lines.append((cur[0][0], cur[-1][1]))
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", default="", help="语料里的文件名或曲名(找它的原图)")
    ap.add_argument("--img", default="", help="直接给图片/目录(与 --file 二选一)")
    ap.add_argument("--query", required=True, help="要找的数字串(1-7)")
    ap.add_argument("--dry", action="store_true", help="只解析路径与记录, 不跑 OCR")
    ap.add_argument("--min-line", type=int, default=25, help="行高小于它就当标题/歌词行跳过")
    a = ap.parse_args()
    Q = re.sub(r"[^1-7]", "", a.query)
    if len(Q) < 4:
        print("片段太短(至少 4 个音)"); return 1

    rec, dirs = None, []
    if a.file:
        rec = score_of(a.file)
        if not rec:
            print(f"语料里没找到 {a.file}"); return 1
        dirs = image_dirs_of(rec)
        print(f"曲名 {rec.get('title')} · file {(rec.get('file') or [''])[0]} · "
              f"source {(rec.get('source') or [''])[0]} · n_notes {rec.get('n_notes')}"
              f" · confidence {rec.get('confidence', '(无)')}")
        print(f"图库目录 {len(dirs)} 个: {[os.path.basename(d) for d in dirs]}")
    elif a.img:
        dirs = [a.img] if os.path.isdir(a.img) else [os.path.dirname(a.img)]
    else:
        print("要给 --file 或 --img"); return 1
    if not dirs:
        print("没找到图库目录(语料里的 source= 与图库目录名对不上?)"); return 1

    pages = []
    for d in dirs:
        pages += pages_of(d)
    pages = [p for p in pages if os.path.splitext(p)[1].lower() != ".gif" or True]
    if not pages:
        print("目录里没有图"); return 1
    print(f"页面 {len(pages)} 张: {[os.path.basename(p) for p in pages]}")
    if a.dry:
        print("[--dry] 到此为止(没跑模型)"); return 0

    from PIL import Image, ImageDraw, ImageFont
    import jp_transcribe as JP
    os.makedirs(OUTDIR, exist_ok=True)
    report, hits, best = [], [], (0, "", "", 0)
    for pi, page in enumerate(pages):
        im = Image.open(page)
        W, H = im.size
        lines = music_lines(im)
        print(f"\n=== {os.path.basename(page)} {W}x{H} · 聚成音乐行 {len(lines)} ===", flush=True)
        for li, (y0, y1) in enumerate(lines):
            if y1 - y0 < a.min_line:
                continue
            crop_p = os.path.join(TMP, f"ff_{pi}_{li}.png")
            im.crop((0, max(0, y0 - 8), W, min(H, y1 + 8))).save(crop_p)
            toks, _m = JP.render(crop_p, os.path.join(TMP, f"ff_{pi}_{li}_r.png"))
            d = digits_of(toks)
            line = f"行{li:>2} y{y0}-{y1} 认到 {len(d)} 音: {d[:100]}"
            if Q in d:
                hits.append((pi, li, y0, y1, d))
                line += f"   <<< 命中 {Q}"
            else:
                L = lcs_len(Q, d)
                if L > best[0]:
                    best = (L, d, f"{os.path.basename(page)} 行{li} y{y0}-{y1}", pi)
            print("  " + line, flush=True)
            report.append(line)

    io.open(os.path.join(OUTDIR, f"find_{os.path.basename((rec or {}).get('file', ['img'])[0] if rec else 'img')}.txt"),
            "w", encoding="utf-8", newline="\n").write("\n".join(report) + "\n")

    # ---------------- 画标注 ----------------
    if hits:
        pi, li, y0, y1, d = hits[0]
        page = pages[pi]
        im = Image.open(page).convert("RGB")
        BAND = 300
        canvas = Image.new("RGB", (im.width, im.height + BAND), (255, 255, 255))
        canvas.paste(im, (0, 0))
        dr = ImageDraw.Draw(canvas, "RGBA")
        dr.rounded_rectangle([60, max(0, y0 - 10), im.width - 60, min(im.height, y1 + 10)],
                             radius=16, fill=(220, 30, 30, 46), outline=(200, 20, 20, 255), width=8)
        try:
            f = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 46)
            fs = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 34)
        except Exception:
            f = fs = None
        ty = im.height + 20
        dr.text((70, ty), f"{Q} 出现在第 {pi+1} 张 · 第 {li} 行（y {y0}-{y1}）", font=f, fill=(180, 15, 15))
        dr.text((70, ty + 64), f"这一行认到的数字：{d[:70]}", font=fs, fill=(70, 70, 70))
        dr.text((70, ty + 110), "注：整页转写不存坐标，这里是**按音乐行切出来重认**定位的。",
                font=fs, fill=(130, 130, 130))
        out = os.path.join(OUTDIR, f"{os.path.basename(os.path.dirname(page))[:40]}_{Q}_标注.png")
        canvas.save(out)
        print(f"\n命中: 第 {pi+1} 张 · 行 {li} y{y0}-{y1}\n标注图 -> {out}")
    else:
        print(f"\n**这张图（逐行重认后）没有 {Q} 这一串**。")
        print(f"最接近的是 {best[2]}：最长公共子串 {best[0]} 个音（{best[1][:60]}）")
        print("—— 若语料里却命中过，多半是**整页转写把行尾/括号连读拼出来的假片段**（见 "
              "jianpu-db/misc/records/你怎么说那句是转写误读_20260929.md）。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
