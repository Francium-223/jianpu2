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

**增量**(2026-10-07 加, 判据的唯一实现见 `tools/kind2_cache.py`): 逐目录判"输入变了没有",
没变就复用上一轮的结论 —— 全量重扫 81 分钟里有 73 分钟是在重算**已知答案**。
缓存记"目录 mtime + 被挑中那页的 路径/字节数/mtime + 上次的测量值"; 三者任一变了才重量。
`--full` 强制退回旧行为; `--adopt` 拿现有 `kind2.tsv` 当种子建缓存(第一次启用用, 不重量)。
"""
import csv, glob, os, sys
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import batch_transcribe as BT
import jp_transcribe as JP   # 判据的唯一实现(impure_from)在这里, 三处调用点共用
import kind2_cache as KC

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
    import time
    LIM = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 0
    FULL = "--full" in sys.argv          # 退回全量重扫(不读也不写缓存)
    ADOPT = "--adopt" in sys.argv        # 用现有 kind2.tsv 当种子建缓存
    dirs = sorted(d for d in glob.glob("images-prep/*/*") if os.path.isdir(d))
    if LIM:
        dirs = dirs[:LIM]
    print(f"检查 {len(dirs)} 个目录 (非纯: nline>={BADLINE}"
          f"{' 且 staff>=' + os.environ.get('JP_STAFFMAX', '4') if os.environ.get('JP_PURITY2','0')=='1' else ''})",
          flush=True)

    pkey = KC.params_key()
    old = {} if FULL else KC.load(pkey)
    # 产物路径: 默认 train-work/kind2.tsv; `JP_KIND2_TSV` 只给离线基准用。
    _tsv = os.environ.get("JP_KIND2_TSV") or "train-work/kind2.tsv"
    # `--adopt` 的种子: 现有 kind2.tsv 里这一行的**测量值**(口径未变时它就是权威结论)。
    # 只拿 nline/wide/pure/w/h/staff 六个数; 页面身份这一轮记成当前值, 下一轮页面真变了就失效重量。
    seed = {}
    if ADOPT and not FULL and os.path.exists(_tsv):
        for r in csv.DictReader(open(_tsv, encoding="utf-8"), delimiter="\t"):
            seed.setdefault(r["dir"], r)
    f = open(_tsv, "w", encoding="utf-8", newline="")
    w = csv.writer(f, delimiter="\t")
    w.writerow(["dir", "nline", "wide", "pure", "w", "h", "staff"])
    n = bad = 0
    cache = {}
    n_hit = n_meas = n_seed = n_seed_page = n_gone = n_fail = n_nopage = 0
    t0 = time.time()
    t_stat = t_pick = 0.0                   # 逐项累加, 用来定位"热/冷跑到底慢在哪"
    nt_stat = nt_pick = 0
    for i, d in enumerate(dirs):
        d = d.rstrip("/\\")
        name = os.path.basename(d)
        if name in cache:                 # 历史 kind2.tsv 里同一目录名会出现两次 -> 只留一行
            continue
        _a = time.perf_counter()
        mt = KC._mtime_int(d)
        _b = time.perf_counter()
        c = old.get(name)
        vals = None
        p = None
        hit = False
        if (c and c.get("pure", "") != "" and c.get("page_path", "")
                and c.get("dir_mtime", "") == mt
                and KC._mtime_int("images-prep/" + c["page_path"]) == c.get("page_mtime", "")):
            # 快路径: 目录没增删过文件(mtime 不变) + 被挑中那页没被换过(页 mtime 不变)
            # -> 判据的输入没动 -> 直接复用结论, 连 pick_page 的"逐图读文件头"都省了。
            # (实测 pick_page 平均 4.6 ms/目录(中位 1.2), 空目录 0.1 ms; 这里只花 2 次 stat。)
            vals = (c["nline"], c["wide"], c["pure"], c["w"], c["h"], c["staff"])
            n_hit += 1
            hit = True
            p = None                    # 快路径不需要页路径: row 直接搬既有缓存行
        else:
            # 慢路径第一问: **缓存里那页还在不在**。还在(路径存在且 mtime 没变)就说明
            # 挑中的还是同一页 -> 结论仍然有效, 不用量, 也不用重挑。
            # 这一条把"目录没变但页的 mtime 变了"和"缓存页还在、目录 mtime 变了(多半只多了一张
            # 无关的图)"两类都挡在 pick_page 之外 —— 实测热跑 12.9 万次 pick_page 就是这么来的。
            _c = time.perf_counter()
            cp = "images-prep/" + c["page_path"] if c and c.get("page_path") else None
            if (cp and c.get("pure", "") != "" and os.path.exists(cp)
                    and KC._mtime_int(cp) == c.get("page_mtime", "")):
                vals = (c["nline"], c["wide"], c["pure"], c["w"], c["h"], c["staff"])
                n_hit += 1
                hit = True
            else:
                p = BT.pick_page(d)
                if p:
                    pp = os.path.relpath(p, "images-prep").replace("\\", "/")
                    ps, pm = str(os.path.getsize(p)), KC._mtime_int(p)
                else:
                    pp = ps = pm = ""
                if KC.same_state(c, mt, pp, ps, pm):
                    vals = (c["nline"], c["wide"], c["pure"], c["w"], c["h"], c["staff"])
                    n_hit += 1
                    hit = True          # 页面身份没变 -> 缓存行可以直接沿用, 不必重写
                elif p:
                    try:
                        nl, wd, ww, hh, sf = measure(p)
                        # 判据统一走 jp_transcribe.impure_from: 与旧行为逐字节一致;
                        # JP_PURITY2=1 时改为"nline>=BADLINE 且 staff>=STAFFMAX"。
                        vals = (nl, wd, int(not JP.impure_from(nl, sf)), ww, hh, sf)
                        n_meas += 1
                    except Exception:
                        vals = None
                        n_fail += 1
            t_pick += time.perf_counter() - _c
            nt_pick += 1
            if vals is None and c and c.get("pure", "") != "":
                # 图已不在(滑窗删过)或本轮读图失败 -> 复用既有判定。
                # 依据: 判据的唯一输入是那张图的像素, 像素没了 != 判据失效; 重算已不可能,
                # 而丢掉这一行会让 pick_best 少一个候选 -> 可能改选版本 ✗。
                # **绝不凭空造行**: 没有既有判定就跳过(与旧行为一致)。
                vals = (c["nline"], c["wide"], c["pure"], c["w"], c["h"], c["staff"])
                n_gone += 1
            if vals is None and name in seed:
                s = seed[name]
                vals = (s["nline"], s["wide"], s["pure"], s["w"], s["h"], s["staff"])
                n_seed += 1
                n_seed_page += (1 if p else 0)
        t_stat += _b - _a
        nt_stat += 1
        if vals is not None:
            nl, wd, pu, ww, hh, sf = vals
            pure = int(pu)
            bad += (0 if pure else 1)
            w.writerow([name, nl, wd, pure, ww, hh, sf])
            n += 1
        elif p is None and not hit:
            n_nopage += 1                 # 挑不出谱页 -> 与旧行为一致: 不写行(只留缓存态)
        if not hit:
            cache[name] = KC.row(pkey, name, mt, p, vals)
        elif name not in cache:
            cache[name] = c               # 快路径: 原样搬既有缓存行(不重算页面身份)
        if (i + 1) % 10000 == 0:
            el = time.time() - t0
            print(f"  {i+1}/{len(dirs)}  行 {n}  非纯 {bad}  复用 {n_hit}  重量 {n_meas}  {el:.0f}s"
                  f"  [mtime {t_stat:.0f}s / 慢路径 {t_pick:.0f}s ({nt_pick} 次)]", flush=True)
    f.close()

    if not FULL:
        KC.save(cache)
    print(f"完成 {n}: 纯简谱 {n-bad}, 非纯 {bad} -> {_tsv}")
    print(f"  [增量] 枚举 {len(dirs)} 个目录 / 复用判定 {n_hit} / 真重量 {n_meas} / "
          f"复用既有判定(图没了或读图失败) {n_gone} / 取种子 {n_seed}(其中当轮有谱页 {n_seed_page}) / "
          f"读图失败 {n_fail} / 无谱页 {n_nopage}  (缓存 {len(cache)} 行)  用时 {time.time()-t0:.0f}s",
          flush=True)


