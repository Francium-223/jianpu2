# -*- coding: utf-8 -*-
"""端到端简谱转写器: 简谱图片 → jianpu-ly 音符序列。
流程: 行切割 → 单音符裁剪(放大3倍) → v15 原子模型识别 → 拼回序列。
模型: models/jianpu-lora-v15 (jianpu-atom 真实微调版)
用法: py -3.13 tools/transcribe.py <图片路径> [--out 输出txt]
"""
import os, sys, re, glob, argparse, subprocess, numpy as np
from PIL import Image, ImageDraw
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
sys.path.insert(0, ROOT)

TOL = 170
ROW_GAP = 8
BAR_THR = 3
SCALE = 3
PAD = 8


def strip_tall_verticals(mask, min_len=60):
    """抹掉"纵向连续长度 >= min_len"的竖线(连谱号 / 长竖线 / 页边框)。

    病根: 这类竖线横跨整页的多条音符行, 使水平投影在"行间空白"处也不为 0,
    于是 fine_rows 找不到分隔点 -> 整页被当成一个行带。
    实测《将进酒》整页 1256px 高只切出 1 个行带, crop_note_regions 因而产出
    贯穿全页的巨型块(高 458px, 内含十几个数字), 送进模型必然幻觉(编数字或 'x')。
    数字本身高仅 ~30px, 故 min_len=60 不会误伤数字。
    """
    out = mask.copy()
    H, W = mask.shape
    # 原来逐列 Python 循环 + 每列 np.where: 2000 列就是 2000 轮解释器开销, 纯浪费。
    # 矢量化为"一次算出所有纵向行程 -> 一次比较 -> 按行程清零", 结果逐像素相同。
    if H == 0 or W == 0 or not mask.any():
        return out
    # 纵向行程: 把图**转置**成 (W, H), 每行 = 原图的一列, 行内连续 True 段 = 一条竖线。
    # 转置后起点/终点同处一行、按 (行,列) 升序 i 与 i 一一配对; 直接对行方向 diff
    # 则起点按 (起行,列) 排、终点按 (止行,列) 排, 分别过滤必错配。
    # 必须**先 astype(int8) 再 diff**: bool 上 diff 没有 -1, 整条规则会失效。
    mt = mask.T
    big = np.pad(mt, ((0, 0), (1, 1)), constant_values=False)
    d = np.diff(big.astype(np.int8), axis=1)
    s_x, s_y = np.nonzero(d == 1)          # s_x = 原图列 x, s_y = 起行 y
    _ex, e_y = np.nonzero(d == -1)         # e_y = 止行 y + 1(哨兵列)
    if len(s_x) != len(e_y):
        return out
    keep = (e_y - s_y) >= min_len          # 原判据 `e0 - s0 >= min_len`(含 [False] 哨兵)
    sel = np.flatnonzero(keep)
    if sel.size == 0:
        return out
    # 先按 x 分组再**在组内**处理: 起点/终点的配对来自同一组下标(sel), 分组后组内
    # 仍保持 y 升序 -> 逐条清 `[s_y, e_y)` 与原实现逐条清完全等价(逐条而非整段合并,
    # 因为同列两条长线之间可能夹着一条短线, 那条不能抹)。
    vx = s_x[sel]
    newc = np.r_[True, vx[1:] != vx[:-1]]
    grp = np.flatnonzero(newc).tolist() + [len(vx)]
    for gi in range(len(grp) - 1):
        x = int(vx[grp[gi]])
        for t in sel[grp[gi]:grp[gi + 1]]:
            out[s_y[t]:e_y[t], x] = False
    return out



def fine_rows(content, gap, strip_len=60):
    proj = strip_tall_verticals(content, strip_len) if strip_len else content
    rowsum = proj.sum(axis=1)
    # 用自适应阈值判"有内容", 而非 rowsum > 0:
    # 扫描图常带零星噪点(每几行 1-2 个黑像素), 会让整页被连成一个行带。
    thresh = max(3, int(0.01 * rowsum.max()))
    rows = np.where(rowsum > thresh)[0]
    if len(rows) == 0:
        return []
    segs = []
    start = rows[0]; prev = rows[0]
    for y in rows[1:]:
        if y - prev > gap:
            segs.append((start, prev)); start = y
        prev = y
    segs.append((start, prev))
    return segs


