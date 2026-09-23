# -*- coding: utf-8 -*-
"""简谱转写正式管线 (v2, 组合方案)。
架构:
  1) 切分: transcribe.crop_note_regions/bound_to_note_row (行切割 + 原子框, crop 到行底含下划线)
  2) 数字识别: Qwen3-VL-2B 直接看原子块 (零样本, 准)
  3) 符号识别: geo_detect (时值下划线按 y 行聚类 / 低高八度点 / 附点)
  4) 组装 jianpu-ly token; 同一次运行可输出转写序列 + 标注框图 (图 == 转写)

用法:
  py -3.13 tools/jp_transcribe.py <谱图> [输出图.png]
"""
import os, sys, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# 模型路径: 优先环境变量 QWEN_VL_MODEL, 否则 <仓库根>/models/Qwen3-VL-2B-Instruct
# (原来是写死的绝对路径, 换台机器就找不到 —— 现在跟着仓库走)
MODEL = os.environ.get("QWEN_VL_MODEL") or os.path.join(_ROOT, "models", "Qwen3-VL-2B-Instruct")
BEAM_PRE = {0: "", 1: "q", 2: "s", 3: "d", 4: "h"}
DIGIT_PROMPT = ("这个简谱记号是什么? 只输出一个字符: 数字 1-7, 或 0(休止符), "
                "或 x(两笔交叉的打击/念白记号)。如果这是汉字歌词或其他文字内容, 输出 -。不要解释。")
X_RECHECK_PROMPT = ("这个标记是不是汉字歌词文字？只回答一个字符: 是歌词文字就回答 是，"
                    "是简谱的打击/念白记号 x 就回答 否。")
BAND_PROMPT = ("这一行是简谱(数字谱)的音符行，还是非音符信息？"
               "非音符信息包括: 标题、歌词、署名(词曲作者/演唱者)、调号拍号(如 1=F 2/4)、"
               "速度记号(如 ♩=62)、段落说明。只回答两个字之一: 音符 或 文字。不要解释。")
METER_PROMPT = "这是简谱谱头的一部分。请只输出拍号(形如 4/4 或 3/4 或 2/4 或 6/8), 不要解释。"

_model = _proc = None
_crop_cache = {}          # crop 指纹 -> 数字(重复音符复用, 省大量 Qwen 前向)

def _crop_key(crop):
    """crop 的近似指纹: 缩到 16x24 灰度(容忍微小位移/尺寸差异)。"""
    from PIL import Image
    im = Image.fromarray(crop).convert("L").resize((16, 24))
    return im.tobytes()

def _init():
    global _model, _proc
    if _model is not None:
        return
    import torch
    from transformers import AutoProcessor, AutoModelForImageTextToText
    _proc = AutoProcessor.from_pretrained(MODEL, trust_remote_code=True)
    # 速度关键: processor 默认 size.shortest_edge=65536 -> 短边至少 256px, 于是
    # 一个 33x9 的音符小块被放大成 512x320 = 320 个 patch(放大 550 倍), 纯浪费算力 ——
    # 实测模型前向占总耗时 94%, 单谱 17s(260 块)。JP_MINPIX 可把最小像素数调小
    # (如 784 = 短边 28px), 小块不再被暴力放大 -> patch 数降一个数量级。
    _mp = os.environ.get("JP_MINPIX")
    if _mp:
        try:
            _ip = getattr(_proc, "image_processor", None)
            if _ip is not None:
                _ip.size = {"shortest_edge": int(_mp), "longest_edge": 16777216}
        except Exception:
            pass
    # dtype 可配: 本地 4070 用 bfloat16; Kaggle 的 P100/T4 不支持 bf16, 需设 JP_DTYPE=float16
    _dt = os.environ.get("JP_DTYPE", "bfloat16")
    _dtype = {"float16": torch.float16, "bfloat16": torch.bfloat16,
              "float32": torch.float32}.get(_dt, torch.bfloat16)
    _model = AutoModelForImageTextToText.from_pretrained(
        MODEL, trust_remote_code=True, dtype=_dtype).eval()
    # 关键: 必须显式搬到 GPU。原先用 device_map=None 会让模型留在 CPU,
    # 推理慢 10-50 倍(这正是"一张谱要几分钟"的根因)。
    if torch.cuda.is_available():
        _model = _model.to("cuda")
    print(f"[jp] 模型已加载, device={_model.device}, dtype={_dtype}", flush=True)

def _digit_of(crop):
    """Qwen3-VL-2B 看原子块 -> 数字字符。"""
    import torch, numpy as np
    from PIL import Image
    im = Image.fromarray(crop).convert("RGB")
    chat = [{"role": "user", "content": [{"type": "image"}, {"type": "text", "text": DIGIT_PROMPT}]}]
    text = _proc.apply_chat_template(chat, tokenize=False, add_generation_prompt=True)
    enc = _proc(images=im, text=text, return_tensors="pt")
    enc = {k: (v.to(_model.device) if torch.is_tensor(v) else v) for k, v in enc.items()}
    with torch.no_grad():
        out = _model.generate(**enc, max_new_tokens=2, do_sample=False)
    s = _proc.decode(out[0][enc["input_ids"].shape[1]:], skip_special_tokens=True).strip()
    m = re.search(r"[0-7x]", s)
    if m:
        return m.group(0)
    return "-" if "-" in s else "?"

