# -*- coding: utf-8 -*-
"""和弦 token: 用例回归 + **全库逐 token 前后对拍**(唯一口径改动不许动单音 token)。

为什么要它(实测, 2026-10-05):
  语料里的和弦写法照抄 jianpu-ly 的真实输出 —— `[时值字母][(八度记号+变音?+音级)…][附点]`,
  多个音**连写成一个 token**, 八度/变音写在**各自音级左边**。真实例子:
      `d,4,,b5,,3,,1` (32 分音符: 低八度 4 ＋ 低两个八度降 5/3/1)   jianpu-db/scores/th03_04.txt
      `q'16`                                                          jianpu-db/scores/th02_14.txt
      `s6,5.`                                                         jianpu-db/scores/th03_08.txt
  依据是参考实现本身(项目里的 vendored 副本): vendor/jianpu_ly/__init__.py:1860
  `chordNotes_markup()` 调 :1802 `grace_octave_fix()`(把写在数字右边的记号搬到左边;
  中文歧义位置要头里声明 `OctavesBefore`, 见 :1819 的报错)。
  而改动前 `TOKEN` 正则**一个和弦 token 都匹配不上**、`seq()` 把它们**整批丢掉** ——
  实测全库 11,876 份里和弦 token 261,647 个、写明 646,747 个音(有音高的 646,710 个),
  分布在 223 首, 这 646,710 个音从来没进过检索索引。

  ⚠ **八度方向**: `,` = -1、`'` = +1(代码算 `逗号 - 撇`)。这是**改动前就有的**方向,
    本次一个字都没动(硬要求: 单音 token 逐字节不变)。用例里的期望值必须照**这个**口径写,
    不要照"简谱书面方向"写 —— 之前这里就写反过, 6 个用例假红。

两种用法(改 jptok.py **之前**先跑第一种):
    py -3.13 tools/check_chord_tokens.py --dump train-work/jptok_corpus_before.jsonl
    py -3.13 tools/check_chord_tokens.py --baseline train-work/jptok_corpus_before.jsonl
    py -3.13 tools/check_chord_tokens.py          # 只跑内置用例(不依赖语料)

⚠ 基线必须是**改动前**的 jptok 生成的。前一个 agent 把 jptok.py 改了才想起要基线, 于是
  `--dump` 出来的"改动前"其实是"改动后"。正确做法是从 git 里取改动前的副本再 dump:
      git show HEAD:skills/jianpu-melody-lookup/jptok.py > <临时目录>/jptok_orig.py
      再用 importlib 加载那份副本调本文件的 dump()(见 train-work 里那份基线的来源说明)。

对拍断言(缺一不可):
  ① **逐 token 输出**: 每个**不同** token 的 parse_token/is_note/is_pitch/duration_letter/beat
     与改动前逐字节相同 —— **除非**该 token 本身是"和弦形状"(≥2 个音级连写)。
  ② **逐文件输出**: 每份谱的 seq()/recover_bars() 指纹相同 —— **除非**该文件含和弦 token。
  ③ 含和弦的文件里, 音数**只增不减**, 而且"新增的音数 == 该文件里和弦 token 写明的**有音高**音数"
     (逐文件配平; 这才叫"原来认的一个不少, 丢掉的都回来了", 光看"总数涨了"不算证明)。
"""
import argparse
import hashlib
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DB = os.environ.get("JIANPU_DB") or os.path.join(os.path.dirname(ROOT), "jianpu-db")
SKILL = os.environ.get("JIANPU_JTOK") or os.path.join(ROOT, "skills", "jianpu-melody-lookup")
if os.path.isdir(SKILL) and SKILL not in sys.path:
    sys.path.insert(0, SKILL)
import jptok  # noqa: E402  **唯一实现**

# 和弦形状的**独立**判据(不调 jptok, 免得"用被测代码给被测代码分类"):
#   整个 token 由 时值字母 + 若干组(八度记号* 变音? 音级) + 尾巴记号 组成, 且**音级 ≥2 个**。
#   `4/4`(含 `/`)、`1=C`(含 `=`)这类都进不来, 不会被误判成和弦。
CHORD_SHAPE = re.compile(
    r"^[cqsdh]*(?:[,']*[#b♯♭]?[1-7x0]){2,}[,']*[#b♯♭]?[cqsdh]*[.]*\]?$")
