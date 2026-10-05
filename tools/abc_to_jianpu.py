# -*- coding: utf-8 -*-
"""ABC -> 简谱数字串转换器(入库形态)。

2026-10-06: 从 `_analysis/abc_to_jianpu.py` **移进仓库**(`jianpu2/tools/`), 并抽出**公共口径** ——
调号与音级映射、时值切分、token 形态、八度归一、和弦写法、source 命名、语料头部排版、
以及"每个 token 过 jptok 白名单 + jianpu-db/score.py 能解析"这两道校验, 全部落在
`tools/convert_common.py`(**唯一一份**), 与 MIDI 版 `tools/midi_to_jianpu.py` 共用。
理由是这个项目最怕口径漂移: token 白名单曾在 score.py / show_hit.py / 前端 search.js 里
各写一份, 结果带 `#` 的音在 data.jsonl 里**整段丢掉**(18 首中招); 转换口径同理, 抄两份必漂。

本文件只负责"ABC 这一半": 头/正文切分、分词、反复与段序展开、以及 ABC 特有的记账。
**不往 `jianpu-db/scores/` 写任何东西**: 产物只出到 `--outdir`(探针), 入库由人工/流水线决定。

作者 2026-10-04 定的三条口径(照做, 不再改)
==========================================
① `status=converted`(机械转换, 与 `midi` 区分) —— 已加进
   `jianpu-db/parse_scores.py` 的 `OK_STATUS` 与 `jianpu2/tools/check_corpus_invariants.py` 的白名单。
   **MIDI 转换属于同一类**, 也写 `converted`。
② **小调一律 La-based**: 主音记 `,6`(与 `jianpu-db/README.md`"小调一级记作`,6`; 大调一级记作`1`"一致)。
   换算规则: `1=` 取**同调号的关系大调主音**, 且该参考音比小调主音**高一个八度**位置 ——
   于是自然小调音阶写出来是 `,6 ,7 1 2 3 4 5 6`。大调仍是 Do-based(主音 `1`)。
③ `source` 形状 `<站点token>-<id>`: 站点 token = 来源集合名(`abcgh`/`abczd`/`abcnm`),
   id = `sha1(仓库路径 + '#' + 文件内序号)[:12]`(**必须含文件内序号**, 否则 `X:` 块里粘的第二首会撞车)。
反复展开(唯一的入库级拦路)
==========================
**实现**: `|:` `:|` `::` `:|:` `|::` + `[1`/`[2`/… 房子 + 不带方括号的 `|1`/`|2` + `P:` 段序(`Y:` 演奏顺序)。
规矩: 段内 `:|` 无配对 `|:` 时回到**本段开头**(不是整首开头 —— 否则多段曲会指数爆炸);
`[1 … :| [2 …` 的首/次结尾按 ABC 语义展开(第二遍跳过 `[1` 走 `[2`);
输出**一个反复记号都不留**(语料正文里没有反复记号)。
`Y:` 不是标准 ABC 字段(Standard 1.6/2.1 都没有), 它是 Nottingham 清洗版加的"段落演奏顺序", 语义有两义:
  - 若某段字母在 `Y:` 里出现 **≥2 次** -> 按 `Y:` 逐次播放该段**原文一遍**(不再叠加段内 `:|`);
  - 若只出现 **1 次** -> 该段按 ABC 语义展开(段内 `:|` 生效)。
  这条是**启发式**, 理由是两条都满足: ①`Y:AB` + 每段以 `:|` 收尾 = 民谣标准的 `AABB`;
  ②`Y:AA`(单段, 文件里 `N:A(acc) A(unacc)`)只播两遍, 与 `N:` 注释一致。

仍未做(诚实清单)
================
  * 连音 `(3`/broken rhythm `>` 的**时值比例**未缩放(音高不受影响; 单列 `dur_lossy` 记账);
  * 和弦各音**时值不齐**时(jianpu-ly 只给一个时值)按第一个音出 + 记 `chord_mixed_len`;
  * `V:` 多声部 / `&` 声部叠加: 原样判错, 不做;
  * 行内 `[K:]/[L:]/[M:]` 已认, 其它行内字段记 `inline_field`(判为结构性);
  * 未闭合的 `|:` 只播一遍 + 记 `unclosed_repeat`;
  * `!segno!`/`!D.C.!`/`!fine!` 跳转记号与 `P:(AB)2` 段序仍**判否**(记 `jump_mark`/
    `parts_order_complex`); 占比已量化在 `abc_chord_octave_report.md` 里, 等作者定口径。

作者 2026-10-05 又定的两条(已实现)
=================================
④ **八度归一**: 整首升/降 12 个半音这两个方案里, 取 `,` + `'` 记号总数最少的那种;
   两者计数相同(或都比原样差)则保持原样 —— 见 `normalize_octave()`。
   实测: 只整体平移, **音级序列一个都不动**; 平移若让任何音超出 jianpu-ly 认的 ±3 个记号, 该方案作废。
⑤ **和弦按和弦输出**: ABC 的 `[a2A2]`(同时发声)写成 jianpu-ly 的**数字连写**(如 `,1'35`),
   **不摊平成序列、也不丢音**。形态取自语料实测(261611 个和弦 token / 223 首 / 全是 status=midi):
   `[时值字母][(八度记号 变音? 音级) …][附点]`, 八度记号写在**各自音级前面**。
  ✅ **下游缺口已闭**(2026-10-05 复核实测): `jianpu-db` 唯一的 token 实现现在**认和弦 token**。
   实测 `jptok.parse_token('135')` -> `[(1,0,0),(3,0,0),(5,0,0)]`, `seq('1 64 2')` -> 4 个音
   (以前和弦里的音会**整批丢掉**; 本文件自检里那条旧断言已按实测改成"认得且不丢音")。


用法
----
    py -3.13 abc_to_jianpu.py <file.abc> [--tune N] [--json] [--all] [--scan] [--corpus]
    py -3.13 abc_to_jianpu.py --selfcheck          # 本器自检(含与公共口径的一致性)
    py -3.13 abc_to_jianpu.py --run <manifest.tsv> --outdir <dir> --per-file 5
    py -3.13 abc_to_jianpu.py --regress-cc0 <_cc0_ingest_manifest.tsv> \
        --samples-dir <abc_samples/cc0_all>        # 492 首已入库 ABC 产物: 逐 token + 逐字节回归
    py -3.13 convert_common.py --selfcheck         # 只验公共口径
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

# 公共口径(调号/音级/时值/token/八度归一/和弦/source/语料排版/校验)只有一份, 在这里:
#   tools/convert_common.py。本器与 midi_to_jianpu.py 都从它 import, 不许在本文件里再抄一遍。
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import convert_common as cc                                     # noqa: E402
from convert_common import (                                     # noqa: E402
    ABC_OCT_BASE, CHORD_TOK_RE, ConvertError, DEGREE_TABLE, FIELD_RE, FIG_RE,
    FLAT_ORDER, LETTER_IDX, MAJOR_BASE, MAX_OCT, MINOR_MODES, MODE_STEPS,
    NATURAL_PC, PITCH_TOK_RE, SHARP_ORDER, SRC_RE, TuneResult as CommonTuneResult,
    count_octave_marks, count_rest_tokens, degree_of, degree_of_abs, fig_oct,
    key_label, key_sig_text, load_jptok, make_source, normalize_octave,
    parse_key, shift_token_octave, source_id, spell_midi, split_duration,
    token_figures, token_note_count, wrap_tokens,
)

# 旧名保留: 本器历史上有 AbcError, 现在与公共模块的 ConvertError 同一个类
AbcError = ConvertError

# 2026-10-05 新修的两个**解析拦路**的开关(只为**实测对比旧数字**保留: 关掉 = 修复前的行为)。
# 正式转换恒为 True; `_abc_fix_account.py` 那类脚本会把它们改成 False 跑一份对照。
INLINE_COMMENT_FIX = True
DOLLAR_LINEBREAK_FIX = True


def strip_inline_comments(text):
    """ABC 标准: 行内 `%` 之后到行尾都是注释(`%` 起头的整行更不必说)。

    实测(CC0 全批 3234 首): 解析失败的 1105 首里 **724 首**的根因就是它 —— 源里在谱面行尾
    用 `%` 写注释(形如 `| G2 A |% 手写注`)。以前分词器把注释文字当正文 -> `other` 分支报
    "未识别的字符", 整首判错。
    ⚠ 行首 `%%` 是**指令行**(`%%endtext`/`%%MIDI`), 而且 `%%endtext` 参与拆曲, 必须原样留着
      交给上层按 `%` 跳过 —— 所以这里只对"行首不是 `%`"的行下手; 引号 `"…"` 里的 `%` 也不动。
    """
    out = []
    for line in text.splitlines():
        if line.lstrip().startswith('%'):
            out.append(line)
            continue
        in_q = False
        cut = len(line)
        for i, ch in enumerate(line):
            if ch == '"':
                in_q = not in_q
            elif ch == '%' and not in_q:
                cut = i
                break
        out.append(line[:cut])
    return '\n'.join(out)


def linebreak_chars(text):
    """`I:linebreak $` -> {'$'}: 该文件里 `$` 也算换行。

    实测(CC0 全批): 解析失败的 229 首全部来自 `RVW2-2-2 to 201.abc` 这类
    "I:linebreak $"(源里用 `$` 当排版换行, 形如 `… D3 z2 G |$ G2 B …`)。
    ABC 只允许 `<EOL>`/`$`/`;` 三种 linebreak; `$` 在正文里**没有别的含义**
    (不是音名/时值/记号), 所以缺省就认 `$`; `;` 只在 `I:linebreak ;` 明确声明时才当换行。
    """
    chars = {'$'}
    for line in text.splitlines():
        s = line.strip()
        if s.startswith('I:') and 'linebreak' in s.lower():
            val = s.split('linebreak', 1)[-1].strip()
            if val[:1] in ('$', ';'):
                chars.add(val[0])
    return chars


# --------------------------------------------------------------------------
# 时值: ABC 长度 -> 四分音符数(时值 -> token 的那一步在 convert_common 里)
# --------------------------------------------------------------------------
def parse_abc_len(s):
    """ABC 长度串 -> 相对 L: 的倍数。'' -> 1; '2' -> 2; '/' -> 0.5; '3/2' -> 1.5; '//' -> 0.25"""
    if not s:
        return 1.0
    m = re.fullmatch(r'(\d*)(/+)(\d*)', s)
    if m:
        a, sl, b = m.groups()
        num = float(a) if a else 1.0
        den = float(b) if b else float(2 ** len(sl))
        return num / den
    try:
        return float(s)
    except ValueError:
        raise AbcError('长度串无法解析: %r' % s)


def parse_fraction(s):
    """'1/8' / '4/4' / 'C' / 'C|' -> (num, den)"""
    s = (s or '').strip()
    if s in ('C', 'c'):
        return (4, 4)
    if s in ('C|', 'c|'):
        return (2, 2)
    m = re.match(r'^(\d+)\s*/\s*(\d+)', s)
    if m:
        return (int(m.group(1)), int(m.group(2)))
    raise AbcError('拍号无法解析: %r' % s)


# --------------------------------------------------------------------------
# 正文分词 -> 事件流
# --------------------------------------------------------------------------
BODY_RE = re.compile(r"""
   (?P<inlinefield>\[[A-Za-z]:[^\]\n]*\])
 | (?P<ending>\[\d)
 | (?P<barline>:\|:|\|::|::|\|\]|\|\||\[\||:\||\|:|\|)
 | (?P<chord>"[^"\n]*")
 | (?P<grace>\{[^}\n]*\})
 | (?P<deco>![^!\n]*!|\+[^+\n]*\+)
 | (?P<tuplet>\(\d+)
 | (?P<multirest>Z\d*)
 | (?P<rest>[zx])
 | (?P<note>[\^_=]{0,2}[A-Ga-g][',]*(?P<nlen>[0-9/]*))
 | (?P<tie>-)
 | (?P<broken>[<>]+)
 | (?P<roll>~)
 | (?P<slur>[()])
 | (?P<chordopen>\[)
 | (?P<chordclose>\])
 | (?P<staccato>\.)
 | (?P<legacydeco>[HLMPSTuv])
 | (?P<ws>\s+)
 | (?P<other>.)
""", re.X)

# 事件: ('n', token) 音符 / ('t', token) 其它输出 token / ('b', kind) 小节线
#       ('end', n) 房子 / ('part', 'A') P: 段标记
BAR_SUB = {'|': 'single', '||': 'double', '|]': 'final', '[|': 'single'}
REPEAT_SUB = {'|:': ('open',), ':|': ('close',), '::': ('close', 'open'),
              ':|:': ('close', 'open'), '|::': ('close', 'open')}

# --------------------------------------------------------------------------
# 本器开关 + ABC 的和弦组语法(其余 token 形态在 convert_common 里, 一份口径)
# --------------------------------------------------------------------------
# 作者 2026-10-05 口径①: 整首 ±12 半音归一(取 `,`+`'` 总数最少者, 平手保持原样)。
# 关掉它只为**实测对比**(`abc_fix_account` 那类脚本), 正式转换恒为 True。
OCTAVE_NORMALIZE = True

# ABC 正文里一个**和弦组**: `[` + 一个以上"变音串+音名字母+八度记号+长度" + `]`
ABC_CHORD_RE = re.compile(r"\[((?:[\^_=]{0,2}[A-Ga-g][',]*[0-9/]*)+)\]")
ABC_NOTE_RE = re.compile(r"([\^_=]*)([A-Ga-g])([',]*)([0-9/]*)")


class TuneResult(CommonTuneResult):
    """ABC 侧的转换结果: 公共字段(音数/休止/和弦/八度归一/记账三档)在 convert_common 里,
    这里只加 ABC 特有的那些, 以及 `to_dict()`(--json 的字段清单, 与移动前逐字一致)。"""

    def __init__(self):
        CommonTuneResult.__init__(self)
        self.key_label = ''
        self.key_1 = ''
        self.key_sig_text = ''
        self.la_based = False
        self.meter = ''
        self.meter_quarters = 4.0
        self.default_len = ''
        self.title = ''
        self.source = ''
        self.link = ''
        self.page_url = ''
        self.x = ''
        self.repeats_expanded = 0
        self.parts_order = ''
        self.idx_in_file = 0
        self.source_id = ''
        self.n_stray_marker = 0      # 展开后残留的房子/段标记个数(不是 token, 已丢弃并记账)

    def to_dict(self, name=''):
        return {
            'name': name,
            'x': self.x,
            'title': self.title,
            'source': self.source_id,
            'link': self.link,
            'page_url': self.page_url,
            'key': self.key_label,
            'key_1': self.key_1,
            'la_based': self.la_based,
            'key_signature': self.key_sig_text,
            'meter': self.meter,
            'default_len': self.default_len,
            'ok': self.ok,
            'clean': self.clean,
            'pitch_safe': self.pitch_safe,
            'lossy_kinds': self.lossy,
            'dur_lossy_kinds': self.dur_lossy,
            'errors': self.errors,
            'unsupported': {k: v for k, v in self.unsupported.items()},
            'n_pitch_raw': self.n_pitch_raw,
            'n_pitch': self.n_pitch,
            'n_notes_raw': self.notes_total,
            'n_rest_seen': self.n_rest_seen,
            'n_rest_emitted': self.n_rest_emitted,
            'n_dur_approx': self.dur_approx,
            'repeats_expanded': self.repeats_expanded,
            'parts_order': self.parts_order,
            'idx_in_file': self.idx_in_file,
            'n_chord': self.n_chord,
            'n_chord_notes': self.n_chord_notes,
            'n_stray_marker': self.n_stray_marker,
            'oct_shift': self.oct_shift,
            'oct_marks_before': self.oct_marks_before,
            'oct_marks_after': self.oct_marks_after,
            'score': ' '.join(self.tokens),
        }


# --------------------------------------------------------------------------
# 头 / 正文 切分
# --------------------------------------------------------------------------
def split_head_body(text):
    """ABC 文本 -> (headers list[(K,V)], body_lines list[str])。

    口径: **第一个 `K:` 之前的字段行**算头; 之后的字段行(`K:`/`P:`/`W:` …)留在正文里,
    由分词器逐类处理(`W:` 歌词直接跳, `P:` 变成段标记, 第二个 `K:` 变调并记账)。
    以前把所有行首字段都当头部 -> 中段 `P:A` 的位置信息丢失, 且 `Y:`(自定义字段)漏掉会把
    `Y:AB` 当正文把整首判错(实测 4/20)。
    """
    headers = []
    body = []
    seen_k = False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith('%'):
            if seen_k:
                body.append(line)       # %%MIDI / %%VWML 等行内指令 -> 交给分词器忽略
            continue
        m = FIELD_RE.match(s)
        if m and not seen_k:
            k = m.group(1).upper()
            headers.append((k, m.group(2).strip()))
            if k == 'K':
                seen_k = True
            continue
        body.append(line)
    return headers, body


def _emit_note(r, q, deg, acc_s, octn):
    """一个音 -> 事件 + token。"""
    oct_pre = ',' * (-octn) if octn < 0 else ''
    oct_post = "'" * octn if octn > 0 else ''
    parts = split_duration(q)
    if parts is None:
        r.dur_approx += 1
        parts = [(('' if q >= 1.0 else 'q'), 0)]
    letter, dots = parts[0]
    tok = letter + oct_pre + acc_s + str(deg) + oct_post + ('.' * dots)
    r.events.append(('n', tok))
    r.n_pitch_raw += 1
    r.notes_total += 1
    for dtok, _ in parts[1:]:
        r.events.append(('t', dtok))


def _emit_chord(r, q, figs):
    """同时发声的和弦 -> 一个事件 + 一个**和弦 token**(jianpu-ly 数字连写写法)。

    figs: [(音级, 变音串, 八度数), …], 按源里的书写顺序。
    token 形态: `[时值字母][(八度记号 + 变音 + 音级) …][附点]` —— 记号一律写在各自音级**前面**
    (与语料 261611 个和弦 token 一致; 写在后面会被 jianpu-ly 归给下一个音)。
    """
    parts = split_duration(q)
    if parts is None:
        r.dur_approx += 1
        parts = [(('' if q >= 1.0 else 'q'), 0)]
    letter, dots = parts[0]
    body = []
    for deg, acc_s, octn in figs:
        # ⚠ 和弦里**必须**把八度记号写在各自音级前面: 写在后面会被 jianpu-ly 归给**下一个**音
        #   (`5'5` 读成 5 与高音5, 而不是高音5 与 5 —— 音级不同时就是错音)。
        marks = ',' * (-octn) if octn < 0 else "'" * octn
        body.append(marks + acc_s + str(deg))
    tok = letter + ''.join(body) + ('.' * dots)
    r.events.append(('n', tok))
    r.n_pitch_raw += len(figs)
    r.notes_total += len(figs)
    r.n_chord += 1
    r.n_chord_notes += len(figs)
    for dtok, _ in parts[1:]:
        r.events.append(('t', dtok))


def acc_value(marks):
    """ABC 变音记号串(`^`/`_`/`=`, 最多两个) -> (变音 -2..2 或 None 表示"无记号"), 错误串。"""
    if not marks:
        return None, None
    if len(marks) > 2:
        return None, '过多变音记号 %r' % marks
    if len(marks) == 1:
        return (1 if marks == '^' else (-1 if marks == '_' else 0)), None
    if marks == '^^':
        return 2, None
    if marks == '__':
        return -2, None
    return 0, None                                  # `^_`/`_^`/`^=` 之类 -> 互相抵消


def pitch_of_note(r, marks, letter_ch, octmarks, key):
    """ABC 一个音(变音串 + 音名字母 + 八度记号) -> (音级 1..7, 变音串 '', 八度数) 或 None。"""
    acc, err = acc_value(marks)
    if err:
        r.errors.append(err)
        return None
    if acc is not None and abs(acc) > 1:
        r.flag('double_accidental', marks + letter_ch)
        acc = 1 if acc > 0 else -1
    li = LETTER_IDX[letter_ch.upper()]
    deg, delta, octn = degree_of(li, acc, octmarks, letter_ch.islower(), key)
    if abs(delta) > 1:
        r.flag('wild_accidental', '%s%s delta=%d' % (marks, letter_ch, delta))
        delta = 1 if delta > 0 else -1
    return deg, ('#' if delta > 0 else ('b' if delta < 0 else '')), octn


def tokenize_body(body_lines, r: TuneResult, key: Key, lmul: float):
    """正文行 -> 事件流(顺带把所有子集外构造记账)。"""
    for lineno, line in enumerate(body_lines, 1):
        s = line.strip()
        if not s or s.startswith('%'):
            continue
        m = FIELD_RE.match(s)
        if m:
            fld = m.group(1).upper()
            val = m.group(2).strip()
            if fld == 'P':
                r.events.append(('part', val))
                continue
            if fld in ('W', 'w'):
                continue                        # 歌词, 不是谱
            if fld == 'K':
                r.flag('key_change', 'K:%s @%d行' % (val, lineno))
                try:
                    key = parse_key(val)
                    r.key = key
                except AbcError as e:
                    r.errors.append(str(e))
                continue
            if fld == 'M':
                try:
                    mn, md = parse_fraction(val)
                    r.meter = '%d/%d' % (mn, md)
                    r.meter_quarters = 4.0 * mn / md
                    r.flag('meter_change', val)
                except AbcError as e:
                    r.flag('meter_unparsed', str(e))
                continue
            if fld == 'L':
                try:
                    ln, ld = parse_fraction(val)
                    lmul = float(ln) / ld
                    r.flag('length_change', val)
                except AbcError as e:
                    r.flag('length_unparsed', str(e))
                continue
            # 其它字段(S:/Z:/N:/B:/F:/D: …)不是谱面内容 -> 记账, 不判错
            r.flag('body_field', '%s: @%d行' % (fld, lineno))
            continue

        pos = 0
        while pos < len(s):
            mm = BODY_RE.match(s, pos)
            if not mm:
                r.errors.append('%d行 分词卡住于 %d: %r' % (lineno, pos, s[pos:pos + 30]))
                break
            pos = mm.end()
            kind = mm.lastgroup
            txt = mm.group(0)

            if kind == 'ws':
                continue
            if kind == 'barline':
                subs = REPEAT_SUB.get(txt)
                if subs:
                    for sub in subs:
                        r.events.append(('b', sub))
                else:
                    r.events.append(('b', BAR_SUB.get(txt, 'single')))
                continue
            if kind == 'ending':
                r.events.append(('end', int(txt[1])))
                r.flag('ending_expanded', txt)
                continue
            if kind == 'chord':
                r.flag('chord_symbol', txt)
                continue
            if kind == 'grace':
                r.flag('grace_notes', txt)
                continue
            if kind == 'deco':
                # ⚠ 装饰位里混着**跳转记号**(`!segno!` / `!coda!` / `!D.C.!` / `!D.S.!` / `!fine!`):
                #   它们会改**实际演奏顺序**, 不是普通装饰 —— 当普通装饰剥掉就会"看着没错但顺序错",
                #   所以单独记成结构性(判音高不可用), 不许静默。
                if is_jump_mark(txt):
                    r.flag('jump_mark', txt)
                else:
                    r.flag('decoration', txt)
                continue
            if kind == 'tuplet':
                # 只影响时值(本次不按比例缩放, 单列 dur_lossy)
                r.flag('tuplet', txt)
                continue
            if kind == 'multirest':
                nbar = int(txt[1:]) if txt[1:] else 1
                r.n_rest_seen += 1
                r.flag('multirest', txt)
                q = r.meter_quarters * nbar
                parts = split_duration(q)
                if parts is None:
                    r.dur_approx += 1
                    parts = [('', 0)]
                letter, dots = parts[0]
                r.events.append(('t', letter + '0' + ('.' * dots)))
                r.n_rest_emitted += 1
                for dtok, _ in parts[1:]:
                    r.events.append(('t', dtok))
                continue
            if kind == 'inlinefield':
                body_txt = txt[1:-1]
                fm = FIELD_RE.match(body_txt)
                f = fm.group(1).upper() if fm else ''
                v = fm.group(2).strip() if fm else ''
                if f == 'K':
                    r.flag('key_change', txt)
                    try:
                        key = parse_key(v)
                        r.key = key
                    except AbcError as e:
                        r.errors.append(str(e))
                elif f == 'L':
                    try:
                        ln, ld = parse_fraction(v)
                        lmul = float(ln) / ld
                        r.flag('length_change', txt)
                    except AbcError as e:
                        r.flag('length_unparsed', str(e))
                elif f == 'M':
                    try:
                        mn, md = parse_fraction(v)
                        r.meter = '%d/%d' % (mn, md)
                        r.meter_quarters = 4.0 * mn / md
                        r.flag('meter_change', txt)
                    except AbcError as e:
                        r.flag('meter_unparsed', str(e))
                else:
                    r.flag('inline_field', txt)
                continue
            if kind == 'broken':
                r.flag('broken_rhythm', txt)
                continue
            if kind == 'roll':
                # ⚠ ABC 的 `~` 是 roll(装饰), 语料的 `~` 是连音线 —— 语义撞车, 绝不能直传
                r.flag('abc_roll', txt)
                continue
            if kind == 'slur':
                r.flag('slur', txt)
                continue
            if kind == 'staccato':
                # `(cB).A` 的 `.` 是**断音记号**, 不是音符也不是附点; 剥掉不影响音高
                r.flag('staccato', txt)
                continue
            if kind in ('chordopen', 'chordclose'):
                # `[a2A2]` = **同时发声**的和弦 -> 按 jianpu-ly 的数字连写写法输出(不摊平、不丢音)。
                # `[` 在 ABC 里还有三种别的用途, 都已在前面被吃掉: `[K:…]`(inlinefield)、
                # `[1`/`[2` 房子(ending)、`[|` 小节线(barline)。走到这里的 `[` 只可能是和弦。
                cm = ABC_CHORD_RE.match(s, mm.start()) if kind == 'chordopen' else None
                if not cm:
                    r.flag('note_chord', txt)
                    continue
                inner = cm.group(1)
                notes = ABC_NOTE_RE.findall(inner)
                if ''.join(''.join(t) for t in notes) != inner:
                    r.errors.append('%d行 和弦内音符切不开: %r' % (lineno, inner))
                    continue
                figs, qs, bad = [], [], False
                for marks, letter, octmarks, lenstr in notes:
                    p = pitch_of_note(r, marks, letter, octmarks, key)
                    if p is None:
                        bad = True
                        break
                    figs.append(p)
                    qs.append(lmul * parse_abc_len(lenstr) * 4.0)
                if bad or not figs:
                    continue
                pos = cm.end()
                if len(set(qs)) > 1:
                    # jianpu-ly 的和弦只有**一个**时值 -> 各音时值不齐时按第一个音出, 单列记账
                    r.flag('chord_mixed_len', '%s -> %r' % (inner, sorted(set(qs))))
                if len(figs) == 1:
                    # `[c]` 这种单音方括号: 其实就是普通音 -> 走单音路径
                    _emit_note(r, qs[0], figs[0][0], figs[0][1], figs[0][2])
                else:
                    _emit_chord(r, qs[0], figs)
                continue
            if kind == 'tie':
                if r.events and not (r.events[-1][0] == 't' and r.events[-1][1] == '~'):
                    r.events.append(('t', '~'))
                else:
                    r.flag('stray_tie', txt)
                continue
            if kind == 'legacydeco':
                # ABC 1.6 单字符装饰: T=trill H=fermata L=accent M=低音莫登特
                # P=高音莫登特 S=turn u=上弓 v=下弓(不是音名字母 A-G, 剥离 + 记账)
                r.flag('decoration', txt)
                continue
            if kind == 'other':
                if txt.isdigit() and 1 <= int(txt) <= 9 and r.events and r.events[-1][0] == 'b':
                    # 不带方括号的结尾写法: `|1 … :|2 …`
                    r.events.append(('end', int(txt)))
                    r.flag('ending_expanded', '|' + txt)
                    continue
                r.errors.append('%d行 未识别的字符 %r' % (lineno, txt))
                continue
            if kind == 'rest':
                mul = 1.0
                rm = re.match(r'^([0-9/]*)', s[pos:])
                if rm and rm.group(1):
                    mul = parse_abc_len(rm.group(1))
                    pos += len(rm.group(1))
                r.n_rest_seen += 1
                if txt == 'x':
                    r.flag('invisible_rest_x', '空休止按 0 出, 语料里 x = 念白, 语义不同')
                q = lmul * mul * 4.0
                parts = split_duration(q)
                if parts is None:
                    r.dur_approx += 1
                    parts = [(('' if q >= 1.0 else 'd'), 0)]
                letter, dots = parts[0]
                r.events.append(('t', letter + '0' + ('.' * dots)))
                r.n_rest_emitted += 1
                for dtok, _ in parts[1:]:
                    r.events.append(('t', dtok))
                continue
            if kind != 'note':
                r.errors.append('内部错误 kind=%s' % kind)
                continue

            # ---- 音符 ----
            nm = ABC_NOTE_RE.fullmatch(txt)
            if not nm:
                r.errors.append('%d行 音符切不开: %r' % (lineno, txt))
                continue
            marks, letter, octmarks, lenstr = nm.groups()
            p = pitch_of_note(r, marks, letter, octmarks, key)
            if p is None:
                continue
            deg, acc_s, octn = p
            mul = parse_abc_len(lenstr)
            q = lmul * mul * 4.0
            _emit_note(r, q, deg, acc_s, octn)


# --------------------------------------------------------------------------
# 反复 / 段序 展开
# --------------------------------------------------------------------------
def _build_repeat_tree(evs):
    """事件流(无 `part`) -> (嵌套 item 列表, 未闭合的 `|:` 个数)。

    item: ('n'/'t', tok) | ('b', 'single'|'final'|'double') | ('end', n) | ('rep', [items], explicit)
    """
    levels = [[]]
    starts = [0]
    explicit = [False]
    unclosed = 0
    for e in evs:
        if e[0] == 'b' and e[1] == 'open':
            levels.append([])
            starts.append(0)
            explicit.append(True)
        elif e[0] == 'b' and e[1] == 'close':
            if explicit[-1]:
                content = levels.pop()
                starts.pop()
                explicit.pop()
                levels[-1].append(('rep', content, True))
            else:
                # 段内 `:|` 无配对 `|:` -> 回**本段开头**;
                # 例外: 本段自上次反复边界以来已有 `[2` 房子 -> 这个 `:|` 是房子的收尾, 只当小节线
                st = starts[-1]
                seg = levels[-1][st:]
                if any(x[0] == 'end' and x[1] >= 2 for x in seg):
                    levels[-1].append(('b', 'single'))
                else:
                    levels[-1] = levels[-1][:st] + [('rep', seg, False)]
            starts[-1] = len(levels[-1])
        else:
            if e[0] == 'b' and e[1] in ('open', 'close'):
                levels[-1].append(('b', 'single'))
            else:
                levels[-1].append(e)
    while len(levels) > 1:
        content = levels.pop()
        starts.pop()
        explicit.pop()
        unclosed += 1
        levels[-1].extend(content)
    return levels[0], unclosed


def _flatten_rep(body, tail, counter):
    """一个反复组 -> 展开后的事件流。"""
    pre = []
    endings = {}
    cur = None
    for e in body:
        if e[0] == 'end':
            cur = e[1]
            endings.setdefault(cur, [])
        elif cur is None:
            pre.append(e)
        else:
            endings[cur].append(e)
    if not endings:
        counter.append(1)
        once = _flatten_level(body, counter)
        return once + once
    nums = sorted(set(endings) | set(tail))
    if len(nums) < 2:
        nums = [1, 2]
    counter.append(1)
    out = []
    for k in range(1, max(nums) + 1):
        if k > 2 and k not in nums:
            continue
        out.extend(_flatten_level(pre + endings.get(k, []) + tail.get(k, []), counter))
    return out


def _flatten_level(items, counter):
    out = []
    i = 0
    n = len(items)
    while i < n:
        it = items[i]
        if it[0] == 'rep':
            tail = {}
            j = i + 1
            # 吸收紧随其后的 `[2`/`[3` 结尾块(ABC 允许 `:| [2 …` 写成闭括号之后)
            while j < n and items[j][0] == 'end' and items[j][1] >= 2:
                num = items[j][1]
                j += 1
                chunk = []
                while j < n:
                    e = items[j]
                    if e[0] == 'end':
                        break
                    chunk.append(e)
                    j += 1
                    if e[0] == 'b' and e[1] in ('final', 'double'):
                        break
                tail[num] = chunk
            out.extend(_flatten_rep(it[1], tail, counter))
            i = j
        elif it[0] == 'b':
            out.append(('b', 'single'))
            i += 1
        else:
            out.append(it)
            i += 1
    return out


def _flatten_section(evs, expand, counter):
    if not expand:
        evs = [('b', 'single') if (e[0] == 'b' and e[1] in ('open', 'close')) else e
               for e in evs]
    tree, unclosed = _build_repeat_tree(evs)
    return _flatten_level(tree, counter)


def expand_events(r: TuneResult):
    """事件流 -> (最终 token 列表, 展开后音符事件数)。处理 `P:`/`Y:` 段序 + 反复 + 房子。"""
    evs = r.events
    # 1) 切段
    sections = []           # [(letter_or_None, events)]
    cur_letter = None
    cur = []
    for e in evs:
        if e[0] == 'part':
            if cur:
                sections.append((cur_letter, cur))
            cur_letter = (e[1] or '').strip().upper()[:1]
            cur = []
        else:
            cur.append(e)
    if cur:
        sections.append((cur_letter, cur))
    has_parts = any(l is not None for l, _ in sections)
    counter = []

    if not has_parts:
        flat = _flatten_section(evs, True, counter)
    else:
        secmap = {}
        for letter, ev in sections:
            if letter:
                secmap.setdefault(letter, []).append(ev)
        order_raw = (r.parts_order or '').strip()
        if re.search(r'[^A-Za-z\s]', order_raw):
            # `P:(AB)2` / `P:A2B2` 这种带括号或重复次数的段序, 本器只按字母顺序播一遍
            # -> 顺序可能不对, 记成结构性(判音高不可用), 绝不静默
            r.flag('parts_order_complex', order_raw)
        order = ''.join(ch for ch in order_raw.upper() if ch.isalpha())
        out = []
        used = set()
        # 首个无标记段(前导音乐)照原序先播
        for letter, ev in sections:
            if letter is None:
                out.extend(_flatten_section(ev, True, counter))
        if order:
            cnt = {}
            for ch in order:
                cnt[ch] = cnt.get(ch, 0) + 1
            for ch in order:
                if ch not in secmap:
                    r.flag('part_unmatched', ch)
                    continue
                if len(secmap[ch]) > 1:
                    r.flag('part_duplicate', ch)
                ev = secmap[ch][0]
                # 该字母在 Y: 里出现 >=2 次 -> 逐次播原文; 否则按 ABC 语义展开段内 `:|`
                expanding = cnt[ch] < 2
                out.extend(_flatten_section(ev, expanding, counter))
                used.add(ch)
                r.flag('parts_expanded', 'Y/P=%s' % order)
        else:
            for letter, ev in sections:
                if letter is None:
                    continue
                out.extend(_flatten_section(ev, True, counter))
                used.add(letter)
        for letter, ev in sections:
            if letter is not None and letter not in used:
                r.flag('part_unmatched', letter)
                out.extend(_flatten_section(ev, True, counter))
        flat = out
    r.repeats_expanded = len(counter)

    # 2) 归一: 连续 `|` 合并, 去掉最前面的 `|`
    toks = []
    n_pitch = 0
    for e in flat:
        if e[0] == 'b':
            if not toks or toks[-1] != '|':
                toks.append('|')
            continue
        if e[0] == 'n':
            n_pitch += token_note_count(e[1])          # 和弦按音数算
            toks.append(e[1])
            continue
        if e[0] in ('end', 'part'):
            # 房子号 `[1`/`|2` 或段标记漏到展开结果里(例如整个文件根本没有反复/段序):
            # 它们**不是 token**, 绝不能进数字串(以前会塞进一个 int, 让 `' '.join` 直接崩 ——
            # CC0 全批实测踩到)。记账: 音高集合仍在(顺序按原文一遍), 归 DURATION_ONLY 那一档。
            r.n_stray_marker += 1
            if e[0] == 'end':
                r.flag('ending_expanded', '展开后残留房子 %r' % (e,))
            continue
        if not isinstance(e[1], str):
            r.errors.append('展开后出现非字符串 token: %r' % (e,))
            continue
        toks.append(e[1])
    while toks and toks[0] == '|':
        toks.pop(0)
    while len(toks) > 1 and toks[-1] == '|' and toks[-2] == '|':
        toks.pop()
    return toks, n_pitch


# --------------------------------------------------------------------------
# 单曲转换
# --------------------------------------------------------------------------
def convert_tune(text, name='', parts_order=None):
    """一段单曲 ABC(含头) -> TuneResult"""
    r = TuneResult()
    # `I:linebreak $` -> `$` 也算换行; 行内 `%` 到行尾是注释。
    # ⚠ 两个开关只是为**实测对比修复前后的数字**存在(`_abc_fix_account.py` 会把它们关掉跑一遍),
    #   正式转换恒为 True。
    brk = linebreak_chars(text) if DOLLAR_LINEBREAK_FIX else set()
    if INLINE_COMMENT_FIX:
        text = strip_inline_comments(text)
    headers, body = split_head_body(text)
    hd = {}
    for k, v in headers:
        hd.setdefault(k, []).append(v)
    r.x = (hd.get('X') or [''])[0]
    r.title = ' / '.join(hd.get('T') or [])
    r.source = ' / '.join(hd.get('S') or [])
    r.page_url = (hd.get('F') or [''])[0]
    if parts_order is None:
        # `Y:`(Nottingham 清洗版自定义的段落演奏顺序)优先; 标准 ABC 的 `P:` 头其次
        y = (hd.get('Y') or [''])[0].strip()
        p = (hd.get('P') or [''])[0].strip()
        parts_order = y or p
    r.parts_order = parts_order or ''
    klist = hd.get('K') or []
    if not klist:
        r.errors.append('缺 K: 头(调号未知 -> 首调无从谈起)')
        return r
    try:
        key = parse_key(klist[0])
    except AbcError as e:
        r.errors.append(str(e))
        return r
    r.key = key
    r.key_label = key.label
    r.key_1 = key.ref_label
    r.key_sig_text = key.sig_text
    r.la_based = key.la_based
    mlist = hd.get('M') or []
    if mlist:
        try:
            mn, md = parse_fraction(mlist[0])
            r.meter = '%d/%d' % (mn, md)
            r.meter_quarters = 4.0 * mn / md
        except AbcError as e:
            r.flag('meter_unparsed', str(e))
    llist = hd.get('L') or []
    lmul = None
    if llist:
        try:
            ln, ld = parse_fraction(llist[0])
            lmul = float(ln) / ld
            r.default_len = llist[0]
        except AbcError as e:
            r.flag('length_unparsed', str(e))
    if lmul is None:
        r.flag('length_default', '缺 L: -> 按 ABC 默认 1/8 处理')
        lmul = 1.0 / 8.0

    body = [b.replace('\\', ' ') for b in body]      # ABC 换行续行
    if brk:
        # `$`(以及声明过的 `;`)是**换行**, 不是正文内容: 换成空格(等于把断行接回一行)。
        body = [b.translate({ord(c): ' ' for c in brk}) for b in body]
    tokenize_body(body, r, key, lmul)

    # ---------- 零丢失自检(必须: 历史上踩过三次静默丢音) ----------
    # ⚠ 和弦按**音数**算: 一个 `[a2A2]` 事件 = 2 个发声的音(摊平会丢一半, 这正是要防的)
    n_note_ev = sum(token_note_count(e[1]) for e in r.events if e[0] == 'n')
    if n_note_ev != r.n_pitch_raw:
        r.errors.append('音符事件数不符: 事件 %d, 计数 %d(静默丢音!)'
                        % (n_note_ev, r.n_pitch_raw))
    n_rest_ev = 0
    for e in r.events:
        if e[0] != 't':
            continue
        if re.match(r"^[cqsdh]*[',]*0", e[1]):
            n_rest_ev += 1
    if r.n_rest_seen != r.n_rest_emitted or r.n_rest_seen != n_rest_ev:
        r.errors.append('休止数不符: 见到 %d, 输出 %d, 事件 %d(静默丢音!)'
                        % (r.n_rest_seen, r.n_rest_emitted, n_rest_ev))
    if r.errors:
        r.tokens = []
        return r

    r.tokens, n_pitch_post = expand_events(r)
    r.n_pitch = n_pitch_post
    # 收尾: 八度归一 + 四条"静默丢音"断言(与 MIDI 侧**同一份实现**, 见 convert_common)
    cc.check_no_note_loss(r, n_pitch_post, normalize=OCTAVE_NORMALIZE)
    return r


# --------------------------------------------------------------------------
# 多曲文件拆分
# --------------------------------------------------------------------------
def _subsplit(lines):
    """在一个 `<X:>` 块内部再切一次(本地语料会把两首曲子粘在一个 X: 下)。

    规则: 已经见过 `K:` 且 见过 `W:`(歌词) 或 `%%endtext` 之后, 再来一个 `T:` 行 -> 新曲起点。
    紧跟第一条 `T:` 的第二个 `T:`(别名)不会触发。
    """
    starts = [0]
    seen_k = False
    seen_end = False
    for i, l in enumerate(lines):
        if i == 0:
            continue
        s = l.strip()
        if s.lower().startswith('%%endtext'):
            seen_end = True
            continue
        if re.match(r'^[A-Za-z]:', s) and not s.startswith('%'):
            k = s[0].upper()
            if k == 'K':
                seen_k = True
            elif k == 'W':
                seen_end = True
            elif k == 'T' and seen_k and seen_end:
                starts.append(i)
                seen_k = False
                seen_end = False
    return starts


def split_tunes(text):
    """按 `X:` 行拆成 [(x_value, tune_text), ...]。

    ⚠ 实测坑: 一个 `<X:>` 块里可能**粘着两首**曲子 —— 第二首没有自己的 `X:`,
    只有 `%%endtext` 或一段 `W:` 歌词之后的那个新 `T:`, 而且两首常常不同调号。
    所以两段式拆(`X:`/`%%endtext` 粗切 + 块内细切); 第二首没有 `X:` 时 x 记为空。
    """
    lines = text.splitlines()
    coarse = set()
    for i, l in enumerate(lines):
        if re.match(r'^\s*X\s*:', l):
            coarse.add(i)
    for i, l in enumerate(lines):
        if l.strip().lower().startswith('%%endtext'):
            j = i + 1
            while j < len(lines) and (not lines[j].strip() or lines[j].strip().startswith('%')):
                j += 1
            if j < len(lines):
                coarse.add(j)
    coarse = sorted(coarse)
    if not coarse:
        return [('', text)]
    starts = []
    for n, st in enumerate(coarse):
        en = coarse[n + 1] if n + 1 < len(coarse) else len(lines)
        block = lines[st:en]
        for off in _subsplit(block):
            starts.append(st + off)
    starts = sorted(set(starts))
    out = []
    for n, st in enumerate(starts):
        en = starts[n + 1] if n + 1 < len(starts) else len(lines)
        chunk = '\n'.join(lines[st:en])
        m = re.match(r'^\s*X\s*:\s*(\S*)', lines[st])
        out.append((m.group(1) if m else '', chunk))
    return out


def corpus_text(res, name, link, source, status='converted', page_url='',
                transcriber='abc2jianpu', alias=None, meter_note='', default_meter=None):
    """一首 -> 语料形态文本(`%--` 之后是正文)。

    头部字段与排版都在 `convert_common.corpus_text()`(**唯一一份**), 这里只把 ABC 侧的三条
    记账注释按原顺序拼好: `%1=`(原调/调号/拍号/L/ABC-X/展开次数/La-based)、
    `%八度归一=`(平移量/记号数/和弦数)、`%ABC 源文件=`(原始 ABC 直链)。
    `link=` **不写**: 作者给的头部清单里没有它, 而 README 口径是"必须人工核对过的收录页"
    —— ABC 的原始文件直链不是收录页。原始出处放在 `%` 注释行里(注释不进任何字段)。
    """
    comments = ['%%1=%s  原调=%s  调号=%s  拍号=%s  L:%s  ABC-X:%s  展开:%d  La-based:%s'
                % (res.key_1, res.key_label, res.key_sig_text, res.meter or '(未给)',
                   res.default_len or '(未给)', res.x or '(无)', res.repeats_expanded,
                   '是' if res.la_based else '否'),
                # ⚠ 这里与下一行都必须写 `%%`: 单个 `%` 会被当成格式化指令(`%1d` 之类)抛 ValueError;
                #   本仓库的 `1=` 调号行正好以 `1=` 开头 —— 同一个坑在语料侧也在。
                '%%八度归一=%+d  八度记号 %d->%d  和弦 %d 个(%d 音)'
                % (res.oct_shift, res.oct_marks_before, res.oct_marks_after,
                   res.n_chord, res.n_chord_notes)]
    if page_url:
        comments.append('%ABC 源文件=' + page_url)
    if meter_note:
        comments.append('%' + meter_note)
    return cc.corpus_text(title=res.title or name, source=source, name=name,
                          comments=comments, meter=res.meter or None,
                          default_meter=default_meter, alias=alias, link=link,
                          status=status, transcriber=transcriber, tokens=res.tokens)


# --------------------------------------------------------------------------
# 20 首样张批量跑
# --------------------------------------------------------------------------
def slugify(s, n=28):
    s = re.sub(r'[^0-9A-Za-z]+', '_', (s or '')).strip('_').lower()
    return s[:n] or 'untitled'


def repo_path_of(url):
    """出处 URL -> 仓库内路径(去 scheme/host/分支段)。"""
    m = re.match(r'^https?://[^/]+/(.+)$', (url or '').strip())
    p = m.group(1) if m else (url or '')
    seg = p.split('/')
    if len(seg) >= 3 and seg[2] in ('main', 'master', 'HEAD'):
        p = '/'.join(seg[:2] + seg[3:])
    elif len(seg) >= 3 and seg[0] == 'raw.githubusercontent.com':
        p = '/'.join(seg[1:2] + seg[3:])
    return p



# 会改实际演奏顺序的"装饰位"记号(ABC 把它们写在 !..! 里): `!segno!` `!coda!` `!D.C.!` `!D.S.!` `!fine!` …
JUMP_NAMES = re.compile(r'(?i)^(segno|coda|fine|d\.?\s*c\.?|d\.?\s*s\.?|'
                        r'da\s*capo|dal\s*segno|to\s*coda|dc|ds)([.\s].*)?$')


def is_jump_mark(txt):
    """`!segno!` / `!D.C.alfine!` 这类**跳转**记号 -> True(不是普通装饰)。"""
    return bool(JUMP_NAMES.match((txt or '').strip('!+').strip()))



def equi_indices(n, per_file):
    if per_file >= n:
        return list(range(n))
    if per_file <= 1:
        return [0]
    return [round(i * (n - 1) / float(per_file - 1)) for i in range(per_file)]


def do_run(manifest, outdir, per_file, limit=None):
    os.makedirs(outdir, exist_ok=True)
    rows = []
    nn = 0
    srcs = []
    for line in open(manifest, encoding='utf-8'):
        line = line.rstrip('\n')
        if not line.strip() or line.startswith('#'):
            continue
        parts = line.split('\t')
        path, url = parts[0], (parts[1] if len(parts) > 1 else '')
        site = (parts[2].strip() if len(parts) > 2 and parts[2].strip() else 'abcunk')
        if not os.path.isabs(path):
            # 相对路径先按当前目录解, 再按清单所在目录解(清单里写的是 _analysis 起算的相对路径)
            cand = [path, os.path.join(os.path.dirname(os.path.abspath(manifest)), path)]
            path = next((c for c in cand if os.path.isfile(c)), cand[0])
        with open(path, encoding='utf-8', errors='replace') as f:
            text = f.read()
        tunes = split_tunes(text)
        idxs = equi_indices(len(tunes), per_file)
        repopath = repo_path_of(url)
        for i in idxs:
            x, chunk = tunes[i]
            nn += 1
            tag = '%02d' % nn
            res = convert_tune(chunk, os.path.basename(path))
            idx_in_file = i + 1
            sid = source_id(repopath, idx_in_file)
            res.source_id = '%s-%s' % (site, sid)
            res.link = url
            res.idx_in_file = idx_in_file
            fn = '%s_%s_%s.txt' % (tag, slugify(res.title or ('x' + x), 30), slugify(x, 6))
            d = res.to_dict(os.path.basename(path))
            d['idx'] = tag
            d['file'] = fn
            d['source_file'] = os.path.basename(path)
            d['repo_path'] = repopath
            d['site'] = site
            d['url'] = url
            d['idx_in_file'] = idx_in_file
            rows.append((res, d, fn, chunk))
            srcs.append((d['source'], url, repopath, idx_in_file, os.path.basename(path)))
    # ---------- 写盘 + 断言 ----------
    for res, d, fn, chunk in rows:
        text = corpus_text(res, fn, d['url'], d['source'], status='converted',
                           page_url=res.page_url)
        with open(os.path.join(outdir, fn), 'w', encoding='utf-8', newline='\n') as f:
            f.write(text)
    with open(os.path.join(outdir, 'sources.tsv'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('idx\tsource\tsite\trepo_path\tidx_in_file\tsource_file\torigin_url\n')
        for n, (res, d, fn, chunk) in enumerate(rows, 1):
            f.write('%s\t%s\t%s\t%s\t%d\t%s\t%s\n'
                    % (d['idx'], d['source'], d['site'], d['repo_path'], d['idx_in_file'],
                       d['source_file'], d['url']))
    ids = [r[1]['source'] for r in rows]
    dup = sorted({i for i in ids if ids.count(i) > 1})
    bad = sorted(i for i in ids if not SRC_RE.match(i))
    summary = {
        'n_tunes': len(rows),
        'n_parsed': sum(1 for r in rows if r[0].ok),
        'n_pitch_safe': sum(1 for r in rows if r[0].pitch_safe),
        'n_clean': sum(1 for r in rows if r[0].clean),
        'n_la_based': sum(1 for r in rows if r[0].la_based),
        'n_pitch_raw': sum(r[0].n_pitch_raw for r in rows),
        'n_pitch_expanded': sum(r[0].n_pitch for r in rows),
        'n_rest_seen': sum(r[0].n_rest_seen for r in rows),
        'n_rest_emitted': sum(r[0].n_rest_emitted for r in rows),
        'n_dur_approx': sum(r[0].dur_approx for r in rows),
        'repeats_expanded': sum(r[0].repeats_expanded for r in rows),
        'n_chord': sum(r[0].n_chord for r in rows),
        'n_chord_notes': sum(r[0].n_chord_notes for r in rows),
        'oct_shift_counts': {str(d): sum(1 for r in rows if r[0].oct_shift == d)
                             for d in (0, 1, -1)},
        'oct_marks_before': sum(r[0].oct_marks_before for r in rows),
        'oct_marks_after': sum(r[0].oct_marks_after for r in rows),
        'source_unique': not dup,
        'source_duplicated': dup,
        'source_shape_bad': bad,
        'tunes': [r[1] for r in rows],
    }
    with open(os.path.join(outdir, 'run_report.json'), 'w', encoding='utf-8', newline='\n') as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)
    print('== %s 汇总 ==' % os.path.basename(os.path.abspath(outdir)))
    print('曲数 %d / 解析成功 %d / pitch_safe %d / 完全子集内 %d'
          % (summary['n_tunes'], summary['n_parsed'], summary['n_pitch_safe'],
             summary['n_clean']))
    print('音数: 源 %d -> 展开后 %d (反复展开次数 %d)'
          % (summary['n_pitch_raw'], summary['n_pitch_expanded'],
             summary['repeats_expanded']))
    print('和弦 %d 个 / 和弦里 %d 个音' % (summary['n_chord'], summary['n_chord_notes']))
    print('八度归一: 平移分布 %s  记号 %d -> %d'
          % (summary['oct_shift_counts'], summary['oct_marks_before'],
             summary['oct_marks_after']))
    print('source 唯一: %s  形状不合规: %s'
          % ('PASS' if not dup else 'FAIL %r' % (dup,),
             'PASS' if not bad else 'FAIL %r' % (bad,)))
    return summary


# --------------------------------------------------------------------------
# 自检
# --------------------------------------------------------------------------
def _toks_of(text):
    return convert_tune(text)


def _notes(res):
    return [t for t in res.tokens if re.match(r"^[cqsdh]*[',]*[#b]?[1-7][',]*\.*$", t)]


def _deg_oct(tok):
    m = re.match(r"^[cqsdh]*([',]*)([#b]?)([1-7])([',]*)(\.*)$", tok)
    pre, acc, deg, post, dots = m.groups()
    octn = post.count("'") - pre.count(',')
    return int(deg), octn


def _load_jptok():
    """加载本仓库的**唯一** token 实现(`skills/jianpu-melody-lookup/jptok.py`), 只读。

    实现搬进了 `convert_common.load_jptok()`, 这里保留旧名字只是别让老脚本/自检引用断掉。
    """
    return load_jptok()


def load_score_module():
    """`jianpu-db/score.py`(平台唯一解析实现); 拿不到就按 `convert_common.load_score_module()` 报错。"""
    return cc.load_score_module()


def run_selfcheck(verbose=True):
    global OCTAVE_NORMALIZE
    cases = []

    def chk(name, cond, detail=''):
        cases.append((name, bool(cond), detail))

    def conv(body, key='C', L='1/4', M='4/4', extra=''):
        return convert_tune('X:1\nT:t\nM:%s\nL:%s\nK:%s\n%s\n%s\n' % (M, L, key, extra, body))

    # ---- ① 调号隐含 ----
    r = conv('E F G A B c', key='E')
    chk('坑① K:E 的 F -> 2(不是 #1)', _notes(r) == ['1', '2', '3', '4', '5', '6'],
        'out=%r' % (_notes(r),))
    r = conv('=F', key='E')
    chk('坑① K:E 的 =F(还原号) -> b2', _notes(r) == ['b2'], 'out=%r' % (_notes(r),))
    r = conv('^F', key='E')
    chk('坑① K:E 的 ^F(调号已有 F#, 显式升号是冗余) -> 2', _notes(r) == ['2'],
        'out=%r' % (_notes(r),))
    r = conv('F', key='C')
    chk('坑① K:C 的 F -> 4', _notes(r) == ['4'], 'out=%r' % (_notes(r),))
    outs = {}
    for k in ('C', 'G', 'D', 'F'):
        body = {'C': 'C D E F G A B c', 'G': 'G A B c d e f g',
                'D': 'D E F G A B c d', 'F': 'F G A B c d e f'}[k]
        outs[k] = tuple(_deg_oct(t) for t in _notes(conv(body, key=k)))
    chk('坑① 大调 Do-based 不变性(4 个调同一段旋律 -> 同一音级+八度)',
        len(set(outs.values())) == 1, 'variants=%r' % (outs,))

    # ---- ② 休止 ----
    r = conv('C D z E | z4 | F2 z2 | G z z z |')
    chk('坑② 休止不丢(见 6 出 6)', r.n_rest_seen == 6 and r.n_rest_emitted == 6,
        '%d/%d' % (r.n_rest_seen, r.n_rest_emitted))
    chk('坑② 休止 token 数 = 6', sum(1 for t in r.tokens if '0' in t) == 6,
        'toks=%r' % (r.tokens,))

    # ---- ③ 小调 La-based ----
    am = conv('A B c d e f g a', key='Am')
    chk('③ K:Am 主音 -> ,6', _notes(am)[0] == ',6', 'out=%r' % (_notes(am),))
    chk('③ K:Am 自然小调音阶 = ,6 ,7 1 2 3 4 5 6',
        _notes(am) == [',6', ',7', '1', '2', '3', '4', '5', '6'], 'out=%r' % (_notes(am),))
    c_same = conv('A B c d e f g a', key='C')
    chk('③ 同一段 K:C 与 K:Am: 音级一一相同',
        [x[0] for x in map(_deg_oct, _notes(c_same))] == [x[0] for x in map(_deg_oct, _notes(am))],
        'C=%r Am=%r' % (_notes(c_same), _notes(am)))
    # ⚠ 作者口径①(八度归一)上线后, "小调版整体低一个八度"**只在归一之前**成立:
    #   归一按"记号最少"各自重新锚定, 会把 K:C 那版也挪到与小调一样的位置。这里关掉归一测该性质。
    OCTAVE_NORMALIZE = False
    c_raw = conv('A B c d e f g a', key='C')
    a_raw = conv('A B c d e f g a', key='Am')
    OCTAVE_NORMALIZE = True
    chk('③ 归一之前: 同一段 K:C 与小调版整体低一个八度(归一后这条被①覆盖)',
        all(_deg_oct(a)[1] == _deg_oct(c)[1] - 1
            for a, c in zip(_notes(a_raw), _notes(c_raw))),
        'C=%r Am=%r' % (_notes(c_raw), _notes(a_raw)))
    cmaj = conv('C D E F G A B c', key='C')
    chk('③ K:C 大调音阶 = 1 2 3 4 5 6 7 1\'',
        _notes(cmaj) == ['1', '2', '3', '4', '5', '6', '7', "1'"], 'out=%r' % (_notes(cmaj),))
    chk('③ 关系大小调对得上: Am[2:] == C大调[:6]',
        _notes(am)[2:] == _notes(cmaj)[:6],
        'Am=%r C=%r' % (_notes(am), _notes(cmaj)))
    for k, ref, body in (('Em', 'G', 'E F G A B c d e'), ('Dm', 'F', 'D E F G A B c d'),
                         ('Gm', 'Bb', 'G A B c d e f g'), ('Bm', 'D', 'B c d e f g a b')):
        rr = conv(body, key=k)
        chk('③ K:%s 自然小调音阶 -> ,6 ,7 1 2 3 4 5 6 (1=%s)' % (k, ref),
            _notes(rr) == [',6', ',7', '1', '2', '3', '4', '5', '6'] and rr.key_1 == ref,
            'out=%r 1=%s' % (_notes(rr), rr.key_1))

    # ---- ④ 反复展开(K:C 下 C D E F G A B = 1 2 3 4 5 6 7) ----
    CDEF, AB, EFGA = ['1', '2', '3', '4'], ['6', '7'], ['3', '4', '5', '6']
    ABCD = ['6', '7', '1', '2']

    def rep(body, key='C'):
        rr = conv(body, key=key)
        return _notes(rr), rr

    n, rr = rep('|:C D E F:|')
    chk('④ |:…:| 两遍', n == CDEF + CDEF, 'out=%r' % (n,))
    chk('④ 展开后没有反复记号残留', not any(t in rr.tokens for t in (':|', '|:')),
        'toks=%r' % (rr.tokens,))
    n, _ = rep('A B :| |:C D:|')
    chk('④ 无配对 |: 的 :| 回到段首 + 之后另起一段',
        n == AB + AB + ['1', '2'] + ['1', '2'], 'out=%r' % (n,))
    n, _ = rep('|:A B::C D:|')
    chk('④ :: = :| + |:', n == AB + AB + ['1', '2'] + ['1', '2'], 'out=%r' % (n,))
    n, _ = rep('|:G A[1 B c:|[2 d e|]')
    chk('④ [1/[2 房子(闭括号后接 [2)',
        n == ['5', '6', '7', "1'"] + ['5', '6', "2'", "3'"], 'out=%r' % (n,))
    n, _ = rep('G A|1 B c:|2 d e|')
    chk('④ 无方括号 |1/|2 房子', n == ['5', '6', '7', "1'"] + ['5', '6', "2'", "3'"],
        'out=%r' % (n,))
    n, _ = rep('A B C D :| E F G A :|')
    chk('④ 连续两个无配对 :| 各回各自段首(不指数膨胀)',
        n == ABCD + ABCD + EFGA + EFGA, 'out=%r' % (n,))
    # P:/Y: 段序
    y_part = ('X:1\nT:t\nY:%s\nM:4/4\nL:1/4\nK:C\n'
              'P:A\nA B C D:|\nP:B\nE F G A:|\n')
    ra = convert_tune(y_part % 'AB')
    chk('④ Y:AB + 每段 :| -> AABB', _notes(ra) == ABCD + ABCD + EFGA + EFGA,
        'out=%r' % (_notes(ra),))
    ra2 = convert_tune('X:1\nT:t\nY:AA\nM:4/4\nL:1/4\nK:C\nP:A\nA B C D:|\n')
    chk('④ Y:AA(单字母出现 2 次) -> 只播两遍, 不再叠加段内 :|',
        _notes(ra2) == ABCD + ABCD, 'out=%r' % (_notes(ra2),))
    flat = ('X:1\nT:t\nY:AABA\nM:4/4\nL:1/4\nK:C\n'
            'P:A\nA B C D|\nP:B\nE F G A||\n')
    ra3 = convert_tune(flat)
    chk('④ 平写正文 + Y:AABA -> 按 Y 逐段播',
        _notes(ra3) == ABCD + ABCD + EFGA + ABCD, 'out=%r' % (_notes(ra3),))

    # ---- ⑤ 源缺陷 ----
    two = ('X:1\nT:A\nK:C\nL:1/4\nC D E F|\nW:words\n%%endtext\nT:B\nK:G\nL:1/4\nG A B c|\n')
    ts = split_tunes(two)
    chk('⑤ X: 一块粘两首 -> 拆成 2 首', len(ts) == 2, 'n=%d' % len(ts))
    chk('⑤ 拆开后第二首用自己的调号 G', convert_tune(ts[1][1]).key_label == 'G',
        'key=%s' % convert_tune(ts[1][1]).key_label)
    ry = convert_tune('X:1\nT:t\nY:AB\nM:4/4\nL:1/4\nK:G\nP:A\nA B|\nP:B\nC D|\n')
    chk('⑤ 自定义头 Y: 不再当正文判错', ry.ok, 'errors=%r' % (ry.errors,))
    rl = conv('C T D H E L F')
    chk('⑤ ABC 1.6 单字符装饰 T/H/L 剥离且音高无损',
        _notes(rl) == CDEF and not rl.lossy, 'out=%r lossy=%r' % (_notes(rl), rl.lossy))
    rj = conv('C D !segno! E F !D.C.alfine! G')
    chk('⑤ 跳转记号 !segno!/!D.C.! 不按普通装饰放过(判音高不可用)',
        _notes(rj) == ['1', '2', '3', '4', '5'] and 'jump_mark' in rj.lossy,
        'out=%r lossy=%r' % (_notes(rj), rj.lossy))
    rc = convert_tune('X:1\nT:t\nY:(AB)2\nM:4/4\nL:1/4\nK:C\nP:A\nA B|\nP:B\nC D|\n')
    chk('⑤ 带括号/次数的段序(如 (AB)2) 不静默按字母播',
        'parts_order_complex' in rc.lossy, 'lossy=%r' % (rc.lossy,))
    chk('⑤ source 形状合规 + 含文件内序号(相邻序号不同 hash)',
        SRC_RE.match('abcgh-' + source_id('a/b.abc', 7)) is not None
        and source_id('a/b.abc', 7) != source_id('a/b.abc', 8), '')

    # ---- ⑥ 八度归一(作者 2026-10-05 口径①) ----
    hi = conv('c d e f g a b c')                    # K:C, 全是 C5 那一个八度: 记号 8
    chk('⑥ 偏高曲子: 归一后 `,`+`\'` 不增(8 -> 0, 平移 -1)',
        hi.oct_marks_after <= hi.oct_marks_before and hi.oct_shift == -1
        and hi.oct_marks_before == 8 and hi.oct_marks_after == 0,
        'shift=%+d %d -> %d toks=%r' % (hi.oct_shift, hi.oct_marks_before,
                                        hi.oct_marks_after, hi.tokens))
    lo = conv('C, D, E, F, G, A, B, C')             # 偏低: 7 个记号 -> 上移一格剩 1 个
    chk('⑥ 偏低曲子: 归一后记号不增(7 -> 1, 平移 +1)',
        lo.oct_marks_after <= lo.oct_marks_before and lo.oct_shift == 1
        and lo.oct_marks_after == 1,
        'shift=%+d %d -> %d toks=%r' % (lo.oct_shift, lo.oct_marks_before,
                                        lo.oct_marks_after, lo.tokens))
    tie = conv('G A B c d e')                       # 3 记号: +1 -> 9, -1 -> 3 -> 平手 -> 原样
    chk('⑥ 两个平移记号数平手 -> 保持原样(shift 0)',
        tie.oct_shift == 0 and tie.oct_marks_after == tie.oct_marks_before == 3,
        'shift=%+d %d -> %d toks=%r' % (tie.oct_shift, tie.oct_marks_before,
                                        tie.oct_marks_after, tie.tokens))
    mid = conv('C D E F G A B c')                   # 1 记号, 两个平移都更差 -> 原样
    chk('⑥ 两个平移都比原样差 -> 保持原样(shift 0)',
        mid.oct_shift == 0 and mid.oct_marks_before == 1,
        'shift=%+d %d -> %d' % (mid.oct_shift, mid.oct_marks_before, mid.oct_marks_after))
    OCTAVE_NORMALIZE = False
    raw_hi = conv('c d e f g a b c')
    OCTAVE_NORMALIZE = True
    same = [f for t in raw_hi.tokens for f in token_figures(t)]
    sh = [f for t in hi.tokens for f in token_figures(t)]
    chk('⑥ 归一只是整体挪八度: 音级序列与源一致、每个音正好平移 shift 个八度',
        len(same) == len(sh)
        and all(a[2] == b[2] and fig_oct(a[0]) + hi.oct_shift == fig_oct(b[0])
                for a, b in zip(same, sh)),
        'raw=%r sh=%r' % (raw_hi.tokens, hi.tokens))
    chk('⑥ 归一后所有音都在 jianpu-ly 认的 ±3 个记号内',
        all(abs(fig_oct(f[0])) <= MAX_OCT for t in hi.tokens + lo.tokens
            for f in token_figures(t)), '')

    # ---- ⑦ 和弦(作者 2026-10-05 口径②) ----
    rce = conv('[CEG]')                             # K:C L:1/4
    chk('⑦ [CEG] -> 一个和弦 token `135`(不摊平成三个 token)',
        rce.tokens == ['135'] and rce.n_chord == 1 and rce.n_chord_notes == 3
        and not rce.lossy,
        'toks=%r lossy=%r' % (rce.tokens, rce.lossy))
    mk_src = 'X:1\nT:t\nM:6/8\nL:1/8\nK:D\n[a2A2]a gfe|\n'
    OCTAVE_NORMALIZE = False
    mk_raw = convert_tune(mk_src)
    OCTAVE_NORMALIZE = True
    mk = convert_tune(mk_src)
    chk('⑦ [a2A2](K:D, L:1/8; 关掉归一) -> `\'55 q5\' q4\' q3\' q2\' |`(和弦没被摊平也没丢音)',
        mk_raw.tokens == ["'55", "q5'", "q4'", "q3'", "q2'", '|'] and not mk_raw.lossy
        and mk_raw.n_pitch_raw == 6 and mk_raw.n_chord == 1 and mk_raw.n_chord_notes == 2,
        'toks=%r lossy=%r' % (mk_raw.tokens, mk_raw.lossy))
    chk('⑦ 归一开着时和弦跟着整体平移(音集一个不丢, 平移 %+d)' % mk.oct_shift,
        mk.oct_shift == -1
        and sorted((int(f[2]), fig_oct(f[0]) + mk.oct_shift)
                   for t in mk_raw.tokens for f in token_figures(t))
        == sorted((int(f[2]), fig_oct(f[0]))
                  for t in mk.tokens for f in token_figures(t)),
        'raw=%r norm=%r' % (mk_raw.tokens, mk.tokens))
    oc = conv("[C,E'G]")
    chk('⑦ 带八度的和弦: 记号写在各自音级前 -> `,1\'35`',
        oc.tokens == [",1'35"], 'toks=%r' % (oc.tokens,))
    ml = conv('[C2E4] F')
    chk('⑦ 各音时值不齐的和弦: 仍不丢音, 只记 dur_lossy 的 chord_mixed_len',
        ml.n_chord == 1 and ml.n_chord_notes == 2 and ml.pitch_safe
        and 'chord_mixed_len' in ml.dur_lossy and 'chord_mixed_len' not in ml.lossy,
        'lossy=%r dur_lossy=%r toks=%r' % (ml.lossy, ml.dur_lossy, ml.tokens))
    chk('⑦ 和弦音数进"零丢失"自检(源 %d 音 -> token 里 %d 音)'
        % (mk.n_pitch_raw, sum(token_note_count(t) for t in mk.tokens)),
        sum(token_note_count(t) for t in mk.tokens) == mk.n_pitch_raw == mk.n_pitch, '')
    try:
        _jp = _load_jptok()
    except Exception as e:                                  # noqa: BLE001
        _jp = None
        chk('⑦ jptok 白名单对照(拿不到 jptok: %s)' % e, False, '')
    if _jp is not None:
        # 拆回"每个发声的音一个 token"后, 交给 jianpu-db 自己的唯一实现解析:
        flat = []
        for t in oc.tokens:
            for marks, acc, dig in token_figures(t):
                flat.append(marks + acc + dig)
        got = [_jp.parse_token(x) for x in flat]
        chk('⑦ 和弦里每个音都能被 jptok 按单音读对(,1 / \'3 / 5)',
            got == [(1, 0, 1), (3, 0, -1), (5, 0, 0)], 'flat=%r got=%r' % (flat, got))
        chk('⑦ 下游缺口已闭: jptok 的 parse_token 认和弦 token 且 seq 不丢音('
            '实测 parse_token(\'135\')=%r, seq(\'1 64 2\')=%r)'
            % (_jp.parse_token('135'), _jp.seq('1 64 2')),
            _jp.parse_token('135') == [(1, 0, 0), (3, 0, 0), (5, 0, 0)]
            and len(_jp.seq('1 64 2')) == 4, '')

    # ---- ⑧ 两个新修的解析拦路(作者 2026-10-05 口径) ----
    rc1 = convert_tune('X:1\nT:t % 标题注释\nM:4/4\nL:1/4\nK:C\nC D E F |% 行尾注释\nG A B c %^_x\n')
    chk('⑧ 行内 `%` 注释(含 `T:` 行尾与谱面行尾)不再判错, 注释文字不进正文',
        rc1.ok and _notes(rc1) == ['1', '2', '3', '4', '5', '6', '7', "1'"]
        and rc1.title == 't',
        'ok=%s title=%r errors=%r out=%r' % (rc1.ok, rc1.title, rc1.errors, _notes(rc1)))
    chk('⑧ 引号内的 `%` 不当注释(不被腰斩)',
        _notes(convert_tune('X:1\nT:t\nM:4/4\nL:1/4\nK:C\n"50% off"C D\n')) == ['1', '2'], '')
    rc2 = convert_tune('X:1\nT:t\nI:linebreak $\nM:6/8\nL:1/8\nK:G\nG2 B d2 e |$ d2 B A2 G |$ G3 z2 G |\n')
    chk('⑧ `I:linebreak $` 的 `$` 当换行(不再报未识别字符), 音数正确',
        rc2.ok and rc2.n_pitch_raw == 10 and rc2.n_rest_seen == 1
        and _notes(rc2)[:6] == ['1', 'q3', '5', 'q6', '5', 'q3'],
        'ok=%s errors=%r out=%r' % (rc2.ok, rc2.errors, _notes(rc2)))
    rc3 = convert_tune('X:1\nT:t\nM:4/4\nL:1/4\nK:C\nC D $ E F\n')
    chk('⑧ 未声明时 `$` 也当换行(`$` 在 ABC 正文里没有别的含义)',
        rc3.ok and _notes(rc3) == ['1', '2', '3', '4'], 'errors=%r' % (rc3.errors,))
    chk('⑧ `%%endtext` 指令行不被行内注释规则吃掉(拆曲仍靠它)',
        len(split_tunes('X:1\nT:A\nK:C\nL:1/4\nC D|\nW:words\n%%endtext\nT:B\nK:G\nL:1/4\nG A|\n')) == 2, '')

    # ---- ⑨ 与平台唯一实现对齐(jptok 白名单 + jianpu-db/score.py 真解析) ----
    # 为什么非加不可: 本器 2026-10-06 移进仓库、口径搬进 `convert_common`, 最容易的坏法就是
    # "自己算得挺对, 但平台认不出这些 token"。所以: ① 每个 token 过 jptok 白名单;
    # ② 把整份语料文本交给 `jianpu-db/score.py` 走一遍 read->write_buf->expand->to_record
    #    (只在临时目录里落中间文件, **不碰仓库**), 断言读回来的正文与写出去的逐 token 相同。
    sid = make_source('abcgh', 'x/y.abc', 1)
    sample = convert_tune('X:1\nT:t\nM:6/8\nL:1/8\nK:Am\nA B c d [e2g2] z2 e | A, B, c d ^g a |\n')
    txt = corpus_text(sample, 'selftest.txt', '', sid)
    problems = cc.score_check(txt, sample.tokens, tag='abc_selftest')
    chk('⑨ 每个 token 过 jptok 白名单, 且 jianpu-db/score.py 能原样解析回来',
        not problems, '; '.join(problems))
    chk('⑨ 语料头部: status=converted / transcriber=abc2jianpu / source 形状合规',
        'status=converted\n' in txt and 'transcriber=abc2jianpu\n' in txt
        and SRC_RE.match(sid) is not None, 'source=%r' % sid)
    chk('⑨ 八度归一与和弦记账进了头部注释(平移 %+d, 和弦 %d 个)'
        % (sample.oct_shift, sample.n_chord),
        ('%%八度归一=%+d' % sample.oct_shift) in txt
        and ('和弦 %d 个' % sample.n_chord) in txt, '')

    if verbose:
        npass = 0
        for name, ok, detail in cases:
            print('%s  %s%s' % ('PASS' if ok else 'FAIL', name,
                                '' if ok else '  <- ' + detail))
            npass += 1 if ok else 0
        print('-- 自检 %d/%d 通过 --' % (npass, len(cases)))
    return all(c[1] for c in cases), cases


# --------------------------------------------------------------------------
# 真素材回归: 492 首已入库 ABC 产物(逐 token + 逐字节)
# --------------------------------------------------------------------------
def _body_tokens_of(text):
    """语料文本 -> 正文 token 列表(`%--` 之后, 去掉拍号行/`subtitle=`/`%` 注释/`%END`)。"""
    out, inbody = [], False
    for line in text.splitlines():
        s = line.strip()
        if not inbody:
            if s.replace(' ', '').startswith('%--'):
                inbody = True
            continue
        if s.startswith('%') or not s or re.match(r'^\d+\s*/\s*\d+$', s) \
                or s.startswith('subtitle='):
            continue
        out.extend(s.split())
    return out


def _canon_lines(text):
    """去掉平台在入库后加/搬的那些行: `%` 注释(会被 write_buf 搬到头部)与 `link=`。

    -> 排序后的列表(顺序不计: `write_buf()` 会按 `others` 的键序重排 `alias=` 这类字段)。
    另外把 `alias=` 各项的首尾空格抹掉: 平台的 `write_buf()` 是"读回来 -> 用 `,` 重新拼",
    重新拼接时每项会被 strip(实测 2 首因此与转换器输出差一个空格, 是平台侧行为)。
    """
    out = []
    for l in text.splitlines():
        if l.startswith('%') or l.startswith('link='):
            continue
        if l.startswith('alias='):
            l = 'alias=' + ','.join(x.strip() for x in l[len('alias='):].split(','))
        out.append(l)
    return sorted(out)


def do_regress_cc0(manifest, samples_dir, scores_dir, limit=None, verbose=True,
                   account=None):
    """已入库的 492 首: 拿**原始 ABC 文件**按入库时那套参数重跑, 与库里现存文件对拍。

    为什么这是"移进仓库没弄坏"的硬证据: 这批 492 首(`status=converted`)是转换器进仓库**之前**
    产出的; 现在把同一批原始 ABC 重跑一遍:
      * **逐 token 一致** -> 搬运 + 抽公共模块没有改动任何一条口径;
      * **去掉平台后处理后的逐字节一致** -> 连头部字段、注释文字、正文折行都没动。
    对拍时照抄 `_cc0_ingest.py` 的调用口径(`page_url` 用清单里的原始文件直链、`alias` 来自清单、
    源里没写 `M:` 时记一句并用默认 4/4), 于是剩下的差异只可能来自**入库之后的平台动作**:
      ① `jianpu-db/score.py` 的 `write_buf()` 把 `%` 注释从字段之后搬到字段之前(每次解析都做);
      ② 入库之后补的 `link=<原始文件直链>` 一行(转换器输出里没有它)。
    -> 四个数一起看: `same_tokens` / `same_canon`(忽略上面两件事) / `same_comments`(注释集合相同,
       顺序不计) / `same_bytes`(生字节, 预期 0)。

    还能再强一层: 如果手上有那次转换的**账号 JSON**(`_abc_fix_account.py` 的产物, 它把每个候选的
    token 原样存了下来 —— 那是**搬运之前**那版实现的输出), 传 `--account` 就能拿它做第二份独立
    素材回归: 覆盖面比 492 更宽(CC0 那批是 511 首), 而且比的是**裸 token**(没经过平台 write_buf)。
    """
    import csv
    rows = list(csv.DictReader(open(manifest, encoding='utf-8'), delimiter='\t'))
    if limit:
        rows = rows[:limit]
    n = same_tokens = same_canon = same_comments = same_bytes = missing = 0
    acc_same = acc_n = 0
    acc_bad = []
    detail = []
    if account:
        acc = json.load(open(account, encoding='utf-8'))
        want_acc = {(c['file'], int(c['idx'])): c for c in acc.get('candidates', [])}
        by_file = {}
        for (fn, idx) in want_acc:
            by_file.setdefault(fn, []).append(idx)
        for fn, idxs in sorted(by_file.items()):
            path = os.path.join(samples_dir, fn)
            if not os.path.isfile(path):
                continue
            with open(path, encoding='utf-8', errors='replace') as f:
                tunes = split_tunes(f.read())
            for idx in sorted(idxs):
                c = want_acc[(fn, idx)]
                if 'tokens' not in c or idx > len(tunes):
                    continue
                res = convert_tune(tunes[idx - 1][1], fn)
                acc_n += 1
                if list(res.tokens) == list(c['tokens']):
                    acc_same += 1
                elif len(acc_bad) < 6:
                    a, b = list(c['tokens']), list(res.tokens)
                    i = next((k for k in range(min(len(a), len(b))) if a[k] != b[k]),
                             min(len(a), len(b)))
                    acc_bad.append((fn, idx, a[i:i + 2], b[i:i + 2], len(a), len(b)))
    for row in rows:
        fn = row['file']
        abc_path = os.path.join(samples_dir, row['abc_file'])
        db_path = os.path.join(scores_dir, fn)
        if not os.path.isfile(db_path):
            missing += 1
            detail.append((fn, '库里没有这份文件: %s' % db_path))
            continue
        idx = int(row['idx'])
        with open(abc_path, encoding='utf-8', errors='replace') as f:
            tunes = split_tunes(f.read())
        if idx > len(tunes):
            detail.append((fn, '原始文件里只有 %d 首, 清单要第 %d 首' % (len(tunes), idx)))
            continue
        res = convert_tune(tunes[idx - 1][1], row['abc_file'])
        sid = make_source(row['source'].split('-')[0], repo_path_of(row['url']), idx)
        alias = [a for a in (row.get('alias') or '').split(',') if a] or None
        # 与 _cc0_ingest.py 同参数: page_url 用清单 URL、alias 照抄、缺 M: 时记账 + 默认 4/4
        text = corpus_text(res, fn, '', sid, status='converted', page_url=row['url'],
                           transcriber='abc2jianpu', alias=alias,
                           meter_note='' if res.meter else '源里没写 M: -> 按 ABC 标准默认 4/4 写出',
                           default_meter='4/4')
        db_text = open(db_path, encoding='utf-8').read()
        n += 1
        got = list(res.tokens)
        want = _body_tokens_of(db_text)
        if want == got:
            same_tokens += 1
        elif len(detail) < 12:
            i = next((k for k in range(min(len(want), len(got))) if want[k] != got[k]),
                     min(len(want), len(got)))
            detail.append((fn, 'token 不一致 @%d: 库里 %r / 重跑 %r (共 %d/%d)'
                           % (i + 1, want[i:i + 2], got[i:i + 2], len(want), len(got))))
        if _canon_lines(db_text) == _canon_lines(text):
            same_canon += 1
        elif len(detail) < 12:
            a, b = _canon_lines(db_text), _canon_lines(text)
            only_a = [x for x in a if x not in b][:2]
            only_b = [x for x in b if x not in a][:2]
            detail.append((fn, '去掉注释/link= 后仍不一致: 库里多 %r / 重跑多 %r'
                           % (only_a, only_b)))
        if sorted(l for l in db_text.splitlines() if l.startswith('%')) == \
                sorted(l for l in text.splitlines() if l.startswith('%')):
            same_comments += 1
        if db_text == text:
            same_bytes += 1
    if verbose:
        print('== 真素材回归: 已入库 ABC 产物 + (可选)账号 JSON 里的旧 token ==')
        print('清单 %d 行 / 比对 %d 首(库里缺 %d)' % (len(rows), n, missing))
        print('逐 token 一致: %d/%d' % (same_tokens, n))
        print('字段+正文逐字节一致(顺序不计, 已忽略平台搬走的 `%%` 注释与 `link=`): %d/%d'
              % (same_canon, n))
        print('注释集合一致(顺序不计): %d/%d' % (same_comments, n))
        print('生字节一致(含 write_buf 的字段/注释重排, 预期 0): %d/%d' % (same_bytes, n))
        if account:
            print('账号 JSON 里搬运前那版算出的 token 逐 token 一致: %d/%d' % (acc_same, acc_n))
            for fn, idx, a, b, la, lb in acc_bad:
                print('  !! %s#%d: 旧 %r / 新 %r (共 %d/%d)' % (fn, idx, a, b, la, lb))
        for fn, why in detail:
            print('  !! %s: %s' % (fn, why))
    return {'rows': len(rows), 'compared': n, 'missing': missing,
            'same_tokens': same_tokens, 'same_canon': same_canon,
            'same_comments': same_comments, 'same_bytes': same_bytes,
            'account_tokens_same': acc_same, 'account_tokens_total': acc_n,
            'detail': detail}


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------
def do_extract(manifest, outdir, per_file, only_clean):
    """manifest: 每行 `本地 abc 路径<TAB>出处 URL[<TAB>站点token]`。每个文件等距抽 per_file 首。"""
    os.makedirs(outdir, exist_ok=True)
    rows = []
    nn = 0
    for line in open(manifest, encoding='utf-8'):
        line = line.rstrip('\n')
        if not line.strip() or line.startswith('#'):
            continue
        parts = line.split('\t')
        path, url = parts[0], (parts[1] if len(parts) > 1 else '')
        with open(path, encoding='utf-8', errors='replace') as f:
            text = f.read()
        tunes = split_tunes(text)
        n = len(tunes)
        idxs = equi_indices(n, per_file)
        base = os.path.basename(path)
        for k, i in enumerate(idxs):
            x, chunk = tunes[i]
            res = convert_tune(chunk, base)
            if only_clean and not res.clean:
                continue
            nn += 1
            tag = '%02d' % nn
            fn = '%s_%s_%s.abc' % (tag, slugify(res.title or ('x' + x), 30), slugify(x, 6))
            with open(os.path.join(outdir, fn), 'w', encoding='utf-8', newline='\n') as f:
                f.write(chunk if chunk.endswith('\n') else chunk + '\n')
            rows.append((tag, fn, base, url, x, res.title, res.key_label,
                         res.key_sig_text, res.meter, res.default_len,
                         res.n_pitch, res.n_rest_seen, str(res.clean), str(res.ok)))
    with open(os.path.join(outdir, 'provenance.tsv'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('idx\tfile\tsource_file\torigin_url\tX\ttitle\tkey_1=\tkey_signature\tmeter\tL\t'
                'n_pitch\tn_rest\tin_subset\tparsed\n')
        for r in rows:
            f.write('\t'.join(str(c) for c in r) + '\n')
    print('wrote %d tunes to %s' % (len(rows), outdir))
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description='ABC -> 简谱数字串转换器(入库形态探针)')
    ap.add_argument('abcfile', nargs='*')
    ap.add_argument('--tune', type=int, default=None, help='选第 N 首(1 起)')
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--all', action='store_true', help='整文件所有曲目')
    ap.add_argument('--scan', action='store_true', help='所有文件所有曲目 -> JSON 数组')
    ap.add_argument('--with-score', action='store_true', help='--scan 时一并给数字串')
    ap.add_argument('--link', default='')
    ap.add_argument('--source', default='')
    ap.add_argument('--corpus', action='store_true', help='输出语料形态文本而不是裸数字串')
    ap.add_argument('--list', action='store_true', help='只列曲目')
    ap.add_argument('--extract', metavar='MANIFEST', help='按清单抽取样张到 --outdir')
    ap.add_argument('--run', metavar='MANIFEST', help='批量跑: 转 -> 展开 -> 写语料形态 + 报告')
    ap.add_argument('--outdir', default=None)
    ap.add_argument('--per-file', type=int, default=5)
    ap.add_argument('--limit', type=int, default=None)
    ap.add_argument('--only-clean', action='store_true', help='抽取时只保留落在最小子集内的')
    ap.add_argument('--selfcheck', '--selftest', dest='selfcheck', action='store_true')
    ap.add_argument('--regress-cc0', metavar='MANIFEST',
                    help='真素材回归: 按清单重跑已入库那批 ABC, 与 jianpu-db/scores 现存文件对拍')
    ap.add_argument('--samples-dir', default=None, help='--regress-cc0 用的原始 .abc 目录')
    ap.add_argument('--account', default=None,
                    help='--regress-cc0 可加: 那次转换的账号 JSON(里面存着搬运前那版算的 token)')
    ap.add_argument('--scores-dir', default=None,
                    help='--regress-cc0 比的语料目录(默认 $JIANPU_DB/scores 或 ../jianpu-db/scores)')
    a = ap.parse_args(argv)

    if a.selfcheck:
        ok, _ = run_selfcheck()
        return 0 if ok else 1

    if a.regress_cc0:
        sd = a.scores_dir or os.path.join(cc.DB_DIR, 'scores')
        r = do_regress_cc0(a.regress_cc0, a.samples_dir or '.', sd, a.limit, account=a.account)
        if a.json:
            print(json.dumps(r, ensure_ascii=False, indent=2))
        ok = (r['compared'] and r['same_tokens'] == r['compared']
              and r['same_canon'] == r['compared']
              and (not a.account or r['account_tokens_total'] == 0
                   or r['account_tokens_same'] == r['account_tokens_total']))
        return 0 if ok else 1

    if a.run:
        if not a.outdir:
            ap.error('--run 需要 --outdir')
        do_run(a.run, a.outdir, a.per_file, a.limit)
        return 0

    if a.extract:
        if not a.outdir:
            ap.error('--extract 需要 --outdir')
        return do_extract(a.extract, a.outdir, a.per_file, a.only_clean)

    if not a.abcfile:
        ap.print_help()
        return 2

    if a.scan:
        out = []
        for fn in a.abcfile:
            with open(fn, encoding='utf-8', errors='replace') as f:
                text = f.read()
            for i, (x, t) in enumerate(split_tunes(text), 1):
                res = convert_tune(t, os.path.basename(fn))
                d = res.to_dict(os.path.basename(fn))
                d['x'] = x
                d['idx_in_file'] = i
                if not a.with_score:
                    d.pop('score', None)
                out.append(d)
        print(json.dumps(out, ensure_ascii=False))
        return 0

    fn = a.abcfile[0]
    with open(fn, 'r', encoding='utf-8', errors='replace') as f:
        text = f.read()
    tunes = split_tunes(text)
    if a.list:
        for i, (x, t) in enumerate(tunes, 1):
            hd, _ = split_head_body(t)
            tt = ''
            for k, v in hd:
                if k == 'T' and not tt:
                    tt = v
            print('%3d  X:%-8s %s' % (i, x, tt))
        return 0
    picked = tunes if a.all else [tunes[(a.tune or 1) - 1]]

    outs = []
    for x, t in picked:
        res = convert_tune(t, os.path.basename(fn))
        d = res.to_dict(os.path.basename(fn))
        d['x'] = x
        outs.append((res, d, x))
    if a.json:
        print(json.dumps([d for _, d, _ in outs], ensure_ascii=False, indent=2))
        return 0
    for res, d, x in outs:
        if a.corpus:
            print(corpus_text(res, os.path.basename(fn), a.link,
                              a.source or 'abcgh-probe', status='converted',
                              page_url=res.page_url), end='')
        else:
            print('X:%s  %s' % (x, res.title))
            print('  原调=%s  1=%s (La-based=%s)  调号 %s  拍号 %s  L:%s'
                  % (res.key_label, res.key_1, res.la_based, res.key_sig_text,
                     res.meter or '?', res.default_len or '?'))
            print('  ok=%s 子集内=%s pitch_safe=%s  音数 %d -> %d  休止 %d/%d  时值近似=%d  展开=%d'
                  % (res.ok, res.clean, res.pitch_safe, res.n_pitch_raw, res.n_pitch,
                     res.n_rest_emitted, res.n_rest_seen, res.dur_approx,
                     res.repeats_expanded))
            if res.errors:
                print('  错误: ' + '; '.join(res.errors))
            if res.unsupported:
                print('  子集外: ' + '; '.join('%s×%d' % (k, len(v))
                                              for k, v in res.unsupported.items()))
            print('  ' + ' '.join(res.tokens))
    return 0


if __name__ == '__main__':
    sys.exit(main())

