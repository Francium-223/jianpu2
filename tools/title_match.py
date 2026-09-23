# -*- coding: utf-8 -*-
"""曲名匹配的**唯一实现**(供 cover_mandopop / cover_forecast 共用)。

为什么需要它(2026-09-22 用户实测题暴露):
  《当》(动力火车, 还珠格格主题曲) 在清单里被算成"宽松命中" —— 因为库里有个 **《中原担当》**
  被简单的 `子串包含` 撞上了。同类假阳性还有: 青花→青花瓷 / 夜曲→小夜曲 / 狼→恶狼传说 /
  大海→20飞向大海的夜莺 / 追→51追寻 / 问→45天问(以及 45/51/38 这类前缀编号)。
  这类假阳性会把"含宽松覆盖率"抬高好几个百分点 —— 指标不能这么算。

规则:
  canon(x) = 归一化后反复剥掉**类型后缀**(简谱/歌曲类/演唱/钢琴简谱…) 与**编号前缀**(如 `45天问`).
  严格命中  = canon(语料名) == canon(目标名)
  宽松命中  = 一方是另一方的子串(仅用于人工复核, **不计入**可用覆盖)
"""
import re

ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！?？:：;；·・\-—_…~～'\"“”‘’/\\|&]+")
BRACKET = re.compile(r"[（(\s　【\[《/].*$")

# 站点/上传者加的类型后缀(剥掉后应还原成歌名)
SUFFIX = ["简谱", "歌曲类", "歌谱", "钢琴简谱", "钢琴谱", "钢琴", "正谱", "双谱", "总谱", "弹唱谱",
          "指弹谱", "尤克里里谱", "五线谱", "歌词", "伴奏谱", "原版编配", "指法", "合唱谱",
          "独奏", "弹唱", "扫描版", "纯享版", "原唱", "演唱", "独唱", "吉他谱", "吉他"]
# 站点的编号前缀(如 `45天问` / `7唱不够亲爱的祖国`)
PREFIX_NUM = re.compile(r"^[0-9]{1,3}(?=[\u4e00-\u9fff])")


def norm(s):
    return DROP.sub("", s.translate(ZW)).casefold()


def canon(s):
    """归一化 + 反复剥类型后缀 + 剥编号前缀。"""
    t = norm(s)
    changed = True
    while changed:
        changed = False
        for suf in SUFFIX:
            n = norm(suf)
            if t.endswith(n) and len(t) > len(n):
                t = t[:-len(n)]
                changed = True
                break
    t2 = PREFIX_NUM.sub("", t)
    return t2 or t


def match(corpus_key, target):
    """返回 '严格' / '宽松' / '缺'。只有 '严格' 才算这歌真的在库里。"""
    c, q = canon(corpus_key), canon(target)
    if not c or not q:
        return "缺"
    if c == q:
        return "严格"
    if q in c or c in q:
        return "宽松"
    return "缺"


def head_of(name):
    """从 `浮夸__jianpucn-133666` 取歌名部分。"""
    base = name.split("__")[0]
    return BRACKET.sub("", base) or base
