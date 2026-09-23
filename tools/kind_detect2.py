# -*- coding: utf-8 -*-
"""纯简谱检测(定稿 v3): 两个特征取 OR。

  nline  = "单行最长连续暗段 >= 55% 页宽" 的行数          -> 五线谱/六线谱的直谱线
  wide   = "整行横向覆盖 > 60% 页宽" 的行数                -> 更宽松, 抓断续/淡线

灰度阈值**自适应**(mean-25, 下限60): 固定 128 对淡扫描件失效 —— 实测钢琴五线谱
《我喜欢》(整页均值 230) 用 128 时 nline=0/wide=4 混过过滤器, 自适应后 43/90 判对。

判非纯: nline >= JP_BADLINE(5)

**JP_PURITY2=1 时改为 AND**: `nline>=BADLINE 且 staff>=JP_STAFFMAX(默认4)`。
`staff` = 5% 页高滑窗内最多几条"细长横线"(行覆盖>60%页宽、厚<=8行、看局部密度)。
理由: nline 数的是**行数**, 黑色标题底框(一次 15-20 行)或长连音线的平顶(2-3 行)
都能单独把**纯简谱页**顶上阈值(实测《倔强》纯简谱 nline=26 全来自标题框)。
AND 保证 nline 低的谱照旧放行 -> 对现有已接受语料零改动。判据实现见
`jp_transcribe.impure_from`(唯一实现, 三处调用点共用)。

为什么**不用** wide(整行横向覆盖)做判据:
  * wide 会被**照片**骗 —— 歌谱页常配歌手照/卡通图, 那些暗区让 wide 飙高。
    实测纯简谱《恋着多喜欢》(梁静茹, 页面上有照片+猫+动漫) wide=62, 若用
    "nline>=5 或 wide>=45" 会把它连同 341 个谱、33,595 个音符一起误杀。
  * nline 不会被照片骗(照片不形成"整行连续暗段"), 实测该谱 nline=0 正确通过。
  * 代价: 漏掉极少数"六线谱被数字打断得厉害"的吉他谱(实测 14 个样本里漏 2 个),
    远比误杀 3 万音符划算。wide 仍会算出来存进 tsv, 只作参考不作判据。

灰度阈值**自适应**(mean-25, 下限60): 固定 128 抓不到淡扫描件的谱线 —— 实测钢琴
五线谱《我喜欢》(整页均值 230) 用 128 时 nline=0 混过过滤器, 自适应后 43 判对。
"""
import csv, glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import batch_transcribe as BT
import jp_transcribe as JP   # 判据的唯一实现(impure_from)在这里, 三处调用点共用

BADLINE = int(os.environ.get("JP_BADLINE", "5"))
WIDELINE = int(os.environ.get("JP_WIDELINE", "45"))

def measure(path, thr=None):
    im = Image.open(path).convert("L")
    iw, ih = im.size
    tw = 1200 if iw < 950 else (2000 if iw > 2000 else iw)
    if tw != iw:
        im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
    g = np.asarray(im).astype(np.int16)
    # 自适应阈值: 固定 128 对"淡扫描件"失效 —— 实测钢琴五线谱《我喜欢》(均值230)
    # 用 128 时 nline=0/wide=4 混过过滤器, 改成 mean-25 后是 43/90, 正确判非纯。
    if thr is None:
        thr = max(60, int(g.mean()) - 25)
    W = g.shape[1]
    c = g < thr
    rs = c.sum(axis=1)
    nline = 0
    for y in range(c.shape[0]):
        row = c[y]
        if not row.any():
            continue
        d = np.diff(np.concatenate(([0], row.view(np.int8), [0])))
        st = np.where(d == 1)[0]
        en = np.where(d == -1)[0]
        if len(st) and (en - st).max() >= 0.55 * W:
            nline += 1
    wide = int((rs > 0.60 * W).sum())
    staff = JP._staff_evidence_arr(c, W)
    return nline, wide, W, g.shape[0], staff

if __name__ == "__main__":
    LIM = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 0
    dirs = sorted(d for d in glob.glob("images-prep/*/*") if os.path.isdir(d))
    if LIM:
        dirs = dirs[:LIM]
    print(f"检查 {len(dirs)} 个目录 (非纯: nline>={BADLINE}"
          f"{' 且 staff>=' + os.environ.get('JP_STAFFMAX', '4') if os.environ.get('JP_PURITY2','0')=='1' else ''})",
          flush=True)
    f = open("train-work/kind2.tsv", "w", encoding="utf-8", newline="")
    w = csv.writer(f, delimiter="\t")
    w.writerow(["dir", "nline", "wide", "pure", "w", "h", "staff"])
    n = bad = 0
    for i, d in enumerate(dirs):
        p = BT.pick_page(d)
        if not p:
            continue
        try:
            nl, wd, ww, hh, sf = measure(p)
        except Exception:
            continue
        # 判据统一走 jp_transcribe.impure_from: 默认与旧行为逐字节一致;
        # JP_PURITY2=1 时改为"nline>=BADLINE 且 staff>=STAFFMAX"。
        pure = not JP.impure_from(nl, sf)
        bad += (0 if pure else 1)
        w.writerow([os.path.basename(d.rstrip("/\\")), nl, wd, int(pure), ww, hh, sf])
        n += 1
        if (i + 1) % 1000 == 0:
            print(f"  {i+1}/{len(dirs)}  非纯 {bad}", flush=True)
    f.close()
    print(f"完成 {n}: 纯简谱 {n-bad}, 非纯 {bad} -> train-work/kind2.tsv")
