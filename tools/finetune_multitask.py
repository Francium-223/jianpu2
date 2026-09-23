# -*- coding: utf-8 -*-
"""用真实音符数据微调 multitask-v1 的 CNN, 让模型泛化到真实域。
加载 multitask-v1 权重, 用 real_onehot.jsonl 微调(少量轮, lr小)。
用法: py -3.13 tools/finetune_multitask.py --base models/multitask-v1 --out models/multitask-v1r --epochs 10
"""
import argparse, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
import torch
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms
from PIL import Image
from train_multitask import MultiHeadCNN, DIM_N

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class NoteDataset(Dataset):
    def __init__(self, data, tf):
        self.data = data; self.tf = tf
    def __len__(self):
        return len(self.data)
    def __getitem__(self, i):
        r = self.data[i]
        img = Image.open(r["image"]).convert("RGB")
        if self.tf:
            img = self.tf(img)
        lab = r["label"]
        tens = {k: torch.tensor(v, dtype=torch.float32) for k, v in lab.items() if k in DIM_N}
        if "digit" not in tens:
            tens["digit"] = torch.zeros(DIM_N["digit"])
        return img, tens


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="models/multitask-v1")
    ap.add_argument("--out", default="models/multitask-v1r")
    ap.add_argument("--data", default="train-data-atoms-v4-json/real_onehot.jsonl")
    ap.add_argument("--epochs", type=int, default=10)
    ap.add_argument("--batch", type=int, default=8)
    ap.add_argument("--lr", type=float, default=3e-5)
    ap.add_argument("--size", type=int, default=112)
    a = ap.parse_args()

    data = [json.loads(l) for l in open(a.data, encoding="utf-8")]
    print(f"真实微调样本 {len(data)}")
    # 也混合合成原子(避免遗忘)
    synth = [json.loads(l) for l in open("train-data-atoms-v4-json/onehot.jsonl", encoding="utf-8")][:400]
    data = data + synth
    print(f"混合后 {len(data)}")
    tf = transforms.Compose([transforms.Resize((a.size, a.size)), transforms.ToTensor(),
                             transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])])
    ds = NoteDataset(data, tf)
    dl = DataLoader(ds, batch_size=a.batch, shuffle=True, num_workers=0)
    model = MultiHeadCNN(DIM_N)
    model.load_state_dict(torch.load(os.path.join(a.base, "model.pt"), map_location="cpu"))
    gpu = torch.cuda.is_available()
    if gpu:
        model = model.cuda()
    # 只微调头(冻结backbone前段?) 先微调全部(小lr)
    opt = torch.optim.AdamW(model.parameters(), lr=a.lr)
    lossf = torch.nn.CrossEntropyLoss()
    for ep in range(a.epochs):
        model.train(); tot = 0.0; nb = 0
        for img, lab in dl:
            if gpu:
                img = img.cuda(); lab = {k: v.cuda() for k, v in lab.items()}
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
    print(f"已微调保存 -> {a.out}")


if __name__ == "__main__":
    main()
