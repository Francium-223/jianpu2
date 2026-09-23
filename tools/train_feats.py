# -*- coding: utf-8 -*-
"""用预提取的 Qwen 特征训练 6 个分类头(快, 不用每图跑Qwen vision)。
输入 features.pkl [{feat(2048), label{6维one-hot}}] → 6 线性头 → CE loss。
用法: py -3.13 tools/train_feats.py --feats train-data-atoms-v4-json/features.pkl --out models/qwen-mt-v1
"""
import argparse, json, os, sys, pickle
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIM_N = {"digit": 9, "beam": 5, "low": 4, "voice": 4, "dotted": 2, "accidental": 3}


class FeatDS(Dataset):
    def __init__(self, feats):
        self.feats = feats
    def __len__(self):
        return len(self.feats)
    def __getitem__(self, i):
        r = self.feats[i]
        f = torch.tensor(r["feat"], dtype=torch.float32)
        lab = r["label"]
        tens = {k: torch.tensor(v, dtype=torch.float32) for k, v in lab.items() if k in DIM_N}
        if "digit" not in tens:
            tens["digit"] = torch.zeros(DIM_N["digit"])
        return f, tens


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--feats", default="train-data-atoms-v4-json/features.pkl")
    ap.add_argument("--out", default="models/qwen-mt-v1")
    ap.add_argument("--epochs", type=int, default=30)
    ap.add_argument("--lr", type=float, default=1e-3)
    a = ap.parse_args()
    feats = pickle.load(open(a.feats, "rb"))
    print(f"特征 {len(feats)}")
    ds = FeatDS(feats)
    dl = DataLoader(ds, batch_size=64, shuffle=True, num_workers=0)
    model = nn.ModuleDict({k: nn.Linear(2048, n) for k, n in DIM_N.items()})
    gpu = torch.cuda.is_available()
    if gpu:
        model = model.cuda()
    opt = torch.optim.AdamW(model.parameters(), lr=a.lr)
    lossf = nn.CrossEntropyLoss()
    for ep in range(a.epochs):
        model.train(); tot = 0; nb = 0
        for f, lab in dl:
            if gpu:
                f = f.cuda(); lab = {k: v.cuda() for k, v in lab.items()}
            out = {k: model[k](f) for k in DIM_N}
            loss = None
            for k in DIM_N:
                l = lossf(out[k], lab[k].argmax(dim=1))
                loss = l if loss is None else loss + l
            opt.zero_grad(); loss.backward(); opt.step()
            tot += loss.item(); nb += 1
        print(f"epoch {ep+1}: loss {tot/nb:.3f}")
    os.makedirs(a.out, exist_ok=True)
    flat = {}
    for k, head in model.items():
        for kk, vv in head.state_dict().items():
            flat[f"{k}.{kk}"] = vv
    torch.save(flat, os.path.join(a.out, "heads.pt"))
    json.dump(DIM_N, open(os.path.join(a.out, "dims.json"), "w"))
    print(f"头部已存 -> {a.out}")


if __name__ == "__main__":
    main()
