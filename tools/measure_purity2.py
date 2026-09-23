# -*- coding: utf-8 -*-
"""量化纯度门 nline 的**误杀率**, 并评估"按线数(而非行数)"的新判据。

背景: 现行 `_nline_big` 数的是"单行最长暗段>=55%页宽"的**行数**。
一个黑色标题底框高 15 行 -> 直接贡献 15; 一条长连音线的平顶 3 行 -> 贡献 3。
两者都能单独把**纯简谱页**顶过 BADLINE=5 (实测《倔强》纯简谱 nline=20, 全来自标题框)。

新判据: 把长横线按**纵向连通块**分组, 只把**细块(<=3 行)** 算作"谱线",
**厚块(>=4 行 = 底框/logo/照片)** 不算。n_thin >= BADLINE -> 非纯。

性质: n_thin <= nline, 故新判据**只多放行、绝不误杀**现有已接受语料(零回归)。
本脚本量的是: 多放行的那批里, 有多少是**真污染**(含五线谱/六线谱)。

用法: py -3.13 tools/measure_purity2.py [每边抽样数, 默认150]
"""
import glob
import os
import random
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image

BADLINE = int(os.environ.get("JP_BADLINE", "5"))
THIN_MAX = int(os.environ.get("JP_THINMAX", "3"))   # 块厚 <= 此行数 => 算"线"
THIN_MAX_W = int(os.environ.get("JP_THINMAXW", "8"))  # wide 判据下的细线厚度上限
SAMPLE = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 150


def analyze(img_path):
    """返回 (nline_旧, n_thin_新, n_thick, n_staff)

    n_staff = "5% 页高的滑窗内最多有几个长线组"。
      五线谱/六线谱的本质是 5-6 条**等距成簇**的长线, 所以谱线在局部密集;
      而纯简谱页的长横线来自**长连音线**(零星、互不相邻)和**标题底框/logo**(厚块、单发),
      局部不会密集到 5 条。故 n_staff >= 5 判非纯比"数行数"稳。
    """
    im = Image.open(img_path).convert("L")
    iw, ih = im.size
    tw = 1200 if iw < 950 else (2000 if iw > 2000 else iw)
    if tw != iw:
        im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
    g = np.asarray(im).astype(np.int16)
    thr = max(60, int(g.mean()) - 25)
    W = g.shape[1]
    c = g < thr
    ys = []
    for y in range(c.shape[0]):
        row = c[y]
        if not row.any():
            continue
        d = np.diff(np.concatenate(([0], row.view(np.int8), [0])))
        st = np.where(d == 1)[0]
        en = np.where(d == -1)[0]
        if len(st) and (en - st).max() >= 0.55 * W:
            ys.append(y)
    nline = len(ys)
    n_thin = n_thick = 0
    tops = []
    if ys:
        grp = [ys[0]]
        tops.append(ys[0])
        for y in ys[1:]:
            if y - grp[-1] <= 1:
                grp.append(y)
            else:
                if len(grp) <= THIN_MAX:
                    n_thin += 1
                else:
                    n_thick += 1
                grp = [y]
                tops.append(y)
        if len(grp) <= THIN_MAX:
            n_thin += 1
        else:
            n_thick += 1
    # 滑窗: 窗高 = 5% 页高(五线谱 5 条线 ~ 55px @1200 宽, 窗 60-100px 足够容纳)
    win = max(20, int(0.05 * c.shape[0]))
    n_staff = 0
    for i, t in enumerate(tops):
        k = 0
        for u in tops[i:]:
            if u - t <= win:
                k += 1
            else:
                break
        n_staff = max(n_staff, k)
    # n_staff2: 用"行覆盖 >60% 页宽"(wide 判据) 抓**被品格数字打断**的六线谱线,
    # 但仍按细线分组(厚度<=THIN_MAX_W), 故照片/底框这类厚块不会计入。
    wrows = [y for y in range(c.shape[0]) if c[y].sum() > 0.60 * W]
    tops2 = []
    if wrows:
        g2 = [wrows[0]]
        for y in wrows[1:]:
            if y - g2[-1] <= 1:
                g2.append(y)
            else:
                if len(g2) <= THIN_MAX_W:
                    tops2.append(g2[0])
                g2 = [y]
        if len(g2) <= THIN_MAX_W:
            tops2.append(g2[0])
    n_staff2 = 0
    for i, t in enumerate(tops2):
        k = 0
        for u in tops2[i:]:
            if u - t <= win:
                k += 1
            else:
                break
        n_staff2 = max(n_staff2, k)
    return nline, n_thin, n_thick, n_staff, n_staff2


def build_index():
    idx = {}
    for d in glob.glob("images-prep/*/*"):
        if not os.path.isdir(d):
            continue
        try:
            import batch_transcribe as BT
            idx[BT.safe_name(os.path.basename(d))] = d
        except Exception:
            continue
    return idx


