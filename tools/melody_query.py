# -*- coding: utf-8 -*-
"""旋律片段查歌(简谱数字串) —— "AI Skill" 的用户入口。

用法:
  py -3.13 tools/melody_query.py 51223323323531
  py -3.13 tools/melody_query.py "5 1 2 2 3 3 2 3 3 2 3 5 3 1" --top 10
  py -3.13 tools/melody_query.py 512233 --top 5 --show    # --show 打出谱里命中的那段

说明:
  * 输入只认 1-7 数字(简谱唱名), 空格/下划线/连字符/逗号随便加, 其它字符忽略。
  * 索引 = 全库已转写曲谱(batch-out + batch-out-dup)的**音高串**(丢八度、丢休止、丢认不出的块),
    按**曲名分组** —— 同一首歌的多个版本算一首, 取组内最好成绩(与评测口径一致)。
    **并列时额外报"八度差异"** —— 因为丢八度是为了宽容哼唱, 但八度有时正是唯一能分开两首歌的信息
    (实测《水手》vs《爱上草原的小河》共享同一段 13 音, 只差末两音的低八度记号)。
  * 排序 = 最小错音数; 并列时按"名字更短、非改编版、优先 qupu123"破并列, 并**明说并列组大小**。
  * 出处一栏直接给 `来源=站点-id`(与 scores 里的 source= 一致), 便于人工核对。
"""
import glob
import os
import re
import sys

sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import melody_oct as M

ARGS = [a for a in sys.argv[1:]]
if not ARGS or ARGS[0].startswith("--"):
    sys.exit(__doc__)
TOP = int(ARGS[ARGS.index("--top") + 1]) if "--top" in ARGS else 10
SHOW = "--show" in ARGS
JSON_OUT = "--json" in ARGS
# --indel 1: 容忍漏唱/多唱一个音(真人最常见)。代价是每个查询多比对 len(q) 个变体(慢约 10 倍),
# 但换来的是"哼错一个音/少哼一个字"不再直接失败。评测见 train-work/retrieval_indel.tsv。
INDEL = int(ARGS[ARGS.index("--indel") + 1]) if "--indel" in ARGS else 0
SKIP = "0x"
BADWORD = re.compile(r"吉他|钢琴|双谱|器乐|非洲|尤克里里|古筝|琵琶|二胡|笛|萨克斯|总谱|合唱")

# **可以一次给多段旋律**(非选项参数都是片段): 分数按段相加再排序。
# 为什么重要(实测, train-work/retrieval_holdout.tsv): "拿谱对谱"单段 Top-1 95.5%, 但换成
# **同一首歌的另一份谱**做查询源(留一版本, 更像"凭记忆哼")单段只有 51.3%; 给 5 段后回到 69.6%
# —— 多段让"偶然撞上一段"的别的歌压不过"段段都接近"的真歌。
_vals = {"--top", "--indel"}
FRAGS = []
_i = 0
while _i < len(ARGS):
    _a = ARGS[_i]
    if _a in _vals:
        _i += 2
        continue
    if _a.startswith("--"):
        _i += 1
        continue
    FRAGS.append(_a)
    _i += 1
if not FRAGS:
    sys.exit(__doc__)

QS = []
QOFF = []          # 与 QS 逐音对齐的八度偏移(用户没写记号 => 0)。`,7` = 低八度, `'1` = 高八度。
for _raw in FRAGS:
    _ms = list(re.finditer(r"([,']*)([1-7])", _raw))
    _q = "".join(m.group(2) for m in _ms)
    if len(_q) < 5:
        sys.exit(f"查询片段太短({len(_q)} 个音), 至少 5 个音: {_raw}")
    QS.append(_q)
    QOFF.append([m.group(1).count(",") - m.group(1).count("'") for m in _ms])
q = QS[0]
QLEN = min(len(x) for x in QS)


def pitch_of(txt):
    e, _raw = M.enc(txt)
    return "".join(x[0] for x in e if x[0] not in SKIP)


def enc_of(txt):
    """带八度的编码串(每条 3 字符, 如 `3+0` `7+1`), 与 pitch_of **逐音对齐**。
    用途: 主排序丢八度(对"凭记忆哼唱"更宽容), 但**并列时**用八度再判一次 ——
    实测(2026-09 用户实测《水手》): `3565321232176` 在丢八度口径下 3 首 0 错并列
    (《水手》与《爱上草原的小河》), 带上八度后**零重叠**: 《水手》末两音是 `,7 ,6`(7+1 6+1),
    《爱上草原的小河》是 `7 6`(7+0 6+0)。并列时把八度差异打出来, 用户一看就知道该补哪个记号。"""
    e, _raw = M.enc(txt)
    return "".join(x for x in e if x[0] not in SKIP)


