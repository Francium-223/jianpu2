# -*- coding: utf-8 -*-
"""下载完成后跑: 验证 Qwen3-VL-8B visual 的特征维度 + visual(pixel,image_grid_thw) 接口是否可用.
若维度≠2048 或接口不同, 打印出来供适配. 也测一张 spring 裁剪特征. """
import os,sys; sys.path.insert(0,"tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ["HF_ENDPOINT"]="https://hf-mirror.com"
os.environ["HF_HOME"]="D:/Documents_D/jianpu2/hf_cache"
os.environ.setdefault("TOKENIZERS_PARALLELISM","false")
import torch
from transformers import AutoModel, AutoImageProcessor
from PIL import Image
import numpy as np
MODEL="hf_cache/models--Qwen--Qwen3-VL-8B-Instruct/snapshots" if False else "D:/Documents_D/jianpu2/hf_cache/models--Qwen--Qwen3-VL-8B-Instruct"
# 找 snapshot 目录
import glob
snaps=sorted(glob.glob("D:/Documents_D/jianpu2/hf_cache/models--Qwen--Qwen3-VL-8B-Instruct/snapshots/*"))
print("snapshots:", snaps)
mpath=snaps[0] if snaps else None
if not mpath:
    print("未找到模型快照!"); sys.exit(1)
print("用模型:", mpath)
try:
    qwen=AutoModel.from_pretrained(mpath, dtype=torch.bfloat16, trust_remote_code=True)
    visual=qwen.visual.eval(); visual=visual.to("cuda")
    proc=AutoImageProcessor.from_pretrained(mpath, trust_remote_code=True)
    proc.size={"shortest_edge":224,"longest_edge":448}; proc.max_pixels=224*448*2
    # 测一张 spring 裁剪
    import transcribe as T
    arr=np.asarray(Image.open("images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg").convert("L")); content=arr<T.TOL
    from note_prep import _crop_content
    img=_crop_content(Image.fromarray(arr[610:660]).convert("RGB"))
    enc=proc(img, return_tensors="pt"); p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda())
    print("visual 输出:", tuple(f.shape))
    emb=f.mean(dim=0).float().cpu().numpy()
    print("特征维度:", emb.shape, "特征范数(非零?):", float(np.linalg.norm(emb)))
except Exception as ex:
    print("加载/前向失败:", type(ex).__name__, ex)