def split_row_inner(content, s, e, min_h=22, valley_ratio=0.10):
    """在行带内部按"暗像素低谷"切开上下两层(音符行 vs 紧邻的歌词行/排版说明)。

    病根: fine_rows 只按"全空行"切分, 而排版说明或第二段歌词常常贴在音符行下方
    十几像素处(不产生全空行), 于是被判成同一行 -> 文字被当音符块送去识别,
    产出 '?' / 'x' 等乱码。

    做法: 在行带中部找水平投影的最低谷, 若低谷足够低(<= valley_ratio * 峰值),
    就在该处切断, 返回两个子行带; 否则原样返回。
    """
    block = content[s:e + 1]
    H = block.shape[0]
    if H < 2 * min_h:
        return [(s, e)]
    proj = block.sum(axis=1).astype(float)
    peak = float(proj.max()) if proj.size else 0.0
    if peak <= 0:
        return [(s, e)]
    lo, hi = min_h, H - min_h
    if hi <= lo:
        return [(s, e)]
    seg = proj[lo:hi]
    i = int(np.argmin(seg)) + lo
    low_thr = valley_ratio * peak
    if proj[i] > low_thr:
        return [(s, e)]
    # 关键: 低谷必须"够宽"(连续空行 >= min_gap)。
    # 数字与其下方时值线之间只隔 1-2 行空 -> 不能切(否则数字丢失时值);
    # 音符行与歌词行/排版说明之间通常隔 4 行以上 -> 该切。
    min_gap = 3          # 下划线已由 strip_hlines 单独处理, 这里不必再为保护它卡门槛
    w = 0
    j = i
    while j >= lo and proj[j] <= low_thr:
        w += 1
        j -= 1
    j = i + 1
    while j < hi and proj[j] <= low_thr:
        w += 1
        j += 1
    if w < min_gap:
        return [(s, e)]
    a = (s, s + i - 1)
    b = (s + i + 1, e)
    if a[1] - a[0] + 1 < min_h:
        return [(s, e)]
    # 判定下半段是不是"歌词行": 下半段若含"数字形状"的连通域(汉字/数字),
    # 就是歌词 -> 必须切开(否则汉字被当音符切出来, 实测《问候歌》满屏假 'x');
    # 若下半段只有细横线(下划线带) -> 不能切(切了数字就丢时值)。
    lower = content[b[0]:b[1] + 1]
    if _any_textlike_cc(lower):
        return [a, b]
    return [(s, e)]


def _any_textlike_cc(mask, h_lo=14, h_hi=45, w_min=6):
    """mask 里是否存在"像文字/数字"的连通域(满足 h_lo<=h<=h_hi, h>w, w>=w_min)。

    `split_row_inner` 只用到**存在性**, 而旧写法 `any(... for c in components(lower))`
    会先把整块标注成 Python 列表/元组再判断。这里仍走同一个 `_cc_label`(见上: 不看连通域
    只看单条行程会误判, `h>w` 在连通后未必保持), 但**边生成边判、命中即返回**, 不再把
    全部连通域物化。判据与旧版逐元素一致(验证: `_analysis/cc_textlike_equiv.py`)。
    """
    for c in _cc_label(mask):
        if h_lo <= c[5] <= h_hi and c[5] > c[4] and c[4] >= w_min:
            return True
    return False


def strip_hlines(sub, max_h=6, min_w=8, lab=None):
    """抹掉"细横线"连通域(时值下划线 / 延音杠 / 部分连音线)。

    病根: 下划线横跨相邻多个数字, 把它们连成"一个大连通域"(高~25 宽~60),
    于是 crop_note_regions 的"数字 = 高>宽"判据全部不成立 -> 整组音符被丢弃。
    实测《问候歌》(7 行谱)只切出 22 个 token, 图上绝大多数音符没被切出来。

    返回 (抹线后的 mask, 被抹掉的横线 bbox 列表 [(x0,y0,x1,y1,w,h), ...])。
    数字的横笔画与数字主体相连(整体 h>=14), 不会被误判为横线。

    `lab` 可传入 `_cc_label(sub, want_index=True, want_runs=True)` 的返回值复用 ——
    调用点(`jp_transcribe` 第一遍/第三遍)本来也要标一次, 复用能省掉整图标注。
    只传元组列表时(旧调用点)自己补算行程。**`lines` 的元素顺序**与旧版相同
    (连通块发现顺序); 下游只按字段取用, 不依赖顺序。
    """
    if lab is None:
        comps, runs, run_of, rows, r_a0, r_a1 = _cc_label(sub, want_index=True, want_runs=True)
    elif isinstance(lab, tuple):
        comps, runs, run_of, rows, r_a0, r_a1 = lab
    else:
        comps = lab
        runs, run_of, rows, r_a0, r_a1 = _cc_label(sub, want_runs=True)[1:]
    out = sub.copy()
    lines = []
    hit = set()
    for k, c in enumerate(comps):
        w, h = c[4], c[5]
        if h <= max_h and w >= min_w and w >= 2 * h:
            lines.append((c[0], c[1], c[2], c[3], w, h))
            hit.add(k)
    if hit:
        # 整块 = 它全部行程的并 -> 按行程一次性清零(大时值线可跨 500px, 不必逐像素循环)
        ro_np = np.asarray(run_of)
        sel = np.isin(ro_np, np.fromiter(hit, dtype=ro_np.dtype, count=len(hit)))
        for i in np.nonzero(sel)[0].tolist():
            out[rows[i], r_a0[i]:r_a1[i] + 1] = False
    return out, lines



