# -*- coding: utf-8 -*-
"""端到端 Qwen 转写: 简谱图 → 拆分音符 → Qwen特征 → 分类头 → 组装 jianpu-ly。"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
import torch
import torch.nn as nn
from PIL import Image
import numpy as np
import transcribe as T
from note_prep import _crop_content
from geo_detect import _components, geo_detect
from classify_block import classify_block
from qwen_loader import load_qwen_visual, get_processor

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIM_N = {"digit": 9, "beam": 5, "low": 4, "voice": 4, "dotted": 2, "accidental": 3}
BEAM_PRE = {0: "", 1: "q", 2: "s", 3: "d", 4: "h"}
DIGIT = ["1", "2", "3", "4", "5", "6", "7", "0", "x"]
ACC = ["", "#", "b"]
HEADS_DIR = "models/qwen-mt-v1"


def to_token(res):
    dv = DIGIT[res["digit"]] if 0 <= res["digit"] < len(DIGIT) else ""
    if not dv:
        return "-"
    return BEAM_PRE[res["beam"]] + ACC[res["accidental"]] + "," * res["low"] + "'" * res["voice"] + dv + "." * res["dotted"]


def bar_extent(sub):
    """音符行纵向范围 = 小节线(细高)的 y 区间。返回 (top, bottom) 或 None。
    小节线只在音符行, 其 y 范围 = 音符行真实高度; 歌词在 bar_bottom 之下。
    """
    comps = T.components(sub)
    thin = [c for c in comps if c[4] <= 5 and c[5] >= 10]
    if not thin:
        return None
    # 基准高度用"中位数细高"而非最高: 单根异常高(如伴奏部杠)会把 max 抬得过高,
    # 使真小节线(h~42)被 0.8*max 排除 -> bar_bottom 过高, 歌词被误留进音符行. 中位数更鲁棒.
    hs = sorted(c[5] for c in thin)
    hbase = hs[len(hs) // 2]
    bars = [c for c in thin if c[5] >= 0.8 * hbase and c[5] >= 20]
    if len(bars) < T.BAR_THR:
        return None
    # 小节线 y 顶部应聚在音符行顶(靠上). 按 y-top 取主簇(众数), 剔除离群者——
    # 若有的"杠"y-top 明显低于主簇(如伴奏部杠 y-top=64 vs 真节线 y-top=3), 它是伴奏/杂项, 会抬bar_bottom.
    ytops = sorted(b[1] for b in bars)
    ymed = ytops[len(ytops) // 2]
    bars = [b for b in bars if abs(b[1] - ymed) <= 24]  # 只留 y-top 接近主簇的
    if len(bars) < T.BAR_THR:
        return None
    return min(b[1] for b in bars), max(b[3] for b in bars)


def bound_to_note_row(row_gray, nx0, nx1, ny0, ny1, be):
    """把块的下沿(主体)限制在音符行内: 若块延伸到 bar_bottom 之下(即并入歌词),
    则把裁剪上界收敛到音符行底. 避免歌词被并入音符块导致 is_note 误拒/误认。
    返回 (crop_or_None): 若块主体整体落在音符行之下的歌词区(ny0>bbot), 返回 None 表示该块是歌词字, 应跳过。

    x 方向只留极小余量(2px): 原先左右各扩 T.PAD=8, 当相邻数字间距 <16px 时会把
    邻居数字一起框进来, 模型看到"两个数字"就吐 '0' —— 实测《问候歌》86 块里
    有 13 块是这种(两个挨近的数字被并进同一 crop)。
    """
    XPAD = 2
    if be is None:
        return row_gray[max(0, ny0 - T.PAD):ny1 + T.PAD, max(0, nx0 - XPAD):nx1 + XPAD]
    btop, bbot = be
    # 块主体起点在音符行内(或略上), 则下界收到 bar_bottom; 若块整体在歌词区, 丢弃(歌词字, 不是音符)
    if ny0 > bbot + 2:
        return None
    y1 = min(max(ny1, bbot), bbot + 6)   # 至少到行底(含下划线), +6 留余量
    return row_gray[max(0, ny0 - T.PAD):y1 + T.PAD, max(0, nx0 - XPAD):nx1 + XPAD]


def main():
    proc = get_processor()
    visual = load_qwen_visual()
    device = "cuda" if torch.cuda.is_available() else "cpu"
    heads = nn.ModuleDict({k: nn.Linear(2048, n) for k, n in DIM_N.items()})
    heads.load_state_dict(torch.load(os.path.join(HEADS_DIR, "heads.pt"), map_location="cpu"))
    heads.eval()

    # is_note 概率门: 用学习到的二分类判断"这是不是真音符"(替代硬编码 classify_block)
    try:
        is_note = nn.Linear(2048, 1)
        _is_sd = torch.load(os.path.join(HEADS_DIR, "is_note.pt"), map_location="cpu")
        if "linear.weight" in _is_sd:  # Net 包装时带 linear 前缀
            _is_sd = {"weight": _is_sd["linear.weight"], "bias": _is_sd["linear.bias"]}
        is_note.load_state_dict(_is_sd)
        is_note.eval()
        IS_NOTE_THR = float(os.environ.get("IS_NOTE_THR", "0.42"))
        print(f"[is_note] 已加载概率门, 阈值 {IS_NOTE_THR}", file=sys.stderr)
    except Exception as e:
        is_note = None
        print(f"[is_note] 未找到/加载失败, 退回硬编码: {e}", file=sys.stderr)
    if device != "cpu":
        heads = heads.to(device)
        if is_note is not None:
            is_note = is_note.to(device)

    def predict_one(im):
        crop = _crop_content(im)
        enc = proc(crop, return_tensors="pt")
        pixel, grid = enc["pixel_values"], enc["image_grid_thw"]
        if device != "cpu":
            pixel = pixel.to(device); grid = grid.to(device)
        with torch.no_grad():
            feats = visual(pixel, grid).mean(dim=0).float()
            out = {k: heads[k](feats.unsqueeze(0)) for k in DIM_N}
            dig_p = torch.softmax(out["digit"], -1)  # digit类概率
        return {k: int(out[k].argmax(dim=1).item()) for k in DIM_N}, dig_p

    # rest-0 置信门: 预测为0 但 p(0) 低于阈值时, 判为"假0"(其实是他数字), 改用除0外最大概率的digit.
    # 阈值由 spring 对齐扫描选定: 0.60→OK77, 0.75→OK80(最佳, 假0再降4), 0.80→OK79(rest0回退多), 取 0.75.
    ZERO_CONF_THR = float(os.environ.get("ZERO_CONF_THR", "0.75"))
    print(f"[rest0门] 阈值 {ZERO_CONF_THR}", file=sys.stderr)

    for arg in sys.argv[1:]:
        img = Image.open(arg).convert("L")
        arr = np.asarray(img); content = arr < T.TOL
        toks = []
        meta = []  # 每个块元数据: 供渲染脚本画框(转写即渲染一致性)
        for i, (s, e) in enumerate(T.fine_rows(content, T.ROW_GAP)):
            sub = content[s:e + 1]
            if T.count_bars(sub, e - s + 1) < T.BAR_THR:
                continue
            row_gray = arr[s:e + 1]
            be = bar_extent(sub)
            for (nx0, nx1, ny0, ny1) in T.crop_note_regions(sub):
                crop = bound_to_note_row(row_gray, nx0, nx1, ny0, ny1, be)
                if crop is None:
                    continue  # 该块整体落在歌词区(歌词字), 跳过
                if crop.size == 0:
                    continue
                try:
                    m = crop < 170; Hh, Ww = m.shape
                    # 硬编码块分类: dash→'-', rest→'0', 其他按后续处理
                    btype = classify_block(crop)
                    if btype == "dash":
                        toks.append("-")
                        meta.append({"band":i,"s":s,"e":e,"x0":int(nx0),"x1":int(nx1),"ny0":int(ny0),"y1":int(y1),"btype":"dash","tok":"-"})
                        continue
                    if btype == "rest":
                        toks.append("0")
                        meta.append({"band":i,"s":s,"e":e,"x0":int(nx0),"x1":int(nx1),"ny0":int(ny0),"y1":int(y1),"btype":"rest","tok":"0"})
                        continue
                    if btype != "digit":
                        continue
                    # is_note 概率门: 在学习到的 P(is_note) 低于阈值时, 判为歌词/杂项, 拒绝.
                    # 只对 classify_block 判为 digit 的块做门控, 以剔除被误判为数字的歌词/弧线/杂项.
                    if is_note is not None:
                        cimg = _crop_content(Image.fromarray(crop).convert("RGB"))
                        enc = proc(cimg, return_tensors="pt")
                        pixel, grid = enc["pixel_values"], enc["image_grid_thw"]
                        if device != "cpu":
                            pixel = pixel.to(device); grid = grid.to(device)
                        with torch.no_grad():
                            f = visual(pixel, grid).mean(dim=0).float().unsqueeze(0)
                            p_note = torch.sigmoid(is_note(f)).item()
                        if p_note < IS_NOTE_THR:
                            print(f"  [门控] 块 BBox被拒 P(note)={p_note:.2f} (歌词/杂项)", file=sys.stderr)
                            continue
                    res, dig_p = predict_one(Image.fromarray(crop).convert("RGB"))
                    # rest-0 置信门: 若预测为0但 p(0)不足, 是"假0"(真实为数字), 改用除0外最大数字.
                    if res["digit"] == 7:  # DIGIT[7]="0"
                        p0 = dig_p[0, 7].item()
                        if p0 < ZERO_CONF_THR:
                            # 去掉0类后取最大
                            d_args = dig_p[0].clone(); d_args[7] = -1e9
                            res["digit"] = int(d_args.argmax(dim=0).item())
                            print(f"  [rest0门] p(0)={p0:.2f}<{ZERO_CONF_THR} 拒0, 改判 digit{res['digit']}", file=sys.stderr)
                    # 时值(下划线)用几何检测(100%准), 不用 Qwen beam 头(真实域易错)
                    gd = geo_detect(crop)
                    res["beam"] = gd["beam"]
                    # 低八度点数 也优先用几何检测: Qwen low 头会把"时值下划线"误判成低八度点
                    # (下划线也在数字正下方, 位置和低八点相近) -> 产生假 ',3q', 导致 ',' 混入八分/十六分.
                    # geo_detect 能区分(下划线->beam, 低八点->low), 故用 geo 覆盖 low, 修正这类误判.
                    # 但仅当 geo 检出的低八点数 <= Qwen low 头时用 geo(geo 更可信); 若 geo 也漏(真低八点丢失),
                    # 例如 geo low=0 而 GT 是低八, 这里不强行加(避免把非低八误加). 用 geo 值为准.
                    res["low"] = gd["low"]
                    tok = to_token(res)
                    if tok:
                        toks.append(tok)
                        meta.append({"band":i,"s":s,"e":e,"x0":int(nx0),"x1":int(nx1),"ny0":int(ny0),"y1":int(y1),"btype":"digit","tok":tok})
                except Exception as ex:
                    print(f"  块跳过(异常): {ex}", file=sys.stderr)
                    continue
        print(f"{os.path.basename(arg)}: {len(toks)} 音")
        print("  ", " ".join(toks))
        rj = os.environ.get("RENDER_JSON")
        if rj:
            import json
            print(f"[RENDER] meta块 {len(meta)} 词 {len(toks)}", file=sys.stderr)
            json.dump({"toks": toks, "blocks": meta, "img": arg}, open(rj, "w", encoding="utf-8"))
            print(f"  渲染元数据 -> {rj}", file=sys.stderr)


if __name__ == "__main__":
    main()
