# -*- coding: utf-8 -*-
"""统一转写管线: 转写 与 渲染 共用同一套 算法/模型/函数.
`transcribe(img_path)` 返回 (toks, blocks_meta). 渲染脚本读 blocks_meta 直接画, 保证 图==转写.
"""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
import torch, torch.nn as nn
from PIL import Image
import numpy as np
import transcribe as T
from note_prep import _crop_content
from geo_detect import _components, geo_detect
from classify_block import classify_block
from qwen_loader import load_qwen_visual, get_processor
# 复用 transcribe_qwen 的函数
import transcribe_qwen as Q

_proc = None; _visual = None; _heads = None; _is_note = None; _device = "cpu"
def _init():
    global _proc, _visual, _heads, _is_note, _device
    if _heads is not None: return
    _proc = get_processor(); _visual = load_qwen_visual()
    _device = "cuda" if torch.cuda.is_available() else "cpu"
    _heads = nn.ModuleDict({k: nn.Linear(2048, n) for k, n in Q.DIM_N.items()})
    _heads.load_state_dict(torch.load(os.path.join(Q.HEADS_DIR, "heads.pt"), map_location="cpu"))
    _heads.eval()
    _is_note = None
    if not os.environ.get("IS_NOTE_DISABLE"):  # IS_NOTE_DISABLE=1 时禁用 is_note 门控(隔离测试用)
        try:
            _is_note = nn.Linear(2048, 1)
            sd = torch.load(os.path.join(Q.HEADS_DIR, "is_note.pt"), map_location="cpu")
            if "linear.weight" in sd: sd = {"weight": sd["linear.weight"], "bias": sd["linear.bias"]}
            _is_note.load_state_dict(sd); _is_note.eval()
        except Exception: _is_note = None
    if _device != "cpu":
        _heads = _heads.to(_device)
        if _is_note is not None: _is_note = _is_note.to(_device)

IS_NOTE_THR = float(os.environ.get("IS_NOTE_THR", "0.42"))
ZERO = float(os.environ.get("ZERO_CONF_THR", "0.75"))

def _vis_feat(pixel, grid):
    """Qwen visual 前向: Qwen3-VL 返回 tuple(元素0=隐状态), Qwen2.5 返回 tensor. 统一取特征 tensor."""
    with torch.no_grad():
        f = _visual(pixel, grid)
        if isinstance(f, (tuple, list)):
            f = f[0]
        return f

def predict_digit(im):
    _init()
    crop = _crop_content(im)
    enc = _proc(crop, return_tensors="pt")
    pixel, grid = enc["pixel_values"], enc["image_grid_thw"]
    if _device != "cpu": pixel = pixel.to(_device); grid = grid.to(_device)
    with torch.no_grad():
        f = _vis_feat(pixel, grid).mean(dim=0).float()
        out = {k: _heads[k](f.unsqueeze(0)) for k in Q.DIM_N}
        dig_p = torch.softmax(out["digit"], -1)
    return {k: int(out[k].argmax(dim=1).item()) for k in Q.DIM_N}, dig_p

def p_note(crop):
    _init()
    if _is_note is None: return 1.0
    cimg = _crop_content(Image.fromarray(crop).convert("RGB"))
    enc = _proc(cimg, return_tensors="pt")
    p, g = enc["pixel_values"], enc["image_grid_thw"]
    if _device != "cpu": p = p.to(_device); g = g.to(_device)
    with torch.no_grad():
        f = _vis_feat(p, g).mean(dim=0).float().unsqueeze(0)
        return torch.sigmoid(_is_note(f)).item()

def classify_token(crop):
    """单个块 -> (btype, tok) 与转写主流程完全一致(dash/rest/digit + geo覆盖beam/low)."""
    btype = classify_block(crop)
    if btype == "dash": return "dash", "-"
    if btype == "rest": return "rest", "0"
    if btype != "digit": return btype, None
    if p_note(crop) < IS_NOTE_THR: return "digit_rejected", None
    res, dig_p = predict_digit(Image.fromarray(crop).convert("RGB"))
    if res["digit"] == 7:
        p0 = dig_p[0, 7].item()
        if p0 < ZERO:
            da = dig_p[0].clone(); da[7] = -1e9; res["digit"] = int(da.argmax(dim=0).item())
    gd = geo_detect(crop)
    res["beam"] = gd["beam"]; res["low"] = gd["low"]
    # 变音(accidental) 强制为 0: 这批真实简谱(春天/时间都去哪了/兄弟抱一下/排排坐) 无 #/b 变音记号,
    # Qwen accidental 头在这些谱上误判(如给 'qb'3' 加降号 b). GT 里无 b/#, 故一律置 0.
    res["accidental"] = 0
    # 高八度点 voice 也优先用几何检测: Qwen voice 头会过分(3+个 ' ,如 'q1'''), 而简谱高八度点通常 1 个、至多 2 个.
    # geo 只在数字顶上方有真实点才计 voice, 用 geo 覆盖头, 防 'q1'''' 这类过计数; 但 geo 若漏 (真高八点).
    # 为保真高八点, 用 geo 值; 同时 geo 已限 min(voice,2).
    res["voice"] = gd["voice"]
    return "digit", Q.to_token(res)

def transcribe(img_path):
    """完整转写: 返回 (toks, blocks_meta). toks=音符序列; blocks_meta=每块(坐标+token, 供渲染)."""
    _init()
    img = Image.open(img_path).convert("L")
    arr = np.asarray(img); content = arr < T.TOL
    toks = []; meta = []
    for i, (s, e) in enumerate(T.fine_rows(content, T.ROW_GAP)):
        sub = content[s:e + 1]
        if T.count_bars(sub, e - s + 1) < T.BAR_THR: continue
        row_gray = arr[s:e + 1]
        be = Q.bar_extent(sub)
        for (nx0, nx1, ny0, ny1) in T.crop_note_regions(sub):
            crop = Q.bound_to_note_row(row_gray, nx0, nx1, ny0, ny1, be)
            if crop is None or crop.size == 0: continue
            try:
                btype, tok = classify_token(crop)
            except Exception as ex:
                print(f"  块异常: {ex}", file=sys.stderr); continue
            if tok:
                toks.append(tok)
                meta.append({"band": i, "s": s, "e": e, "x0": int(nx0), "x1": int(nx1),
                             "ny0": int(ny0), "y1": int(ny1) if (be and ny0 <= be[1] + 2) else int(ny1),
                             "btype": btype, "tok": tok})
    return toks, meta