DIGITS = re.compile(r"[1-7x0]")
# 改动前那条 TOKEN 正则(单音形状)。用来自查"这个和弦 token 在改动前是不是已经能认出来" ——
# 实测语料里**一个都没有**(和弦 token 的音级都连写, 单音正则整体匹配不上), 所以逐文件配平
# 不需要减项。这里留着一个独立判据, 万一以后出现"单音形状的和弦"能当场发现。
SINGLE_SHAPE = re.compile(
    r"^[cqsdh]*[,']*[#b♯♭]?[1-7x0][,']*[#b♯♭]?[cqsdh]*[.]*\]?$")

# 内置用例: 四个**真实** token(出处写在上面 docstring 里) + 边界。
# 期望值写成"每个音自己的 (音级, 变音, 八度)", 顺序照 token 里的书写顺序(不排序)。
# 八度符号见 docstring: `,` = -1, `'` = +1。
CASES = [
    # token,                期望的每个音,                      说明
    ("64",                  [(6, 0, 0), (4, 0, 0)],           "最简两音和弦"),
    (",4,,b5,,3,,1",        [(4, 0, 1), (5, -1, 2), (3, 0, 2), (1, 0, 2)],
     "th03_04.txt 真实 token: 八度/变音写在各自音级左边, 可连写"),
    ("q'16",                [(1, 0, -1), (6, 0, 0)],          "th02_14.txt 真实 token: 时值字母在最前"),
    ("s6,5.",              [(6, 0, 0), (5, 0, 1)],           "th03_08.txt 真实 token: 附点在最末"),
    ("d,4,,b5,,3,,1",       [(4, 0, 1), (5, -1, 2), (3, 0, 2), (1, 0, 2)],
     "th03_04.txt 真实 token(带时值字母 d)"),
    # 语料里真实出现(或同一份文件里真实出现)的其它形状
    ("'1631,6",             [(1, 0, -1), (6, 0, 0), (3, 0, 0), (1, 0, 0), (6, 0, 1)],
     "th07_18.txt 同一行里的 '1631 与 ,6: 记号紧贴**它自己**的音级"),
    ("60's",                [(6, 0, 0), (None, 0, -1)],
     "th18_01.txt 的 instrument 行(元数据, 不在正文): 末尾游离的撇只归**最后一个**音"),
    ("045]",                [(None, 0, 0), (4, 0, 0), (5, 0, 0)],
     "th18_12.txt: 和弦以休止开头 + 分组闭记号 ]"),
    ("#1#1",                [(1, 1, 0), (1, 1, 0)],
     "th02_13.txt: 同一音级写两遍 = 两个音头(不是延音, 不许并)"),
    ("6b55b0",              [(6, 0, 0), (5, -1, 0), (5, 0, 0), (None, -1, 0)],
     "th10_13.txt: 变音在各自音级左边 + 末尾的休止也带变音"),
    ("''1,7",               [(1, 0, -2), (7, 0, 1)],
     "两个撇 = 八度记号连写, 各自独立"),
    ("q0,3",                [(None, 0, 0), (3, 0, 1)],        "和弦以休止开头(前缀时值)"),
    ("#4b6",                [(4, 1, 0), (6, -1, 0)],          "和弦里每个音各自的变音"),
    ("64x0",                [(6, 0, 0), (4, 0, 0), (None, 0, 0), (None, 0, 0)],
     "和弦里的念白 x / 休止 0: 仍产出每一项, 但音级为 None(不进音高串)"),
    ("1x2",                 [(1, 0, 0), (None, 0, 0), (2, 0, 0)],
     "念白**夹在和弦中间**(语料里 10 种带 0/x 的和弦都在头/尾; 中间位置没有真实样本, 这里是兜住解析行为)"),
    # 单音 token 的兼容性钉死(这些**必须**一个字节都不变; 八度方向见 docstring)
    ("1",                   [(1, 0, 0)],                      "单音"),
    ("q1",                  [(1, 0, 0)],                      "前缀时值"),
    ("6c.",                 [(6, 0, 0)],                      "后缀时值 + 附点"),
    (",6",                  [(6, 0, 1)],                      "单音(逗号 = 低音方向取 +1, 见 docstring)"),
    ("1'",                  [(1, 0, -1)],                     "单音(撇 = -1)"),
    ("#4",                  [(4, 1, 0)],                      "单音升号"),
    ("0",                   [(None, 0, 0)],                   "休止"),
    ("x",                   [(None, 0, 0)],                   "念白"),
    ("3]",                  [(3, 0, 0)],                      "分组闭记号跟在音后"),
]
NOT_TOKENS = ["3[", "1=C", "4/4", "todo=add", "-", "~", "|", "%END", "", "c-", "R*1"]


