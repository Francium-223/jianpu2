# -*- coding: utf-8 -*-
"""稳定的 Qwen2.5-VL 视觉加载器。
问题: `device_map="auto"` + `low_cpu_mem_usage` 在混合GPU(AMD核显+NVIDIA)上会触发
0xC0000005 访问违例(-1073741819)崩溃。
方案: 先用 CPU 完整加载模型(稳定), 再把 `.visual` 搬到 CUDA, 其余权重释放(只用 visual)。
用法:
    from qwen_loader import load_qwen_visual
    visual = load_qwen_visual()   # 返回已 eval 且在 cuda 的 qwen.visual
    proc = get_processor()        # 返回 AutoImageProcessor(224)
"""
import os
import torch
from transformers import AutoModel, AutoImageProcessor

MODEL = os.environ.get("QWEN_MODEL", "models/Qwen2.5-VL-3B-Instruct")


def load_qwen_visual(device=None):
    """CPU 载入 Qwen -> 把 .visual 搬到指定设备(CUDA) -> 释放其余权重。
    返回 visual(已 eval, 在 cuda)。device 默认 cuda(可用时)。"""
    if device is None:
        device = "cuda" if torch.cuda.is_available() else "cpu"
    qwen = AutoModel.from_pretrained(MODEL, dtype=torch.bfloat16, trust_remote_code=True)
    visual = qwen.visual
    visual.eval()
    if device != "cpu":
        visual = visual.to(device)
    qwen.visual = None  # 释放非 visual 权重, 省显存
    import gc
    gc.collect()
    if device != "cpu":
        torch.cuda.empty_cache()
    return visual


def get_processor():
    """返回配置好 224 的 AutoImageProcessor(与训练时一致)。"""
    proc = AutoImageProcessor.from_pretrained(MODEL, trust_remote_code=True)
    proc.size = {"shortest_edge": 224, "longest_edge": 448}
    proc.max_pixels = 224 * 448 * 2
    return proc


def extract_feature(visual, proc, pil_img):
    """对单张 PIL 图提 Qwen visual 特征, 返回 2048 维 CPU tensor。
    Qwen3-VL 的 visual(pixel,grid) 返回 tuple(元素0=隐状态), 取 [0]; Qwen2.5 返回 tensor."""
    from note_prep import _crop_content
    img = _crop_content(pil_img.convert("RGB"))
    enc = proc(img, return_tensors="pt")
    pixel, grid = enc["pixel_values"], enc["image_grid_thw"]
    dev = next(visual.parameters()).device
    with torch.no_grad():
        f = visual(pixel.to(dev), grid.to(dev))
        if isinstance(f, (tuple, list)):
            f = f[0]
        return f.mean(dim=0).float().cpu()
