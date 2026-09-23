# -*- coding: utf-8 -*-
"""把 batch-out/*.txt (裸 token 序列) 转成 jianpu-db 的 scores/*.txt 格式。

jianpu-db 格式(见 D:/Documents_D/jianpu-db/README.md):
  %<文件名>
  MBID=<MusicBrainz 唯一标识>
  title=<曲名>
  type=work
  tag=...
  usertag=...
  tagroute=...
  transcriber=<转写者>
  %--
  <拍号 如 4/4>
  [subtitle=...]
  <jianpu-ly 音符>
  NextScore
  ...
  %END

我们只有图, 没有 MBID/usertag -> 留空待补(README 说 MBID 必填, 故加 TODO 注释)。
用法: py -3.13 tools/to_jianpu_db.py [--transcriber 名字]
输出: jianpu-db-out/scores/<name>.txt  (+ jianpu-db-out/progress.txt)
"""
import os, sys, glob, re, time, hashlib, html

sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = "batch-out/*.txt"
OUTDIR = "jianpu-db-out/scores"
TRANSCRIBER = "jianpu2-auto"
NOTE_RE = re.compile(r"^[,']*[qsdh]*[,']*[1-7x0][.,'qsdh-]*$")

def fix_mojibake(s):
    """爬虫存文件名时把 UTF-8 字节当 Latin-1 -> 还原中文。

    注意: 对"本来就正常的中文"绝不能碰 —— 中文无法 encode 成 latin-1,
    会被 errors='ignore' 静默丢掉, 只剩 ASCII
    (实测 '儿歌联唱2（洪波编曲）' 被吃成 '2', 标题全毁)。

    三级策略(实测 2255 个 scores 里 152 个标题是 mojibake):
      1. 严格解码成功 -> 用结果
      2. 严格失败(字节不可逆, 爬虫把部分字节换成了 '_') -> **有损解码**,
         丢掉无效字节、保留能解出的中文片段(实测 40 个能这样救回)
      3. 有损也解不出中文 -> 返回原串, 由 title_of 兜底成可识别的占位名
    """
    try:
        s.encode("latin-1")          # 含真中文会抛异常 -> 说明本来就不是 mojibake
    except UnicodeEncodeError:
        return s
    b = s.encode("latin-1")
    try:
        r = b.decode("utf-8")
        return r if r else s
    except Exception:
        pass
    r = re.sub(r"[\x00-\x1f\x7f-\x9f]", "", b.decode("utf-8", errors="ignore")).strip()
    return r if re.search(r"[\u4e00-\u9fff]", r) else s

def fix_voice(t):
    """我们的 token 高八度撇在前('1) -> jianpu-ly 撇在后(1')；低八度逗号保持在前。"""
    m = re.match(r"^([qsdh]*)([,']*)([1-7x0])([.,'qsdh-]*)$", t)
    if not m:
        return t
    beam, pre, dig, post = m.groups()
    lows = pre.count(","); ups = pre.count("'")
    post = post.replace("'", "")            # 撇只保留八度语义, 统一放数字后
    return beam + "," * lows + dig + "'" * ups + post

def clean_tokens(text):
    """裸 token 序列 -> 合法 jianpu-ly token(高八度撇移到数字后)。

    **连音线 `~` 必须留**(2026-09-22 修): 转写器会输出 `~`, 实测 2216/6618 份谱里有。
    原来只放行音符 token, 把它丢了 —— 音高不受影响, 但**连音线一丢, 一个长音就变成两个音,
    时值就错了** ✗。下游 jianpu-db 的 score.py 白名单本来就是
    `^[,']*[qsdh]*[,']*[1-7x0]` 或 `-` / `|` / `~`, 所以 `~` 是**它认的格式** ✓。

    `(` `)`(圆滑线, 4423 份谱里有)仍然丢掉: 下游白名单**不含**它们(会被静默丢弃),
    而我们在 token 流里对这两个括号的语义(圆滑线? 三连音?)没有验证过 ——
    宁可不写, 也不写下游解析器不认的东西。
    """
    out = []
    for t in text.split():
        if t == "-" or t == "~":
            out.append(t)
        elif NOTE_RE.match(t) and "?" not in t:
            out.append(fix_voice(t))
    return out