def _digits_of_batch(crops, batch_size=None):
    """批量识别多个 crop 的数字(一次前向 N 个, 大幅提速)。返回 list[str]。
    注意: 生成必须用左 padding(padding_side='left'), 否则解码会错位(右 padding 会把生成位对齐到 padding)。"""
    import torch
    from PIL import Image
    _init()
    if not crops:
        return []
    B = batch_size or int(os.environ.get("JP_BATCH", "8"))
    try:
        _proc.tokenizer.padding_side = "left"
    except Exception:
        pass
    results = []
    # 先查缓存: 相同指纹(重复音符)直接复用, 只对未命中的批量调 Qwen
    miss_idx, miss_crops = [], []
    for j, c in enumerate(crops):
        k = _crop_key(c)
        if k in _crop_cache:
            results.append(_crop_cache[k])
        else:
            results.append(None)
            miss_idx.append(j); miss_crops.append(c)
    tmpl = _proc.apply_chat_template(
        [{"role": "user", "content": [{"type": "image"}, {"type": "text", "text": DIGIT_PROMPT}]}],
        tokenize=False, add_generation_prompt=True)
    for i in range(0, len(miss_crops), B):
        chunk = miss_crops[i:i + B]
        imgs = []
        for c in chunk:
            im = Image.fromarray(c).convert("RGB")
            sw = float(os.environ.get("JP_SCALE", "1.0"))
            if sw != 1.0:                       # 降采样: patch 变少 -> ViT 前向更快
                im = im.resize((max(8, int(im.width * sw)), max(8, int(im.height * sw))), Image.LANCZOS)
            imgs.append(im)
        enc = _proc(images=imgs, text=[tmpl] * len(imgs), padding=True, return_tensors="pt")
        enc = {k: (v.to(_model.device) if torch.is_tensor(v) else v) for k, v in enc.items()}
        with torch.no_grad():
            out = _model.generate(**enc, max_new_tokens=2, do_sample=False)
        L = enc["input_ids"].shape[1]
        for t, o in enumerate(out):
            s = _proc.decode(o[L:], skip_special_tokens=True).strip()
            m = re.search(r"[0-7x]", s)
            if m:
                val = m.group(0)
            else:
                val = "-" if "-" in s else "?"
            j = miss_idx[i + t]
            results[j] = val
            _crop_cache[_crop_key(chunk[t])] = val
    return results

def _recheck_x(crops, batch_size=None):
    """对单次被判为 'x' 的块做二次判定: 是打击/念白记号 x, 还是歌词文字?
    返回 list[str], 每个元素 'x'(保留) 或 '-' (歌词, 丢弃)。
    二元问题比 9 类数字问题更易分辨, 用于剔除"汉字歌词被误判为 x"的假念白。"""
    import torch
    from PIL import Image
    _init()
    if not crops:
        return []
    B = batch_size or int(os.environ.get("JP_BATCH", "8"))
    try:
        _proc.tokenizer.padding_side = "left"
    except Exception:
        pass
    results = []
    miss_idx, miss_crops = [], []
    for j, c in enumerate(crops):
        k = _crop_key(c)
        ck = ("xre_", k)
        if ck in _crop_cache:
            results.append(_crop_cache[ck])
        else:
            results.append(None)
            miss_idx.append(j); miss_crops.append(c)
    tmpl = _proc.apply_chat_template(
        [{"role": "user", "content": [{"type": "image"}, {"type": "text", "text": X_RECHECK_PROMPT}]}],
        tokenize=False, add_generation_prompt=True)
    for i in range(0, len(miss_crops), B):
        chunk = miss_crops[i:i + B]
        imgs = [Image.fromarray(c).convert("RGB") for c in chunk]
        enc = _proc(images=imgs, text=[tmpl] * len(imgs), padding=True, return_tensors="pt")
        enc = {k: (v.to(_model.device) if torch.is_tensor(v) else v) for k, v in enc.items()}
        with torch.no_grad():
            out = _model.generate(**enc, max_new_tokens=2, do_sample=False)
        L = enc["input_ids"].shape[1]
        for t, o in enumerate(out):
            s = _proc.decode(o[L:], skip_special_tokens=True).strip()
            # 答"是"开头或含"歌词" = 歌词 -> 丢弃; 其余(否/x/不是)保留为 x
            val = "-" if (s.startswith("是") or "歌词" in s) else "x"
            j = miss_idx[i + t]
            results[j] = val
            _crop_cache[("xre_", _crop_key(chunk[t]))] = val
    return results

def _classify_bands(crops, batch_size=None):
    """批量判定"行带是音符行还是文字行"(标题/歌词/署名)。返回 list[bool] (True=音符行)。
    只对可疑行带(frac<0.85)调用, 通常 1-5 次/谱, 很便宜。
    用途: 纯几何判据无法区分"标题文字行"与"音符+歌词粘连行带"(两者 frac/下划线/高度
    特征都重叠), 而模型看一行是简谱还是汉字文字非常容易。"""
    import torch
    from PIL import Image
    _init()
    if not crops:
        return []
    B = batch_size or int(os.environ.get("JP_BATCH", "8"))
    try:
        _proc.tokenizer.padding_side = "left"
    except Exception:
        pass
    out_flags = []
    tmpl = _proc.apply_chat_template(
        [{"role": "user", "content": [{"type": "image"}, {"type": "text", "text": BAND_PROMPT}]}],
        tokenize=False, add_generation_prompt=True)
    for i in range(0, len(crops), B):
        chunk = crops[i:i + B]
        imgs = [Image.fromarray(c).convert("RGB") for c in chunk]
        enc = _proc(images=imgs, text=[tmpl] * len(imgs), padding=True, return_tensors="pt")
        enc = {k: (v.to(_model.device) if torch.is_tensor(v) else v) for k, v in enc.items()}
        with torch.no_grad():
            out = _model.generate(**enc, max_new_tokens=3, do_sample=False)
        L = enc["input_ids"].shape[1]
        for o in out:
            s = _proc.decode(o[L:], skip_special_tokens=True).strip()
            # 明确说"文字"且没说"音符" -> 文字行
            out_flags.append(not ("文字" in s and "音符" not in s))
    return out_flags

def _target_w(w):
    """归一化后的目标宽度(供 _load_gray 与 render 共用, 保证框与转写同一尺度)。"""
    mw = int(os.environ.get("JP_MAXW", "2000"))
    nw = int(os.environ.get("JP_MINW", "950"))
    tw = int(os.environ.get("JP_SMALLW", "1200"))
    if mw > 0 and w > mw:
        return mw
    if nw > 0 and w < nw:
        return tw
    return w

