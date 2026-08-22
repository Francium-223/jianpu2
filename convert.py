#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
简谱图片 → jianpu-db 格式批量转换（本地 Ollama + Qwen2.5-VL）

输出严格遵循 jianpu-db (https://github.com/your-name/jianpu-db) 的曲谱文件规范:
  - 听感记谱: 大调一级记作 1, 小调一级记作 ,6 (谱面标 6=Xm 时, 主音 6/6'/6'' 自动降八度)
  - 只记特征性线性旋律 (无和弦/无歌词)
  - 元数据区: MBID= / title= / type= / transcriber= / (alias=) / usertag=(可选)
  - %-- 分隔线, 正文: 拍号 + subtitle=段落 + NextScore 分段 + R{}/A{} 重复 + %END

依赖:
  1. 安装并启动 Ollama:  https://ollama.com
  2. 拉取视觉模型:       ollama pull qwen2.5vl:7b   (显存小用 qwen2.5vl:3b)
  3. jianpu_ly 库:       仓库自带 vendor/ 或 pip install jianpu-ly

用法:
  # 转换爬虫下载的目录 (每首歌一个子目录, 含 song.json)
  python convert.py --input images/jianpucn --out scores-out

  # 指定转写者 (否则不写 transcriber= 行, 避免空值)
  python convert.py --input images/qinghuaci --out scores-out --transcriber 你的ID

  # 加 usertag / 手动指定 MBID / 尝试 MusicBrainz 自动查询 MBID
  python convert.py --input images/jianpucn --tags 儿歌,华语 --mbid 310b3b07-ec9f-3e88-9fd8-529c17478179
  python convert.py --input images/jianpucn --lookup-mbid

  # 单张图片 / 只看不跑
  python convert.py --input images/xxx.jpg --out scores-out
  python convert.py --input images/jianpucn --dry-run

输出 (out 目录):
  <歌名>__<站点>-<id>.txt    jianpu-db 格式曲谱文件 (可直接放入 jianpu-db/scores/)
  <歌名>__<站点>-<id>.ly     jianpu-ly 渲染预览 (验证用)
  <歌名>__<站点>-<id>.trans  模型原始转写文本 (人工校对用)
  <歌名>__<站点>-<id>.err    转换失败原因
  summary.csv                 汇总表
"""
import argparse
import base64
import csv
import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.parse
import urllib.request

# --- 10 秒进度报告器: 每 10 秒刷新 progress.txt, 便于实时查看 ---
_PROGRESS_LOCK = threading.Lock()
_CURRENT = "启动中"
_STARTED = time.time()
_PROGRESS_STOP = threading.Event()


def _progress_loop():
    while not _PROGRESS_STOP.is_set():
        with _PROGRESS_LOCK:
            text = _CURRENT
        elapsed = int(time.time() - _STARTED)
        line = (f"{time.strftime('%H:%M:%S')} | 已运行 {elapsed // 60}分{elapsed % 60:02d}秒"
                f" | {text}\n")
        try:
            with open("progress.txt", "w", encoding="utf-8") as f:
                f.write(line)
        except Exception:
            pass
        _PROGRESS_STOP.wait(10)


def set_progress(text):
    global _CURRENT
    with _PROGRESS_LOCK:
        _CURRENT = text


def start_progress_reporter():
    _PROGRESS_STOP.clear()
    threading.Thread(target=_progress_loop, daemon=True).start()


def stop_progress_reporter():
    _PROGRESS_STOP.set()

# jianpu_ly: 优先用 pip 装的, 否则用仓库自带 vendor/
try:
    import jianpu_ly  # noqa
except ImportError:
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "vendor"))
    import jianpu_ly  # noqa

PROMPT = """你是简谱(数字简谱)识别与转写专家。你的输出将进入规范化简谱数据集 jianpu-db, 必须严格遵守其转写规范。

转写规范:
1. 只输出乐谱正文, 不要任何解释、不要代码块标记(```)、不要多余文字。
2. 第一行报告谱面调号: 格式 #KEY 1=C 或 #KEY 6=Am (小调谱通常写 6=Xm); 谱面没有调号就写 #KEY none。
3. 第二行报告拍号: 格式 #TIME 4/4 (谱面没有就按小节内音符时值推断); 若有速度标记再写一行 #TEMPO 4=85。
4. 音符一律按谱面印刷的度数转写, 不要自行移调。大调谱(1=X)度数照抄; 小调谱(6=Xm)也照度数抄写, 移调由后续程序处理。
5. 只记最具有特征性的、响度最大的线性旋律(单声部)。忽略伴奏、和弦、歌词、指法、演奏标记。
6. 音符用 1-7, 休止符 0。高八度加 ' (如 1'), 低八度加 , (如 5,); 升降号跟在数字后: #4、b7。
7. 时值: 四分音符直接写数字 (如 1); 八分前缀 q (q1); 十六分 s (s1); 三十二分 d (d1); 二分音符 1 -; 附点二分 1 - -; 全音符 1 - - -; 附点音符在时值标记后加点 (q1. 或 1.)。每个音符都要标清时值。
8. 圆滑线用 ( 和 ), 延音线用 ~ (如 1 ~ 1), 三连音 3[ q1 q1 q1 ], 前倚音 g[#45]。
9. 完全相同的重复乐句可以省略不记, 或用 R{ ... } (默认重复2遍); 不同结尾用 R{ ... } A{ ... | ... }。
10. 若谱面明显分为不同段落, 每段以 subtitle=段落名 开头、NextScore 分隔; 段落名推荐 intro/layer/verse/pre-chorus/chorus/interlude/bridge/outro/crazy-piano; 无法确定就只写一段, 不要编造段落名。
11. 多张图是同一首曲子的连续页面, 继续转写, 不要重复开头。

只输出乐谱正文。"""


# ---------------------------------------------------------------- 工具函数

def strip_fences(text):
    text = text.strip()
    text = re.sub(r"^```[a-zA-Z]*\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    return text.strip()


def ollama_chat(host, model, prompt, images_b64, timeout=120):
    """调用 Ollama /api/chat (stream=false)。返回 (ok, content_or_error)。

    超时 120s: 模型挂起时应快速失败, 让自愈机制尽快重启服务器。
    """
    payload = {
        "model": model,
        "stream": False,
        "messages": [{"role": "user", "content": prompt, "images": images_b64}],
        "options": {"temperature": 0.1, "repeat_penalty": 1.3, "num_ctx": 8192},
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(host.rstrip("/") + "/api/chat", data=data, headers={
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            resp = json.loads(r.read().decode("utf-8"))
        if "error" in resp:
            return False, resp["error"]
        return True, resp["message"]["content"]
    except urllib.error.HTTPError as e:
        try:
            body = json.loads(e.read().decode("utf-8"))
            return False, body.get("error", f"HTTP {e.code}")
        except Exception:
            return False, f"HTTP {e.code}: {e.reason}"
    except Exception as e:
        return False, f"{type(e).__name__}: {e}"


def clean_title(raw):
    """把爬虫标题清洗成通用曲名 (jianpu-db 的 title 要求现时通用名称)。"""
    t = (raw or "").replace("&nbsp;", " ").replace("&amp;", "&").strip()
    # 按这些标记截断 (长匹配优先)
    cuts = ["尤克里里弹唱谱", "吉他弹唱谱", "尤克里里谱", "小提琴谱", "手风琴谱",
            "电子琴谱", "钢琴谱", "吉他谱", "葫芦丝谱", "萨克斯谱", "古筝谱",
            "二胡谱", "笛箫谱", "弹唱谱", "原版谱", "简谱", "曲谱", "歌谱",
            "（歌词）", "(歌词)", "（简谱）", "(简谱)"]
    pos = len(t)
    for c in cuts:
        i = t.find(c)
        if 0 <= i < pos:
            pos = i
    t = t[:pos]
    # 再按分隔符截断 (描述后缀, 如 _儿歌_xxx、—xxx、-xxx)
    for sep in ["_", "—", "–", "-"]:
        i = t.find(sep)
        if 0 < i < len(t) - 1:
            t = t[:i]
    t = t.strip().strip("。！!· ")
    return t


ARTIST_STOP = {"儿歌", "歌词", "动画", "影视", "主题曲", "插曲", "片尾曲", "片头曲",
               "简谱", "曲谱", "歌谱", "伴奏", "弹唱", "合唱", "独唱", "钢琴", "吉他",
               "版本", "现场", "录音", "混音", "串烧", "翻唱", "原唱", "记谱", "制谱"}


def guess_artist(raw_title):
    """从爬虫标题启发式猜歌手 (仅作 MusicBrainz 过滤用, 猜错只是降置信度)。

    模式1: "外婆的澎湖湾简谱_卓依婷_澎湖湾的情怀" -> 卓依婷 (简谱/歌词等标记后的第一段)
    模式2: "天长地久电影_解语花_插曲简谱_白云演唱" -> 白云 (xx演唱)
    """
    t = raw_title or ""
    m = re.search(r"([\u4e00-\u9fa5A-Za-z0-9·]{1,8})演唱", t)
    if m:
        return m.group(1)
    for sep in ["_", "—", "–", "-"]:
        parts = [p for p in t.split(sep) if p]
        if len(parts) >= 2 and any(k in parts[0] for k in ("简谱", "歌词", "曲谱", "歌谱")):
            cand = parts[1].strip()
            if cand and cand not in ARTIST_STOP and not any(k in cand for k in ARTIST_STOP) \
                    and 1 <= len(cand) <= 8 and not re.search(r"\d", cand):
                return cand
    return ""


def sanitize(name, fallback="song"):
    name = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", name or "")
    name = re.sub(r"\s+", " ", name).strip().strip("._ ")
    return name[:120] or fallback


def musicbrainz_search(kind, title, artist):
    """MusicBrainz 搜索 work/recording。返回候选列表 [{id,title,artists,score}]。"""
    clauses = [f'{kind}:"{title}"']
    if artist:
        clauses.append(f'artist:"{artist}"')
    url = ("https://musicbrainz.org/ws/2/" + kind + "/?query="
           + urllib.parse.quote(" AND ".join(clauses)) + "&fmt=json&limit=5")
    req = urllib.request.Request(url, headers={
        "User-Agent": "jianpu2-converter/1.0 (https://github.com/ssb22/jianpu-ly)",
    })
    with urllib.request.urlopen(req, timeout=20) as r:
        data = json.loads(r.read().decode("utf-8"))
    out = []
    for it in data.get(kind + "s", []):
        if kind == "work":
            artists = [a.get("name", "") for a in it.get("artists", [])]
        else:
            artists = [a.get("name", "") for a in it.get("artist-credit", [])]
        out.append({"id": it["id"], "title": it.get("title", ""),
                    "artists": artists, "score": int(it.get("score", 0))})
    return out


def musicbrainz_lookup(title, artist):
    """自动查找 MBID, 分级置信度。

    返回 (mbid, kind, confidence, matched) 或 (None, None, None, candidates):
      confidence:
        'high'   标题精确 + 歌手匹配 + score>=90        → 直接填
        'medium' 标题精确但无歌手佐证/歌手对不上, 或近似标题(繁简差异) → 填但标记复核
        'low'    标题只是近似                       → 不填
    原则: 错配比没有更糟 (空 MBID 只是进不了流水线, 错 MBID 是污染数据)。
    """
    def norm(s):
        return re.sub(r"\s+", "", s.lower())

    def title_ok(cand):
        """精确匹配优先; 繁简差异等用字符重合度兜底。返回 'exact'/'near'/None。"""
        ct = norm(cand["title"])
        if ct == norm(title):
            return "exact"
        if cand["score"] >= 90 and len(ct) >= 2:
            shared = len(set(ct) & set(norm(title)))
            if shared / max(len(ct), len(norm(title))) >= 0.5:
                return "near"
        return None

    def artist_ok(cand):
        if not artist:
            return False
        return any(artist in a or a in artist
                   or len(set(artist) & set(a)) >= 2 for a in cand["artists"])

    candidates = []          # (kind, cand)
    seen = set()
    for kind in ("work", "recording"):
        try:
            hits = musicbrainz_search(kind, title, artist or None)
        except Exception:
            hits = []
        for c in hits:
            if c["id"] not in seen:
                seen.add(c["id"])
                candidates.append((kind, c))
        time.sleep(1.1)  # MusicBrainz 限速 1 req/s

    if artist and not candidates:
        # 歌手过滤一无所获 → 歌手可能猜错, 回退裸标题查询
        for kind in ("work", "recording"):
            try:
                hits = musicbrainz_search(kind, title, None)
            except Exception:
                hits = []
            for c in hits:
                if c["id"] not in seen:
                    seen.add(c["id"])
                    candidates.append((kind, c))
            time.sleep(1.1)

    ranked = []
    for kind, c in candidates:
        tm = title_ok(c)
        if not tm:
            continue
        a_ok = artist_ok(c)
        if tm == "exact" and a_ok:
            conf = "high" if c["score"] >= 90 else "medium"
        elif tm == "exact" and not artist:
            conf = "medium" if c["score"] >= 90 else "low"
        elif tm == "exact":
            conf = "medium" if c["score"] >= 90 else "low"  # 歌手对不上, 可疑
        else:
            conf = "medium" if c["score"] >= 90 else "low"  # 近似标题(繁简等)
        ranked.append((kind, c, conf))
    if not ranked:
        return None, None, None, candidates[:3]

    order = {"high": 0, "medium": 1, "low": 2}
    ranked.sort(key=lambda x: (order[x[2]], 0 if x[0] == "work" else 1, -x[1]["score"]))
    kind, c, conf = ranked[0]
    return c["id"], kind, conf, {"title": c["title"], "artists": c["artists"]}


# ------------------------------------------------------- jianpu-db 格式处理

def extract_controls(text):
    """提取模型输出中的 #KEY/#TIME/#TEMPO 控制行, 返回 (key, time, tempo, body)。"""
    key = time_sig = tempo = None
    body_lines = []
    for ln in text.splitlines():
        s = ln.strip()
        if s.startswith("#KEY"):
            key = s[4:].strip() or None
            if key and key.lower() in ("none", "无", "-"):
                key = None
        elif s.startswith("#TIME"):
            time_sig = s[5:].strip() or None
            if time_sig:
                m = re.search(r"\d+/\d+", time_sig)   # 容忍 D2/4 等粘连写法
                time_sig = m.group(0) if m else None
        elif s.startswith("#TEMPO"):
            tempo = s[6:].strip() or None
            if tempo and tempo.lower() in ("none", "无", "-"):
                tempo = None
        else:
            body_lines.append(ln)
    return key, time_sig, tempo, "\n".join(body_lines).strip()


def minor_tonic_fix(body, key):
    """jianpu-db 听感记谱: 小调主音降八度 (6→,6, 6'→6, 6''→6', 6,→,,6, 依此类推)。

    注意 jianpu-db 规范中低八度逗号写在数字前 (,6), 高八度撇号写在数字后 (6')。
    只处理谱面音符 token; 时值前缀 (q/s/d/h/c)、附点、延音线等原样保留。
    """
    if not key or not re.search(r"(?i)^6\s*=", key.replace(" ", "")):
        return body
    token_re = re.compile(r"^([sqdhc]?)6('+|,+)?([.\\-]*)$")
    out = []
    for ln in body.splitlines():
        if re.match(r"^\s*(?:subtitle=|NextScore|KeepLength|#|%)", ln):
            out.append(ln)
            continue
        parts = []
        for tok in ln.split():
            m = token_re.match(tok)
            if m:
                octave = m.group(2) or ""
                if octave.startswith("'"):
                    octave = octave[1:]           # 6' → 6, 6'' → 6'
                    tok = m.group(1) + "6" + octave + m.group(3)   # 撇号在数字后
                else:
                    octave = "," + octave         # 6 → ,6, 6, → ,,6
                    tok = m.group(1) + octave + "6" + m.group(3)   # 逗号在数字前
            parts.append(tok)
        out.append(" ".join(parts))
    return "\n".join(out)


def ensure_nextscore(body):
    """jianpu-db 分段规范: 第二个 subtitle= 之前自动补 NextScore (模型常漏)。
    模型常把 NextScore 与 subtitle= 写在同一行: 拆开并放到 subtitle= 之前。"""
    lines = body.splitlines()
    out = []
    seen_subtitle = False
    for ln in lines:
        s = ln.strip()
        if s.startswith("subtitle="):
            if "NextScore" in s:
                if seen_subtitle and (not out or out[-1].strip() != "NextScore"):
                    out.append("NextScore")
                s = s.replace("NextScore", "").strip()
                if not s:
                    continue
            elif seen_subtitle and (not out or out[-1].strip() != "NextScore"):
                out.append("NextScore")
            seen_subtitle = True
        out.append(ln if s == ln.strip() else s)
    return "\n".join(out)


def bar_beats(tok):
    """一个简谱 token 占几拍: 数字=1拍, q/s/d/h 前缀 = 1/2,1/4,1/8,1/16 拍,
    每 '-' +1拍, 附点逐次减半累加 (5.. = 1.75); 行首延续线 '-' 算1拍, barline 算0。"""
    if tok == "|":
        return 0.0
    if tok in ("-", "."):
        return 1.0   # jianpu-ly 把单独的 . 当延长线
    s = tok
    while s and s[0] in "#b',":      # 升降号/八度记号可在时值前缀前后 (q,5 / ,q5)
        s = s[1:]
    dur = ""
    if s and s[0] in "qsdh":
        dur, s = s[0], s[1:]
    while s and s[0] in "#b',":
        s = s[1:]
    m = re.match(r"^([0-7])([.,'\-]*)$", s)
    if not m:
        return 0.0
    b = {"q": 0.5, "s": 0.25, "d": 0.125, "h": 0.0625}.get(dur, 1.0)
    extra = b
    for ch in m.group(2):
        if ch == "-":
            b += 1.0
        elif ch == ".":
            extra /= 2
            b += extra
    return b


def rest_pads(missing):
    """生成补齐 missing 拍 (1/64 精度) 的休止 token 列表。
    1拍=0, 1/2=q0, 1/4=s0, 1/8=d0, 1/16=h0, 任意余数按二进制组合。"""
    n16 = round(missing * 16)          # 以 1/16 拍为最小单位
    pads = ["0"] * (n16 // 16)
    r = n16 % 16
    for val, tok in ((8, "q0"), (4, "s0"), (2, "d0"), (1, "h0")):
        while r >= val:
            pads.append(tok)
            r -= val
    return pads


def fix_bar_segment(seg, bpb):
    """把一个小节 (无 barline 的 token 列表) 补齐到 bpb 拍; 超拍时按 bpb 自动重分小节
    (保留全部音符, 模型的小节线常不可靠)。返回小节列表 (每个是 token 列表)。"""
    used = sum(bar_beats(t) for t in seg)
    if used > bpb + 0.001:
        bars, cur, acc = [], [], 0.0
        for t in seg:
            b = bar_beats(t)
            if cur and acc + b > bpb + 0.001:
                bars.append(cur)
                cur, acc = [], 0.0
            cur.append(t)
            acc += b
        if cur:
            bars.append(cur)
        out = []
        for bar in bars:
            u = sum(bar_beats(t) for t in bar)
            if u > bpb + 0.001:
                # 小节线/时值导致无法整齐切分: 保留不越界的前缀, 其余丢弃, 补休止
                keep, acc2 = [], 0.0
                for t in bar:
                    b = bar_beats(t)
                    if keep and acc2 + b > bpb + 0.001:
                        break
                    keep.append(t)
                    acc2 += b
                bar = keep + rest_pads(bpb - acc2)
            elif u < bpb - 0.001:
                bar = bar + rest_pads(bpb - u)
            out.append(bar)
        return out
    if used < bpb - 0.001:
        return [seg + rest_pads(bpb - used)]
    return [seg]


def auto_bar(toks, bpb):
    """无 barline 的行: 按 bpb 拍自动分小节并补全。返回小节列表。"""
    bars, cur, acc = [], [], 0.0
    for t in toks:
        b = bar_beats(t)
        if cur and acc + b > bpb + 0.001:
            bars.append(cur)
            cur, acc = [], 0.0
        cur.append(t)
        acc += b
    if cur:
        bars.append(cur)
    out = []
    for bar in bars:
        out.extend(fix_bar_segment(bar, bpb))
    return out


def fix_repeat_line(ln, bpb):
    """处理含 R{}/A{} 的行:
    - 空块: R{ } 保留 (作为 A{ 的锚), 空 A{ } 丢弃; 孤立 } 丢弃; 未闭合块丢开括号保留音符
    - A{ 前没有 R{ 时整行压平为普通音符行 (jianpu-ly 会崩)
    - 纯块行: 各块内容按 bpb 补全小节后保留括号 (jianpu-ly 跨块累计 barPos)"""
    toks = ln.split()
    blocks, cur, opener = [], [], None
    prefix, has_outside_notes = [], False
    struct_re = re.compile(r"^(?:subtitle=.*|NextScore|KeepLength|%.*)$")
    for t in toks:
        if re.match(r"^(?:R\d*|A)\{$", t):
            if opener is not None:          # 异常嵌套: 压平
                prefix.extend(cur)
                has_outside_notes = True
            opener, cur = t, []
        elif t == "}" and opener is not None:
            if cur or opener.startswith("R"):
                blocks.append((opener, cur))
            opener, cur = None, []
        elif opener is not None:
            cur.append(t)
        elif t == "}":
            continue                        # 孤立 } 丢弃
        elif struct_re.match(t) or t == "|":
            prefix.append(t)
        else:
            has_outside_notes = True
            prefix.append(t)
    if opener is not None:                  # 未闭合: 丢开括号保留音符
        prefix.extend(x for x in cur if x != "|")
        has_outside_notes = True
    struct = [t for t in prefix if struct_re.match(t)]
    # A{ 前没有同行的 R{ → 压平 (jianpu-ly 的 A{ 需要 R{ 撑场)
    seen_r = any(op.startswith("R") for op, _ in blocks)
    bad_a = any(op.startswith("A") and not seen_r for op, _ in blocks)
    if bad_a or (not blocks and any(x not in struct and x != "|" for x in prefix)):
        has_outside_notes = True
    if not blocks:
        notes = [t for t in prefix if t != "|" and not struct_re.match(t)]
        bars = auto_bar(notes, bpb) if notes else []
        if not bars:
            return " ".join(struct)
        return " ".join(struct + " | ".join(" ".join(b) for b in bars).split())
    if has_outside_notes or bad_a:
        notes = [t for t in prefix if t != "|" and not struct_re.match(t)]
        for _, content in blocks:
            notes.extend(x for x in content if x != "|")
        bars = auto_bar(notes, bpb) if notes else []
        if not bars:
            return " ".join(struct)
        return " ".join(struct + " | ".join(" ".join(b) for b in bars).split())
    rebuilt = []
    for opener_tok, content in blocks:
        inner = [x for x in content if x != "|"]
        rebuilt.append(opener_tok)
        bars = auto_bar(inner, bpb) if inner else []
        if bars:
            rebuilt.extend(" | ".join(" ".join(b) for b in bars).split())
        rebuilt.append("}")
    return " ".join(prefix + rebuilt)


def fix_bars(body, time_sig=None):
    """小节规范化, 保证 jianpu-ly 不报 bar 错误:
    - 每个小节都补休止到整拍 (jianpu-ly 跨行累计 barPos, 中段小节也会影响末尾校验)
    - 无 barline 的行按拍号自动分小节
    - 超拍小节截断过界音符 (草稿容错, 反正要人工修订)"""
    bpb = 4.0
    m = re.match(r"^(\d+)/(\d+)$", (time_sig or "").strip())
    if m:
        bpb = int(m.group(1)) * 4.0 / int(m.group(2))   # 换算成四分音符拍数
    out = []
    for ln in body.splitlines():
        toks = ln.split()
        if not toks or "{" in ln or "}" in ln:
            if "{" in ln or "}" in ln:
                out.append(fix_repeat_line(ln, bpb))   # R{}/A{} 行: 块内补全小节
            else:
                out.append(ln)
            continue
        if not any(re.search(r"[0-7]", t) or t == "-" for t in toks):
            out.append(ln)
            continue
        head = ""
        if re.match(r"^\d+/\d+$", toks[0]):   # 行内拍号 (防御): 摘出来原样放回
            head, toks = toks[0] + " ", toks[1:]
        if not toks:
            out.append(ln)
            continue
        toks = normalize_note_tokens(toks)    # 防御: 拆粘连延音线等
        if "|" not in toks:
            out.append(head + " | ".join(" ".join(b) for b in auto_bar(toks, bpb)))
            continue
        # 按 barline 切段, 逐段补全
        segs, cur = [], []
        for t in toks:
            if t == "|":
                segs.append(cur)
                cur = []
            else:
                cur.append(t)
        segs.append(cur)
        rebuilt = []
        for seg in segs:
            bars = fix_bar_segment(seg, bpb)
            rebuilt.append(" | ".join(" ".join(b) for b in bars))
            rebuilt.append("|")
        out.append((head + " ".join(rebuilt)).strip())
    return "\n".join(out)


def build_score_file(mbid, title, stype, transcriber, usertag, alias, body, copyright_=""):
    """组装 jianpu-db 格式曲谱文件文本。"""
    lines = []
    if mbid:
        lines.append(f"MBID={mbid}")
    lines.append(f"title={title}")
    lines.append(f"type={stype}")
    if usertag:
        lines.append(f"usertag={usertag}")
    if alias and alias != title:
        lines.append(f"alias={alias}")
    if transcriber:
        lines.append(f"transcriber={transcriber}")
    if copyright_:
        lines.append(f"copyright={copyright_}")
    lines.append("%--")
    lines.append(body.strip())
    if not lines[-1].lower().endswith("%end"):
        lines.append("%END")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------- 主流程

def song_units(input_dir):
    """收集待转换单元: 每个含 song.json 的子目录, 或目录下单个图片。
    返回 [(title, artist, src, images, strips)]。NO_STRIPS 时忽略切片 (整图模式)。"""
    global NO_STRIPS
    units = []
    if os.path.isfile(input_dir):
        units.append((os.path.splitext(os.path.basename(input_dir))[0],
                      guess_artist(os.path.basename(input_dir)), input_dir, [input_dir], []))
        return units
    for name in sorted(os.listdir(input_dir)):
        p = os.path.join(input_dir, name)
        if os.path.isdir(p) and os.path.exists(os.path.join(p, "song.json")):
            with open(os.path.join(p, "song.json"), encoding="utf-8") as f:
                meta = json.load(f)
            title = meta.get("title") or name
            artist = meta.get("artist") or guess_artist(title)
            all_files = sorted(os.listdir(p))
            strips = [os.path.join(p, f) for f in all_files if "_strip_" in f
                      and f.lower().endswith((".jpg", ".jpeg", ".png"))]
            if NO_STRIPS:
                strips = []
            images = [os.path.join(p, f) for f in all_files
                      if f.lower().endswith((".jpg", ".jpeg", ".png", ".webp", ".gif"))
                      and "_strip_" not in f]
            # 多图歌曲的切片可能爆炸 (9图×8条=72), 草稿模式限 12 条
            if len(strips) > 12:
                step = len(strips) / 12.0
                strips = [strips[int(i * step)] for i in range(12)]
            if len(images) > 2:
                images = images[:2]
            units.append((title, artist, p, images, strips))
        elif os.path.isfile(p) and p.lower().endswith((".jpg", ".jpeg", ".png", ".webp", ".gif")):
            units.append((os.path.splitext(name)[0], guess_artist(name), p, [p], []))
    return units


def mbid_file_lookup(mbid_map, title):
    """从 --mbid-file 映射表查 MBID。返回 (mbid, type)。"""
    if not mbid_map:
        return None, None
    norm = lambda s: re.sub(r"\s+", "", s)
    t, tn = title, norm(title)
    for key in (t, tn):
        if key in mbid_map:
            v = mbid_map[key]
            if isinstance(v, str):
                return v, None
            return v.get("mbid"), v.get("type")
    return None, None


STRIP_PROMPT = ("这是简谱图片的一个横条片段。请转写其中的音符：数字1-7、休止0、"
                "附点.、延长线-、高低音记号(逗号或撇号)。忽略所有歌词和中文文字。"
                "只输出音符，用空格分隔，不要解释。")
HEADER_PROMPT = ("这是简谱图片。只报告两行：第一行调号(如 1=G 或 6=Am)，"
                 "第二行拍号(如 4/4)；没有就写 none。不要输出其他内容。")


def restart_ollama_server():
    """重启 ollama 服务器 (模型退化自愈)。返回是否成功。

    注意: 沙箱内子进程不能用管道捕获输出 (EPERM), 用 DEVNULL 重定向。
    """
    try:
        script = ("[Environment]::SetEnvironmentVariable('OLLAMA_FLASH_ATTENTION','1','User'); "
                  "Stop-Process -Name 'ollama app','ollama','llama-server' -Force -ErrorAction SilentlyContinue; "
                  "Start-Sleep 4; "
                  "explorer.exe \"$env:LOCALAPPDATA\\Programs\\Ollama\\ollama app.exe\"; "
                  "Start-Sleep 18")
        subprocess.run(["powershell", "-NoProfile", "-Command", script],
                       timeout=120, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(5)
        req = urllib.request.Request("http://127.0.0.1:11434/api/tags")
        urllib.request.urlopen(req, timeout=10)
        return True
    except Exception:
        return False

NOTE_LINE_RE = re.compile(r"[0-7]")
CJK_RE = re.compile(r"[\u4e00-\u9fff]")


def sanitize_model_output(text):
    """清除模型输出的 LaTeX/标记语言/控制字符等垃圾。"""
    t = text.replace("<doc>", " ").replace("</doc>", " ")
    t = re.sub(r"\\frac\s*\{[^}]*\}\s*\{[^}]*\}", " ", t)
    t = re.sub(r"\\begin\{[^}]*\}|\\end\{[^}]*\}|\\overline\{[^}]*\}|\\cdots|\\ldots", " ", t)
    t = re.sub(r"\\[a-zA-Z]+", " ", t)
    t = t.replace("_", " ").replace("|", " | ")
    t = re.sub(r"[{}]", " ", t)
    return t


def is_junk(text):
    """判断模型输出是否可用 (无音符数字即视为拒绝/废话)。"""
    return not NOTE_LINE_RE.search(text)


NOTE_TOKEN_RE = re.compile(r"[#b',]*[qsdhQ]?[0-9iI][.,'\-]*|[\-|]")


def normalize_note_tokens(toks):
    """统一简谱 token 写法 (jianpu-db 规范): 高八度撇号在数字后 (1'), 低八度逗号在数字前 (,6);
    唱名 i/I 是模型对高音 1 的常见误读, 统一为 1'; 8/9 是 jianpu-ly 内置的高音 1/2 写法;
    保留 #/b 升降号与 q/s/d/h 时值前缀; 把粘连的延音线拆开 (2-→2 -),
    因为 jianpu-ly 把 2- 当和弦(1拍) 而语料规范是独立 - token。"""
    out = []
    for tok in toks:
        acc = ""
        if tok and tok[0] in "#b":
            acc, tok = tok[0], tok[1:]
        dur = ""
        if tok and tok[0] in "qsdhQ":
            dur, tok = tok[0].lower(), tok[1:]
        if tok and tok[0] in "iI":
            tok = "1'" + tok[1:]
        m = re.match(r"^([',]*)([89])(.*)$", tok)   # 8→1', 9→2'
        if m:
            tok = m.group(1) + {"8": "1'", "9": "2'"}[m.group(2)] + m.group(3)
        m = re.match(r"^([1-7])(,+)([.\-]*'*)$", tok)      # 6, → ,6
        if m:
            tok = m.group(2) + m.group(1) + m.group(3).rstrip("'")
        m = re.match(r"^('+)([1-7])([.\-]*'*)$", tok)      # '1 → 1' (尾部撇号是噪声)
        if m:
            tok = m.group(2) + m.group(1) + m.group(3).rstrip("'")
        out.extend(split_dashes(acc + dur + tok))
    return out


def split_dashes(tok):
    """2- → ['2', '-']; q2- → ['q2','-']; 2-- → ['2','-','-']; 2.- → ['2.','-']; 其余原样。"""
    if tok == "-" or "-" not in tok:
        return [tok]
    m = re.match(r"^([qsdh]?[#b',]*[0-7iI][.,']*)(-+)(.*)$", tok)
    if not m:
        return [tok]
    lead, dashes, rest = m.group(1), m.group(2), m.group(3)
    out = [lead] + ["-"] * len(dashes)
    if rest:
        out.append(rest)
    return out
STRUCT_RE = re.compile(r"^\s*(?:subtitle=|NextScore|KeepLength|R\d*\s*\{|A\s*\{|%|#|\\bar)")
STRUCT_TOK_RE = re.compile(r"^(?:subtitle=.*|NextScore|KeepLength|R\d*\{|A\{|\}|\||\\bar.*|%.*)$")
NOTE_LIKE_RE = re.compile(r"^[#b',]*[qsdhQ]?[0-9iI][.,'\-]*$")


def clean_struct_line(s):
    """结构行清洗: 保留合法结构 token 与音符 token, 丢弃省略号/编号注释等噪声;
    A{| 拆成 A{ |; 括号不平衡时丢弃全部 R{/A{/} (模型的重复结构几乎总是残缺)。"""
    toks = []
    for t in s.split():
        if t in ("|}", "}|"):                        # |} 粘连体拆开
            toks.append("|")
            toks.append("}")
            continue
        if re.match(r"^(?:R\d*|A)\{\|", t):        # A{| → A{ |
            toks.append(t[:t.index("{") + 1])
            toks.append("|")
            continue
        if STRUCT_TOK_RE.match(t):
            toks.append(t)
        elif NOTE_LIKE_RE.match(t):
            toks.extend(normalize_note_tokens([t]))
    opens = sum(1 for t in toks if "{" in t)
    closes = sum(1 for t in toks if t == "}")
    if opens > closes:
        # 括号不平衡: 丢弃全部 R{/A{/}, 保留里面的音符 (模型结构残缺)
        toks = [t for t in toks if "{" not in t and t != "}"]
    return " ".join(toks)

# --no-strips 开关: 整图单次模式 (适合 7b 等强模型)
NO_STRIPS = False


def clean_body(text):
    """整图单次模式的后处理: 保留结构行, 从混合行抽取音符 token, 剔除歌词。"""
    lines = []
    for ln in text.splitlines():
        s = ln.strip()
        if not s:
            continue
        if STRUCT_RE.match(s):
            # 结构行保留, 但剔除省略号等占位垃圾 (R{ ... } → R{ })
            cleaned = clean_struct_line(s)
            if cleaned:
                lines.append(cleaned)
            continue
        toks = NOTE_TOKEN_RE.findall(s)
        if not toks or all(t in "|-" for t in toks):
            continue
        line = " ".join(normalize_note_tokens(toks))
        if len(toks) > 64:
            line = " ".join(normalize_note_tokens(toks[:64]))
        lines.append(line)
    return "\n".join(lines)


def clean_note_lines(text):
    """从模型文本提取音符行: 从每行中抽取音符 token (可容忍散文/歌词混杂)。"""
    lines = []
    for ln in sanitize_model_output(text).splitlines():
        ln = ln.strip()
        if not ln:
            continue
        toks = NOTE_TOKEN_RE.findall(ln)
        if not toks:
            continue
        # 纯单字符噪声行 (如 "| | |"、长横线循环) 丢弃
        if all(t in "|-" for t in toks):
            continue
        line = " ".join(normalize_note_tokens(toks))
        # 截断超长行 (模型循环产物), 保留前 64 个 token
        if len(toks) > 64:
            line = " ".join(normalize_note_tokens(toks[:64]))
        lines.append(line)
    return lines


def transcribe_strips(strips, full_images, host, model, tries=3):
    """分条转写: 每条独立短问答, 失败重试; 整图用于读调号/拍号。
    返回 (合并文本, 逐条结果)。"""
    header_lines = []
    note_lines = []
    per_strip = []
    for i, sp in enumerate(strips):
        set_progress(f"切片 {i + 1}/{len(strips)}: {os.path.basename(sp)}")
        with open(sp, "rb") as f:
            b64 = base64.b64encode(f.read()).decode("ascii")
        got = None
        for attempt in range(tries):
            ok, content = ollama_chat(host, model, STRIP_PROMPT, [b64])
            if ok and not is_junk(content):
                got = strip_fences(content)
                break
        if got is None:
            per_strip.append((os.path.basename(sp), "FAIL"))
            continue
        per_strip.append((os.path.basename(sp), got))
        for ln in clean_note_lines(got):
            # 跨条连续重复去重 (模型循环): 同一行连续出现 >=3 次只保留前 2 次
            if len(note_lines) >= 2 and note_lines[-1] == ln and note_lines[-2] == ln:
                continue
            note_lines.append(ln)
    # 调号/拍号: 优先从第一条切片的输出提取 (条0通常是谱头), 没有再调用整图
    header_lines = []
    for sp_out in [per_strip[0][1]] if per_strip else []:
        for ln in sanitize_model_output(sp_out).splitlines():
            ln = ln.strip()
            if re.match(r"^\d+=[A-Ga-g](?:#|b|m)?$", ln) or re.match(r"^\d+/\d+$", ln):
                header_lines.append(ln)
    if not header_lines and full_images:
        with open(full_images[0], "rb") as f:
            b64 = base64.b64encode(f.read()).decode("ascii")
        for attempt in range(tries):
            ok, content = ollama_chat(host, model, HEADER_PROMPT, [b64])
            if ok:
                for ln in sanitize_model_output(content).splitlines():
                    ln = ln.strip()
                    if re.match(r"^\d+=[A-Ga-g](?:#|b|m)?$", ln) or re.match(r"^\d+/\d+$", ln):
                        header_lines.append(ln)
                if header_lines:
                    break
    text = "\n".join(header_lines + note_lines)
    return text, per_strip


def process_one(title, artist, images, strips, out_dir, args, dry_run):
    ctitle = clean_title(title) if args.clean_title else title
    base = f"{sanitize(ctitle)}"
    txt_path = os.path.join(out_dir, base + ".txt")
    ly_path = os.path.join(out_dir, base + ".ly")
    trans_path = os.path.join(out_dir, base + ".trans")
    err_path = os.path.join(out_dir, base + ".err")
    if os.path.exists(txt_path):
        return ("skip", base, "", None)
    if dry_run:
        return ("dry", base, f"images={len(images)} strips={len(strips)}", None)

    try:
        return _process_one_impl(title, artist, images, strips, out_dir, args, base,
                                 txt_path, ly_path, trans_path, err_path)
    except Exception as e:
        try:
            with open(err_path, "w", encoding="utf-8") as f:
                f.write(f"CRASH: {type(e).__name__}: {e}\n")
        except Exception:
            pass
        return ("error", base, f"crash: {type(e).__name__}: {e}", None)


def _process_one_impl(title, artist, images, strips, out_dir, args, base,
                      txt_path, ly_path, trans_path, err_path):
    ctitle = clean_title(title) if args.clean_title else title
    if strips:
        raw, per_strip = transcribe_strips(strips, images, args.host, args.model)
        detail = f"strips={len(strips)}"
    else:
        images_b64 = []
        for im in images:
            with open(im, "rb") as f:
                images_b64.append(base64.b64encode(f.read()).decode("ascii"))
        raw = ""
        last_err = ""
        for attempt in range(2):
            ok, content = ollama_chat(args.host, args.model, PROMPT, images_b64, timeout=180)
            if not ok:
                last_err = content
                # 上下文不足/内存分配/超时: 重启服务器 (带上 FLASH_ATTENTION) 后重试一次
                if attempt == 0 and re.search(r"exceeds the available context|failed to allocate|timed out", content) \
                        and restart_ollama_server():
                    continue
                raw = ""
                break
            raw = strip_fences(content)
            body0 = extract_controls(raw)[3]
            if NOTE_LINE_RE.search(body0):   # 正文里有音符数字 → 成功
                break
            # 只有歌词/结构行: 可能是模型退化, 重启后重试一次
            last_err = "模型输出无音符 (可能只有歌词)"
            if attempt == 0 and restart_ollama_server():
                continue
            raw = ""
            break
        if not raw:
            with open(err_path, "w", encoding="utf-8") as f:
                f.write(f"OLLAMA ERROR: {last_err}\n")
            return ("error", base, last_err, None)
        per_strip = None
        detail = f"images={len(images)}"
    if not raw.strip():
        # 自愈: 模型可能退化 (输出 @@@ 等), 重启 ollama 服务器后重试一次
        if restart_ollama_server():
            if strips:
                raw, per_strip = transcribe_strips(strips, images, args.host, args.model)
            else:
                images_b64 = []
                for im in images:
                    with open(im, "rb") as f:
                        images_b64.append(base64.b64encode(f.read()).decode("ascii"))
                ok, content = ollama_chat(args.host, args.model, PROMPT, images_b64, timeout=180)
                raw = strip_fences(content) if ok else ""
    if not raw.strip():
        with open(err_path, "w", encoding="utf-8") as f:
            f.write("模型无有效输出\n")
        return ("error", base, "empty model output", None)
    with open(trans_path, "w", encoding="utf-8") as f:
        f.write(raw)
        if per_strip:
            f.write("\n\n--- 逐条明细 ---\n")
            for name, out in per_strip:
                f.write(f"### {name}\n{out}\n")

    key, time_sig, tempo, body = extract_controls(raw)
    if not strips:  # 整图单次模式: 剔除歌词/混合行 (切片模式已做过 token 抽取)
        body = clean_body(body)
    body = minor_tonic_fix(body, key)
    body = ensure_nextscore(body)
    body = fix_bars(body, time_sig)
    # 清理结尾/空段落: 去掉尾部 NextScore, 以及 NextScore 分隔出的无音符段落
    # (如"前奏"只有 subtitle 没有音符 — 会形成空 score 报错)
    while True:
        body = body.rstrip()
        if re.search(r"NextScore\s*$", body):
            body = re.sub(r"NextScore\s*$", "", body).rstrip()
            continue
        parts = re.split(r"(?m)^\s*NextScore\s*$", body)
        kept, changed = [], False
        for p in parts:
            if not p.strip():
                continue
            p_nosig = re.sub(r"(?m)^\s*(?:subtitle=.*|\d+/\d+.*|%.*|NextScore\s*)$", "", p)
            if NOTE_LINE_RE.search(p_nosig):
                kept.append(p)
            else:
                changed = True
        if not changed:
            break
        body = "\nNextScore\n".join(kept).rstrip()
    if time_sig:
        # 每个 NextScore 分段都补拍号 (jianpu-ly 每个 score 独立处理, 缺省 4/4)
        segs = re.split(r"(?m)^\s*NextScore\s*$", body)
        fixed = []
        for s in segs:
            if not s.strip():
                fixed.append(s)
                continue
            first = s.lstrip().splitlines()[0].strip()
            if re.match(r"^\d+/\d+$", first):
                fixed.append(s)
            else:
                fixed.append(time_sig + "\n" + s)
        body = "\nNextScore\n".join(fixed).strip()
    if tempo:
        body = tempo + "\n" + body

    mbid, mtype, conf, matched = "", None, None, None
    if args.mbid:
        mbid, conf = args.mbid, "manual"
    if not mbid and args.mbid_map:
        mbid, mtype = mbid_file_lookup(args.mbid_map, ctitle)
        if mbid:
            conf = "mbid-file"
    if not mbid and args.lookup_mbid and ctitle:
        mbid, kind, conf, matched = musicbrainz_lookup(ctitle, artist)
        if mbid and kind == "recording" and args.type == "work":
            mtype = "recording"   # 查到的是 recording 实体, type 应同步
    score_type = mtype or args.type

    score = build_score_file(mbid, ctitle, score_type, args.transcriber,
                             args.tags, title, body, getattr(args, "copyright", ""))
    with open(txt_path, "w", encoding="utf-8") as f:
        f.write(score)

    # 用 jianpu-ly 校验正文 (跳过元数据区)
    body_only = score[score.find("%--") + 3:].strip()
    try:
        ly = jianpu_ly.process_input(body_only)
        with open(ly_path, "w", encoding="utf-8") as f:
            f.write(ly)
        status = "ok"
        info = f"{detail}, MBID={'有' if mbid else '缺'}, conf={conf or '-'}, key={key or '?'}, time={time_sig or '?'}"
    except Exception as e:
        with open(err_path, "w", encoding="utf-8") as f:
            f.write(f"JIANPU_LY ERROR: {e}\n\n--- score ---\n{score}")
        status = "error"
        info = str(e)[:200]
    if status == "ok" and not mbid:
        info += " [MBID 为空: 进 parse_scores.py 前必须补]"
    review = None
    if status == "ok":
        review = {
            "base": base, "title": ctitle, "artist": artist or "",
            "mbid": mbid, "type": score_type, "conf": conf or "",
            "matched": json.dumps(matched, ensure_ascii=False) if matched else "",
        }
    return (status, base, info, review)


def mbid_only_run(out_dir, args):
    """只补 MBID 模式: 读取已有 .txt, 查 MusicBrainz 并写入 MBID= 行, 不重跑识别。
    已带 MBID= 的行跳过 (避免覆盖人工填录); 支持 --artist-map 或 --input 提取歌手。
    同时清理 alias 里的 &nbsp; 残留。"""
    start_progress_reporter()
    rows = []
    files = []
    for name in sorted(os.listdir(out_dir)):
        if name.endswith(".txt"):
            files.append(os.path.join(out_dir, name))
    total = len(files)
    artist_map = {}
    if args.artist_map:
        with open(args.artist_map, encoding="utf-8") as f:
            artist_map = json.load(f)
    elif args.input and os.path.isdir(args.input):
        # 从爬虫目录自动提取 清洗后标题 → 歌手
        for name in sorted(os.listdir(args.input)):
            p = os.path.join(args.input, name)
            j = os.path.join(p, "song.json")
            if os.path.isdir(p) and os.path.exists(j):
                try:
                    with open(j, encoding="utf-8") as f:
                        meta = json.load(f)
                    t = meta.get("title") or name
                    a = meta.get("artist") or guess_artist(t)
                    if a:
                        artist_map.setdefault(clean_title(t), a)
                except Exception:
                    pass
    try:
        for i, path in enumerate(files, 1):
            set_progress(f"MBID 补录 {i}/{total}: {os.path.basename(path)}")
            text = open(path, encoding="utf-8").read()
            title = ""
            m = re.search(r"(?m)^title=(.*)$", text)
            if m:
                title = m.group(1).strip()
            artist = artist_map.get(title, "")
            # 清理 alias 残留 &nbsp;
            text = re.sub(r"(?m)^(alias=.*?)&nbsp;+", r"\1", text)
            mbid, kind, conf, matched = "", None, None, None
            if re.search(r"(?m)^MBID=", text):
                mm = re.search(r"(?m)^MBID=([0-9a-f-]{36})", text)
                if mm:
                    mbid = mm.group(1)
                    conf = "已有"
                    kind = "work"
            elif args.mbid_map:
                mbid, mtype = mbid_file_lookup(args.mbid_map, title)
                if mbid:
                    conf = "mbid-file"
                    kind = mtype or "work"
            elif title:
                mbid, kind, conf, matched = musicbrainz_lookup(title, artist)
            if mbid and conf != "已有":
                if re.search(r"(?m)^MBID=", text):
                    text = re.sub(r"(?m)^MBID=.*$", f"MBID={mbid}", text, count=1)
                else:
                    # 插到 %-- 之前 (元数据区)
                    idx = text.find("%--")
                    pos = idx if idx >= 0 else 0
                    text = text[:pos] + f"MBID={mbid}\n" + text[pos:]
                open(path, "w", encoding="utf-8").write(text)
            rows.append([os.path.basename(path), title, artist, mbid or "",
                         "recording" if kind == "recording" else "work",
                         conf or "", json.dumps(matched, ensure_ascii=False) if matched else ""])
            print(f"[{'已有' if conf == '已有' else '填' if mbid else '缺'}] {os.path.basename(path)}  conf={conf or '-'}")
            if not mbid:
                time.sleep(1.1)  # MusicBrainz 限速
    finally:
        stop_progress_reporter()
    with open(os.path.join(out_dir, "mbid_review.csv"), "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(["song", "title", "artist", "mbid", "type", "confidence", "matched"])
        w.writerows(rows)
    filled = sum(1 for r in rows if r[3])
    print(f"MBID 补录完成: {filled}/{len(rows)} 已填, 其余见 mbid_review.csv")


def main():
    ap = argparse.ArgumentParser(description="简谱图片 → jianpu-db 格式 (Ollama + Qwen2.5-VL)")
    ap.add_argument("--input", default="", help="输入: 爬虫输出目录(每首歌一个子目录) 或 单个图片文件")
    ap.add_argument("--out", default="scores-out", help="输出目录 (默认 scores-out)")
    ap.add_argument("--model", default="qwen2.5vl:7b", help="Ollama 模型 (默认 qwen2.5vl:7b)")
    ap.add_argument("--host", default="http://127.0.0.1:11434", help="Ollama 服务地址")
    ap.add_argument("--no-strips", action="store_true",
                    help="整图单次转写模式 (忽略切片, 适合 qwen2.5vl:7b 等强模型)")
    ap.add_argument("--dry-run", action="store_true", help="不调用模型, 只列出要转换的歌曲")
    ap.add_argument("--delay", type=float, default=0.0, help="每首歌之间的间隔秒数")
    ap.add_argument("--transcriber", default="", help="转写者 (不填则不写 transcriber= 行)")
    ap.add_argument("--copyright", default="", help="版权声明 (写入 copyright= 行, 如: 谱源: xxx, 版权归原作者)")
    ap.add_argument("--tags", default="", help="usertag, 逗号分隔 (如: 儿歌,华语)")
    ap.add_argument("--type", default="work", choices=["work", "recording"], help="MusicBrainz 类型 (默认 work)")
    ap.add_argument("--mbid", default="", help="手动指定 MBID")
    ap.add_argument("--mbid-file", default="", help="MBID 映射文件 (json): 标题→uuid 或 标题→{\"mbid\":..,\"type\":..}")
    ap.add_argument("--mbid-only", action="store_true",
                    help="只补录 MBID 模式: 给现有 .txt 查 MBID 并写入, 不重跑识别")
    ap.add_argument("--artist-map", default="",
                    help="标题→歌手 映射 json (mbid-only 用); 或用 --input 指定图片目录自动提取")
    ap.add_argument("--lookup-mbid", action="store_true",
                    help="按标题+歌手尝试 MusicBrainz 查询 MBID (分级置信度, 慢: 每首最多4次请求)")
    ap.add_argument("--clean-title", action="store_true", default=True,
                    help="清洗爬虫标题为通用曲名 (默认开, 用 --no-clean-title 关闭)")
    ap.add_argument("--no-clean-title", dest="clean_title", action="store_false")
    a = ap.parse_args()
    global NO_STRIPS
    NO_STRIPS = a.no_strips

    a.mbid_map = {}
    if a.mbid_file:
        with open(a.mbid_file, encoding="utf-8") as f:
            a.mbid_map = json.load(f)

    if a.mbid_only:
        mbid_only_run(a.out, a)
        return
    if not a.input:
        ap.error("--input 必填 (或使用 --mbid-only)")

    os.makedirs(a.out, exist_ok=True)
    units = song_units(a.input)
    if not units:
        print(f"在 {a.input} 里没有找到歌曲(需要 song.json 子目录或图片文件)", file=sys.stderr)
        sys.exit(1)
    print(f"共 {len(units)} 首, 模型: {a.model}" + ("  [DRY-RUN]" if a.dry_run else ""))

    stats = {"ok": 0, "error": 0, "skip": 0, "dry": 0}
    rows, reviews = [], []
    start_progress_reporter()
    try:
        for idx, (title, artist, _src, images, strips) in enumerate(units, 1):
            set_progress(f"第 {idx}/{len(units)} 首: {title}")
            status, base, info, review = process_one(title, artist, images, strips, a.out, a, a.dry_run)
            stats[status] = stats.get(status, 0) + 1
            rows.append([base, status, info])
            if review:
                reviews.append(review)
            print(f"[{status.upper():5}] {base}  {info}" + (f"  (歌手: {artist})" if artist and status != "skip" else ""))
            if a.delay and status not in ("skip", "dry"):
                time.sleep(a.delay)
    finally:
        stop_progress_reporter()

    with open(os.path.join(a.out, "summary.csv"), "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(["song", "status", "info"])
        w.writerows(rows)
    with open(os.path.join(a.out, "mbid_review.csv"), "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(["song", "title", "artist", "mbid", "type", "confidence", "matched"])
        w.writerows([r.values() for r in reviews])
    print(f"\n完成: 成功 {stats['ok']}, 失败 {stats['error']}, 跳过 {stats['skip']}"
          + (f", dry-run {stats['dry']}" if a.dry_run else ""))
    if stats["error"]:
        print("有失败的歌曲: 看对应 .err, 用编辑器修好 .trans 后重跑即可")
    if reviews:
        need = [r for r in reviews if not r["mbid"] or r["conf"] in ("medium", "low")]
        if need:
            print(f"警告: {len(need)} 首 MBID 缺失或置信度低 (medium/low), 见 {os.path.join(a.out, 'mbid_review.csv')}")
            print("      错配比没有更糟: 低置信度一律不自动填。处理方式:")
            print("      1) 看 mbid_review.csv 的 matched 列挑出正确候选, 写成映射文件:")
            print('         {"小红帽": {"mbid": "xxx", "type": "work"}}  然后加 --mbid-file 重跑')
            print("      2) 或直接用 --mbid <uuid> 指定单首, --lookup-mbid 全自动只填 high")


if __name__ == "__main__":
    main()