def pick_page(d):
    import batch_transcribe as BT
    try:
        return BT.pick_page(d)
    except Exception:
        return None


def sample_names(quarantined, n):
    if quarantined:
        names = [os.path.basename(f)[:-4] for f in glob.glob("batch-out-bad/*.txt")]
    else:
        names = [os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")
                 if not os.path.basename(f).startswith("hot_")]
    random.seed(11)
    random.shuffle(names)
    return names[:n]


def build_admit_list(out_path):
    """扫描全部隔离页, 用**真判据**(jp_transcribe.impure_from) 生成放行名单。

    名单格式 = transcribe_source.py 认的"每行一个目录名"。
    判据在此处不重复实现, 直接调 kind_detect2.measure + impure_from。"""
    import jp_transcribe as JP
    import kind_detect2 as K
    import batch_transcribe as BT
    idx = {}
    for d in glob.glob("images-prep/*/*"):
        if os.path.isdir(d):
            idx[BT.safe_name(os.path.basename(d))] = d
    names = [os.path.basename(f)[:-4] for f in glob.glob("batch-out-bad/*.txt")]
    print(f"隔离页 {len(names)} 个; 图索引 {len(idx)}", flush=True)
    admit, miss, err = [], 0, 0
    for i, nm in enumerate(names, 1):
        d = idx.get(nm)
        if not d:
            miss += 1
            continue
        try:
            p = BT.pick_page(d)
            if not p:
                miss += 1
                continue
            nl, _wd, _W, _H, sf = K.measure(p)
            if not JP.impure_from(nl, sf):
                admit.append(os.path.basename(d.rstrip("/\\")))
        except Exception:
            err += 1
        if i % 500 == 0:
            print(f"  {i}/{len(names)}  已放行 {len(admit)}", flush=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(admit) + "\n")
    print(f"\n放行 {len(admit)} 个 -> {out_path}  (找不到目录 {miss}, 异常 {err})")
    return admit


def main():
    idx = build_index()
    print(f"图目录索引 {len(idx)} 个; BADLINE={BADLINE} 厚块阈值>={THIN_MAX+1}行")
    for quarantined in (True, False):
        tag = "隔离区(batch-out-bad)" if quarantined else "已接受(batch-out)"
        names = sample_names(quarantined, SAMPLE)
        rows = []
        for nm in names:
            d = idx.get(nm)
            if not d:
                continue
            p = pick_page(d)
            if not p:
                continue
            try:
                rows.append(analyze(p))
            except Exception:
                continue
        if not rows:
            print(f"{tag}: 无数据")
            continue
        nl = np.array([r[0] for r in rows])
        nt = np.array([r[1] for r in rows])
        nk = np.array([r[2] for r in rows])
        ns = np.array([r[3] for r in rows])
        ns2 = np.array([r[4] for r in rows])
        print(f"\n=== {tag}  n={len(rows)}")
        print(f"  旧 nline : 中位 {np.median(nl):.0f}  均值 {nl.mean():.1f}  >=5 的占 {100*(nl>=5).mean():.0f}%")
        print(f"  新 n_thin: 中位 {np.median(nt):.0f}  均值 {nt.mean():.1f}  >=5 的占 {100*(nt>=5).mean():.0f}%")
        print(f"  厚块 n_thick: 中位 {np.median(nk):.0f}  均值 {nk.mean():.1f}  >=1 的占 {100*(nk>=1).mean():.0f}%")
        print(f"    n_staff (窗内最多线数): 中位 {np.median(ns):.0f}  >=5 的占 {100*(ns>=5).mean():.0f}%")
        print(f"  ★ n_staff2(行覆盖>60%的细线,窗内最多): 中位 {np.median(ns2):.0f}  "
              f"均值 {ns2.mean():.1f}  >=5 的占 {100*(ns2>=5).mean():.0f}%")
        hist = {}
        for v in ns2:
            hist[v] = hist.get(v, 0) + 1
        keys = sorted(hist)
        print("  n_staff2 分布: " + "  ".join(f"{k}:{hist[k]}" for k in keys[:14]))
        if quarantined:
            admit = int((ns < 5).sum())
            print(f"  => 按 n_staff<5 放行: {admit}/{len(rows)} ({100*admit/len(rows):.0f}%)")
            print(f"     按 n_thin<5 放行: {int((nt<5).sum())}/{len(rows)} ({100*(nt<5).mean():.0f}%)")

    nq = len(glob.glob("batch-out-bad/*.txt"))
    print(f"\n隔离区共 {nq} 个; 若放行率 r, 预计新增 r*{nq} 个谱")


if __name__ == "__main__":
    if "--list" in sys.argv:
        i = sys.argv.index("--list")
        out = sys.argv[i + 1] if len(sys.argv) > i + 1 else "train-work/purity2_admit.txt"
        build_admit_list(out)
        sys.exit(0)
    main()