def title_of(name):
    """从 '草原的歌__jianpujia-341957' 提取曲名(并修 mojibake)。

    再清掉源站噪声后缀, 使 title 中立:
      问候歌简谱_儿歌演唱-简谱  ->  问候歌
      一分钱简谱(歌词)_儿歌_陈洲宏记谱-简谱  ->  一分钱
    另外剥掉曲集序号前缀(`10信念` -> `信念`), 但**不剥纯数字歌名**(`1874` 是陈奕迅的歌,
    不能变成空)。所以只在"数字后面紧跟汉字"时才剥。
    """
    base = name.split("__")[0]
    base = fix_mojibake(base).strip()
    # 零宽字符先去掉: U+200B 这类在源站标题里很常见(实测 63 个目录名), 肉眼看不见,
    # 但会一路带进**交付文件名**(`算什么男人__qupu123-242977`), 而且让曲名匹配失败 ✗
    base = re.sub(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]", "", base)
    # 砍掉"源站套壳": 不只 `简谱` 及之后, 还有**副标题/署名**类词。
    # 实测目录名是 `云朵上的草原` + `草原丁喜萨克斯原创曲` + `简谱_草原大哈演唱_…` 硬接起来的,
    # 只砍 `简谱` 会把整个副标题留下 -> 出现 `丁喜萨_斯`(萨克斯被下划线劈开)这种假人名 ✗,
    # 而人工审核标准是"只留曲名"(如 `燕子归来` / `云朵上的草原`)。
    base = re.sub(r"(原创曲|萨克斯风|萨克斯|词曲|作词|作曲|演唱|制谱|弹唱|演奏|简谱).*$", "", base)
    base = re.sub(r"[_-]?[（(][^（）()]*[)）]", "", base)  # 去括号注释
    base = re.sub(r"^\d{1,3}(?=[\u4e00-\u9fff])", "", base)   # 曲集序号前缀
    # **整段被重复**: 源站把标题渲染了两遍(h1 一份 + slug 一份), 爬虫两遍都拼进了目录名 ->
    #   `[英]GOODMORNINGTOYOU您早儿歌[英]GOOD_MORNING_TO_YOU您早儿歌简谱-简谱`
    # 上面那步只砍掉了"简谱"及之后, 重复的整段还留着 ✗。这里归一化(去非字母数字汉字、转小写)
    # 后若两半相同, 就只留"更像给人看的"那一半(下划线少的那个 = h1 版, 不是 slug 版)。
    # 只认长度 >= 3 的两半, 免得把 `nana` 这类正常歌名误砍。
    def _norm(x):
        return re.sub(r"[^0-9A-Za-z\u4e00-\u9fff]", "", x).lower()

    _n = len(base)
    for _i in range(max(1, _n // 3), _n - max(1, _n // 3) + 1):
        _a, _b = base[:_i], base[_i:]
        # 真重复是**紧挨着拼接**的(爬虫直接连起来); `Honey Honey` 这种带空格的正常歌名
        # 归一化后两半也相同, 但断点处有空白 -> 必须排除, 否则会把好名字砍坏 ✗
        if base[_i - 1].isspace() or base[_i].isspace():
            continue
        _na, _nb = _norm(_a), _norm(_b)
        if len(_na) >= 3 and _na == _nb:
            base = _a if _a.count("_") <= _b.count("_") else _b
            break
    base = base.strip("_- ")
    # 兜底: 名字里既没中文也没字母/数字(只剩 mojibake 残渣) -> 用可识别的占位名,
    # 而不是把 'å_2' 这种当标题(实测 100 个标题的字节彻底丢了, 救不回)。
    # 判据: 完全无中文/字母/数字 或者 仍含 latin-1 乱码字符且中文少于 2 个。
    # **纯数字歌名必须放行**(`1874` 是陈奕迅的歌, 曾经被判成'没内容'改名成 `未命名-…` ✗)
    _cjk = len(re.findall(r"[\u4e00-\u9fff]", base))
    _has_moji = bool(re.search(r"[\u00c0-\u00ff]", base))
    if (not re.search(r"[\u4e00-\u9fffA-Za-z0-9]", base)) or (_has_moji and _cjk < 2):
        sid = re.search(r"([A-Za-z]+\d*-\d+)$", name)
        base = f"未命名-{sid.group(1)}" if sid else "未命名"
    return base or name

def wd_qid(title):
    """查 Wikidata QID(中文歌覆盖远好于 MusicBrainz)。返回 (qid, label) 或 ('','')。"""
    import json, urllib.request, urllib.parse
    if len(title) < 2:
        return "", ""
    url = "https://www.wikidata.org/w/api.php?" + urllib.parse.urlencode(
        {"action": "wbsearchentities", "search": title, "language": "zh",
         "format": "json", "limit": 3})
    req = urllib.request.Request(url, headers={"User-Agent": "jianpu2-transcriber/0.1"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                d = json.load(r)
            hits = d.get("search", []) or []
            if not hits:
                return "", ""
            x = hits[0]
            return x.get("id", ""), x.get("label", "")
        except Exception:
            time.sleep(2.0 * (attempt + 1))
    return "", ""


def source_of(name):
    """从目录名推断来源站, 写进 tag= 便于溯源(数据集里混了三个源)。"""
    n = name.lower()
    if "qupu123" in n:
        return "qupu123"
    if "jianpujia" in n:
        return "jianpujia"
    if "jianpucn" in n:
        return "jianpu.cn"
    if "hot-crawl" in n:
        return "hot"
    return ""

def load_clean_titles(path="train-work/title_clean.tsv"):
    """读"文本模型洗过的曲名"(train-work/title_clean.tsv) -> {目录名: 清名}。

    用户口径(2026-09-22): 正常名字 = 除了必要的曲名没有多余的; 全量都喂给本地 Qwen3-1.7B
    洗过(train-work/refine_titles_llm.py), 再用 tools/tidy_title_clean.py 去掉书名号。
    这里**接在重建管线里**, 而不是事后改文件 —— 否则下一次重建又脏回去。
    只收"非空 / 不是 ? / 与原名不同 / <=40 字"的条目; 其余退回 title_of()。
    """
    m = {}
    if not os.path.exists(path):
        return m
    try:
        with open(path, encoding="utf-8") as f:
            next(f, None)
            for ln in f:
                p = ln.rstrip("\n").split("\t")
                if len(p) < 4:
                    continue
                full, orig, clean, changed = p[0], p[1], p[2], p[3]
                if clean in ("", "?") or changed != "1" or clean == orig:
                    continue
                if len(clean) > 40 or "\n" in clean:
                    continue
                m[full] = clean
    except Exception as ex:
        print(f"  [warn] 读 {path} 失败({type(ex).__name__}), 退回 title_of()", flush=True)
    return m


def load_clean_titles_soft():
    """优先用跑完的 title_clean.tsv; 还没有(清洗进行中/被中断)就用边跑边存的 .part.tsv。"""
    if os.path.exists("train-work/title_clean.tsv"):
        return load_clean_titles("train-work/title_clean.tsv")
    return load_clean_titles("train-work/title_clean.part.tsv")


def to_score(name, toks, transcriber, mbid="", kind="work", meter="4/4", mb_title="", wd="",
             out_name=""):
    # 标题先解 HTML 实体 —— 爬虫从网页取标题时没解码, 会把 `&nbsp;` 一路带进文件名和 title=
    # (实测 `苹果香&nbsp;&nbsp;.txt`)。这里是**根因**, 修在这里才不会下次重建又脏回去。
    title = html.unescape(mb_title or title_of(name))
    title = re.sub(r"\s+", " ", title.replace("\u00a0", " ")).strip() or title_of(name)
    # 外部标识(可选): 只有真查到才写; 查不到就不写 —— ID 不是必选项
    # `%` 行必须等于**真实文件名**: 撞名时文件名会带 `_2/_3` 序号,
    # 原来这里用 title 拼 -> `%夜曲.txt` 而文件叫 `夜曲_2.txt`, 下游按 % 行认名就对不上了 ✗
    pct = out_name or re.sub(r'[\\/:*?"<>|\s]+', "_", title).strip("_")[:60] or title
    lines = [f"%{pct}.txt"]
    if mbid:
        lines.append(f"MBID={mbid}")
    if wd:
        lines.append(f"Wikidata={wd}")
    lines += [
        f"title={title}",
        "tag=",                       # 衍生字段(score.py 由 usertag 算出), 生成时留空即可
        # usertag 也留空 —— **事后**由 `tools/tag_ocr_scores.py` 按 source= 回连下载目录
        # (批次名=当时爬谁的页 / 目录名里的语种·编配 / 曲名题材)批量补, 补不出的写 `todo=add tags`。
        # 为什么不在这里写: 这一步要读 images-prep 的目录名, 放在重建管线里会让"重建"依赖磁盘现状。
        "usertag=",
        "tagroute=",
        f"transcriber={transcriber}",
        # 状态分级: ok=人工校对过 / midi=由 MIDI 硬转的 / ocr=由图片 OCR 来的(本项目产出)
        # jianpu-db 的数据集只收 ok(白名单过滤), 所以机器产物不会混进 data.jsonl,
        # 但仍可在 data.json 里查到、逐首校对后升级。
        "status=ocr",
        "%--",
    ]
    # 来源(用户要求: 谱子必须能说出出处, 不然被问到没法答)。
    # 目录名形如 `浮夸__jianpucn-133666` -> 站点 + 站点 id。
    #
    # **`source=` 的值必须是"单个安全 token", 不能塞 URL**(2026-09-22 踩过的坑):
    # 下游 `score.py:make_link()` 会把它当**目录名**用(`by_source/<值>/…`),
    # 值里带 `:` `/` 空格 → `OSError [WinError 123]` → `parse_scores.py` 在第 1 首就崩,
    # `out.jsonl` 只剩 1 首(而 verify 当时只查"可解析/有曲目", 拿旧文件混过去了 ✗)。
    # 所以站点首页只放在**注释行**里(`%` 开头, 下游解析器会跳过), 不放进字段值。
    # **id 允许是"拼音别名"**(2026-09-22 新增): qupu123 有一部分谱页只有拼音网址
    # (`/tongsu/sizi/heseliuding.html` 这类), 页面里没有自己的数字 id, 站内搜索也搜不到它们
    # —— 实测《黑色柳丁》就是这种。用拼音当 id 仍然满足"单个安全 token"的要求,
    # 且 `% 出处` 仍写站点首页, 出处在目录名里可复核。旧行为(只认数字)会让这些谱掉进
    # 下面的兜底分支变成 `source=unknown` ✗。
    _ms = re.match(r"^(.*?)__([a-z0-9]+)-([0-9a-z_]+)$", name or "")
    if _ms:
        _site, _sid = _ms.group(2), _ms.group(3)
        _url = {"jianpucn": "http://www.jianpu.cn/",
                "qupu123": "https://www.qupu123.com/",
                "jianpujia": "https://www.jianpujia.com/"}.get(_site, "")
        lines.insert(len(lines) - 1, f"source={_site}-{_sid}")
        if _url:
            lines.insert(len(lines) - 1, f"% 出处 {_url}")
    else:
        # 兜底: 少数目录名没有 `__站点-id`(手工抓的 hot-crawl), 但**不能因此就不写来源** ——
        # 之前这样漏出 4 份无 source= 的谱(实测 `不潮不用花钱`/`相思遥`/`英雄_21qupu`/`英雄_qpcxw`)。
        # 顺序: ①目录里记的原页 URL(grab_sheet 现在会写 _source.txt) ②名字里认得出的站点 ③老实写 unknown。
        _srctxt = ""
        for _d in glob.glob(f"images-prep/*/{glob.escape(name)}/_source.txt"):
            try:
                _srctxt = open(_d, encoding="utf-8", errors="replace").read().strip().splitlines()[0]
            except Exception:
                _srctxt = ""
            if _srctxt:
                break
        _tok = next((t for t in ("21qupu", "qpcxw", "qinyipu", "gita") if t in (name or "")), "")
        if _srctxt:
            _host = re.sub(r"^https?://", "", _srctxt).split("/")[0]
            lines.insert(len(lines) - 1, f"source={_host or 'unknown'}")
            lines.insert(len(lines) - 1, f"% 出处 {_srctxt}")
        elif _tok:
            lines.insert(len(lines) - 1, f"source={_tok}")
        else:
            lines.insert(len(lines) - 1, "source=unknown")
            lines.insert(len(lines) - 1, f"% 出处未记录(本地 images-prep/hot-crawl/{name})")
    lines += [
        meter,
        "subtitle=score",
    ]
    # 音符: 每行最多 ~40 token(可读性), 不插入小节线(原谱小节未保留)
    W = 40
    for i in range(0, len(toks), W):
        lines.append(" ".join(toks[i:i + W]))
    lines.append("%END")
    return "\n".join(lines) + "\n"

def main():
    transcriber = TRANSCRIBER
    if "--transcriber" in sys.argv:
        transcriber = sys.argv[sys.argv.index("--transcriber") + 1]
    do_mbid = "--mbid" in sys.argv                 # 用 MusicBrainz 查 MBID
    do_meter = "--meter" in sys.argv               # 用 Qwen 认谱头拍号
    kind = "work"
    if "--kind" in sys.argv:
        kind = sys.argv[sys.argv.index("--kind") + 1]
    os.makedirs(OUTDIR, exist_ok=True)
    files = sorted(glob.glob(SRC))
    CLEAN = load_clean_titles_soft()
    print(f"曲名清洗表: {len(CLEAN)} 条(先用清名, 其余退回 title_of)", flush=True)
    n = 0
    n_local = 0
    _used_names = set()          # 输出文件名去重(撞名时加 _2/_3, 不加源 ID)
    for f in files:
        name = os.path.splitext(os.path.basename(f))[0]
        if name in ("progress",):
            continue
        toks = clean_tokens(open(f, encoding="utf-8").read())
        if len(toks) < 10:            # 太短(转写失败/空) -> 跳过
            continue
        title = CLEAN.get(name) or title_of(name)
        safe_base = re.sub(r'[\\/:*?"<>|\s]+', "_", title).strip("_")[:60] or name
        # 撞名处理: 不同源的谱常有同名标题(如 3 首《只是太爱你》), 直接覆盖会丢数据。
        # 文件名保持中立(只含曲名), 仅在冲突时加最小序号 _2/_3...
        safe = safe_base
        _k = 2
        while safe in _used_names:
            safe = f"{safe_base}_{_k}"
            _k += 1
        _used_names.add(safe)
        meter = "4/4"
        # 拍号复用: **旧 scores 文件里已经认过拍号就别再调模型** —— detect_meter 要跑一次
        # Qwen 前向(~0.45s/份), 5678 份就是 40 分钟, 而绝大多数文件的拍号上一轮早就认过、
        # 内容也没变。实测把复用加上后速率从 ~130 份/分 提到上千份/分。
        # 旧文件不存在(或没有拍号行)时才回落到模型识别。
        _old = f"{OUTDIR}/{safe}.txt"
        if not os.path.exists(_old):
            # finalize 会把旧 scores 移到 scores-prev/(不再删) —— 拍号复用的落点在这里,
            # 否则每次重建都要对 6000+ 份谱重跑模型认拍号(~50 分钟 GPU) ✗
            _old = f"jianpu-db-out/scores-prev/{safe}.txt"
        _reuse = ""
        if os.path.exists(_old):
            try:
                _ls = open(_old, encoding="utf-8", errors="replace").read().splitlines()
                if "%--" in _ls:
                    for _l in _ls[_ls.index("%--") + 1: _ls.index("%--") + 4]:
                        if re.match(r"^\d+/\d+$", _l.strip()):
                            _reuse = _l.strip()
                            break
            except Exception:
                pass
        if do_meter and not _reuse:
            try:
                import jp_transcribe as JP
                hits = glob.glob(f"images-prep/*/{name}/*.jpg")
                # 用与转写一致的 pick_page(qupu123 优先 002.jpg 简谱页), 而不是"最大文件"
                # (最大文件常是五线谱页或损坏图 -> 拍号读错页/失败)。
                pages = [p for p in hits if "__pg" not in os.path.basename(p)]
                page = None
                if pages:
                    from batch_transcribe import pick_page
                    for src in glob.glob(f"images-prep/*/{name}/"):
                        page = pick_page(src)
                        if page:
                            break
                if page:
                    meter = JP.detect_meter(page) or "4/4"
            except Exception as ex:
                print(f"  拍号识别失败({type(ex).__name__}): {name[:30]}", flush=True)
        if _reuse:
            meter = _reuse
        mbid = ""
        mb_title = ""
        wd = ""
        if do_mbid:
            try:
                import mbid_lookup
                # 查询词清洗: 去 [日]/[英] 等前缀、去重复段、取主标题
                q = re.sub(r"^\[[^\]]{1,3}\]", "", title)          # 去 [日] 前缀
                q = re.split(r"[_\[]", q)[0]                       # 取 _ / [ 前
                # 文件名常把标题写两遍(中文+英文), 取第一个"段"(字母/汉字串)
                segs = re.findall(r"[A-Za-z][A-Za-z' ]{2,}|[\u4e00-\u9fff]{2,}", q)
                q = (segs[0] if segs else q)[:60].strip()
                # 标题过短(如 "2026"/"小")查 MB 极易误配(2026 -> Earth 2026) -> 不查
                if len(q) < 4:
                    q = ""
                if q:
                    mbid, hits = mbid_lookup.best_mbid(q, kind=kind)
                    mbid = mbid or ""
                    if hits:
                        cand = hits[0][1] or ""
                        # 相似度把关: MusicBrainz 对中文歌覆盖差, 模糊匹配常错配
                        # (如 "一分钱" 匹配到 "一切從簡") -> 不够像就丢弃, 宁可留空
                        from difflib import SequenceMatcher
                        sim = SequenceMatcher(None, q, cand).ratio()
                        if sim >= float(os.environ.get("MB_SIM", "0.65")):
                            mb_title = cand
                        else:
                            mbid = ""
                    if mbid:
                        print(f"  MBID {mbid}  title={mb_title!r}  <- {q}", flush=True)
                    else:
                        # MusicBrainz 未收录(中文歌普遍) -> 查 Wikidata QID 作可验证标识
                        wq, wlab = wd_qid(q)
                        if wq:
                            wd = wq
                            print(f"  Wikidata {wq} ({wlab})  <- {q}", flush=True)
                        time.sleep(0.5)
                time.sleep(1.1)       # MusicBrainz 限流 ~1 req/s
            except Exception as ex:
                print(f"  MBID 查询失败({type(ex).__name__}): {title[:30]}", flush=True)
                # MusicBrainz 限流/失败时也要试 Wikidata(否则中文歌会全被漏掉)
                try:
                    q = re.sub(r"^\[[^\]]{1,3}\]", "", title_of(name))
                    q = re.split(r"[_\[]", q)[0]
                    segs = re.findall(r"[A-Za-z][A-Za-z' ]{2,}|[\u4e00-\u9fff]{2,}", q)
                    q = (segs[0] if segs else q)[:40].strip()
                    if len(q) >= 2:
                        wq, wlab = wd_qid(q)
                        if wq:
                            wd = wq
                            print(f"  Wikidata {wq} ({wlab})  <- {q}", flush=True)
                except Exception:
                    pass
                time.sleep(1.1)
        # **title= 必须和文件名同源** —— 上面 title 已经优先取了文本模型的清名,
        # 但 to_score 内部是 `mb_title or title_of(name)`, 不显式传下去就会退回 title_of(),
        # 结果文件名是清名、title= 还是旧名(实测就是这么漏的) ✗
        _txt = to_score(name, toks, transcriber, mbid=mbid, kind=kind,
                        meter=meter, mb_title=(mb_title or title), wd=wd, out_name=safe)
        # **保留旧文件里的人工标记** —— 重建是"清空再写", 会把 todo= / preferred= 冲掉 ✗
        # (实测: 一边打 todo 一边被 finalize 的 scores 重建擦掉, 计数从 351 掉到 240)。
        # 这些字段本来就是给人/下游看的, 不属于自动生成内容, 必须继承。
        # finalize 现在把旧 scores **移到 scores-prev/**(不再删除), 所以这里也去那儿找 ——
        # 顺带让**拍号复用**重新生效(否则每次重建都要对 6000+ 份谱重跑一次模型认拍号, ~50 分钟 GPU)。
        _oldp = f"{OUTDIR}/{safe}.txt"
        if not os.path.exists(_oldp):
            _oldp = f"jianpu-db-out/scores-prev/{safe}.txt"
        if os.path.exists(_oldp):
            try:
                _old = open(_oldp, encoding="utf-8", errors="replace").read()
                for _m in re.finditer(r"^(todo=.*|preferred=\d+)$", _old, re.M):
                    if _m.group(1) not in _txt:
                        _txt = _txt.replace("%--", _m.group(1) + "\n%--", 1)
            except Exception:
                pass
        with open(f"{OUTDIR}/{safe}.txt", "w", encoding="utf-8") as g:
            g.write(_txt)
        n += 1
        if not mbid:
            n_local += 1
    print(f"转换完成: {n} 个 -> {OUTDIR}/  (MBID {'已查' if do_mbid else '未查'}, 占位 {n_local} 个)")
    with open("jianpu-db-out/progress.txt", "w", encoding="utf-8") as g:
        g.write(f"转换 {n} 个 (源 {len(files)} 个, mbid={do_mbid})\n")

if __name__ == "__main__":
    main()