def _fingerprint(seq):
    return hashlib.sha1(repr(seq).encode("utf-8")).hexdigest()[:16]


def _cases_report():
    """内置用例: 只查 jptok 自己的行为(不依赖语料)。返回 (失败数, 行列表)。"""
    bad, lines = 0, []
    for tok, want, why in CASES:
        got = jptok.parse_token(tok)
        flat = got if isinstance(got, list) else ([] if got is None else [got])
        if flat != want:
            bad += 1
            lines.append("  ✗ %-16r 期望 %s, 实得 %s   (%s)" % (tok, want, got, why))
        else:
            lines.append("  ✓ %-16r -> %s" % (tok, flat))
        # parse_token_all 必须与 parse_token 同源(单音: 1 项元组; 和弦: 列表)
        allv = jptok.parse_token_all(tok)
        if allv != flat:
            bad += 1
            lines.append("  ✗ %-16r parse_token_all 与 parse_token 不一致: %s vs %s"
                         % (tok, allv, flat))
    for tok in NOT_TOKENS:
        got = jptok.parse_token(tok)
        if got is not None:
            bad += 1
            lines.append("  ✗ %-16r 期望 None, 实得 %s" % (tok, got))
        if jptok.parse_token_all(tok) != []:
            bad += 1
            lines.append("  ✗ %-16r parse_token_all 期望 [], 实得 %s" % (tok, jptok.parse_token_all(tok)))
    # 和弦 token 必须进音高串(这是本次缺陷的正面断言)
    for tok in ("64", ",4,,b5,,3,,1", "q'16", "s6,5."):
        if not jptok.is_pitch(tok):
            bad += 1
            lines.append("  ✗ %-16r is_pitch 应为真" % tok)
    # 含休止/念白的和弦: is_note 为真(它是 token), 但也要能进音高串(里面还有有音高的音)
    for tok in ("60's", "045]", "64x0", "q0,3"):
        if not (jptok.is_note(tok) and jptok.is_pitch(tok)):
            bad += 1
            lines.append("  ✗ %-16r is_note/is_pitch 应为真/真, 实得 %s/%s"
                         % (tok, jptok.is_note(tok), jptok.is_pitch(tok)))
    # 纯休止/念白形状不算音高
    for tok in ("00", "xx", "0x"):
        if jptok.is_pitch(tok):
            bad += 1
            lines.append("  ✗ %-16r is_pitch 应为假" % tok)
    # seq() 不再丢音: 和弦里的每个音级都要出现
    got = [d for d, _a, _o in jptok.seq("1 64 2")]
    if got != [1, 6, 4, 2]:
        bad += 1
        lines.append("  ✗ seq('1 64 2') 期望 [1, 6, 4, 2], 实得 %s" % got)
    else:
        lines.append("  ✓ seq('1 64 2') -> [1, 6, 4, 2]")
    # 和弦里的休止/念白不占音高, 但也不该打断后面的音
    got = [d for d, _a, _o in jptok.seq("64x0 3")]
    if got != [6, 4, 3]:
        bad += 1
        lines.append("  ✗ seq('64x0 3') 期望 [6, 4, 3], 实得 %s" % got)
    else:
        lines.append("  ✓ seq('64x0 3') -> [6, 4, 3]")
    # 和弦内部不去重(两个音头就是两个音); 跨 token 的连音线照旧并
    got = [d for d, _a, _o in jptok.seq("'#1#1")]
    if got != [1, 1]:
        bad += 1
        lines.append("  ✗ seq(\"'#1#1\") 期望 [1, 1](和弦内不去重), 实得 %s" % got)
    else:
        lines.append("  ✓ seq(\"'#1#1\") -> [1, 1](和弦内不去重)")
    got = [d for d, _a, _o in jptok.seq("1 ~ 1")]
    if got != [1]:
        bad += 1
        lines.append("  ✗ seq('1 ~ 1') 期望 [1](连音线照旧并), 实得 %s" % got)
    else:
        lines.append("  ✓ seq('1 ~ 1') -> [1](连音线照旧并)")
    # 单音 token 的回归: 和弦支持不许改动单音路径的输出
    if jptok.parse_token(",4,,b5,,3,,1") == jptok.parse_token("4"):
        bad += 1
        lines.append("  ✗ 和弦 token 被当成了单音")
    return bad, lines