def _load_gray(img_path):
    """读灰度图; 把页宽归一化到被调好的尺度。
    病根: 管线里所有尺寸阈值都是"绝对像素"(如数字 14<=高<=50)。两头都会翻车:
      * 过高分辨率(实测 4547x4512 三声部合唱谱): 音符高约 90px -> 被 <=50 滤光;
      * 过小图(jianpu.cn 的《十年》只有 511x786): 音符高约 8px -> 被 >=14 滤光,
        整谱只剩休止符。故宽度 >JP_MAXW(2000) 缩到 2000; <JP_MINW(950) 放大到 1200。
        门槛提到 950 的理由: 简谱的前奏/引子常用小一号字, 实测《富士山下》正文数字 15px
        而前奏只有 13px, 卡在"数字高>=14"之下 -> 整个前奏被读成休止符。放大后 13->19px 就过了。
    返回 (灰度数组, 缩放比)。"""
    from PIL import Image
    import numpy as np
    im = Image.open(img_path).convert("L")
    w, h = im.size
    mw = int(os.environ.get("JP_MAXW", "2000"))
    nw = int(os.environ.get("JP_MINW", "950"))
    tw = int(os.environ.get("JP_SMALLW", "1200"))
    sc = 1.0
    if mw > 0 and w > mw:
        sc = mw / float(w)
        im = im.resize((mw, max(1, int(round(h * sc)))), Image.LANCZOS)
    elif nw > 0 and w < nw:
        sc = tw / float(w)
        im = im.resize((tw, max(1, int(round(h * sc)))), Image.LANCZOS)
    return np.asarray(im), sc

def detect_meter(img_path):
    """用 Qwen 认谱头拍号(如 4/4)。失败返回 None。"""
    import torch
    from PIL import Image
    _init()
    im = Image.open(img_path).convert("RGB")
    W, H = im.size
    top = im.crop((0, 0, W, max(40, int(H * 0.20))))          # 谱头区
    chat = [{"role": "user", "content": [{"type": "image"}, {"type": "text", "text": METER_PROMPT}]}]
    text = _proc.apply_chat_template(chat, tokenize=False, add_generation_prompt=True)
    enc = _proc(images=top, text=text, return_tensors="pt")
    enc = {k: (v.to(_model.device) if torch.is_tensor(v) else v) for k, v in enc.items()}
    with torch.no_grad():
        out = _model.generate(**enc, max_new_tokens=4, do_sample=False)
    s = _proc.decode(out[0][enc["input_ids"].shape[1]:], skip_special_tokens=True).strip()
    m = re.search(r"(\d)\s*/\s*(\d)", s)
    return f"{m.group(1)}/{m.group(2)}" if m else None

def _nline_big(img_path, thr=None):
    """判断是否"非纯简谱"。返回 (nline, wide):
      nline = "单行最长连续暗段 >= 55% 页宽" 的行数(五线谱/六线谱的直谱线跨整页)
      wide  = "整行横向覆盖 > 60% 页宽" 的行数(更宽松, 抓断续/淡线)
    两者取 OR 判非纯(见 transcribe 里的用法)。只用 nline 会漏掉"六线谱被数字打断"
    的吉他弹唱谱(实测 187 个漏检, 其中 26 个已转出 7495 个污染音符)。
    灰度阈值自适应(mean-25): 固定 128 抓不到淡扫描件的谱线(实测钢琴五线谱《我喜欢》)。"""
    import numpy as np
    from PIL import Image
    im = Image.open(img_path).convert("L")
    iw, ih = im.size
    tw = 1200 if iw < 950 else (2000 if iw > 2000 else iw)
    if tw != iw:
        im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
    g = np.asarray(im).astype(np.int16)
    if thr is None:
        thr = max(60, int(g.mean()) - 25)
    W = g.shape[1]
    c = g < thr
    rs = c.sum(axis=1)
    n = 0
    for y in range(c.shape[0]):
        row = c[y]
        if not row.any():
            continue
        d = np.diff(np.concatenate(([0], row.view(np.int8), [0])))
        st = np.where(d == 1)[0]
        en = np.where(d == -1)[0]
        if len(st) and (en - st).max() >= 0.55 * W:
            n += 1
    wide = int((rs > 0.60 * W).sum())
    return n, wide

def _staff_evidence(img_path, thr=None):
    """谱线证据: "5% 页高滑窗内最多有几条**细长横线**"。

    为什么不用 nline(数行数): 一个黑色标题底框(如《倔强》15 行)或一条长连音线
    的平顶(3 行) 都能单独贡献 >=BADLINE 行, 把**纯简谱页**误判成非纯(实测《倔强》
    纯简谱 nline=26 全来自标题框; 《爱》纯简谱 nline=7 来自两条长圆滑线)。
    为什么不用"连续暗段>=55%页宽": 六线谱的谱线被品格数字**打断**, 连续段够不到 55%
    (实测《让我欢喜让我忧》纯六线谱 nline=5 却检不到谱线)。
    故改用: 行覆盖率 >60% 页宽(抓被打断的线) + 按细线分组(厚<=THINMAXW 行, 故
    照片/底框这类**厚块**不计入) + 局部窗口密度(谱线是 5-6 条**等距成簇**的,
    而长连音线/标题框是零星单发, 局部不会密集)。
    已知案例 10/10 判对(见 tools/measure_purity2.py)。"""
    import numpy as np
    from PIL import Image
    im = Image.open(img_path).convert("L")
    iw, ih = im.size
    tw = 1200 if iw < 950 else (2000 if iw > 2000 else iw)
    if tw != iw:
        im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
    g = np.asarray(im).astype(np.int16)
    if thr is None:
        thr = max(60, int(g.mean()) - 25)
    W = g.shape[1]
    c = g < thr
    return _staff_evidence_arr(c, W)

