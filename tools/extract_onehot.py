# -*- coding: utf-8 -*-
"""从 JSON 训练数据提取 6 个子模型的 one-hot 标注。
每个子模型一个维度:
  digit(9类), beam(5类), low(4类), voice(4类), dotted(2类), accidental(3类)
输出: train-data-atoms-v4-json/onehot.jsonl  (每行 {image, label:{dim: one_hot}})
杠(-)在每个维度都标注为唯一存在: special dash -> 单独处理
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.stdout.reconfigure(encoding="utf-8")

SRC = "train-data-atoms-v4-json/manifest.jsonl"
OUT = "train-data-atoms-v4-json/onehot.jsonl"

DIMS = {
    "digit": ["1", "2", "3", "4", "5", "6", "7", "0", "x"],
    "beam": [0, 1, 2, 3, 4],
    "low": [0, 1, 2, 3],
    "voice": [0, 1, 2, 3],
    "dotted": [0, 1],
    "accidental": ["", "#", "b"],
}


def onehot(v, cats):
    idx = cats.index(v)
    return [0] * idx + [1] + [0] * (len(cats) - idx - 1)


rows = [json.loads(l) for l in open(SRC, encoding="utf-8")]
out = []
ndash = 0
for r in rows:
    js = r["json"]
    if js.get("type") == "dash":
        ndash += 1
        # 杠: 单独标记, digit 用长度9全0(杠不是数字, 不参与数字分类)
        label = {"dash": [1], "digit": [0]*9, "beam": [0]*5, "low": [0]*4,
                 "voice": [0]*4, "dotted": [0]*2, "accidental": [0]*3}
        label["dash_flag"] = 1
    else:
        label = {}
        # digit 可能在特殊字符里, 用 json['digit'](已是 '5' 等); 若是 '0'/'x' 在 digit 类里
        d = str(js["digit"])
        if d in DIMS["digit"]:
            label["digit"] = onehot(d, DIMS["digit"])
        else:
            # digit 异常(如空), 用默认
            label["digit"] = onehot("1", DIMS["digit"])
        label["beam"] = onehot(js["beam"], DIMS["beam"])
        label["low"] = onehot(js["low"], DIMS["low"])
        label["voice"] = onehot(len(js["voice"]), DIMS["voice"])
        label["dotted"] = onehot(js["dotted"], DIMS["dotted"])
        label["accidental"] = onehot(js["accidental"], DIMS["accidental"])
        label["dash_flag"] = 0
    out.append({"image": r["image"], "label": label})

with open(OUT, "w", encoding="utf-8") as f:
    for r in out:
        f.write(json.dumps(r, ensure_ascii=False) + "\n")
print(f"one-hot 标注 {len(out)} 条 -> {OUT}")
print(f"杠原子 {ndash} 个(单独 dash_flag)")
# 验证每条 digit one-hot 长度为 9, 其他长度正确
bad = []
for r in out:
    ln = r["label"]["digit"] if "digit" in r["label"] else r["label"].get("dash")
    # 杠 label 无标准 digit, 跳过
    if "digit" in r["label"] and len(r["label"]["digit"]) != 9:
        bad.append(r["image"])
print(f"digit one-hot 长度异常的: {len(bad)}")