def _corpus_files(scores):
    return sorted(f for f in os.listdir(scores)
                  if f.endswith(".txt") and not f.endswith(("_expand.txt", "_buf.txt")))


def _old_seq(body):
    """按**改动前**的口径重放整份谱 -> (seq, 逐token有音高的音数)。

    ⚠ 必须用"改动前那条 TOKEN 正则 + 改动前的 pitched() 逻辑"自己重放一遍, 不能拿
    新 jptok 的任何函数 —— 否则就是"用被测代码给被测代码分类", 反而证明不了兼容性。
    ⚠ 也不能拿旧 jptok 的 `seq()` 直接算, 那样基线就得绑死在旧副本上; 这里自己实现一份,
    判据只有 SINGLE_SHAPE(改动前的白名单形状)+ 连音线规则(改动前就有, 本次没动)。
    """
    out, tie, last_note, n_raw = [], False, False, 0
    for t in (body or "").split():
        if t == "~":
            tie = last_note
            continue
        if t == "-" or re.match(r"^[cqsdh]+-$", t or ""):
            continue                       # 延长记号: 不打断连音线(改动前就有的行为)
        notes = _old_shapes(t)
        if not notes:
            tie, last_note = False, False
            continue
        n_raw += 1
        p = notes[0]
        if tie and out and (out[-1][0], out[-1][1]) == p:
            tie, last_note = False, True
            continue
        out.append(p)
        tie, last_note = False, True
    return out, n_raw


def _old_shapes(t):
    """改动前那条 `TOKEN` 正则单独认出的音: 有音高返回 [(音级,变音)] 否则 []。

    与 jptok 无关的第二份写法是故意的: 这是**独立判据**, 不能拿被测代码给自己分类。
    ⚠ 只对**单音形状**(音级恰好 1 个)有意义; 实测全库没有一个和弦 token 是单音形状
    (SINGLE_SHAPE 计数 = 0), 所以这里的取法不会误伤。
    ⚠ 改动前 `parse_token` 返回的是**元组**; 这里只留 (音级, 变音) 两项 —— 连音线判据
    只看这两项(改动前就是), 八度不参与。
    """
    if not SINGLE_SHAPE.match(t or ""):
        return []
    dig = re.search(r"([1-7x0])[,']*[#b♯♭]?[cqsdh]*[.]*\]?$", t or "")
    if not dig or dig.group(1) in ("0", "x"):
        return []
    return [(int(dig.group(1)), _acc_of(t))]


def _acc_of(t):
    return 1 if ("#" in t or "♯" in t) else (-1 if ("b" in t or "♭" in t) else 0)


def _all_of(t):
    """当前 jptok 的口径: a token -> [每个音]。

    加这一层是为了**能用改动前的 jptok 跑基线**: 那份副本(从 git HEAD 抽出来的)只有
    `parse_token`, 没有 `parse_token_all`(它正是本次新增的)。直接调 `jptok.parse_token_all`
    会在生成基线时 AttributeError —— 前一个 agent 就是这么把基线搞丢的。
    """
    if hasattr(jptok, "parse_token_all"):
        return jptok.parse_token_all(t)
    got = jptok.parse_token(t)
    if got is None:
        return []
    return got if isinstance(got, list) else [got]


