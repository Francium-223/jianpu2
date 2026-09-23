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
    for x in range(W):
        col = mask[:, x]
        if not col.any():
            continue
        d = np.diff(np.concatenate(([False], col, [False])).view(np.int8))
        for s0, e0 in zip(np.where(d == 1)[0], np.where(d == -1)[0]):
            if e0 - s0 >= min_len:
                out[s0:e0, x] = False
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
    has_text = any(14 <= c[5] <= 45 and c[5] > c[4] and c[4] >= 6
                   for c in components(lower))
    if has_text:
        return [a, b]
    return [(s, e)]


def strip_hlines(sub, max_h=6, min_w=8):
    """抹掉"细横线"连通域(时值下划线 / 延音杠 / 部分连音线)。

    病根: 下划线横跨相邻多个数字, 把它们连成"一个大连通域"(高~25 宽~60),
    于是 crop_note_regions 的"数字 = 高>宽"判据全部不成立 -> 整组音符被丢弃。
    实测《问候歌》(7 行谱)只切出 22 个 token, 图上绝大多数音符没被切出来。

    返回 (抹线后的 mask, 被抹掉的横线 bbox 列表)。
    数字的横笔画与数字主体相连(整体 h>=14), 不会被误判为横线。
    """
    H, W = sub.shape
    lbl = np.zeros((H, W), dtype=np.int32)
    out = sub.copy()
    lines = []
    cid = 0
    for y in range(H):
        for x in range(W):
            if sub[y, x] and lbl[y, x] == 0:
                cid += 1
                q = deque([(y, x)]); lbl[y, x] = cid
                minx = maxx = x; miny = maxy = y
                pix = []
                while q:
                    cy, cx = q.popleft(); pix.append((cy, cx))
                    if cx < minx: minx = cx
                    if cx > maxx: maxx = cx
                    if cy < miny: miny = cy
                    if cy > maxy: maxy = cy
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < H and 0 <= nx < W and sub[ny, nx] and lbl[ny, nx] == 0:
                                lbl[ny, nx] = cid; q.append((ny, nx))
                w = maxx - minx + 1; h = maxy - miny + 1
                if h <= max_h and w >= min_w and w >= 2 * h:
                    for (py, px) in pix:
                        out[py, px] = False
                    lines.append((minx, miny, maxx, maxy, w, h))
    return out, lines


def components(sub):
    lbl = np.zeros_like(sub, dtype=np.int32)
    comps = []
    H, W = sub.shape
    for y in range(H):
        for x in range(W):
            if sub[y, x] and lbl[y, x] == 0:
                q = deque([(y, x)]); lbl[y, x] = 1
                minx = maxx = x; miny = maxy = y; cnt = 0
                while q:
                    cy, cx = q.popleft(); cnt += 1
                    minx = min(minx, cx); maxx = max(maxx, cx)
                    miny = min(miny, cy); maxy = max(maxy, cy)
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < H and 0 <= nx < W and sub[ny, nx] and lbl[ny, nx] == 0:
                                lbl[ny, nx] = 1; q.append((ny, nx))
                comps.append((minx, miny, maxx, maxy, maxx - minx + 1, maxy - miny + 1, cnt))
    return comps


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


def crop_note_regions(sub):
    comps = components(sub)
    if not comps:
        return []
    bars = [c for c in comps if c[4] <= 5 and c[5] >= 35]
    bar_x = sorted([(c[0] + c[2]) / 2.0 for c in bars])
    bar_x = [b for b in bar_x if b < sub.shape[1] - 2]
    seg_bounds = [(0, bar_x[0])] if bar_x else []
    for i in range(len(bar_x)):
        seg_bounds.append((bar_x[i], bar_x[i + 1] if i + 1 < len(bar_x) else sub.shape[1] - 1))
    digits = [c for c in comps if 8 <= c[4] <= 22 and 14 <= c[5] <= 34 and c[5] >= c[4]]
    digits.sort(key=lambda c: c[0])
    if not digits:
        return []
def crop_note_regions(sub):
    """逐符号切块: 每个连通域(数字/杠)一个块, 严格不重叠。
    - 数字(竖形 高>宽 高度14-40): 块=数字+正下方附属(下划线/低八度点/附点), x=数字左缘..右缘(不收纳右侧)。
    - 杠(横线 宽>高*2 宽>15): 块=杠本身(独立原子)。
    - 小节线(细高)忽略。按x排序输出。"""
    H, W = sub.shape
    # 关键: 先抹掉细横线(时值下划线/延音杠), 否则下划线会把相邻多个数字连成
    # "一个大连通域"(宽>>高), 使下面"数字 = 高>宽"的判据全体失效 ->
    # 整组音符被丢弃(实测《问候歌》7 行谱只切出 22 个 token)。
    stripped, hlines = strip_hlines(sub)
    comps = components(stripped)
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
    MODEL = "models/Qwen2.5-VL-3B-Instruct"
    LORA = "models/jianpu-atom"
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
