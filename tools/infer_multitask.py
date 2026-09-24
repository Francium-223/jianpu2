# -*- coding: utf-8 -*-
"""多任务 CNN(ResNet18 + 6 头) 推理: 音符图 → jianpu-ly token。

**为什么有这个文件**: 端到端 CNN 转写脚本 `transcribe_cnn.py` 里写着
`from infer_multitask import predict, to_token, model` —— 但那个模块在抢救包里**丢了**
(2026-09-25 全仓库只有引用、没有实现, 于是这条路一直是断的)。这里按三处**既有口径**把它复原:

* 模型结构/头维度: `train_multitask.py` 的 `MultiHeadCNN` + `models/*/dims.json`(**直接 import,
  不复制一份**, 免得两份漂);
* 标签词表: `build_real_onehot.py` 里的 DIGITS/BEAMS/LOWS/VOICES/DOTS/ACCS(顺序就是 one-hot 的下标);
* token 组装: `token_json.json_to_token`(**唯一一份** token↔JSON 口径)。

标签词表(下标 → 含义):
    digit  ["1","2","3","4","5","6","7","0","x"]   beam [0,1,2,3,4](空/q/s/d/h)
    low    [0,1,2,3](逗号个数)                      voice [0,1,2,3](撇号个数)
    dotted [0,1]                                   accidental ["","#","b"]

用法:
    python3 tools/infer_multitask.py 某张音符图.png            # 单图
    python3 tools/infer_multitask.py 整页简谱.png --full       # 整页: 切行→切音符→逐个识别
    JIANPU_CNN_MODEL=models/multitask-v1 python3 tools/infer_multitask.py x.png
"""
import argparse
import os
import sys

import numpy as np
import torch
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                       # jianpu2
WS = os.path.dirname(ROOT)                         # 工作区

sys.path.insert(0, HERE)
from train_multitask import DIM_N, MultiHeadCNN    # noqa: E402  结构只有一份
from note_prep import prep                         # noqa: E402
from token_json import json_to_token               # noqa: E402

DIGITS = ["1", "2", "3", "4", "5", "6", "7", "0", "x"]
BEAMS = [0, 1, 2, 3, 4]
LOWS = [0, 1, 2, 3]
VOICES = [0, 1, 2, 3]
DOTS = [0, 1]
ACCS = ["", "#", "b"]

MODEL_DIR = os.environ.get("JIANPU_CNN_MODEL") or os.path.join(WS, "models", "multitask-v2")


def _load(model_dir=MODEL_DIR):
    with open(os.path.join(model_dir, "dims.json"), encoding="utf-8") as f:
        import json
        dims = json.load(f)
    net = MultiHeadCNN(dims)
    state = torch.load(os.path.join(model_dir, "model.pt"), map_location="cpu")
    net.load_state_dict(state)                     # strict: 键对不上就当场炸, 别静默乱猜
    net.eval()
    return net


model = _load()


def predict_batch(imgs):
    """一批 PIL 图 → 每个的**语义**结果(不是下标): digit 是 '1'..'x', beam/low/dotted 是数值。"""
    if not imgs:
        return []
    x = torch.stack([prep(im) for im in imgs])
    with torch.no_grad():
        out = model(x)
    res = []
    for i in range(len(imgs)):
        res.append({
            "digit": DIGITS[int(out["digit"][i].argmax())],
            "beam": BEAMS[int(out["beam"][i].argmax())],
            "low": LOWS[int(out["low"][i].argmax())],
            "voice": VOICES[int(out["voice"][i].argmax())],
            "dotted": DOTS[int(out["dotted"][i].argmax())],
            "accidental": ACCS[int(out["accidental"][i].argmax())],
        })
    return res


def predict(img):
    """单个 PIL 图 → 语义结果 dict(与 predict_batch 同一口径)。"""
    return predict_batch([img])[0]


def to_token(res):
    """语义结果 → jianpu-ly token(走 token_json 的唯一一份组装口径)。"""
    voice = res.get("voice", 0)
    return json_to_token({
        "digit": res["digit"],
        "beam": res["beam"],
        "low": res["low"],
        "voice": "'" * (voice if isinstance(voice, int) else len(str(voice))),
        "dotted": res["dotted"],
        "accidental": res["accidental"],
    })


def transcribe_image(path, batch=64, verbose=False):
    """整页: 复用 transcribe.py 的行/音符切分, 逐个音符过 CNN。返回 token 列表。"""
    sys.path.insert(0, HERE)
    import transcribe as T
    im = Image.open(path).convert("L")
    arr = np.asarray(im)
    content = arr < T.TOL
    toks = []
    for (s, e) in T.fine_rows(content, T.ROW_GAP):
        sub = content[s:e + 1]
        if T.count_bars(sub, e - s + 1) < T.BAR_THR:
            continue
        row_gray = arr[s:e + 1]
        crops = []
        for (nx0, nx1, ny0, ny1) in T.crop_note_regions(sub):
            crop = row_gray[max(0, ny0 - T.PAD):ny1 + T.PAD, max(0, nx0 - T.PAD):nx1 + T.PAD]
            if crop.size == 0:
                continue
            crops.append(Image.fromarray(crop).convert("RGB"))
        for i in range(0, len(crops), batch):
            chunk = crops[i:i + batch]
            for res in predict_batch(chunk):
                tok = to_token(res)
                if tok:
                    toks.append(tok)
        if verbose:
            print(f"  行 {s}-{e}: {len(crops)} 个音符", flush=True)
    return toks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--full", action="store_true", help="整页转写(切行切音符)")
    ap.add_argument("--model", default=MODEL_DIR, help="模型目录(默认 %s)" % MODEL_DIR)
    ap.add_argument("--verbose", action="store_true")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
    if a.model != MODEL_DIR:
        global model
        model = _load(a.model)
        print("模型:", a.model)
    if a.full:
        toks = transcribe_image(a.image, verbose=a.verbose)
        seq = " ".join(toks)
        print(f"{len(toks)} 个 token: {seq}")
        print("数字串:", "".join(c for c in seq if c.isdigit()))
    else:
        res = predict(Image.open(a.image).convert("RGB"))
        print(res, "->", to_token(res))
    return 0


if __name__ == "__main__":
    sys.exit(main())
