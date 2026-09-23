# -*- coding: utf-8 -*-
"""统一音符图预处理: 裁白边到内容 + Resize + 归一化。
让合成原子图和真实音符图在进入 CNN 前形态一致(数字本体占比高, 尺寸统一)。
"""
import numpy as np
import torch
from torchvision import transforms
from PIL import Image

SIZE = 112


def _crop_content(img):
    """裁掉白边, 只留内容(暗像素区域)。"""
    arr = np.asarray(img.convert("L"))
    m = arr < 200
    ys, xs = np.where(m)
    if len(ys) == 0:
        return img
    pad = 4
    y0, y1 = max(0, ys.min() - pad), min(arr.shape[0], ys.max() + pad + 1)
    x0, x1 = max(0, xs.min() - pad), min(arr.shape[1], xs.max() + pad + 1)
    return img.crop((x0, y0, x1, y1))


def prep(img):
    """PIL Image -> tensor(归一化), 裁白边+统一size。"""
    img = _crop_content(img)
    tf = transforms.Compose([
        transforms.Resize((SIZE, SIZE)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])
    return tf(img)


def load_img_tensor(path):
    return prep(Image.open(path).convert("RGB"))