def group_of(name):
    base = re.sub(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]", "", name.split("__")[0])
    # 以《 开头的名字切完会是空 -> 45 个不相关的谱会**塌成同一首"歌"** ✗, 空就退回原名
    return re.split(r"[（(\s　【\[《]", base)[0].strip() or base.strip()


def site_of(name):
    # id 可能是数字, 也可能是拼音别名(qupu123 有一批只有拼音网址的谱页, 见 to_jianpu_db.py)
    m = re.match(r"^.*__([a-z0-9]+)-([0-9a-z_]+)$", name)
    return f"{m.group(1)}-{m.group(2)}" if m else "?"


groups = {}
ENC = {}
for pat in ("batch-out/*.txt", "batch-out-dup/*.txt"):
    for f in glob.glob(pat):
        b = os.path.basename(f)[:-4]
        try:
            txt = open(f, encoding="utf-8", errors="replace").read()
            d = pitch_of(txt)
            ENC[b] = enc_of(txt)
        except Exception:
            continue
        if len(d) < len(q):
            continue
        groups.setdefault(group_of(b), []).append(
            (b, np.frombuffer(d.encode("ascii", "ignore"), dtype=np.uint8)))

qa = np.frombuffer(q.encode("ascii", "ignore"), dtype=np.uint8)
if not JSON_OUT:
    print(f"查询片段 {(' | '.join(QS))}  ({len(QS)} 段)   索引 {len(groups)} 首歌 / "
          f"{sum(len(v) for v in groups.values())} 份谱\n")


def frag_variants(s):
    """一段查询本身(+ 允许漏/多唱 1 个音时, 它的所有单删变体)。"""
    out = [s] + ([s[:i] + s[i + 1:] for i in range(len(s))] if INDEL >= 1 else [])
    return [np.frombuffer(v.encode("ascii", "ignore"), dtype=np.uint8) for v in out]


QVAR = [frag_variants(s) for s in QS]

# 多段查询: **每段各自取最小错音数, 然后相加**(不是取所有段里的最小值) ——
# 只有"段段都接近"的歌才会总分最低, 偶然撞上一段的歌压不过去。
res = []
for g, ents in groups.items():
    total = 0
    det = []                     # 每段的 (最小错音, 位置, 文件名, 比对长度)
    ok_all = True
    for vb_list in QVAR:
        best, where, which, vlen = None, -1, "", 0
        for vb in vb_list:
            for n, arr in ents:
                if len(arr) < len(vb):
                    continue
                w = np.lib.stride_tricks.sliding_window_view(arr, len(vb))
                mism = (w != vb).sum(axis=1)
                i = int(mism.argmin())
                m = int(mism[i])
                if best is None or m < best:
                    best, where, which, vlen = m, i, n, len(vb)
        if best is None:
            ok_all = False
            break
        total += best
        det.append((best, where, which, vlen))
    if ok_all and det:
        b0, w0, n0, v0 = det[0]
        res.append((total, g, n0, w0, v0, det))

# "同曲名族"热度: 库里同一首歌常被拆成多个曲名组(`…主题曲` / `…主题曲-简谱` / `强军战歌1`/`强军战歌2` /
# `…_歌曲类`)。破并列要的"这首歌有多热"必须跨这些后缀汇总, 否则同一首歌各算 1 份, 白让冷门歌打平。
# **只用于破并列**, 不改分组定义本身 —— 改了会牵动所有检索评测的口径。
TAIL = re.compile(r"(?:[-_（(]?\s*(?:简谱|歌曲类|歌谱|五线谱|正谱|完整版|弹唱|吉他谱|钢琴谱)\s*[)）]?)+$"
                  r"|(?<=[\u4e00-\u9fff])[0-9]$")


def pop_key(g):
    k = g
    for _ in range(3):
        k2 = TAIL.sub("", k)
        if k2 == k or not k2:
            break
        k = k2
    return k


POP = {}
for _g in groups:
    POP.setdefault(pop_key(_g), 0)
for _g in groups:
    POP[pop_key(_g)] += len(groups[_g])

# 破并列: 非改编版 > **同曲名族谱份数多的(热度信号)** > 名字短 > qupu123 优先。
# 为什么把"热度"提到"名字短"前面(实测驱动, 2026-09-22 用户实测题 `11117535`):
#   并列的《坚如磐石》(1 份谱, 名字 4 字) 与《别看我只是一只羊/喜羊羊与灰太狼》(2 份谱, 名字 24 字)
#   —— 旧规则按"名字短"排, 把冷门歌排到了第 1, 用户真正要的动画主题曲掉到第 2。
#   谱份数是"这首歌被人反复上传/多源覆盖"的直接证据, 比名字长短更能代表"这是一首有名的歌"。
res.sort(key=lambda r: (r[0], BADWORD.search(r[1].split("__")[0]) is not None,
                        -POP[pop_key(r[1])],
                        len(r[1]), site_of(r[2]) != "qupu123" if site_of(r[2]) != "?" else True, r[1]))