def _cc_label(mask, want_count=False, want_index=False, want_runs=False):
    """**8 邻接连通域标注(唯一真源)** —— 行程(RLE) + 并查集, 与原逐像素 BFS 等价。

    为什么换: 原来 `components` 是**逐像素 Python BFS**(deque + 9 邻居), 2000x1500
    的一页有 300 万像素, 一个 crop 就要几百微秒 —— 实测它占整条转写 CPU 几何路径的
    **57%**(`_analysis/cpu_baseline.json`), 而 CPU 又占总耗时的 29.3%。

    等价性(**零近似**): 8 邻接下, 第 y 行的行程 [a0,a1] 与第 y-1 行的行程 [b0,b1]
    连通 <=> `a1+1 >= b0 and b1+1 >= a0`(x 区间相交或相邻); 同一行内两个行程之间
    必有背景像素, 故同行内绝不连通。=> 行程粒度并查集给出的连通划分与逐像素 BFS
    **完全一致**(含斜向单像素接触)。包围盒 = 该块所有行程外包盒的并。
    返回顺序也一致: 行优先、行内 x 升序 = BFS 的发现顺序(逐元素比对见
    `_analysis/cc_bench.py`, 随机掩码 800 例 + 结构化 13 例全等)。

    want_count=True 时第 7 位是**像素数**(与旧实现逐元素相同; 已用"实心 9x9 -> 81、
    一行两个 2px 段 -> 2 和 2、单像素散布"等用例钉死)。此位在整条生产转写链上
    **没有任何读取点**(全仓 grep `c[6]` 只命中 `tools/dump_cut_nogpu.py` 里对另一个
    list 的下标), 保留纯属兼容旧签名。

    want_index=True 时末尾附"该块在本结果里的下标" —— 供 `strip_hlines` 复用同一份
    标注(它本来就是"标注 -> 挑细横线"), 省掉一次全图标注。

    want_runs=True 时返回 (comps, runs, run_of, row_of, a0, a1):
      runs[i] = (row, x0, x1) 第 i 个行程;  run_of[i] = 该行程所属**结果下标**。
      供 strip_hlines 一次性抹掉整块(不必逐像素 Python 循环)。
    """
    H, W = mask.shape
    # 空值返回形状: `want_runs=True` 是 6 元组(调用方要解包), 其余一律 **`[]`**
    # (原来是 `([], [], [], [], [], [])` —— 对 `want_runs=False` 的调用方来说那是
    # "6 个元素"而不是"0 个连通域", 迭代它会拿到 6 个空 list, `c[5]` 直接越界)。
    empty = ([], [], [], [], [], []) if want_runs else []
    if H == 0 or W == 0 or not mask.any():
        return empty
    # 行程 = "每行里连续的 True 段"。左右各补一列 False 后一次 diff 拿到 1/-1
    # (起点/终点)。**必须 np.pad 显式补齐**: 起点与终点要按 (行,列) 一一配对,
    # 分别过滤会错配; 也**不能**用 `np.diff(..., prepend=False)` —— numpy 2.5 把
    # `prepend=False` 当成"补一行/一列 False", 结果比输入多一列, 行程整体错位。
    big = np.pad(mask, ((0, 0), (1, 1)), constant_values=False)
    d = np.diff(big.astype(np.int8), axis=1)
    rr, cc = np.nonzero(d == 1)
    er, ec = np.nonzero(d == -1)
    n_run = len(rr)
    if n_run == 0:
        return empty
    if len(er) != n_run:
        raise RuntimeError(f"行程配对失败: 起点 {n_run} 终点 {len(er)}")
    row_of = rr
    a0 = cc
    a1 = ec - 1                               # diff 的终点列是"之后第一列", 故 -1
    starts = np.flatnonzero(np.r_[True, row_of[1:] != row_of[:-1]])
    bounds = list(np.r_[starts, n_run].tolist())
    p_a0 = a0.tolist()
    p_a1 = a1.tolist()
    p_row = row_of.tolist()
    parent = list(range(n_run))

    def _find(i, parent=parent):
        r = i
        while parent[r] != r:
            r = parent[r]
        while parent[i] != r:               # 路径压缩
            parent[i], i = r, parent[i]
        return r

    for gi in range(1, len(starts)):
        # **空行必须先断链**: `starts` 只记"有行程的行", 两组的行号可能相差 >1
        # (中间是空行)。空行隔开的两行在 8 邻接下**不连通**, 若照旧比对就会把跨行
        # 的块误并(踩过: 6x9 掩码里行0与行4 被并成一个块)。故必须核对相邻行号。
        if row_of[bounds[gi]] - row_of[bounds[gi - 1]] != 1:
            continue
        ps, pe = bounds[gi - 1], bounds[gi]
        for i in range(bounds[gi], bounds[gi + 1]):
            ai0, ai1 = p_a0[i], p_a1[i]
            j = ps
            while j < pe and p_a0[j] <= ai1 + 1:
                if p_a1[j] >= ai0 - 1:
                    ri, rj = _find(i), _find(j)
                    if ri != rj:
                        if ri < rj:
                            parent[rj] = ri
                        else:
                            parent[ri] = rj
                j += 1
    INF = 1 << 30
    # 每个行程的包围盒/像素数按根聚合 —— 用 numpy 按根做分段 reduce, 比逐行程 Python
    # 循环快一个量级(实测: 一条 2000px 宽的行带有 1~4 万条行程, 逐条 Python 循环
    # 是这条路径剩下的主要开销)。顺序无关, 与原实现逐元素相同。
    a0n = np.asarray(p_a0, dtype=np.int64)
    a1n = np.asarray(p_a1, dtype=np.int64)
    rn = np.asarray(p_row, dtype=np.int64)
    roots = np.fromiter((_find(i) for i in range(n_run)), dtype=np.int64, count=n_run)
    uniq, inv = np.unique(roots, return_inverse=True)
    ncomp = len(uniq)
    minx = np.full(ncomp, INF, dtype=np.int64)
    maxx = np.full(ncomp, -1, dtype=np.int64)
    miny = np.full(ncomp, INF, dtype=np.int64)
    maxy = np.full(ncomp, -1, dtype=np.int64)
    npix = np.zeros(ncomp, dtype=np.int64)
    np.minimum.at(minx, inv, a0n)
    np.maximum.at(maxx, inv, a1n)
    np.minimum.at(miny, inv, rn)
    np.maximum.at(maxy, inv, rn)
    np.add.at(npix, inv, a1n - a0n + 1)
    # 结果顺序 = 发现顺序(行优先、行内 x 升序) = 每个根第一次出现的位置
    first_at = np.full(ncomp, n_run, dtype=np.int64)
    pos = np.arange(n_run, dtype=np.int64)
    np.minimum.at(first_at, inv, pos)
    order_idx = np.argsort(first_at, kind="stable")
    if want_count:
        npc = npix[order_idx].tolist()
    out = []
    for k in range(ncomp):
        c = order_idx[k]
        t = (int(minx[c]), int(miny[c]), int(maxx[c]), int(maxy[c]),
             int(maxx[c] - minx[c] + 1), int(maxy[c] - miny[c] + 1))
        if want_count:
            t = t + (npc[k],)
        if want_index:
            t = t + (k,)
        out.append(t)
    if want_runs:
        # 行程 -> **结果下标**: np.unique 给的 inv 是"按根升序"的编号, 要换成发现顺序
        outpos = np.empty(ncomp, dtype=np.int64)
        outpos[order_idx] = np.arange(ncomp, dtype=np.int64)
        run_of = outpos[inv].tolist()
        return out, list(zip(p_row, p_a0, p_a1)), run_of, p_row, p_a0, p_a1
    return out



