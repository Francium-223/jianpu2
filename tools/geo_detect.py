# -*- coding: utf-8 -*-
"""几何检测八度点/下划线/附点: 按连通域长宽比分类。
- 下划线(时值线): 宽>>高(细横线), 在数字下方
- 八度点: 各向均匀(长宽比≈1), 上=高八度 下=低八度
- 附点: 数字右侧均匀点
输出: {beam, low, voice, dotted}
"""
import numpy as np
from collections import deque


def _components(mask):
    H, W = mask.shape
    lbl = np.zeros((H, W), dtype=np.int32)
    comps = []
    for y in range(H):
        for x in range(W):
            if mask[y, x] and lbl[y, x] == 0:
                q = deque([(y, x)]); lbl[y, x] = 1
                minx = maxx = x; miny = maxy = y
                while q:
                    cy, cx = q.popleft()
                    minx = min(minx, cx); maxx = max(maxx, cx)
                    miny = min(miny, cy); maxy = max(maxy, cy)
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < H and 0 <= nx < W and mask[ny, nx] and lbl[ny, nx] == 0:
                                lbl[ny, nx] = 1; q.append((ny, nx))
                comps.append((minx, miny, maxx, maxy, maxx - minx + 1, maxy - miny + 1))
    return comps


def geo_detect(crop):
    """crop: 灰度数组(音符块)。返回 {beam, low, voice, dotted}。"""
    m = crop < 170
    comps = _components(m)
    ys, xs = np.where(m)
    if len(ys) == 0:
        return {"beam": 0, "low": 0, "voice": 0, "dotted": 0}
    # 数字主体 = 高>宽 且 高度>=20 的竖形(数字); 排除点/线/升降号小符号。
    # 必须排除"小节线"(极细高的竖线, 如 w=3 h=43): 它高度最大, 会抢走下面的 main,
    # 于是数字正下方的低八度点落在小节线的 y 范围内、又在它右侧 -> 被误判成附点
    # (实测 spring 因此吐了 3 个假的 '5.')。真正数字的 高/宽 约 1.5-3, 小节线 >= 5。
    digits = [c for c in comps if c[5] >= 18 and c[5] > c[4] and c[5] < 3.5 * c[4]]
    if not digits:
        digits = comps
    main = max(digits, key=lambda c: c[5]) if digits else max(comps, key=lambda c: c[5])
    dx0, dy0, dx1, dy1 = main[0], main[1], main[2], main[3]
    dcenter = (dx0 + dx1) / 2.0
    beam = low = voice = dotted = 0
    # 下划线(时值线): 扫描图里一道杠常断成多个碎片 -> 收集"细片段"后按 y 行聚类, 每个 y 簇算一条杠
    line_frags = []
    for c in comps:
        if c is main: continue
        cx0, cy0, cx1, cy1, w, h = c
        if h <= 3 and w >= 2 and w / max(h, 1) >= 2 and cy0 > dy1 - 2 and cx0 < dx1 and cx1 > dx0:
            line_frags.append(c)
    ys = sorted(line_frags, key=lambda c: (c[1] + c[3]) / 2)
    groups = []          # [(y_mid, [frags...])]
    for c in ys:
        ym = (c[1] + c[3]) / 2
        if groups and ym - groups[-1][0] <= 2:
            groups[-1][1].append(c); groups[-1][0] = (groups[-1][0] + ym) / 2
        else:
            groups.append([ym, [c]])
    # 只有"该 y 行所有碎片合计宽度 >= 10"才算一条真下划线(排除孤立小点)
    beam = sum(1 for ym, cs in groups if sum(x[4] for x in cs) >= 4)
    # 补充判据: 数字与下划线"粘连"成一个分量时(排版紧凑的谱很常见, 如 qinyipu 的谱),
    # 上面基于"独立细碎片"的检测会完全漏掉 -> 直接扫主分量逐行的横向跨度:
    #   数字主体宽度 ≈ 主分量上部的跨度; 下部若出现"明显更宽的连续行组", 每组即一条下划线。
    try:
        spans = []
        for y in range(dy0, dy1 + 1):
            xr = np.where(m[y, dx0:dx1 + 1])[0]
            spans.append(int(xr.max() - xr.min() + 1) if len(xr) else 0)
        if spans:
            up = spans[:max(1, int(len(spans) * 0.55))]
            base = max(max(up), 1)
            wide = [y for k, y in enumerate(range(dy0, dy1 + 1)) if spans[k] >= 1.6 * base]
            add, prev = 0, None
            for y in wide:
                if prev is None or y - prev > 2:
                    add += 1
                prev = y
            if add:
                beam = max(beam, min(add, 4))
    except Exception:
        pass
    for c in comps:
        if c is main:
            continue
        cx0, cy0, cx1, cy1, w, h = c
        aspect = w / max(h, 1)
        cy = (cy0 + cy1) / 2; cxc = (cx0 + cx1) / 2
        is_line = (aspect > 2.5 and w >= 10)                                  # (保留供参考)
        is_dot = (0.4 <= aspect <= 2.5 and 3 <= w <= 14 and 3 <= h <= 14)    # 均匀圆点
        near_x = abs(cxc - dcenter) <= max(dx1 - dx0, 8)
        if is_dot:
            if cy < dy0 - 1:                                                 # 数字顶上方点 = 高八度
                voice += 1
            elif (dy1 - 1 < cy) and near_x:                                  # 数字正下方x内点 = 低八度
                # 低八度点须"紧贴数字底"——距数字底需小于 数字高度的~0.6(下划线下方一小段).
                # 排除在下划线更下方的远处小点(常是歌词"里/这"等笔画或杂纹被误判为低八度点 -> 假 q,,x).
                if cy - dy1 <= 0.6 * max(dy1 - dy0, 1) + 3:
                    low += 1
            elif cx0 > dx1 - 1 and (dy0 - 2) <= cy <= (dy1 + 2):             # 数字右侧且与数字同高 = 附点
                dotted += 1                                                  # (加y约束: 排除数字右下方的低八点被误判为附点)
    # voice 上限 1: 简谱里"两个及以上高八度点"极罕见, 常是误判(用户实测 '' 基本可忽略)
    return {"beam": min(beam, 4), "low": min(low, 3), "voice": min(voice, 1), "dotted": min(dotted, 1)}
