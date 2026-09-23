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
    # 数字主体 = 高>宽 且 高度>=20 的竖形(数字); 排除点/线/升降号小符号
    digits = [c for c in comps if c[5] >= 18 and c[5] > c[4]]
    if not digits:
        digits = comps
    main = max(digits, key=lambda c: c[5]) if digits else max(comps, key=lambda c: c[5])
    dx0, dy0, dx1, dy1 = main[0], main[1], main[2], main[3]
    dcenter = (dx0 + dx1) / 2.0
    beam = low = voice = dotted = 0
    for c in comps:
        if c is main:
            continue
        cx0, cy0, cx1, cy1, w, h = c
        aspect = w / max(h, 1)
        cy = (cy0 + cy1) / 2; cxc = (cx0 + cx1) / 2
        is_line = (aspect > 2.5 and w > 12)                                  # 下划线: 宽横线
        is_dot = (0.4 <= aspect <= 2.5 and 3 <= w <= 14 and 3 <= h <= 14)    # 均匀圆点
        near_x = abs(cxc - dcenter) <= max(dx1 - dx0, 8)
        if is_line and cy > dy1 - 2:                                         # 数字下方横线 = 时值线
            beam += 1
        elif is_dot:
            if cy < dy0 - 1:                                                 # 数字顶上方点 = 高八度
                voice += 1
            elif (dy1 - 1 < cy) and near_x:                                  # 数字正下方x内点 = 低八度
                # 低八度点须"紧贴数字底"——距数字底需小于 数字高度的~0.6(下划线下方一小段).
                # 排除在下划线更下方的远处小点(常是歌词"里/这"等笔画或杂纹被误判为低八度点 -> 假 q,,x).
                if cy - dy1 <= 0.6 * max(dy1 - dy0, 1) + 3:
                    low += 1
            elif cx0 > dx1 - 1:                                              # 数字右侧点 = 附点
                dotted += 1
    return {"beam": min(beam, 4), "low": min(low, 3), "voice": min(voice, 3), "dotted": min(dotted, 1)}