def components(sub):
    """兼容旧签名: 6 元组 (x0, y0, x1, y1, w, h, 像素数)。见 `_cc_label`。"""
    return _cc_label(sub, want_count=True)


def _geo_comps(mask):
    """`geo_detect._components` 的返回形状 —— **6 元组** (x0, y0, x1, y1, w, h, 像素数)。

    ⚠ 这里纠正一个**存量误读**: `_analysis/cc_bench.py` 的注释与 `_analysis/cc_baseline/`
    里的副本都写着"`geo_detect._components` 返回 5 元组, 不含 cnt", 但**对着 git HEAD
    实测是 6 元组**(`git show HEAD:tools/geo_detect.py`: BFS 里 `cnt` 确实在数, 只是
    geo_detect 自己的判据只用前 6 位)。本函数**保持 6 元组**: `geo_detect.geo_detect` 与
    `classify_block.classify_block` 都是 `x0, y0, x1, y1, w, h = c` 的 6 元解包,
    少给一位就是 ValueError(本轮改到一半时真的踩过这个 IndexError)。

    **空掩码必须先返回 []**: `_cc_label` 在 `want_runs=False` 的空值分支返回 **6 元组**
    `([], [], [], [], [], [])`(为兼容它自己的 want_runs=True 形状), 直接迭代会拿到
    6 个空 list -> `c[5]` 越界。

    末位**必须切掉**像素数: HEAD 的 `geo_detect._components` 里 `cnt` 虽然在数, 但
    **没有**加到返回元组上(只有 `transcribe.components` 加了), 所以这里是 `c[:6]`。
    切掉后与 HEAD 逐元素相等(见 `_analysis/cc_equiv_changes.py`)。
    """
    if mask.size == 0 or not mask.any():
        return []
    return [c[:6] for c in _cc_label(mask, want_count=True)]



