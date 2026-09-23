# -*- coding: utf-8 -*-
"""块分类: 数字/下划线/杠/空, 按连通域特征。
- 数字: 竖形(高>宽, 高>=18)
- 下划线: 横线(宽>高*1.5), 紧贴数字底部(时值线)
- 杠: 横线(宽>高*1.5), 独立短横(延音杠)
- 空: 暗px极少
返回: "digit" / "underline" / "dash" / "empty"
"""
import numpy as np
from geo_detect import _components


def classify_block(crop):
    m = crop < 170
    npx = int(m.sum())
    H, W = m.shape
    if npx < 8:
        return "empty"
    comps = _components(m)
    if not comps:
        return "empty"
    # 数字竖形(高>=16 且 高>宽)
    has_digit = any(c[5] >= 16 and c[5] > c[4] for c in comps)
    if has_digit:
        return "digit"
    # 休止0: 主连通域 矮(高<14)且小(椭圆), 比数字矮窄
    main = max(comps, key=lambda c: c[5])
    if main[5] < 14 and main[4] <= 10 and main[5] > main[4]:
        return "rest"
    # 无数字竖形: 单一横线连通域 = 真杠; 否则(多横线/不规则) = 下划线/空(跳过)
    if len(comps) == 1 and comps[0][4] > 2 * comps[0][5] and comps[0][4] > 15:
        return "dash"
    return "empty"