def _staff_evidence_arr(c, W):
    """_staff_evidence 的"已阈值化"版本: 传入暗掩码 c 与页宽 W。

    拆出来是为了让 kind_detect2(它自己已经把图读成掩码了)能直接调用,
    避免为同一张图**重复读盘+缩放**一遍。"""
    thick = int(os.environ.get("JP_THINMAXW", "8"))
    rows = [y for y in range(c.shape[0]) if c[y].sum() > 0.60 * W]
    tops = []
    if rows:
        grp = [rows[0]]
        for y in rows[1:]:
            if y - grp[-1] <= 1:
                grp.append(y)
            else:
                if len(grp) <= thick:
                    tops.append(grp[0])
                grp = [y]
        if len(grp) <= thick:
            tops.append(grp[0])
    win = max(20, int(0.05 * c.shape[0]))
    best = 0
    for i, t in enumerate(tops):
        k = 0
        for u in tops[i:]:
            if u - t <= win:
                k += 1
            else:
                break
        best = max(best, k)
    return best

def _purity2_on():
    """纯度门是否用"AND 版"判据。**默认开** ✓ —— 因为 2026-09-20 那次隔离区回收
    (663 页) 就是用 JP_PURITY2=1 跑进语料的 ✓; 若默认关, 下一次 finalize 跑
    kind_detect2 时会把它们**原样搬回隔离区** ✗(把回收整个撤销 ✗)。
    该判据对**已接受语料零改动** ✓(nline<BADLINE 一律放行 ✓ 构造上不可能误杀 ✓),
    要退回旧行为: JP_PURITY2=0。"""
    return os.environ.get("JP_PURITY2", "1") == "1"

def impure_from(nline, staff_evidence):
    """**判据的唯一实现** —— 所有调用点都必须走这里, 防止逻辑漂移。

    非纯 = nline >= JP_BADLINE(默认5)。
    JP_PURITY2 开(默认)时改成"nline>=BADLINE **且** staff_evidence>=JP_STAFFMAX(默认4)"。

    **另加一条硬条件**(2026-09-21 抽检发现, 见 tools/scan_mixed.py):
      staff_evidence >= JP_STAFFHARD(默认5) -> 一律判非纯, 不管 nline 多少。
    为什么: 六线谱的谱线被品格数字打断 -> nline 很低(如《平淡》nline=1), 于是被 AND
    判据放行, 转写出来就是在读**六线谱的品格数字**(实测该页 x 率 17% ✗)。
    实测剂量-反应关系(全库抽 2000 页):
      staff 0/1/2 -> x 率 2.08/2.17/2.18% ✓ (98% 的干净页都在这三档)
      staff 5/6/7/10 -> 10.6/8.5/14.8/17.4% ✗
      staff>=4 -> 10.43% (是干净档的 4.8 倍)
    取 5 而非 4: 4 那一档只有 11 页且 x 率 4.66%, 留作保守; 从 5 起污染明显。
    已知案例实测: 《平淡》staff=12 -> 非纯 ✓; 《倔强》staff=0、《爱》staff=1 -> 纯 ✓
    (后两张正是旧判据误杀的纯简谱页, 新规则保持放行 ✓)。

    AND 的含义: 只要 nline 低就照旧放行 -> 只把隔离区里被"黑色标题底框/长连音线"
    冤枉的纯简谱页放回来。详见 _staff_evidence。"""
    if staff_evidence >= int(os.environ.get("JP_STAFFHARD", "5")):
        return True
    if nline < int(os.environ.get("JP_BADLINE", "5")):
        return False
    if _purity2_on():
        return staff_evidence >= int(os.environ.get("JP_STAFFMAX", "4"))
    return True

def is_impure(img_path):
    """纯简谱门: True = 非纯简谱(五线谱/六线谱/总谱/吉他混合), 不该转写。

    这类谱上的六线谱数字会被当音符读进来, 是语料的主要污染源
    (实测移出 464 个/2.6 万音符)。**两处调用点(transcribe 与
    transcribe_source)共用本函数**, 避免判据漂移。

    只用 nline 判, 不用 wide: wide 会被页面上的照片骗(实测纯简谱
    《恋着多喜欢》wide=62, 若用 OR 会误杀 341 个谱/33595 音符)。

    JP_PURITY2(默认开)时改为"旧判据 **且** 谱线证据"——对现有已接受语料零改动
    (nline<BADLINE 一律放行, 构造上不可能误杀), 只把隔离区里被黑色标题底框/
    长连音线冤枉的纯简谱页放回来。详见 _staff_evidence。"""
    try:
        nl, _wd = _nline_big(img_path)
        # 谱线证据**必须无条件算** —— 六线谱被品格数字打断时 nline 很低(如《平淡》nline=1),
        # 若在这里 early-return "纯" 就把 impure_from 里那条硬条件(staff>=5)跳过了 ✗。
        st = _staff_evidence(img_path)
    except Exception:
        return False
    return impure_from(nl, st)