def count_bars(sub, H):
    """判定一个横带是否为'音符行': 需存在 >=BAR_THR 个真小节线。
    真节线 = 细(h<=5) 高>=20 且 接近带内最高细高(>=0.8*max), 并对高度取聚类(多数等高)。
    旧版用 0.5*H 判高, 当音符行与下方歌词行被 fine_rows 合并(H被撑大)时会误判为0,
    导致整行(如 spring 第三行)被整行丢弃。改为相对最高细高, 不受 H 膨胀影响。
    """
    comps = components(sub)
    thin = [c for c in comps if c[4] <= 5 and c[5] >= 10]
    if len(thin) < BAR_THR:
        return 0
    # 基准高度用"中位数细高"而非最高: 单根异常高(如伴奏部杠 h=54)会把最高抬得过,
    # 使真正的小节线(h~42)被 0.8*max 排除, 导致整行被误判非音符行. 中位数更鲁棒.
    hs_all = sorted(c[5] for c in thin)
    hbase = hs_all[len(hs_all) // 2]
    real = [c for c in thin if c[5] >= 0.8 * hbase and c[5] >= 20]
    if len(real) < BAR_THR:
        return 0
    hs = sorted(c[5] for c in real)
    med = hs[len(hs) // 2]
    return sum(1 for c in real if abs(c[5] - med) <= 4)


def crop_note_regions(sub, lab_pre=None):
    """逐符号切块: 每个连通域(数字/杠)一个块, 严格不重叠。
    - 数字(竖形 高>宽 高度14-40): 块=数字+正下方附属(下划线/低八度点/附点), x=数字左缘..右缘(不收纳右侧)。
    - 杠(横线 宽>高*2 宽>15): 块=杠本身(独立原子)。
    - 小节线(细高)忽略。按x排序输出。

    `lab_pre` 可由调用点传入 `_cc_label(sub, want_index=True, want_runs=True)` ——
    `jp_transcribe.transcribe` 的第一遍/第三遍**已经**为了行带判据标过一次同一个 sub,
    这里复用可省掉"再标一次 + 再抹一次线"。不传(旧调用点)时行为与从前一致。
    """
    H, W = sub.shape
    # 关键: 先抹掉细横线(时值下划线/延音杠), 否则下划线会把相邻多个数字连成
    # "一个大连通域"(宽>>高), 使下面"数字 = 高>宽"的判据全体失效 ->
    # 整组音符被丢弃(实测《问候歌》7 行谱只切出 22 个 token)。
    stripped, hlines = strip_hlines(sub, lab=lab_pre)
    comps = _cc_label(stripped, want_count=True)
    if not comps:
        return []
    bar_cands = list(comps) + list(hlines)
    bar_x = sorted([(c[0] + c[2]) / 2.0 for c in bar_cands if c[4] <= 5 and c[5] >= 35])
    bar_x = [b for b in bar_x if b < W - 2]
    # 若检测不到小节线(bar_x 空, 如行首无竖杠/小节线高度<35), 仍须给一个整行大段,
    # 否则 digits 循环被跳过 -> 整行切不出任何数字(新格式谱 0 音).
    seg_bounds = [(0, bar_x[0])] if bar_x else [(0, W - 1)]
    for i in range(len(bar_x)):
        seg_bounds.append((bar_x[i], bar_x[i + 1] if i + 1 < len(bar_x) else W - 1))
    # 数字(竖形) 和 杠(横线)
    # 宽连通域切分(必须在 digits 判据之前做):
    # 相邻两个数字靠得近时, 相连的下划线把它们粘成"一个连通域"(宽>>单数字宽, 高<宽),
    # 于是既不是 digit(要求高>宽) 也不是 dash -> 但会被后续逻辑当块送进模型 -> 吐 '0'.
    # 实测《问候歌》86 块里 13 块是这种连体块。
    # 用"上部 75% 行"做列投影切开: 下划线在下部不参与投影, 数字间的空隙得以显现。
    _ws = sorted(c[4] for c in comps if 12 <= c[5] <= 45)
    _med = _ws[len(_ws) // 2] if _ws else 10
    _split = []
    for c in comps:
        x0, y0, x1, y1, w, h = c[0], c[1], c[2], c[3], c[4], c[5]
        if w <= 1.8 * _med or h < 12:
            _split.append(c); continue
        patch = stripped[y0:y1 + 1, x0:x1 + 1]
        ntop = max(1, int(h * 0.75))
        colsum = patch[:ntop].sum(axis=0)
        segs, cur = [], None
        for i in range(w):
            if colsum[i] > 0:
                if cur is None: cur = i
            elif cur is not None:
                segs.append((cur, i - 1)); cur = None
        if cur is not None:
            segs.append((cur, w - 1))
        if len(segs) <= 1:
            _split.append(c); continue
        for (a, b) in segs:
            if b - a + 1 < 4:
                continue
            _split.append((x0 + a, y0, x0 + b, y1, b - a + 1, h))
    comps = _split
    # 数字宽下限原为 6: 数字 '1' 只有 5px 宽 -> 被整类丢掉(实测《问候歌》第1行
    # "1 1 1 3" 里的两个 1 全没框)。放宽到 3。
    # 但必须排除"小节线"(极细高的竖线, 如 宽3 高43): 它 高>宽、宽>=3、高<=45,
    # 原来完全满足数字判据 -> 被当成数字切块送进模型 -> 吐多余的音(实测 spring
    # 多出 4 个音), 标注图上还会看到"框住小节线"的怪框。真数字 高/宽 约 1.5-3,
    # 小节线 >= 5, 故用 高 < 3.5*宽 卡掉。
    digits = [c for c in comps if c[5] >= 14 and c[5] <= 45 and c[5] > c[4] and c[4] >= 3
              and c[5] < 3.5 * c[4]]
    # 延音杠/下划线: 来自被抹掉的横线(hlines), 而非 stripped(那里已经没有横线了)
    # 宽度下限原为**固定 12px** —— 这是**字号相关**的 bug ✗: 实测 GT 图(train-work/gt/*.jpg,
    # 1000px 宽)里真延音杠只有 w=11/h=4(见 tools/diag_dash.py), 正好卡在 12 之下 -> 全被丢掉 ✗
    # (兄弟抱一下 因此丢 9 根杠、快乐父子俩 丢 8 根, 是它们 GT 匹配率低的主因 ✗)。
    # 大字号的谱杠 >12px 所以不受影响, 这就是全库仍有 1.6 万个 '-' 的原因。
    # 默认改为 8, 与 strip_hlines 自己的 min_w=8 对齐(管线本来就把 w>=8 的细横线当线) ✓。
    # 实测证据: ① GT 音高袋准确率 94.6% -> 97.6% ✓(兄弟抱一下 94.3->98.6, 快乐父子俩 89.7->96.6);
    #          ② 抽 80 页语料, 杠块只 +4.7%(1059->1109) 且**没有任何一页变少** ✓
    #             (见 tools/test_dashminw.py); ③ 新增的杠都在原图上看图核实为真 ✓。
    # 要退回旧行为: JP_DASHMINW=12。
    _dashminw = int(os.environ.get("JP_DASHMINW", "8"))
    _dbgdash = os.environ.get("JP_DEBUGDASH", "") == "1"
    dashes = [c for c in hlines if c[4] > _dashminw and c[4] > 2 * c[5]]
    regions = []
    digit_spans = [(d[0], d[2]) for d in digits]      # 所有数字的 x 范围
    dig_top = min((d[1] for d in digits), default=0)
    dig_bot = max((d[3] for d in digits), default=0)
    for (seg_x0, seg_x1) in seg_bounds:
        # 延音杠: 独立块。两个必要条件:
        #   (1) x 中心不落在任何数字的 x 范围内(否则是数字正下方的时值下划线);
        #   (2) y 中心必须落在"数字的高度带"内 —— 与数字同高的才是真延音杠;
        #       落在数字下方的横线是"时值下划线带"(尤其共同下划线), 不能独立成块。
        for da in dashes:
            dc = (da[0] + da[2]) / 2.0
            _why = None
            if not (seg_x0 <= dc <= seg_x1):
                _why = f"中心不在本段 x[{int(seg_x0)}-{int(seg_x1)}]"
            elif any(s0 <= dc <= s1 for s0, s1 in digit_spans):
                _why = "中心落在数字 x 范围内(是时值下划线)"
            elif any(not (da[2] < s0 or da[0] > s1) for s0, s1 in digit_spans):
                _why = "x 范围与数字重叠(是时值下划线)"
            else:
                da_y = (da[1] + da[3]) / 2.0
                if digits and not (dig_top - 4 <= da_y <= dig_bot + 4):
                    _why = f"y中心{da_y:.0f} 不在数字带[{dig_top-4:.0f}-{dig_bot+4:.0f}]内"
            if _why:
                if _dbgdash:
                    print(f"[dash] 丢 x{da[0]}-{da[2]} w{da[4]} h{da[5]}: {_why}", flush=True)
                continue
            if _dbgdash:
                print(f"[dash] 收 x{da[0]}-{da[2]} w{da[4]} h{da[5]} y{da[1]}-{da[3]}", flush=True)
            # 上面 _why 链里已经查过"x 范围不能与任何数字重叠":
            # 时值下划线在数字"正下方", 其 x 必然覆盖数字(横跨相邻两个数字的下划线
            # 中心恰好落在两数字之间, 只用"中心点"判据会放行 -> 变成独立块 -> 模型吐 '0';
            # 实测《问候歌》86 块里 13 块就是这么来的)。真延音杠位于数字之间, 不重叠。
            regions.append((int(da[0] - 3), int(da[2] + 3), int(da[1] - 4), int(da[3] + 4)))
        # 数字: 正下方附属归属, x=数字左缘..右缘(不收纳右侧杠/数字)
        for d in digits:
            dc = (d[0] + d[2]) / 2.0
            if not (seg_x0 <= dc <= seg_x1):
                continue
            x0 = d[0]; x1 = d[2]; y0 = d[1]; y1 = d[3]
            dx1_orig = d[2]   # 数字原始右缘(附点收纳必须相对它判断, 否则x1连锁扩大->跨到隔壁音符)
            # 收纳 附点(数字右侧紧邻小点)。
            # 病根: 原来固定"距右缘 1-12px"。附点的间距是随字号缩放的 —— 大谱
            # (数字高 35px, 如《友谊天长地久》)附点在 16-25px 处, 全部超出 12px
            # -> 一个都没收进来 -> geo_detect 看不到 -> 整谱 dotted=0(附点全丢)。
            # 小谱(数字高 15)附点约 7-11px, 故用 max(12, 0.8*数字高) 兼顾两者。
            _gap = max(12, int(0.8 * d[5]))
            _dmax_w = max(10, int(0.4 * d[5]))
            _dmax_h = max(12, int(0.45 * d[5]))
            for c in comps:
                if c == d: continue
                if not (2 <= c[4] <= _dmax_w and 2 <= c[5] <= _dmax_h): continue
                # 必须是"点"(近方形), 不能是扁的下划线碎片: 否则会把数字下方的时值线
                # 碎片当附点吸进来 -> x1 过度扩张 -> 把隔壁数字一起框进同一块
                # (实测 spring 出现 45px 宽的块里含 小节线+5+4, 并吐假附点 '5.')。
                if not (0.4 <= c[4] / max(c[5], 1) <= 2.5): continue
                dcx = c[0] - dx1_orig
                if 1 <= dcx <= _gap and (d[1] - 8) <= c[1] and c[3] <= (d[3] + 8):
                    x1 = max(x1, min(c[2], dx1_orig + _gap + 6))
            # 只收纳"正下方"(x 在数字范围内, y>数字底)的下划线/低八度点; 绝不向右收纳杠/附点
            for c in comps:
                if c == d:
                    continue
                # 排除小节线
                if c[4] <= 5 and c[5] >= 35:
                    continue
                # 排除右侧杠
                if c[4] > 12 and c[5] <= 8 and c[4] > 2 * c[5]:
                    continue
                # 正下方附属(下划线/低八度点): 与数字x范围有重叠即收纳(下划线常比数字宽, 用包含条件会漏收->crop截断第二道杠)
                if c[0] <= x1 + 2 and c[2] >= x0 - 2 and c[1] >= y1 - 1:
                    y1 = max(y1, c[3])
            regions.append((int(max(seg_x0, x0)), int(min(seg_x1, x1)), int(y0), int(y1)))
    # 按 x 排序(杠和数字混排按 x)
    regions.sort(key=lambda r: r[0])
    return regions


def split_image(path):
    """行切割 + 单音符裁剪, 返回 [(row_idx, 裁剪图), ...] 按阅读顺序。"""
    im = Image.open(path).convert("L")
    arr = np.asarray(im)
    content = arr < TOL
    segs = fine_rows(content, ROW_GAP)
    crops = []
    for i, (s, e) in enumerate(segs):
        sub = content[s:e + 1]
        H = e - s + 1
        if count_bars(sub, H) < BAR_THR:
            continue
        regions = crop_note_regions(sub)
        row_gray = arr[s:e + 1]
        for (nx0, nx1, ny0, ny1) in regions:
            crop = row_gray[max(0, ny0 - PAD):ny1 + PAD, max(0, nx0 - PAD):nx1 + PAD]
            h, w = crop.shape
            big = Image.fromarray(crop).resize((w * SCALE, h * SCALE), Image.LANCZOS)
            canvas = np.full((big.height + 2 * PAD, big.width + 2 * PAD), 255, dtype=np.uint8)
            canvas[PAD:PAD + big.height, PAD:PAD + big.width] = np.asarray(big)
            crops.append((i, Image.fromarray(canvas)))
    return crops


def recognize(crops, out_dir):
    """用 v15 识别所有裁剪, 返回按顺序的 token 列表。"""
    os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
    import torch
    from peft import PeftModel
    from transformers import AutoModelForImageTextToText, AutoProcessor, BitsAndBytesConfig
    from PIL import Image as PILImage
    import outlines
    from outlines.inputs import Chat, Image as OImage
    # 2026-09-24 修: 模型目录原来写死成相对路径("models/…"), 只会按 **cwd** 找 ->
    #   * 新机器上 LoRA 适配器在工作区根 `../models/`(1.1GB, 从 06_模型_adapters.tar 解出来的),
    #     而 `jianpu2/models/` 根本不存在 -> 找不到;
    #   * 而且写的是 `models/jianpu-atom`, 实际装的是 `models/jianpu-lora-v15`(脚本头部注释也写 v15)。
    # 现在: 环境变量 > jianpu2/models > 工作区根 models/, 名字也对齐(可用 JIANPU_LORA 覆盖)。
    def _model_dir(name):
        cands = []
        if os.environ.get("JIANPU_MODELS"):
            cands.append(os.path.join(os.environ["JIANPU_MODELS"], name))
        cands += [os.path.join(ROOT, "models", name),
                  os.path.join(os.path.dirname(ROOT), "models", name)]
        for c in cands:
            if os.path.isdir(c):
                return c
        return cands[-1]                      # 都没有: 指个最有希望的, 让报错信息有用

    MODEL = os.environ.get("JIANPU_VLM") or _model_dir("Qwen2.5-VL-3B-Instruct")
    LORA = os.environ.get("JIANPU_LORA") or _model_dir("jianpu-lora-v15")
    PROMPT = "这个简谱音符是什么？只输出一个音符 token, 不要解释。"
    # 最窄白名单: 训练数据实际出现的合法音符 token(有限枚举), 不含8/9/sqqq等垃圾
    NOTE_REGEX = open(os.path.join(ROOT, "train-work", "whitelist.txt"), encoding="utf-8").read().strip()
    quant = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type="nf4",
                               bnb_4bit_compute_dtype=torch.bfloat16, bnb_4bit_use_double_quant=True)
    proc = AutoProcessor.from_pretrained(MODEL, trust_remote_code=True)
    proc.image_processor.size = {"shortest_edge": 384, "longest_edge": 1344}
    proc.image_processor.max_pixels = 384 * 1344 * 2
    hf_model = AutoModelForImageTextToText.from_pretrained(MODEL, quantization_config=quant, device_map="auto",
                                                           trust_remote_code=True, torch_dtype=torch.bfloat16,
                                                           attn_implementation="sdpa")
    hf_model = PeftModel.from_pretrained(hf_model, LORA)
    hf_model.eval()
    omodel = outlines.from_transformers(hf_model, proc)
    grammar = outlines.regex(NOTE_REGEX)
    os.makedirs(out_dir, exist_ok=True)
    results = []
    for idx, (ri, img) in enumerate(crops):
        fn = os.path.join(out_dir, f"r{ri:02d}_{idx:03d}.png")
        img.save(fn)
        pil = PILImage.open(fn).convert("RGB")
        pil.format = "PNG"
        prompt = Chat([{
            "role": "user",
            "content": [
                {"type": "image", "image": OImage(pil)},
                {"type": "text", "text": PROMPT},
            ],
        }])
        ans = omodel(prompt, output_type=grammar, max_new_tokens=16)
        results.append((ri, ans.strip()))
    return results


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    crops = split_image(a.image)
    print(f"切出 {len(crops)} 个音符")
    results = recognize(crops, os.path.join(ROOT, "train-work", "transcribe_tmp"))
    seq = []
    for ri, ans in results:
        t = ans.strip()
        if t and t not in ("!", "?"):
            seq.append(t)
    out = " ".join(seq)
    print(f"\n转写序列 ({len(seq)} 音):")
    print(out)
    if a.out:
        with open(a.out, "w", encoding="utf-8") as f:
            f.write(out + "\n")
        print(f"已保存 -> {a.out}")


if __name__ == "__main__":
    main()
