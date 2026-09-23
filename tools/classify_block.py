# -*- coding: utf-8 -*-
"""块分类: 数字/下划线/杠/空, 按连通域特征。
- 数字: 竖形(高>宽, 高>=18)
- 下划线: 横线(宽>高*1.5), 紧贴数字底部(时值线)
- 杠: 横线(宽>高*1.5), 独立短横(延音杠)
- 空: 暗px极少
返回: "digit" / "underline" / "dash" / "empty"
"""
import os

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
    # 数字竖形(高>=12 且 高>宽)。
    # 阈值原为 16: 实测《问候歌》的数字高只有 15 -> 差 1px 全被判成 "empty" 丢弃
    # (17 个块只出 2 个 token)。降到 12; 汉字等非音符已由行带过滤(瘦高块占比)挡住。
    has_digit = any(c[5] >= 12 and c[5] > c[4] for c in comps)
    if has_digit:
        return "digit"
    # 休止0: 主连通域 矮(高<14)且小(椭圆), 比数字矮窄
    main = max(comps, key=lambda c: c[5])
    if main[5] < 12 and main[4] <= 10 and main[5] > main[4]:
        return "rest"
    # 真延音杠 '-' : 块内存在"任一个"平直宽横线连通域 且 位于块的上部.
    # (不再只用"面积最大"的连通域——真'-'杠常是短平直横, 不一定是面积最大, 用面积最大会漏判.)
    # 判据: 宽横线 w>=JP_DASHMINW, aspect>2(明显扁), 且线中心在块上部(cy<0.5*H) => 在音符之上 = 真延音杠.
    # 音符下的时值下划线/连音弧 在数字下方(cy>0.6*H) => 不高叉. 这样短/变形真'-'杠更容易被判定.
    #
    # 宽度下限原为**固定 12px** —— 与 transcribe.crop_note_regions 里同一类**字号相关**的 bug ✗:
    # 实测 GT 图(1000px 宽)的真延音杠只有 w=11, 卡在 12 之下 -> 判 empty -> 整根杠丢掉 ✗
    # (兄弟抱一下 丢 9 根、快乐父子俩 丢 8 根)。故与那边共用同一个旋钮 JP_DASHMINW, 默认 8 ✓
    # (证据见 transcribe.py 里那段注释)。要退回旧行为: JP_DASHMINW=12。
    _dashminw = int(os.environ.get("JP_DASHMINW", "8"))
    for c in comps:
        if c[4] >= _dashminw and c[4] > 2 * c[5]:
            cy = (c[1] + c[3]) / 2.0
            if cy < H * 0.5:  # 平直宽横线在块上部 = 真延音杠(在数字之上), 而非下方时值线
                return "dash"
    return "empty"