def transcribe(img_path):
    """谱图 -> (tokens, blocks_meta)。blocks_meta 每项含坐标/token/btype, 供渲染。"""
    import numpy as np
    from PIL import Image
    import transcribe as T
    import transcribe_qwen as Q
    # 纯简谱门: 非纯简谱(五线谱/六线谱/总谱/吉他混合)一律不转 —— 这类谱上
    # 六线谱的数字会被当音符读进来, 是语料的主要污染源(实测移出 464 个/2.6 万音符)。
    if os.environ.get("JP_KINDFILTER", "1") == "1":
        if is_impure(img_path):
            return [], []
    from classify_block import classify_block
    from geo_detect import geo_detect
    # JP_DRAWONLY=1 = 只想看切分图, 不要模型 -> 先别加载(省显存, 也不跟别的转写抢卡)
    if os.environ.get("JP_DRAWONLY") != "1":
        _init()
    arr, _sc = _load_gray(img_path)
    content = arr < T.TOL
    # 阶段1: 切块(收集 crop + 类型), 数字块留待批量识别
    blocks = []
    _curve_of = {}   # 块索引 -> 所在弧线(连音线/圆滑线)的 id          # (s,nx0,nx1,ny0,ny1,crop,bt)
    # 行切分后再做一次"行内 y 切分": 把贴在音符行下方的歌词行/排版说明切开,
    # 否则文字会被当音符块送去识别 -> 产出 '?'/'x' 乱码
    bands = []
    for s0, e0 in T.fine_rows(content, T.ROW_GAP):
        bands += T.split_row_inner(content, s0, e0)
    # 谱头区判定(JP_HEADER=1): 简谱的旋律从第一个"明确音符行"(瘦高块占比 frac>=0.85)
    # 开始; 它上面的行带就是标题/副标题/署名/表情记号(如《友谊天长地久》的
    # "日语版《友谊地久天长》" "稲垣千穎 填词" "♩=62")。这些文字行同样"瘦高块够多 +
    # 有横线", 会被下面的逐块判据当音符 -> 整行文字变 token(实测该谱前 20 个 token
    # 全是标题区垃圾, 连 ♩=62 都读成 "6 2")。故整段丢弃。
    # "瘦高"判据的比例阈值。原为 1.4: 实测部分行(如《两只老虎》第二结尾那两行)的数字
    # 排得略扁(h/w = 1.20-1.29), 全部卡在 1.4 之下 -> 整行被判"无音符"丢掉(图上那两行
    # 一个框都没有)。降到 1.15 让这类行通过; 汉字的 h/w 约 1.0-1.1, 仍会被挡;
    # 万一放进来歌词行, 也会被下面的模型"音符行/文字行"判定剔除。
    _TALLR = float(os.environ.get("JP_TALLR", "1.15"))
    # 谱头区(第一个"严格阈值下也算音乐行"的行带之前)用 _TALLR_HEAD=1.4 的严格判据:
    # 否则调号/拍号行(如 `1=F 2/4`)会以 frac>=0.85 混进来 —— 它长得像记号, 连模型
    # 都会判成"音符"(实测 spring 因此多出 `1 - - - 'x`)。正文才用宽松的 1.15。
    _TALLR_HEAD = float(os.environ.get("JP_TALLR_HEAD", "1.4"))
    _head_until = -1      # -1 = 没找到谱头边界 -> 全文用宽松阈值(靠模型判定挡谱头)
    for _i, (_s, _e) in enumerate(bands):
        _sub = content[_s:_e + 1]
        _st, _ = T.strip_hlines(_sub)
        _c = [c for c in T.components(_st) if 10 <= c[5] <= 50 and c[4] >= 4]
        # 音乐起点的判据: 连通域够多(>=15) 且 (严格阈值下瘦高占比>=0.40 或 下划线>=6条)。
        # 只要求 frac 会漏判 —— 《卖报歌》《两只老虎》这类"数字偏扁"的谱, 引子行的
        # 严格 frac(0.15) 甚至低于标题行(0.31), 边界就被跳过, 引子被当谱头丢掉
        # (实测卖报歌第一行 12 条时值线, 一个框都没有)。但引子行有 12 条下划线,
        # 标题行只有 2 条 —— 用"下划线够多"补上这个判别。
        if _c and len(_c) >= 15:
            _fr4 = sum(1 for c in _c if c[5] >= _TALLR_HEAD * c[4]) / len(_c)
            _nl4 = sum(1 for h in T.strip_hlines(_sub)[1] if h[4] >= 8)
            if _fr4 >= 0.40 or _nl4 >= 6:
                _head_until = _i
                break
    # 第一遍: 算每个行带的几何特征 -> "确定接受(frac>=0.85)" / "可疑" / "丢弃"
    _MODE = os.environ.get("JP_ROWFILTER", "frac_abs")
    _plan = []          # [s, e, sub, stripped, hlines, accept, suspicious]
    for _bi, (s, e) in enumerate(bands):
        _R = _TALLR_HEAD if _bi < _head_until else _TALLR
        sub = content[s:e + 1]
        # 行带过滤: 区分"音符行"与"歌词行/文字行"。
        # 不能只按"瘦高块占比 frac"判 —— 大量版式把音符行与紧邻的歌词行粘在同一个
        # 行带里(如 Blue Berry Hill: 每个行带 = 简谱行 + 其下英文歌词行), 此时 frac
        # 恒为 0.4-0.6, 整谱真音符会被误丢(实测 275 个真音符只剩 1 个)。
        # 故判据 = "占比高" 或 "瘦高块够多 + 有下划线/延音杠"。
        _stripped, _hlines = (None, [])
        _accept, _susp = True, False
        if _MODE != "none":
            _stripped, _hlines = T.strip_hlines(sub)
            _cs = [c for c in T.components(_stripped) if 10 <= c[5] <= 50 and c[4] >= 4]
            _tall = [c for c in _cs if c[5] >= _R * c[4]]
            _frac = (len(_tall) / len(_cs)) if _cs else 0.0
            if _MODE == "frac":
                _accept = _frac >= 0.85
            elif _MODE == "bars":
                _accept = T.count_bars(sub, e - s + 1) >= T.BAR_THR
            else:  # frac_abs
                # 纯歌词行: 汉字也有竖笔(瘦高块 4-7 个), 但绝无下划线 -> 靠下划线剔除。
                # 粘连行带(音符+歌词粘一起): frac 0.4-0.6 但有下划线 -> 保留。
                _nline = sum(1 for h in _hlines if h[4] >= 8)
                # 高度齐整门(JP_ROWCV>0 时启用), 默认关(实测会误杀粘连行带里的真音符)。
                _cv_ok = True
                _cvthr = float(os.environ.get("JP_ROWCV", "0"))
                if _cvthr > 0 and _frac < 0.60 and len(_tall) >= 3:
                    _hs2 = sorted(c[5] for c in _tall)
                    _med2 = _hs2[len(_hs2) // 2]
                    _mean2 = sum(_hs2) / len(_hs2)
                    _sd2 = (sum((h - _mean2) ** 2 for h in _hs2) / len(_hs2)) ** 0.5
                    _cv_ok = (not _med2) or (_sd2 / _med2) <= _cvthr
                _accept = (_frac >= 0.85) or (len(_tall) >= 6 and _nline >= 1 and _cv_ok)
                # 全部候选行带都要过模型判定: 单靠 frac>=0.85 "确定接受" 会把标题/调号行
                # (如 `1=F 2/4`) 也放进来(实测 spring 因此多出 `1 - - - 'x` 5 个垃圾)。
                _susp = _accept
        if os.environ.get("JP_DEBUGBAND") == "1":
            _nn = len(_cs) if _MODE != "none" else -1
            _ff = _frac if _MODE != "none" else -1.0
            print(f"  [几何] y={s}-{e} n={_nn} frac={_ff:.2f} R={_R:.2f} "
                  f"{'接受' if _accept else '丢弃'}", file=sys.stderr)
        if not _accept:
            continue
        _plan.append([s, e, sub, _stripped, _hlines, True, _susp, _R])
    # 第二遍: 可疑行带交模型判"音符行 / 文字行"(几何判据无法区分"标题文字行"与
    # "音符+歌词粘连行带", 但模型看一行是简谱还是汉字文字很容易) -> 剔除文字行。
    if os.environ.get("JP_BANDCLS", "1") == "1":
        _si = [i for i, p in enumerate(_plan) if p[6]]
        if _si:
            _bc = [arr[_plan[i][0]:_plan[i][1] + 1] for i in _si]
            try:
                _fl = _classify_bands(_bc)
            except Exception:
                _fl = [True] * len(_si)
            for i, f in zip(_si, _fl):
                if not f:
                    _plan[i][5] = False
                    if os.environ.get("JP_DEBUGBAND") == "1":
                        print(f"  [行带] y={_plan[i][0]}-{_plan[i][1]} 模型判: 文字 -> 丢弃", file=sys.stderr)
    if os.environ.get("JP_DEBUGBAND") == "1":
        print(f"  [谱头边界] _head_until={_head_until} / 行带总数={len(bands)}", file=sys.stderr)
    # 第三遍: 从保留的行带里收集音符块
    for (s, e, sub, _stripped, _hlines, _accept, _susp, _R) in _plan:
        if not _accept:
            continue
        row_gray = arr[s:e + 1]
        be = Q.bar_extent(sub)
        # 音符行底 fallback + 高度基准: bar_extent 常因小节线被下划线/数字粘连而返回
        # None, 使 bound_to_note_row 退化为"无歌词拒绝"(crop 下沿 +8px 把紧邻的歌词
        # 并进来 -> 模型吐 '?'/'x')。故用"本行最高的一簇连通域"(音乐数字是本行最大符号)
        # 估计音符行 y 范围 + 数字参考高度 _h_ref, 用于剔除更矮的歌词字母。
        _h_ref = 0
        if _stripped is None:
            _stripped, _ = T.strip_hlines(sub)
        _cs2 = [c for c in T.components(_stripped) if 10 <= c[5] <= 45 and c[4] >= 3]
        # 参考高度用"瘦高块的中位数", 不用 max: max 会被少数高竖线/括号(43-45px)
        # 抬飞, 导致真数字(21-22px)被高度门整类误杀(实测幸福花园 255->61)。
        # 参考高度也必须用"按行带的可变阈值" _R, 不能用固定 1.4: 《卖报歌》引子行的
        # 数字 h/w=1.20-1.29 不算瘦高(1.4), 于是 _tall2 只剩两个 `:||:(` 记号(h=38/26),
        # h_ref 被抬成 26 -> 高度门(0.8*26=20.8) 把全部 h=18 的真数字杀光(实测该行
        # crop_note_regions 切出 25 个块, 最后只留 1 个)。
        _tall2 = [c for c in _cs2 if c[5] >= _R * c[4]]
        if _tall2:
            _hs = sorted(c[5] for c in _tall2)
            _h_ref = _hs[len(_hs) // 2]
            _dig = [c for c in _tall2 if c[5] >= 0.8 * _h_ref]
            if _dig and be is None:
                be = (min(c[1] for c in _dig), max(c[3] for c in _dig))
        _regs = T.crop_note_regions(sub)
        _nblk = len(blocks)
        if os.environ.get("JP_DEBUGBAND") == "1":
            print(f"  [切块] y={s}-{e} be={be} h_ref={_h_ref} "
                  f"crop_note_regions={len(_regs)}", file=sys.stderr)
        for (nx0, nx1, ny0, ny1) in _regs:
            crop = Q.bound_to_note_row(row_gray, nx0, nx1, ny0, ny1, be)
            if crop is None or crop.size == 0:                continue
            bt = classify_block(crop)
            # 碎片块过滤: 若判为数字块, 但块内没有任何"像数字的连通域"(高大>=12 且宽>=4),
            # 说明这只是线条/空白碎片 -> 绝不能送进模型, 否则它会幻觉出一个数字或 'x'。
            if bt == "digit":
                big = [c for c in T.components(crop < T.TOL) if c[5] >= 12 and c[4] >= 4]
                if not big:
                    continue
                # 高度门: 块内主连通域高度须接近本行数字参考高度(>=0.8*_h_ref)。
                # 歌词字母(尤其英文 l/h/b/d 等竖笔)虽然 h>w, 但明显矮于音乐数字,
                # 此门把这类"假数字"剔除(实测 Blue Berry Hill 的 ? 从 120 降到接近 0)。
                if _h_ref and max(c[5] for c in big) < 0.8 * _h_ref:
                    continue
            blocks.append((s, nx0, nx1, ny0, ny1, crop, bt))
        if os.environ.get("JP_DEBUGBAND") == "1":
            print(f"       -> 该行带产出块 {len(blocks) - _nblk}", file=sys.stderr)
        # 连音线/圆滑线检测(用户明确的记谱规则):
        #   两个数字一样 + 弧线 = 连音线(~);  不一样 + 弧线 = 圆滑线( ( ) )
        # 几何判据(实测标定):
        #   * **时值线**(数字下方的直线)高度只有 1-3px, 而且已被 strip_hlines 剥掉 -> 排除
        #   * **连音线/圆滑线**是弧, 高度 4-14px, 残留在 stripped 内容里 -> 就是它
        #   * 所以候选 = stripped 里 w>=12 且 4<=h<=14 的细连通域
        #     (只看 _hlines 会一条都找不到 —— 实测《兄弟抱一下》的弧线 h=8 没被剥掉)
        _blk = list(range(_nblk, len(blocks)))
        if _blk:
            # 块元组是 (s, nx0, nx1, ny0, ny1, crop, bt): ny1 在**索引 4**,
            # 索引 5 是 crop 数组(拿它做 max 会 ValueError: 数组形状不一)
            _dbot = max(blocks[i][4] for i in _blk)          # 本行数字的底
            _dtop = min(blocks[i][3] for i in _blk)          # 本行数字的顶
            _cand = [c for c in T.components(_stripped)
                     if c[4] >= 12 and 4 <= c[5] <= 14
                     and (c[1] >= _dbot - 6 or c[3] <= _dtop + 6)]
            for _k, c in enumerate(_cand):
                _mem = [i for i in _blk
                        if c[0] - 4 <= (blocks[i][1] + blocks[i][2]) / 2.0 <= c[2] + 4]
                # 只认"两到六个音"的弧线: 用户规则讲的是两个数字之间;
                # 而且实测长线(w=417/545 罩 9-22 个音)是整句时值线/谱线, 不是连线。
                if 2 <= len(_mem) <= 6:
                    for i in _mem:
                        _curve_of[i] = (s, _k)
    # 调试: JP_DRAWBOXES=<out.png> 把"行带 + 被接受的块"画到原图上, 供人眼核对切分对不对。
    # **必须画在真函数里** —— 另抄一份几何必漂: 2026-09-21 用旧版 frac<0.85 规则另写一份去画
    # 《浮夸》, 19 个行带只留 2 个、23 个框, 与真管线差到看不出是一回事 ✗。
    # JP_DRAWONLY=1 时画完即返回(不加载模型、不占 GPU), 用于"只想看图"的场合。
    _dbgout = os.environ.get("JP_DRAWBOXES")
    if _dbgout:
        from PIL import Image as _PImage
        from PIL import ImageDraw as _PImageDraw
        _im = _PImage.fromarray(arr).convert("RGB")
        _dr = _PImageDraw.Draw(_im)
        for (_bs, _be) in bands:                     # 灰 = 行带范围(被整行丢弃的也画出来, 好对比)
            _dr.rectangle([1, _bs, _im.size[0] - 2, _be], outline=(185, 185, 185), width=1)
        for (_s, _nx0, _nx1, _ny0, _ny1, _crop, _bt) in blocks:
            _col = (0, 170, 0) if _bt == "digit" else (
                (0, 0, 230) if _bt == "dash" else (230, 0, 0))
            _dr.rectangle([_nx0, _s + _ny0, _nx1, _s + _ny1], outline=_col, width=2)
        _im.save(_dbgout)
        print(f"[drawboxes] {_im.size[0]}x{_im.size[1]} 行带 {len(bands)} 个, 接受块 {len(blocks)} 个 "
              f"(绿=数字 蓝=延音杠 红=其它 灰=行带) -> {_dbgout}", file=sys.stderr)
        if os.environ.get("JP_DRAWONLY") == "1":
            return [], []

    # 阶段2: 批量识别数字块(一次前向多个, 大幅提速)
    digit_idx = [i for i, b in enumerate(blocks) if b[6] == "digit"]
    digits = {}
    if digit_idx:
        nums = _digits_of_batch([blocks[i][5] for i in digit_idx])
        digits = dict(zip(digit_idx, nums))
    # 阶段2.5: x 复核 —— 单次 9 类识别会把汉字歌词误判为 'x'。只对 'x' 块做二元复核
    # ("打击记号 x 还是歌词文字?"), 判为歌词的改成 '-' (组装时跳过)。
    if os.environ.get("JP_X_RECHECK", "") == "1" and digits:
        x_idx = [i for i, v in digits.items() if v == "x"]
        if x_idx:
            re = _recheck_x([blocks[i][5] for i in x_idx])
            for i, r in zip(x_idx, re):
                if r != "x":
                    digits[i] = "-"
    # 阶段3.5: 行带级过滤 —— 调号/拍号行(如 `1=F 3/4`、`1=F 4/4 ♩=62`)会被当成
    # 音符行放进来: 它长得像记号, 连模型的"音符行/文字行"判定都会说是音符, 结果开头
    # 多出 `1 - - - 'x` 这类垃圾(实测 spring 多 5 个 token、MooЯlight Serenade 更多)。
    # 这类行只出现在**谱头**(前两个被接受的行带), 特征是"数字极少且占比低"。
    # 真音符行即便全是长音(1 - - -)也至少有若干数字, 故要求 >=4 个数字才留下。
    _by_band = {}
    for i, (s, nx0, nx1, ny0, ny1, crop, bt) in enumerate(blocks):
        _by_band.setdefault(s, []).append(i)
    _first_bands = sorted(_by_band)[:2]
    _drop = set()
    for _s in _first_bands:
        _idx = _by_band[_s]
        _nd = sum(1 for i in _idx
                  if blocks[i][6] == "digit" and digits.get(i, "?") not in ("-", "?"))
        if _nd < 4:
            _drop.update(_idx)
            continue
        # 已知问题(未修, 见 train-work/QA_findings.md):
        # 标题/调号行(如 `1=D 4/4 ♩=72 亲切、温馨地`)会单独成一个行带, 且带 11 个
        # "数字"(1=D、4/4、=72), 所以 `_nd < 4` 拦不住 -> 开头混进 `q1 qx - - - - 7 7 2 4 4 x x`。
        # 试过"带内按 y 中位数分簇丢上面的块": 无效 —— 实测谱头的数字块与音乐的数字块
        # 会被 crop_note_regions 粘成**同一个块**(如 x[83,96] y[45,105] 高 60px), 信息已丢。
        # 又试过按 frac(瘦高块占比)丢: 谱头带 frac=0.38 vs 音乐带 0.83-0.97, 看似可分,
        # 但实测 150 个谱里"第一带 frac<0.6"占 31%, 且另有多半落在"两带都不高"的 54% 里
        # (真的第一行音乐 frac 也可以很低), 贸然丢会**整行丢音乐**。故暂不上线。
    # 阶段3: 组装 token
    toks, meta = [], []
    # 连音线/圆滑线: 同一条弧线罩住的块, 同音 -> 每两个之间插 '~';
    # 不同音 -> 首尾插 '(' ')'(圆滑线)。只对"留下来了"的块生效。
    _cmark_before, _cmark_after = {}, {}
    _groups = {}
    for _i, _cid in _curve_of.items():
        _groups.setdefault(_cid, []).append(_i)
    for _cid, _mem in _groups.items():
        _mem = [i for i in sorted(_mem) if i not in _drop]
        if len(_mem) < 2:
            continue
        _dg = [digits.get(i) for i in _mem]
        if _dg[0] not in (None, "-", "?") and all(x == _dg[0] for x in _dg):
            for _i in _mem[:-1]:                    # 同音 -> 连音线
                _cmark_after[_i] = _cmark_after.get(_i, "") + " ~"
        else:                                        # 不同音 -> 圆滑线
            _cmark_before[_mem[0]] = _cmark_before.get(_mem[0], "") + "("
            _cmark_after[_mem[-1]] = _cmark_after.get(_mem[-1], "") + " )"
    for i, (s, nx0, nx1, ny0, ny1, crop, bt) in enumerate(blocks):
        if i in _drop:
            continue
        if i in _cmark_before:
            toks.append(_cmark_before[i].strip())
        lab = None
        if bt == "dash":
            lab = "-"
        elif bt == "rest":
            lab = "0"
        elif bt == "digit":
            d = digits.get(i, "?")
            if d in ("-", "?"):
                continue  # 模型判为歌词/非音符 -> 跳过(消 x/? 噪声)
            gd = geo_detect(crop)
            if d == "0":
                lab = BEAM_PRE[gd["beam"]] + "0"       # 休止符: 有时值, 无八度/附点
            else:
                lab = BEAM_PRE[gd["beam"]] + ","*gd["low"] + "'"*gd["voice"] + d + "."*gd["dotted"]
        if lab is None:
            continue
        toks.append(lab)
        # 框的 y 范围: 行带常和歌词粘在一起, 直接用行带高度会把框画得很长(实测
        # 《可惜不是你》的框横跨两三行)。所以取块内"主连通域"(音符本身)的紧致包围盒,
        # 找不到再退回行带范围。仅影响可视化, 不影响 token。
        _cy0, _cy1 = int(ny0), int(ny1)
        if bt == "digit":
            try:
                _big = [c for c in T.components(crop < T.TOL) if c[5] >= 12 and c[4] >= 4]
                if _big:
                    _m = max(_big, key=lambda c: c[5] * c[4])
                    # bound_to_note_row 的裁剪上界是 max(0, ny0 - T.PAD),
                    # 所以 crop 行 0 对应行带内的 max(0, ny0-T.PAD) 行
                    _off = max(0, int(ny0) - T.PAD)
                    if _m[3] - _m[1] >= 8:      # 框太小说明找错了 -> 回退行带范围
                        _cy0 = _off + _m[1]
                        _cy1 = _off + _m[3]
            except Exception:
                pass
        meta.append({"band": s, "s": s, "e": e, "x0": int(nx0), "x1": int(nx1),
                     "ny0": _cy0, "y1": _cy1, "btype": bt, "tok": lab})
        if i in _cmark_after:               # 连音线 '~' / 圆滑线 ')' 跟在这个音后面
            toks.extend(_cmark_after[i].split())
    return toks, meta

def render(img_path, out_png):
    """转写 + 画标注框图(同一次运行, 保证 图==转写)。"""
    from PIL import Image, ImageDraw, ImageFont
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 10)
    except Exception:
        font = ImageFont.load_default()
    toks, meta = transcribe(img_path)
    # 与 transcribe 用同一尺度(过宽缩、过小放), 否则框会错位
    im = Image.open(img_path).convert("RGB")
    _tw = _target_w(im.width)
    if _tw != im.width:
        im = im.resize((_tw, max(1, int(round(im.height * _tw / im.width)))), Image.LANCZOS)
    dr = ImageDraw.Draw(im)
    W, H = im.size
    for b in meta:
        col = (0, 90, 255)
        if b["btype"] == "dash": col = (150, 150, 150)
        elif b["btype"] == "rest": col = (0, 150, 0)
        x0 = max(0, b["x0"] - 6); x1 = min(W - 1, b["x1"] + 6)
        y0 = max(0, b["s"] + b["ny0"] - 6); y1 = min(H - 1, b["s"] + b["y1"] + 6)
        dr.rectangle([x0, y0, x1, y1], outline=col, width=1)
        dr.text((x0 + 1, y0 + 1), b["tok"], fill=col, font=font)
    # JP_NOPNG=1 时不写标注图 —— 大批量转写时标注图约 1MB/张, 上万张会把磁盘撑爆。
    # 转写结果(token)在 txt 里, 标注图只是可视化, 可事后按需重生成。
    if os.environ.get("JP_NOPNG", "") != "1":
        im.convert("RGB").save(out_png)   # 源图可能是 RGBA/P, 存 JPEG 前必须转 RGB
    return toks, meta
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    img = sys.argv[1]
    outp = sys.argv[2] if len(sys.argv) > 2 else "train-work/transcribe_out.png"
    toks, meta = render(img, outp)
    print(f"音 {len(toks)}  -> {outp}")
    print(" ".join(toks))