tie = sum(1 for r in res if r[0] == res[0][0]) if res else 0


def oct_diff(name, where, vlen, qs, qoff):
    """并列候选的八度差异: 谱里那段 vs **用户给的**八度(没写记号就当 +0)。
    返回 [(第几音, 谱里, 你给)]。"""
    es = ENC.get(name, "")
    if vlen != len(qs) or len(es) < (where + vlen) * 3:
        return None                      # 用了漏/多音的变体时索引对不齐, 不判
    qe = "".join(f"{c}{o:+d}" for c, o in zip(qs, qoff))
    seg = es[where * 3:(where + vlen) * 3]
    return [(j + 1, seg[j * 3:j * 3 + 3], qe[j * 3:j * 3 + 3])
            for j in range(vlen) if seg[j * 3:j * 3 + 3] != qe[j * 3:j * 3 + 3]]


def jz(code):
    """把内部编码 `1-1`/`7+1` 还原成简谱写法 —— 内部符号是 `,` 记 +、`'` 记 -(ABC 习惯),
    直接打给人看会读反(`1-1` 是**高**八度 `'1`)。"""
    return ("," if code[1] == "+" else "'") * int(code[2]) + code[0]


# 只在"并列最高分"的候选上判八度 —— 这时八度是**唯一**还能把并列分开的信息
OCT = {}
for (_m, _g, _name, _w, _v, _d) in res[:TOP]:
    if res and _m == res[0][0]:
        OCT[_name] = oct_diff(_name, _d[0][1], _d[0][3], QS[0], QOFF[0])

if JSON_OUT:
    import json
    out = {
        "query": QS,
        "query_len": [len(x) for x in QS],
        "indel_slack": INDEL,
        "songs_indexed": len(groups),
        "scores_indexed": sum(len(v) for v in groups.values()),
        "candidates": len(res),
        "best_mismatch_total": res[0][0] if res else None,
        "tie_at_best": tie,
        "results": [
            {
                "rank": i,
                "title": g,
                "mismatch_total": m,
                "mismatch_per_frag": [d[0] for d in det],
                "exact": m == 0,
                "source": site_of(name),
                "score_file": name,
                "match_at_note": where + 1,
                "matched_len": vlen,
                "score_window": "".join(chr(c) for c in dict(groups[g])[name]
                                        [max(0, where - 2):where + vlen + 2]),
                "octave_checked": name in OCT,
                "octave_diff": [{"note": j, "in_score": a, "you_gave": b,
                                 "in_score_jianpu": jz(a), "you_gave_jianpu": jz(b)}
                                for j, a, b in (OCT.get(name) or [])],
            }
            for i, (m, g, name, where, vlen, det) in enumerate(res[:TOP], 1)
        ],
    }
    print(json.dumps(out, ensure_ascii=False, indent=2))
    sys.exit(0)

print(f"最接近的是 {tie} 首并列(总分 {res[0][0] if res else '-'}), 按名字/来源破并列后给出前 {TOP} 首:\n")
for i, (m, g, name, where, vlen, det) in enumerate(res[:TOP], 1):
    mark = "✓完全一致" if m == 0 else f"共错 {m} 个音"
    per = "" if len(det) == 1 else "  各段 " + "/".join(str(d[0]) for d in det)
    octs = ""
    if m == res[0][0]:                   # 只在"并列最高分"上判八度, 这是唯一能把并列分开的信息
        d0 = oct_diff(name, det[0][1], det[0][3], QS[0], QOFF[0])
        if d0 is not None:
            octs = ("  八度: 一致" if not d0 else
                    "  八度: 差%d个音[" % len(d0) +
                    ",".join(f"第{j}音 谱里{jz(a)}/你给{jz(b)}" for j, a, b in d0[:4]) + "]")
    print(f"{i:2d}. {g:<22} {mark:<10} 来源={site_of(name):<22} 命中位置≈第{where+1}个音{per}{octs}")
    if SHOW:
        arr = dict(groups[g])[name]
        seg = "".join(chr(c) for c in arr[max(0, where - 2):where + vlen + 2])
        print(f"     谱里这段: {seg}   (第 1 段查询 {q})")
print(f"\n共 {len(res)} 首歌进入候选。想放大核对原图: py -3.13 tools/zoom_phrase.py <曲名> \"{q}\"")