def _tokens_and_files(scores):
    """-> (不同 token 的判定表, 逐文件指纹, 含和弦的文件 set, 逐文件"和弦里有音高的音数", 全局计数)

    逐文件的指纹里额外记两项(改动前该文件 seq 的音数与它的音多重集指纹), 给 compare 的 ③ 配平用。
    """
    toks, files, chord_files = {}, {}, set()
    chord_pitch_per_file = {}
    n_chord_tok = n_chord_note = n_chord_pitch = n_chord_rest = n_single_shape = 0
    for fn in _corpus_files(scores):
        raw = io.open(os.path.join(scores, fn), encoding="utf-8", errors="replace").read()
        _head, _sep, body = raw.partition("%--")
        words = body.split()
        n_pitch_here = 0
        for t in words:
            if "\t" in t or "\n" in t:
                continue
            if t not in toks:
                p = jptok.parse_token(t)
                toks[t] = [repr(p), int(jptok.is_note(t)), int(jptok.is_pitch(t)),
                           jptok.duration_letter(t), repr(jptok.beat(t))]
            if CHORD_SHAPE.match(t) and len(DIGITS.findall(t)) >= 2:
                chord_files.add(fn)
                n_chord_tok += 1
                n_chord_note += len(DIGITS.findall(t))
                for d, _a, _o in _all_of(t):
                    if d is None:
                        n_chord_rest += 1
                    else:
                        n_chord_pitch += 1
                        n_pitch_here += 1
                if SINGLE_SHAPE.match(t):
                    n_single_shape += 1     # 应该永远是 0(见 SINGLE_SHAPE 的说明)
        if n_pitch_here:
            chord_pitch_per_file[fn] = n_pitch_here
        seq = jptok.seq(body)
        old_seq, old_raw = _old_seq(body)
        new_raw = sum(1 for t in words for d, _a, _o in _all_of(t) if d is not None)
        bpb = jptok.beats_per_bar_from(raw)
        bars = jptok.recover_bars([{"subtitle": "score", "score": " ".join(words)}], bpb)
        files[fn] = [1 if fn in chord_files else 0, len(words), len(seq), _fingerprint(seq),
                     _fingerprint(bars), old_raw, _fingerprint(sorted(old_seq)), new_raw]
    return (toks, files, chord_files, chord_pitch_per_file,
            dict(n_chord_tok=n_chord_tok, n_chord_note=n_chord_note, n_chord_pitch=n_chord_pitch,
                 n_chord_rest=n_chord_rest, n_single_shape=n_single_shape))


def dump(scores, out):
    (toks, files, chord_files, cpf, n) = _tokens_and_files(scores)
    with io.open(out, "w", encoding="utf-8") as f:
        f.write(json.dumps({"kind": "tokens", "n": len(toks)}, ensure_ascii=False) + "\n")
        for t in sorted(toks):
            f.write(json.dumps({"t": t, "v": toks[t]}, ensure_ascii=False) + "\n")
        f.write(json.dumps({"kind": "files", "n": len(files),
                            "chord_files": sorted(chord_files), "chord_pitch": cpf,
                            "counts": n}, ensure_ascii=False) + "\n")
        for fn in sorted(files):
            f.write(json.dumps({"f": fn, "v": files[fn]}, ensure_ascii=False) + "\n")
    n_notes = sum(v[2] for v in files.values())
    print("%d 份谱 / %d 个不同 token / 含和弦的 %d 份 -> %s"
          % (len(files), len(toks), len(chord_files), out))
    print("  和弦 token %d 个(写明 %d 个音; 有音高 %d + 休止念白 %d) · 改动前进索引的音 %d"
          % (n["n_chord_tok"], n["n_chord_note"], n["n_chord_pitch"], n["n_chord_rest"], n_notes))
    if n["n_single_shape"]:
        print("  ! 有 %d 个和弦 token 是「单音形状」(改动前就能认出)-> 逐文件配平要减项"
              % n["n_single_shape"])


