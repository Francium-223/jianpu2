# -*- coding: utf-8 -*-
"""真实音符微调 Qwen 特征头: 提取真实音符图的 Qwen 特征 + 微调 qwen-mt-v1 头。
用澎湖湾真实音符(finetune_gt 189) + 合成原子(保留)共同微调, 提升真实域泛化。
用法: py -3.13 tools/finetune_qwen_feats.py
"""
import json, os, sys, pickle
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
import torch, torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from PIL import Image
from note_prep import _crop_content
from token_json import token_to_json
from qwen_loader import load_qwen_visual, get_processor
import re

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIM_N = {"digit": 9, "beam": 5, "low": 4, "voice": 4, "dotted": 2, "accidental": 3}
DIGITS = ["1", "2", "3", "4", "5", "6", "7", "0", "x"]
BEAMS = [0, 1, 2, 3, 4]; LOWS = [0, 1, 2, 3]; VOICES = [0, 1, 2, 3]; DOTS = [0, 1]; ACCS = ["", "#", "b"]
NOTE_RE = re.compile(r"^[,']*[qsdh]*[,']*[1-7x][.,'qsdhc\-]*$")


def oh(v, cats):
    if v not in cats:
        return [0] * len(cats)
    i = cats.index(v)
    return [0] * i + [1] + [0] * (len(cats) - i - 1)


def main():
    # 真实音符
    real = []
    for ln in open("train-work/finetune_gt.jsonl", encoding="utf-8"):
        r = json.loads(ln)
        tok = r["text"]
        if tok == "-" or not NOTE_RE.match(tok):
            continue
        js = token_to_json(tok)
        d = js["digit"]
        if d not in DIGITS:
            continue
        lab = {"digit": oh(d, DIGITS), "beam": oh(js["beam"], BEAMS), "low": oh(js["low"], LOWS),
               "voice": oh(len(js["voice"]), VOICES), "dotted": oh(js["dotted"], DOTS),
               "accidental": oh(js["accidental"], ACCS)}
        real.append({"image": r["image"], "label": lab})
    # 混合合成原子
    synth = [json.loads(l) for l in open("train-data-atoms-v4-json/manifest.jsonl", encoding="utf-8")]
    synth_items = []
    import random; random.seed(1)
    for r in random.sample(synth, 500):
        js = r["json"]
        if js.get("type") == "dash":
            continue
        lab = {"digit": oh(js["digit"], DIGITS) if js["digit"] in DIGITS else [0]*9,
               "beam": oh(js["beam"], BEAMS), "low": oh(js["low"], LOWS),
               "voice": oh(len(js["voice"]), VOICES), "dotted": oh(js["dotted"], DOTS),
               "accidental": oh(js["accidental"], ACCS)}
        synth_items.append({"image": r["image"], "label": lab})
    alldata = real + synth_items
    print(f"微调数据: 真实 {len(real)} + 合成 {len(synth_items)} = {len(alldata)}")

    # 提取 Qwen 特征
    proc = get_processor()
    visual = load_qwen_visual()
    device = "cuda" if torch.cuda.is_available() else "cpu"
    feats_list = []
    for i, r in enumerate(alldata):
        img = _crop_content(Image.open(r["image"]).convert("RGB"))
        enc = proc(img, return_tensors="pt")
        pixel, grid = enc["pixel_values"], enc["image_grid_thw"]
        if device != "cpu":
            pixel = pixel.to(device); grid = grid.to(device)
        with torch.no_grad():
            h = visual(pixel, grid).mean(dim=0).float().cpu().numpy()
        feats_list.append({"feat": h.tolist(), "label": r["label"]})
        if (i + 1) % 100 == 0:
            print(f"  特征 {i+1}/{len(alldata)}")
    pickle.dump(feats_list, open("train-data-atoms-v4-json/real_features.pkl", "wb"))
    print(f"特征已存 real_features.pkl ({len(feats_list)})")

    # 微调头部(从 qwen-mt-v1 加载)
    heads = nn.ModuleDict({k: nn.Linear(2048, n) for k, n in DIM_N.items()})
    heads.load_state_dict(torch.load("models/qwen-mt-v1/heads.pt", map_location="cpu"))
    heads.train()
    if device != "cpu":
        heads = heads.to(device)
    ds = [(torch.tensor(f["feat"], dtype=torch.float32), {k: torch.tensor(v, dtype=torch.float32) for k, v in f["label"].items() if k in DIM_N}) for f in feats_list]
    dl = DataLoader(ds, batch_size=32, shuffle=True, num_workers=0)
    opt = torch.optim.AdamW(heads.parameters(), lr=3e-4)
    lossf = nn.CrossEntropyLoss()
    for ep in range(20):
        heads.train(); tot = 0; nb = 0
        for f, lab in dl:
            if device != "cpu":
                f = f.to(device); lab = {k: v.to(device) for k, v in lab.items()}
            out = {k: heads[k](f) for k in DIM_N}
            loss = None
            for k in DIM_N:
                l = lossf(out[k], lab[k].argmax(dim=1))
                loss = l if loss is None else loss + l
            opt.zero_grad(); loss.backward(); opt.step(); tot += loss.item(); nb += 1
        print(f"epoch {ep+1}: loss {tot/nb:.3f}")
    torch.save({f"{k}.{kk}": vv for k, head in heads.items() for kk, vv in head.state_dict().items()},
               "models/qwen-mt-v1/heads.pt")
    print("头部微调已存 models/qwen-mt-v1/heads.pt")


if __name__ == "__main__":
    main()
