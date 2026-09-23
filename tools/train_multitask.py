# -*- coding: utf-8 -*-
"""轻量CNN 多头分类: ResNet18 共享特征 + 6 个分类头。
每个音符图 → 6 个 one-hot(digit/beam/low/voice/dotted/accidental)。
训练: 图像(统一 resize) → ResNet18 backbone → 6 线性头 → CE loss 求和。
用法: py -3.13 tools/train_multitask.py --data train-data-atoms-v4-json/onehot.jsonl --out models/multitask-v1 --epochs 15
"""
import argparse, json, os, sys
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms, models
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

DIM_N = {"digit": 9, "beam": 5, "low": 4, "voice": 4, "dotted": 2, "accidental": 3}


class NoteDataset(Dataset):
    def __init__(self, data, tf):
        self.data = data
        self.tf = tf

    def __len__(self):
        return len(self.data)

    def __getitem__(self, i):
        r = self.data[i]
        img = Image.open(r["image"]).convert("RGB")
        if self.tf:
            img = self.tf(img)
        else:
            from note_prep import prep
            img = prep(img)
        lab = r["label"]
        tens = {k: torch.tensor(v, dtype=torch.float32) for k, v in lab.items() if k in DIM_N}
        if "digit" not in tens:
            tens["digit"] = torch.zeros(DIM_N["digit"])
        return img, tens


class MultiHeadCNN(nn.Module):
    def __init__(self, out_n):
        super().__init__()
        self.backbone = models.resnet18(weights=None)
        self.backbone.fc = nn.Identity()
        feat = 512
        self.heads = nn.ModuleDict({k: nn.Linear(feat, n) for k, n in out_n.items()})

    def forward(self, x):
        f = self.backbone(x)
        return {k: self.heads[k](f) for k in self.heads}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="train-data-atoms-v4-json/onehot.jsonl")
    ap.add_argument("--out", default="models/multitask-v1")
    ap.add_argument("--epochs", type=int, default=15)
    ap.add_argument("--batch", type=int, default=16)
    ap.add_argument("--lr", type=float, default=3e-4)
    ap.add_argument("--size", type=int, default=112)
    a = ap.parse_args()

    data = [json.loads(l) for l in open(a.data, encoding="utf-8")]
    print(f"样本 {len(data)}")
    tf = None  # 用 note_prep.prep(裁白边统一形态)
    ds = NoteDataset(data, tf)
    dl = DataLoader(ds, batch_size=a.batch, shuffle=True, num_workers=0)
    model = MultiHeadCNN(DIM_N)
    gpu = torch.cuda.is_available()
    if gpu:
        model = model.cuda()
    opt = torch.optim.AdamW(model.parameters(), lr=a.lr)
    lossf = nn.CrossEntropyLoss()
    for ep in range(a.epochs):
        model.train(); tot = 0.0; nb = 0
        for img, lab in dl:
            if gpu:
                img = img.cuda()
                lab = {k: v.cuda() for k, v in lab.items()}
            out = model(img)
            loss = None
            for k in DIM_N:
                l = lossf(out[k], lab[k].argmax(dim=1))
                loss = l if loss is None else loss + l
            opt.zero_grad(); loss.backward(); opt.step()
            tot += loss.item(); nb += 1
        print(f"epoch {ep+1}: loss {tot/nb:.3f}")
    os.makedirs(a.out, exist_ok=True)
    torch.save(model.state_dict(), os.path.join(a.out, "model.pt"))
    with open(os.path.join(a.out, "dims.json"), "w") as f:
        json.dump(DIM_N, f)
    print(f"已保存 -> {a.out}")


if __name__ == "__main__":
    main()