def load_baseline(path):
    toks, files, chord_files, cpf, counts = {}, {}, [], {}, {}
    with io.open(path, encoding="utf-8") as f:
        for ln in f:
            o = json.loads(ln)
            k = o.get("kind")
            if k == "tokens":
                continue
            if k == "files":
                chord_files = o["chord_files"]
                cpf = o.get("chord_pitch") or {}
                counts = o.get("counts") or {}
                continue
            if "t" in o:
                toks[o["t"]] = o["v"]
            else:
                files[o["f"]] = o["v"]
    return toks, files, set(chord_files), cpf, counts


def compare(scores, base):
    btok, bfile, bchord, _bcpf, _bcnt = load_baseline(base)
    (toks, files, _chord, cpf, n) = _tokens_and_files(scores)
    print("jptok = %s" % jptok.__file__)
    print("基线  = %s\n" % base)

    # ① 逐 token
    changed = [t for t in sorted(set(btok) & set(toks)) if btok[t] != toks[t]]
    new_tok = sorted(set(toks) - set(btok))
    gone_tok = sorted(set(btok) - set(toks))
    bad_tok = [t for t in changed if not (CHORD_SHAPE.match(t) and len(DIGITS.findall(t)) >= 2)]
    print("① 逐 token: 比过 %d 个不同 token; 变了 %d 个; 新增 %d; 消失 %d"
          % (len(btok), len(changed), len(new_tok), len(gone_tok)))
    for t in bad_tok[:10]:
        print("   ✗ 非和弦 token 变了: %r  前 %s  后 %s" % (t, btok[t], toks[t]))
    for t in changed[:5]:
        print("   · %-14r 前 %s -> 后 %s" % (t, btok[t], toks[t]))

    # ② 逐文件(只比基线里有的那几项: 新格式多存了一个"逐token音数"给 ③ 用)
    n_cmp = min(len(bfile[f]) for f in bfile) if bfile else 0
    fdiff = [f for f in sorted(set(bfile) & set(files))
             if bfile[f][:n_cmp] != files[f][:n_cmp]]
    bad_file = [f for f in fdiff if f not in bchord]
    print("\n② 逐文件: 比过 %d 份(每份比 %d 项: 含和弦标记/词数/seq音数/seq指纹/bars指纹"
          "/改动前逐token音数/改动前音多重集指纹); seq/bars 指纹变了 %d 份; 其中含和弦的 %d 份"
          % (len(bfile), n_cmp, len(fdiff), len(fdiff) - len(bad_file)))
    for f in bad_file[:10]:
        print("   ✗ 不含和弦的文件变了: %s 前 %s 后 %s" % (f, bfile[f], files[f]))

    # ③ 逐文件配平(**这才是"原来一个不少、丢掉的都回来"的证明**)
    #    基线里每份谱记了"改动前"的**两个层次**的音数:
    #      bfile[f][5] = 改动前**逐 token 有音高**的音数(不并连音线)   —— 对应新 files[f][7]
    #      bfile[f][2] = 改动前 seq() 的音数(已并连音线)             —— 对应新 files[f][2]
    #    于是每份含和弦的谱有两句**精确到 1** 的配平式:
    #      (a) 新逐token - 旧逐token == 该文件和弦 token 里**有音高**的音数 want
    #          (和弦 token 改动前一个音都不贡献 —— 实测 SINGLE_SHAPE 计数 = 0,
    #           所以旧逐token 里根本没有和弦的音)
    #      (b) 新 seq - 旧 seq == want - 多并掉的音数
    #    ⚠ 为什么会有"多并掉": 和弦展开会**插入**音, 连音线 `~` 两侧对上的那一对可能与改动前
    #      不是同一对 —— 实测全库多并 323 个(少进索引 323 个; 不是丢音, 是被算成一个音头)。
    #      更要紧的是:**旧序列不是新序列的子序列**(并掉谁会让后面的音整体前移),
    #      所以"一个不少"只能用**多重集**核, 不能用子序列核(我第一版就写错了)。
    grew = gain = extra_tot = 0
    shrank, mismatch, lost = [], [], []
    for f in sorted(bchord):
        if f not in bfile or f not in files:
            continue
        before, after = bfile[f][2], files[f][2]
        want = cpf.get(f, 0)
        # (a) 逐 token 层次
        if len(bfile[f]) > 5 and len(files[f]) > 7:
            d_raw = files[f][7] - bfile[f][5]
            if d_raw != want:
                mismatch.append(("逐token", f, bfile[f][5], files[f][7], want))
        # (b) seq 层次
        extra = want - (after - before)
        if extra < 0:
            mismatch.append(("seq", f, before, after, want))
        else:
            extra_tot += extra
        if after > before:
            grew += 1
            gain += after - before
        elif after < before:
            shrank.append((f, before, after))
        # 改动前的音(多重集)一个不少
        if len(bfile[f]) > 6 and len(files[f]) > 6 and bfile[f][6] != files[f][6]:
            lost.append((f, bfile[f][2], files[f][2]))
    print("\n③ 含和弦的 %d 份: 音数增加 %d 份(共 +%d 个音); 减少 %d 份"
          % (len(bchord), grew, gain, len(shrank)))
    for row in shrank[:5]:
        print("   ✗ 音数变少: %s %d -> %d" % row)
    for row in mismatch[:10]:
        print("   ✗ 配平式对不上: %s %s 前 %d 后 %d 和弦音 %d" % row)
    print("   本次改动新进索引的和弦音 = %d（全库和弦里有音高的音共 %d 个, 分在 %d 个和弦 token 里）"
          % (gain, n["n_chord_pitch"], n["n_chord_tok"]))
    print("   其中 %d 个新音与前面的音被连音线并成一个音头(所以没进索引), 逐文件解出的"
          "「多并数」合计 = %d" % (n["n_chord_pitch"] - gain, extra_tot))
    print("   改动前已认出的音(逐文件 seq 音多重集指纹, 含和弦的 %d 份): %s"
          % (len(bchord), "%d 份全部保留 ✓" % len(bchord) if not lost
             else "!! %d 份对不上 %s" % (len(lost), lost[:5])))
    for f, a, b in lost[:5]:
        print("      %s 改动前 seq %d 个音, 现在 %d 个音" % (f, a, b))

    ok = (not bad_tok and not bad_file and not shrank and not mismatch
          and not gone_tok and not new_tok and not lost)
    print("\n%s" % ("逐 token / 逐文件对拍通过 ✓（差异全部落在和弦 token 与含和弦的文件里, 且逐文件配平）"
                    if ok else "!! 对拍失败(见上面的 ✗)"))
    return 0 if ok else 1


def _corpus_anchor(a):
    """语料锚点: 今天的实测规模必须与文档写的一致(否则要么语料变了、要么口径变了)。"""
    (toks, files, chord_files, cpf, n) = _tokens_and_files(a.scores)
    want = dict(tokens=21193, chord_files=223, chord_tok=261647, chord_pitch=646710)
    got = dict(tokens=len(toks), chord_files=len(chord_files),
               chord_tok=n["n_chord_tok"], chord_pitch=n["n_chord_pitch"])
    bad = []
    for k, v in want.items():
        if got[k] != v:
            bad.append("%s 期望 %d, 实得 %d" % (k, v, got[k]))
    print("④ 语料锚点: " + ("与文档一致 ✓ (%s)" % ", ".join("%s=%d" % (k, got[k]) for k in sorted(got))
                             if not bad else "!! " + "; ".join(bad)))
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scores", default=os.path.join(DB, "scores"))
    ap.add_argument("--dump", default="")
    ap.add_argument("--baseline", default="")
    ap.add_argument("--anchor", action="store_true", help="比今天的语料规模与文档写的数")
    ap.add_argument("--skip-cases", action="store_true")
    a = ap.parse_args()

    rc = 0
    if not a.skip_cases:
        bad, lines = _cases_report()
        print("内置用例(%d 个 token 用例 + %d 个非 token):" % (len(CASES), len(NOT_TOKENS)))
        for ln in lines:
            print(ln)
        print("  用例: %s\n" % ("全部通过 ✓" if not bad else "%d 个 ✗" % bad))
        rc = 1 if bad else 0
    if a.anchor:
        rc |= 1 if _corpus_anchor(a) else 0
    if a.dump:
        dump(a.scores, a.dump)
    if a.baseline:
        rc |= compare(a.scores, a.baseline)
    return rc


if __name__ == "__main__":
    sys.exit(main())
