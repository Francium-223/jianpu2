# -*- coding: utf-8 -*-
"""MIDI / ABC -> 简谱转换的**公共口径**(全项目唯一一份, 不许在转换器里各写一份)。

为什么必须唯一(本项目的血教训): token 白名单曾在 score.py / show_hit.py / 前端 search.js
里各写一份, 结果"升降号"这一处口径三份各不相同 —— 实测全库带 `#` 的音在 data.jsonl 里
**被整段丢掉**(18 首)。调号/小调/八度归一/和弦写法同理: `abc_to_jianpu.py` 与
`midi_to_jianpu.py` 一旦各留一份, 两种输入转换出来的简谱迟早不是同一种谱。

分工(实测后定的边界):
  * 本文件 = "记谱无关"的那一半 —— 调号与音级映射、时值切分、token 拼写、八度归一、
    和弦 token、source 命名、语料头部/正文排版、jptok/score.py 校验;
  * 各自转换器 = "记谱相关"的那一半 —— 把 ABC / MIDI 的语法读成"音高 + 时值"事件流。

口径(作者 2026-10-04 / 2026-10-05 定的, 实测数字见 `jianpu2/docs/CONVERTERS.md`)
================================================================================
① `status=converted` = 由 **ABC 等记谱格式机械转换**而来(已在发布白名单:
   `jianpu-db/parse_scores.py` 的 `OK_STATUS`、`jianpu-db/tools/check_data_sane.py`、
   `jianpu2/tools/check_corpus_invariants.py`、`jianpu2/tools/melody_search.py` 四处)。
   MIDI 转换属于同一类, **继续用 `converted`**, 不新造状态。
② 小调 **La-based**: 主音记 `,6`(与 `jianpu-db/README.md`"小调一级记作 `,6`;
   大调一级记作 `1`"一致); 大调 Do-based(主音 `1`)。
   实现: `1=` 取**同调号的关系大调主音**, 且比小调主音高一个小三度(落在主音上方最近的
   那个位置) —— 自然小调音阶于是写成 `,6 ,7 1 2 3 4 5 6`。
③ **八度归一**: 整首升/降 12 半音这两个方案里, 取 `,` + `'` 总数最少的那种;
   平手或两个方案都更差 -> 保持原样。实测: 只整体平移, 音级序列一个都不动。
④ **和弦按和弦 token 输出**: 多个音连写成一个 token, 八度/变音写在**各自音级左边**
   (`d,4,,b5,,3,,1` 这种写法, 抄自语料里 261611 个和弦 token 与 jianpu-ly 的
   `chordNotes_markup()`); 不摊平成序列、也不丢音。
⑤ `source` = `<站点token>-<id>`, 必须过 `^[a-z0-9]+-[0-9a-z_]+$`;
   id = `sha1(仓库路径 + '#' + 文件内序号)[:12]`(**必须含序号**, 否则一块里粘的第二首会撞车)。
⑥ 正文里**没有反复记号**(一律展开); 休止 `0`、念白 `x` 不得静默丢。

用法
----
    py -3.13 convert_common.py --selfcheck        # 只验公共口径本身
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)                      # jianpu2/
JTOK_DIR = os.path.join(REPO, 'skills', 'jianpu-melody-lookup')
# jianpu-db 与本仓库平级(与 check_tools.sh 的 `DB0="${JIANPU_DB:-$(cd .. && pwd)/jianpu-db}"` 同一约定)
DB_DIR = os.environ.get('JIANPU_DB') or os.path.join(os.path.dirname(REPO), 'jianpu-db')


# ==========================================================================
# 一、音名 / 调号
# ==========================================================================
LETTER_IDX = {'C': 0, 'D': 1, 'E': 2, 'F': 3, 'G': 4, 'A': 5, 'B': 6}
NATURAL_PC = [0, 2, 4, 5, 7, 9, 11]
SHARP_ORDER = [3, 0, 4, 1, 5, 2, 6]     # F C G D A E B
FLAT_ORDER = [6, 2, 5, 1, 4, 0, 3]      # B E A D G C F
MAJOR_BASE = {0: 0, 1: 2, 2: 4, 3: -1, 4: 1, 5: 3, 6: 5}

# ABC 的"中音区"锚点: 大写无记号 = MIDI 八度 4(C4 = 60)。
# 实测依据: jianpu-ly/abc2midi 通用约定, 大写 C = 中央 C = 60; 本文件只拿它把
# "ABC 相对八度"与"MIDI 绝对八度"对到同一根轴上, 绝对值取多少不影响简谱输出。
ABC_OCT_BASE = 4

# mode -> (该调式主音往下数几个音名字母到关系大调主音, 往下几个半音)
MODE_STEPS = {
    'major': (0, 0), 'maj': (0, 0), 'ion': (0, 0), 'ionian': (0, 0), '': (0, 0),
    'dorian': (1, 2), 'dor': (1, 2),
    'phrygian': (2, 4), 'phry': (2, 4),
    'lydian': (3, 5), 'lyd': (3, 5),
    'mixolydian': (4, 7), 'mix': (4, 7),
    'minor': (5, 9), 'min': (5, 9), 'aeolian': (5, 9), 'aeo': (5, 9), 'm': (5, 9),
    'locrian': (6, 11), 'loc': (6, 11),
}
# 大三度在上方 -> Do-based(主音 `1`); 小三度在上方 -> La-based(主音 `,6`, 参考关系大调)
MINOR_MODES = {'minor', 'min', 'aeolian', 'aeo', 'm', 'dorian', 'dor',
               'phrygian', 'phry', 'locrian', 'loc'}

FIELD_RE = re.compile(r'^([A-Za-z]):(.*)$')


class ConvertError(Exception):
    """转换期可预期的输入错误(不是 bug)。"""


def key_sig_from_fifths(n):
    """五度圈数 -> 7 个音名字母上的变音(-1/0/+1)。"""
    sig = [0] * 7
    if n > 0:
        for L in SHARP_ORDER[:n]:
            sig[L] = 1
    elif n < 0:
        for L in FLAT_ORDER[:-n]:
            sig[L] = -1
    return sig


# 大调主音音级(半音) -> 五度圈数(取变音记号最少的拼写)。实测语料 160 首写了 `1=` 的谱里
# 同时有降号拼写(`1=bB`/`1=bD`/`1=bG`)与升号拼写; 平手(只有 F#/Gb 这一对, 6 升 vs 6 降)时
# 取**降号**拼写, 理由是语料实测出现过 `1=Gb` 而没出现过 `1=#F`(样本小, 只作平手定序用)。
_MAJOR_FIFTHS = {}
for _n in range(-7, 8):
    _pc = (_n * 7) % 12
    _MAJOR_FIFTHS.setdefault(_pc, []).append(_n)
for _pc, _lst in _MAJOR_FIFTHS.items():
    _lst.sort(key=lambda n: (abs(n), 0 if n < 0 else 1))


def major_fifths(pc):
    """大调主音音级 -> 五度圈数(变音最少; 平手取降号)。"""
    return _MAJOR_FIFTHS[pc % 12][0]


def fifths_label(n):
    """五度圈数 -> 关系大调主音的音名拼写(如 -5 -> 'Db', 6 -> '#F')。

    实现: 先找音级(半音)对得上的字母(本位音); 对不上时**按五度圈方向**决定升还是降
    —— 升号调(n>=0)把 pc 下方那个字母升上去, 降号调(n<0)把 pc 上方那个字母降下来。
    ⚠ 不能只按"差 1 就记升、差 11 就记降": 那样 `-5` 会被写成 `C#`(而它应是 `Db`)。
    """
    pc = (n * 7) % 12
    for li in range(7):
        if NATURAL_PC[li] == pc:
            return 'CDEFGAB'[li]
    if n >= 0:
        for li in range(7):
            if (NATURAL_PC[li] + 1) % 12 == pc:
                return 'CDEFGAB'[li] + '#'
    else:
        for li in range(7):
            if (NATURAL_PC[li] - 1) % 12 == pc:
                return 'CDEFGAB'[li] + 'b'
    raise ConvertError('五度圈 %d 拼不出来' % n)


class Key(object):
    """一个调号 + 首调参考音(`1=` 落在哪个音名的哪个八度)。

    `ref_oct` 是**绝对** MIDI 八度(C4 -> 4), 由 `ABC_OCT_BASE + ref_reg` 得到, 于是
    ABC 的"相对八度"与 MIDI 的"绝对八度"走同一个 `degree_of_abs()`。
    """

    def __init__(self, li, acc, mode, sig, nsig, ref_letter, ref_acc, ref_reg, la_based=False):
        self.li = li
        self.acc = acc
        self.mode = mode
        self.sig = sig
        self.nsig = nsig
        self.ref_letter = ref_letter
        self.ref_acc = ref_acc
        self.ref_reg = ref_reg
        self.ref_oct = ABC_OCT_BASE + ref_reg
        self.la_based = la_based

    @property
    def label(self):
        """原调名, 如 `Gm` / `D`。"""
        return key_label(self.li, self.acc, self.mode)

    @property
    def ref_label(self):
        """`1=` 的值, 如 `Bb`。"""
        return key_label(self.ref_letter, self.ref_acc, 'major')

    @property
    def sig_text(self):
        return key_sig_text(self.sig)

    @property
    def ref_midi(self):
        """`1=` 参考音的绝对音高(MIDI 号)。C4 -> 12*(4+1)+0 = 60。"""
        return 12 * (self.ref_oct + 1) + NATURAL_PC[self.ref_letter] + self.ref_acc

    def __repr__(self):
        return '<Key %s 1=%s La-based=%s>' % (self.label, self.ref_label, self.la_based)


def parse_key(raw: str) -> Key:
    """`K:` 头(ABC 语法) -> Key。"""
    s = (raw or '').strip()
    s = s.split('%')[0].strip()
    m = re.match(r"^([A-Ga-g])([#b]?)\s*([A-Za-z]*)", s)
    if not m:
        raise ConvertError('K: 无法解析: %r' % raw)
    letter = m.group(1).upper()
    acc = 1 if m.group(2) == '#' else (-1 if m.group(2) == 'b' else 0)
    mode_word = (m.group(3) or '').lower()
    if mode_word not in MODE_STEPS:
        raise ConvertError('K: 未知调式 %r (来自 %r)' % (mode_word, raw))
    li = LETTER_IDX[letter]
    steps, semis = MODE_STEPS[mode_word]
    maj_letter = (li - steps) % 7
    tonic_pc = (NATURAL_PC[li] + acc) % 12
    maj_pc = (tonic_pc - semis) % 12
    nat = NATURAL_PC[maj_letter]
    d = (maj_pc - nat) % 12
    if d == 0:
        maj_acc = 0
    elif d == 1:
        maj_acc = 1
    elif d == 11:
        maj_acc = -1
    else:
        raise ConvertError('K: 关系大调变音算不出来 (%r)' % raw)
    n = MAJOR_BASE[maj_letter] + 7 * maj_acc
    sig = key_sig_from_fifths(n)
    mode = mode_word or 'major'
    if mode in MINOR_MODES:
        # La-based: `1=` = 关系大调主音, 且记在主音**上方最近的**那个位置
        #   k = (7-steps)%7 = 主音往上数几个音名字母到关系大调主音
        #   -> 自然小调主音落成 `,6`(Am/Em/Dm/Gm/Bm 实测一致), 大调族仍 Do-based。
        k = (7 - steps) % 7
        step = li + k
        return Key(li, acc, mode, sig, n, step % 7, maj_acc, step // 7, la_based=True)
    return Key(li, acc, mode, sig, n, li, acc, 0)


def key_from_tonic_midi(tonic_midi, minor):
    """绝对主音音高(MIDI 号) + 是否小调 -> Key。

    MIDI 没有音名拼写, 所以拼写规则必须写死并说明依据:
      * 调号取"变音记号最少"的那种拼写(平手取降号), 与 `major_fifths()` 同一份表;
      * **小调 La-based 的参考音 = 主音上方小三度**(= 同调号的关系大调主音),
        于是自然小调音阶写成 `,6 ,7 1 2 3 4 5 6` —— 与 ABC 侧的 `parse_key('Am')` 逐项一致
        (实测: 两者对同一段 A B c d e f g a 给出的 token 完全相同, 见 --selfcheck)。
    """
    rel = int(tonic_midi) + (3 if minor else 0)
    pc = rel % 12
    n = major_fifths(pc)
    label = fifths_label(n)
    ref_letter = LETTER_IDX[label[0]]
    ref_acc = 1 if label.endswith('#') else (-1 if label.endswith('b') else 0)
    ref_oct = (rel - NATURAL_PC[ref_letter] - ref_acc) // 12 - 1
    sig = key_sig_from_fifths(n)
    if minor:
        # 原调 = 关系大调主音往下小三度
        tpc = (pc - 3) % 12
        slabel = fifths_label(major_fifths(tpc))
        sli = LETTER_IDX[slabel[0]]
        sacc = 1 if slabel.endswith('#') else (-1 if slabel.endswith('b') else 0)
        return Key(sli, sacc, 'minor', sig, n, ref_letter, ref_acc,
                   ref_oct - ABC_OCT_BASE, la_based=True)
    return Key(ref_letter, ref_acc, 'major', sig, n, ref_letter, ref_acc,
               ref_oct - ABC_OCT_BASE, la_based=False)


def key_label(li, acc, mode):
    name = 'CDEFGAB'[li] + ('#' if acc == 1 else 'b' if acc == -1 else '')
    return name + ('' if mode in ('major', '') else mode)


def key_sig_text(sig):
    out = []
    for i, v in enumerate('CDEFGAB'):
        if sig[i] == 1:
            out.append(v + '#')
        elif sig[i] == -1:
            out.append(v + 'b')
    return ' '.join(out) if out else '(无升降)'


# ==========================================================================
# 二、音级 / 变音 / 八度(ABC 与 MIDI 共用的那一步)
# ==========================================================================
# 十二音级表: 相对 `1=` 参考音的半音槽 -> (音级, 变音)。MIDI 侧拼写音高就用这张表(依据见 spell_midi)。
# 自然音槽 0/2/4/5/7/9/11 -> 1..7 无变音; 另 5 个半音槽按语料实测的多数写法: #1 b3 #4 b6 b7。
DEGREE_TABLE = {0: (1, 0), 1: (1, 1), 2: (2, 0), 3: (3, -1), 4: (3, 0), 5: (4, 0),
                6: (4, 1), 7: (5, 0), 8: (6, -1), 9: (6, 0), 10: (7, -1), 11: (7, 0)}


def degree_of_abs(key: Key, letter_idx, acc, oct_index):
    """-> (音级 1..7, 变音差 -1/0/+1, 八度记号数 +上 -下)

    音级 = 音名字母相对 `1=` 参考音的位次(调号怎么变都不动);
    变音 = 实际音高 - 该调号在本音名字母上应有的音高。
    于是 `K:E` 的 `F`(调号含 F#) -> 音级 2, 变音 0 -> `2`(而不是 `#1`);
    小调(La-based)的 `1=` 是关系大调主音且高一档 -> 主音 `A` 落在 `,6`。
    """
    dstep = oct_index * 7 + letter_idx
    tstep = key.ref_oct * 7 + key.ref_letter
    diff = dstep - tstep
    deg = (diff % 7) + 1
    octn = diff // 7
    expected = key.sig[letter_idx]
    actual = acc if acc is not None else expected
    return deg, actual - expected, octn


def degree_of(letter_idx, acc, octmarks, lowcase, key: Key):
    """ABC 侧入口: 音名字母 + 八度记号串(`'`/`,`) + 是否小写 -> degree_of_abs 的同一结果。"""
    reg = 1 if lowcase else 0
    for ch in octmarks:
        reg += 1 if ch == "'" else -1
    return degree_of_abs(key, letter_idx, acc, ABC_OCT_BASE + reg)


def spell_midi(midi, key: Key, how='degree'):
    """绝对音高(MIDI 号) -> (音级 1..7, 变音 -1/0/+1, 八度记号数)。

    MIDI 只给半音, **不给音名拼写** —— 所以这一步必须选一套写死的规则, 不能"看心情"。

    默认 `how='degree'`: 相对 `1=` 参考音的**十二音级表**(大调音阶的 12 个半音槽):
        半音 0->1, 1->#1, 2->2, 3->b3, 4->3, 5->4, 6->#4, 7->5, 8->b6, 9->6, 10->b7, 11->7
    依据(**实测**, 不是惯例抄来的): 全库 270 首 `status=midi` 的谱(本身就由 MIDI 那条路
    转来)里, 5 个半音槽的两可写法计数是
        #1 183107 / b2 169852     b3 244991 / #2 125684     #4 485353 / b5 218949
        b6 239791 / #5 179310     b7 344009 / #6 135076
    —— **5 个槽全部与上表一致**。所以按这张表拼写, 与语料自身的多数写法同向。
    ⚠ 八度直接取 `floor((音高 - 参考音)/12)`: 十二音级表的每个槽与音名字母一一对应,
      所以它和 jianpu-ly 的"记号写在哪一级上"是同一套格子(实测 K:G 的 F 自然 = `,b7`,
      与 ABC 侧按音名字母算出来的结果逐项相同)。

    `how='letter'`: 只按**调号方向**挑音名字母(升号调取升号、降号调取降号), 好处是每个音
    都能说清是哪个字母, 坏处是降号调里的半音会被读成"降下一级"而不是"升本级" ——
    实测 `K:F` 的 B 自然: 默认表给 `#4`, letter 模式给 `b5`(音高相同、写法不同)。
    仅供对比, 默认不用。
    """
    d = int(midi) - key.ref_midi
    o = d // 12
    step = d - 12 * o
    if how != 'letter' or step in (0, 2, 4, 5, 7, 9, 11):
        deg, delta = DEGREE_TABLE[step]
        return deg, delta, o
    # letter 模式: 半音槽上的音按调号方向选字母, 再回过头算音级/变音
    pc = int(midi) % 12
    cands = []
    for L in range(7):
        want = (NATURAL_PC[L] + key.sig[L]) % 12
        dd = (pc - want) % 12
        if dd == 1:
            cands.append((L, key.sig[L] + 1, 'sharp'))
        elif dd == 11:
            cands.append((L, key.sig[L] - 1, 'flat'))
    want = 'sharp' if key.nsig >= 0 else 'flat'
    pick = next((c for c in cands if c[2] == want), cands[0])
    L, acc = pick[0], pick[1]
    oct_index = (int(midi) - (NATURAL_PC[L] + acc)) // 12 - 1
    deg, delta, o2 = degree_of_abs(key, L, acc, oct_index)
    return deg, delta, o2


# ==========================================================================
# 三、时值: 四分音符数 -> 简谱 token 分量
# ==========================================================================
# jptok.BEAT 口径: c=1 拍(四分), q=1/2, s=1/4, d=1/8, h=1/16 (单位=四分音符)
_FIRST = [(1.0, '', 0), (1.5, '', 1), (0.5, 'q', 0), (0.75, 'q', 1),
          (0.25, 's', 0), (0.375, 's', 1), (0.125, 'd', 0), (0.1875, 'd', 1),
          (0.0625, 'h', 0), (0.09375, 'h', 1)]
# 续接项只能是「时值字母 + `-`」——jptok 的 dash 正则是 ^[cqsdh]+-$: 不能带附点
_DASH = [(1.0, '-'), (0.5, 'q-'), (0.25, 's-'), (0.125, 'd-'), (0.0625, 'h-')]
_TOL = 1e-9


def split_duration(quarters):
    """四分音符数 -> token 分量列表; 精确表示不了返回 None。"""
    q = quarters
    if q <= 0:
        return None
    for val, letter, dots in _FIRST:
        if abs(val - q) < _TOL:
            return [(letter, dots)]
    for val, letter, dots in _FIRST:
        rest = q - val
        if rest <= _TOL:
            continue
        for dv, dtok in _DASH:
            if abs(dv - rest) < _TOL:
                return [(letter, dots), (dtok, None)]
    for val, letter, dots in _FIRST:
        rest = q - val
        if rest <= _TOL:
            continue
        for dv1, dtok1 in _DASH:
            r2 = rest - dv1
            if r2 <= _TOL:
                continue
            for dv2, dtok2 in _DASH:
                if abs(dv2 - r2) < _TOL:
                    return [(letter, dots), (dtok1, None), (dtok2, None)]
    for val, letter, dots in _FIRST:
        rest = q - val
        if rest <= _TOL:
            continue
        for dv1, dtok1 in _DASH:
            r2 = rest - dv1
            if r2 <= _TOL:
                continue
            for dv2, dtok2 in _DASH:
                r3 = r2 - dv2
                if r3 <= _TOL:
                    continue
                for dv3, dtok3 in _DASH:
                    if abs(dv3 - r3) < _TOL:
                        return [(letter, dots), (dtok1, None), (dtok2, None), (dtok3, None)]
    return None


def duration_tokens(quarters):
    """时值 -> [(token 字符串, 是否续接项), …]; 精确表示不了时返回 (近似分量, True)。

    收尾用: 第一个分量是音头 token(带音级), 后面是 `-`/`q-` 这类延长记号。
    """
    parts = split_duration(quarters)
    if parts is None:
        return [(('' if quarters >= 1.0 else 'q'), 0)], True
    return parts, False


# 每个 token 主体的拍数(与 jptok.BEAT 表同一份口径: c=1 q=1/2 s=1/4 d=1/8 h=1/16)
_COMP_BEATS = {'': 1.0, 'q': 0.5, 's': 0.25, 'd': 0.125, 'h': 0.0625}
_DASH_BEATS = {'-': 1.0, 'q-': 0.5, 's-': 0.25, 'd-': 0.125, 'h-': 0.0625}


def duration_parts(quarters):
    """四分音符数 -> ([(时值字母, 附点数, 该分量拍数, 是否音头), …], exact)。

    **音头那一项只给字母与附点, 音级由调用方拼进去**(附点必须在音级**后面**: `,5.` 对,
    `.,5` 错 —— 实测踩过: 把附点拼进"音头字符串"再挂音级, 就写成了 `.,5`,
    `jptok.token_figures` 一个音都认不出, 于是自检报"静默丢音")。
    续接项的字母就是完整记号(`-` / `q-` / `s-` / `d-` / `h-`), 附点恒为 0。

    为什么要单独给拍数: MIDI 的时值直接从 tick 算, **一个音可能跨好几小节**(整个音符连音),
    这时必须把 `|` 插在延长记号之间, 而不是把小节线全堆到音尾。

    ⚠ 与 `split_duration` 的关系: 先走它(<= 4 拍都能精确表示, 输出与它逐项等价);
      表示不了的长音再按"音头吃 1 + 小数部分、整数拍用 `-` 接"拆开 —— 简谱正是这么写长音的。
      例: 8.25 拍 -> (1 + 0.25) 拍的音头 + 7 个 `-`。
    """
    if quarters <= 0:
        return [], False

    def _unpack(parts):
        out = []
        for i, (letter, dots) in enumerate(parts):
            if dots is None:                        # 延长记号(续接项)
                out.append((letter, 0, _DASH_BEATS[letter], False))
            else:
                out.append((letter, dots,
                            _COMP_BEATS[letter] * (1.5 if dots else 1.0), i == 0))
        return out

    parts = split_duration(quarters)
    if parts is not None:
        return _unpack(parts), True
    n = int(quarters)
    frac = quarters - n
    if n >= 1:
        head = split_duration(1.0 + frac)
        if head is not None:
            out = _unpack(head)
            out.extend([('-', 0, 1.0, False)] * (n - 1))
            return out, True
    return [('', 0, 1.0, True)], False


# ==========================================================================
# 四、token 形态(和弦 = jianpu-ly 的"数字连写")
# ==========================================================================
# 语料实测(2026-10-05, `_scan_chords2.py`, 全库 11876 首 8354629 个 token):
#   **261611 个和弦 token, 分布在 223 首里, 全部 status=midi** —— 形态一律是
#   `[时值字母][(八度记号 变音? 音级) …][附点]`, **每个音级各自带自己的八度记号**,
#   记号一律写在**它所修饰的那个音级的左边**:
#       `d,4,,b5,,3,,1`(32分音符, 4/降5/3/1, 后三个低两个八度)
#       `q'16`(八分音符, 高音1 + 6)      `s6,5.`(十六分附点, 6 + 低音5)
#   参考实现 `jianpu-ly.py:1861 chordNotes_markup()`: 逐字符扫, `,`/`'` 只对**后面**那个
#   数字生效; `grace_octave_fix()` 把"写在数字右边的"记号搬回该数字左边。
#   -> 结论: 按"记号在前、各带各的"输出最稳; 渲染前 jianpu-ly 还会按音高重排(sort_chords),
#      所以**文件里的音序不承载语义**, 转换器按源里的书写顺序输出。
PITCH_TOK_RE = re.compile(r"^([cqsdh]*)([',]*)([#b]?)([1-7])([',]*)([.]*)$")
CHORD_TOK_RE = re.compile(r"^([cqsdh]*)((?:[',]*[#b]?[1-7]){2,})([.]*)$")
FIG_RE = re.compile(r"([',]*)([#b]?)([1-7])")
# jianpu-ly 单音八度校验: 只接受 ,,, ,, , '' ' ''' 八档 -> scoreError("Can't handle octave …")
MAX_OCT = 3
# 休止/念白 token(念白 `x` 也是 token, 只是不参与音高)
REST_TOK_RE = re.compile(r"^[cqsdh]*[',]*[x0]")
# 唯一的 token 白名单判据在 skill 目录的 jptok.py; 这里是它认的"非音符但合法的正文记号"
BODY_MARKS = ('|', '-', '~')


def token_figures(tok):
    """token -> [(八度记号, 变音, 音级字符), ...]。

    单音 1 项; **和弦 N 项(同时发声的每个音各算一项)**; 休止/延长/连音线/不是 token -> []。
    """
    m = CHORD_TOK_RE.match(tok or '')
    if m:
        return FIG_RE.findall(m.group(2))
    m = PITCH_TOK_RE.match(tok or '')
    if m:
        return [(m.group(2) + m.group(5), m.group(3), m.group(4))]
    return []


def token_note_count(tok):
    """token 里有几个**发声的音**(和弦按音数算) —— 用来做"零丢失"自检。"""
    return len(token_figures(tok))


def fig_oct(marks):
    """八度记号串 -> 八度数(**正 = 高**; `,` 减 1、`'` 加 1)。

    ⚠ 注意 jptok 的 `parse_token` 用的是**反号**(它算 `逗号 - 撇`), 两者不要混。
    """
    return marks.count("'") - marks.count(',')


def count_octave_marks(tokens):
    """整首谱里 `,` + `'` 的总数(和弦里的每个音都算)。"""
    return sum(len(f[0]) for t in tokens for f in token_figures(t))


def count_rest_tokens(tokens):
    """休止/念白 token 个数。"""
    return sum(1 for t in tokens if REST_TOK_RE.match(t))


def shift_token_octave(tok, delta):
    """把 token 整体平移 delta 个八度 -> (新 token, True); (原 token, True) 表示不是音符;
    (None, False) 表示**超界**(jianpu-ly 只认 ±3 个记号) -> 该方案作废。"""
    if delta == 0:
        return tok, True
    m = CHORD_TOK_RE.match(tok or '')
    if m:
        out = []
        for marks, acc, dig in FIG_RE.findall(m.group(2)):
            k = fig_oct(marks) + delta
            if abs(k) > MAX_OCT:
                return None, False
            out.append((',' * (-k) if k < 0 else "'" * k) + acc + dig)
        return m.group(1) + ''.join(out) + m.group(3), True
    m = PITCH_TOK_RE.match(tok or '')
    if not m:
        return tok, True
    pre, acc, dig, post, dots = m.group(2), m.group(3), m.group(4), m.group(5), m.group(6)
    k = fig_oct(pre) + fig_oct(post) + delta
    if abs(k) > MAX_OCT:
        return None, False
    marks = ',' * (-k) if k < 0 else "'" * k
    # 记号写在前还是后: **跟原 token 保持一致**(本器负八度写前、正八度写后; 语料两种都有)。
    # ⚠ 2026-10-06 实测(差点改坏): "原本一个记号都没有"的音, 这里会把正记号写在**数字前面**
    #   (`1` -> `'1`)。我一度把它改成写后面(更合 `_emit_note` 的约定), 结果 492 首真素材回归
    #   从 492/492 掉到 **485/492** —— 说明既有产物就是"记号在前"这个形态, 改了就是改口径。
    #   所以**保持原样**: jptok 两种写法都认(TOKEN 正则里 oct1/oct2 都在), 下游不受影响。
    if pre or not post:
        return m.group(1) + marks + acc + dig + dots, True
    return m.group(1) + acc + dig + marks + dots, True


def normalize_octave(tokens):
    """整首升/降 12 个半音, 选 `,`+`'` 总数最少的那个; 平手保持原样。

    -> (新 tokens, delta, 平移前记号数, 平移后记号数, {delta: 记号数})
    只比较 0 / +1 / -1 三个方案; 平移会让任何音超出 ±3 个记号时该方案作废(jianpu-ly 会报错)。
    """
    before = count_octave_marks(tokens)
    cands = [(before, 0, list(tokens))]
    counts = {0: before}
    for d in (1, -1):
        new, ok = [], True
        for t in tokens:
            nt, good = shift_token_octave(t, d)
            if not good:
                ok = False
                break
            new.append(nt)
        if ok:
            counts[d] = count_octave_marks(new)
            cands.append((counts[d], d, new))
    prio = {0: 0, 1: 1, -1: 2}          # 平手 -> 原样(0) 优先
    best = min(cands, key=lambda c: (c[0], prio[c[1]]))
    return best[2], best[1], before, best[0], counts


# ==========================================================================
# 五、公共结果对象 + 收尾自检
# ==========================================================================
class TuneResult(object):
    """一首曲子的转换结果(公共字段)。

    子集外构造分三档(用于"能不能入库"的判断):
      ① DURATION_ONLY —— 只影响时值/展开次数, **音高序列仍然忠实**;
      ② PITCH_LOSSLESS —— 剥掉不丢音高(和弦记号/装饰音/圆滑线/断奏/…);
      ③ 其余(结构性构造) -> pitch_safe=False。
    ⚠ `tuplet`/`broken_rhythm` 归 ①: 它们只改时值不改音级, 时值不忠实的部分单列 dur_lossy。
    """
    DURATION_ONLY = {'meter_unparsed', 'length_unparsed', 'length_default', 'stray_tie',
                     'tuplet', 'broken_rhythm', 'multirest', 'invisible_rest_x',
                     'meter_change', 'body_field', 'parts_expanded', 'ending_expanded',
                     'repeat_expanded', 'unclosed_repeat', 'chord_mixed_len',
                     # ---- MIDI 侧(音高都还是忠实的, 只是时值/选轨/调号这类记账) ----
                     'leading_silence', 'quantized', 'overlap_trimmed', 'note_too_short',
                     'bars_synthesized', 'key_inferred', 'key_forced', 'no_meter',
                     'melody_ambiguous', 'melody_merged', 'unclosed_note',
                     'duplicate_note_on'}
    PITCH_LOSSLESS = {'chord_symbol', 'grace_notes', 'slur', 'decoration', 'abc_roll',
                      'staccato',
                      # MIDI 侧:
                      'program_change', 'text_meta', 'lyric_meta', 'pitch_bend',
                      'aftertouch', 'controller'}

    def __init__(self):
        self.events = []
        self.tokens = []
        self.n_pitch = 0            # 展开/输出后音符个数
        self.n_pitch_raw = 0        # 源里音符个数(展开前)
        self.n_rest_seen = 0
        self.n_rest_emitted = 0
        self.errors = []
        self.unsupported = {}
        self.notes_total = 0
        self.dur_approx = 0
        self.key = None
        self.oct_shift = 0
        self.oct_marks_before = 0
        self.oct_marks_after = 0
        self.n_chord = 0             # 同时发声的和弦个数(按和弦输出)
        self.n_chord_notes = 0       # 和弦里一共几个发声的音

    def flag(self, kind, detail=''):
        d = self.unsupported.setdefault(kind, [])
        if len(d) < 8:
            d.append(detail)

    @property
    def ok(self):
        """能不能产出数字串(没有未识别字符、没有休止数不符)。"""
        return not self.errors

    @property
    def clean(self):
        """是否**完全落在最小子集内**(ok 且没有任何子集外构造被记账)。"""
        return self.ok and not self.unsupported

    @property
    def lossy(self):
        """有没有会让**音高序列**不忠实的子集外构造。"""
        return sorted(k for k in self.unsupported
                      if k not in self.DURATION_ONLY and k not in self.PITCH_LOSSLESS)

    @property
    def dur_lossy(self):
        """音高忠实但时值不忠实的构造。"""
        return sorted(k for k in self.unsupported if k in self.DURATION_ONLY)

    @property
    def pitch_safe(self):
        """音高序列可用(能解析, 且没有会让音高不忠实的构造)。"""
        return self.ok and not self.lossy

    def corpus_tokens(self):
        return list(self.tokens)


def check_no_note_loss(r: TuneResult, n_pitch_post, normalize=True):
    """收尾断言(ABC 与 MIDI 同一套): 八度归一 + 四条"静默丢音"检查。

    历史上静默丢音踩过三次(# 的音整段丢 / 后缀时值丢 / 和弦 token 整批丢), 所以每条
    计数都必须在**同一个函数**里对上; 各自转换器只负责把 n_pitch_post 算出来。
    """
    # 展开只能是"复制", 不许少音
    if n_pitch_post < r.n_pitch_raw:
        r.errors.append('展开后音数变少: %d -> %d' % (r.n_pitch_raw, n_pitch_post))
    if normalize:
        n_before_norm = sum(token_note_count(t) for t in r.tokens)
        r.tokens, r.oct_shift, r.oct_marks_before, r.oct_marks_after, _c = \
            normalize_octave(r.tokens)
        if sum(token_note_count(t) for t in r.tokens) != n_before_norm:
            r.errors.append('八度归一改了音数: %d -> %d'
                            % (n_before_norm, sum(token_note_count(t) for t in r.tokens)))
    else:
        r.oct_marks_before = r.oct_marks_after = count_octave_marks(r.tokens)
    n_tok_pitch = sum(token_note_count(t) for t in r.tokens)
    if n_tok_pitch != n_pitch_post:
        r.errors.append('展开后 token 里音符数不符: token %d, 事件 %d(静默丢音!)'
                        % (n_tok_pitch, n_pitch_post))
    n0 = count_rest_tokens(r.tokens)
    if n0 < r.n_rest_emitted:
        r.errors.append('休止 token 计数不符: %d < %d' % (n0, r.n_rest_emitted))
    return r


# ==========================================================================
# 六、source 命名 + 语料排版
# ==========================================================================
SRC_RE = re.compile(r'^[a-z0-9]+-[0-9a-z_]+$')


def source_id(repopath, idx_in_file):
    """`sha1(仓库路径 + '#' + 文件内序号)[:12]` —— **必须含序号**, 否则块内第二首会撞车。"""
    h = hashlib.sha1(('%s#%d' % (repopath, idx_in_file)).encode('utf-8')).hexdigest()
    return h[:12]


def make_source(site, repopath, idx_in_file):
    """`<站点token>-<sha1>`; 形状由 `SRC_RE` 钉住(不合规就直接抛, 不许悄悄入库)。"""
    sid = '%s-%s' % (site, source_id(repopath, idx_in_file))
    if not SRC_RE.match(sid):
        raise ConvertError('source 形状不合规(要求 %s): %r' % (SRC_RE.pattern, sid))
    return sid


def wrap_tokens(tokens, width=100):
    """正文按 100 列折行(**逐字节口径**: 与已入库的 492 首 ABC 产物同一份排版代码)。"""
    body = ' '.join(tokens)
    lines, cur = [], ''
    for t in body.split():
        if len(cur) + len(t) + 1 > width:
            lines.append(cur)
            cur = t
        else:
            cur = (cur + ' ' + t).strip()
    if cur:
        lines.append(cur)
    return lines


def corpus_text(title, source, name, comments=(), meter=None, default_meter=None,
                alias=None, link='', status='converted', transcriber='', tokens=(),
                width=100):
    """一首 -> 语料形态文本(`%--` 之后是正文)。

    作者 2026-10-05 定的入库头(照做): `title=` / `source=` / `transcriber=` / `status=converted`;
    `usertag` **留空**(不编); 多行 `T:` 的别名进 `alias=`; `link=` 只在确有收录页时写。
    `comments` 是 `%` 注释行(调号/八度归一/来源文件这些"记账"信息都放这儿)。
    """
    head = []
    head.append('%' + name)
    head.append('title=' + title)
    if alias:
        head.append('alias=' + ','.join(alias))
    head.append('tag=')
    head.append('usertag=')
    head.append('tagroute=')
    head.append('transcriber=' + transcriber)
    head.append('status=' + status)
    head.append('source=' + source)
    if link:
        head.append('link=' + link)
    head.extend(comments)
    head.append('%--')
    if meter:
        head.append(meter)
    elif default_meter:
        # ABC 标准: 没有 `M:` 时默认 4/4(不是我们编的) —— 但要在头里注明是默认值。
        head.append(default_meter)
    head.append('subtitle=score')
    head.extend(wrap_tokens(tokens, width))
    head.append('%END')
    return '\n'.join(head) + '\n'


# ==========================================================================
# 七、校验: jptok 白名单 + jianpu-db/score.py 真解析
# ==========================================================================
def load_jptok():
    """加载本仓库的**唯一** token 实现(`skills/jianpu-melody-lookup/jptok.py`), 只读。"""
    if JTOK_DIR not in sys.path:
        sys.path.insert(0, JTOK_DIR)
    import jptok
    return jptok


def load_score_module():
    """加载 `jianpu-db/score.py`(平台的唯一解析实现), 只读、不写仓库。

    它是硬依赖: 拿不到就直接抛 —— 与 score.py 对 jptok 的态度一致("不静默降级换口径")。
    确实要跳过时设 `JIANPU_SKIP_SCORE_CHECK=1`(或给 selfcheck 传 --no-score-check)。
    """
    if DB_DIR not in sys.path:
        sys.path.insert(0, DB_DIR)
    import score
    return score


def bad_tokens(tokens, jp=None):
    """-> 不是合法正文 token 的那些(空列表 = 全过白名单)。

    判据只有一份: `jptok.is_note()`(它认单音与和弦 token), 外加正文里合法的 `|`/`-`/`~`
    与 KeepLength 补时值后的 `c-`/`q-` 形延长记号。
    """
    jp = jp or load_jptok()
    bad = []
    for t in tokens:
        if jp.is_note(t) or t in BODY_MARKS or re.match(r'^[cqsdh]+-$', t):
            continue
        bad.append(t)
    return bad


def score_roundtrip(text, tag='selftest'):
    """把语料文本交给 `jianpu-db/score.py` 真解析一遍 -> (record, 正文字符串)。

    只走 `read() -> write_buf() -> expand() -> to_record()` 这四步(null 副作用都落在临时目录),
    **不碰仓库**: `parse()` 尾部还会写 `_buf.txt`/建 `by_*` 链接, 这里刻意不调。
    """
    score = load_score_module()
    d = tempfile.mkdtemp(prefix='jpc_%s_' % tag)
    path = os.path.join(d, tag + '.txt')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    s = score.Score(path)
    s.read()
    s.derive_others()
    s.write_buf()
    s.expand()
    rec = s.to_record()
    body = ' '.join(sec['score'] for sec in rec['sections'])
    return rec, body


def score_check(text, tokens, tag='selftest'):
    """断言一条链: 每个 token 过 jptok 白名单, 且 score.py 能把正文原样读回来。

    -> 问题列表(空 = 通过)。
    """
    problems = []
    jp = load_jptok()
    bad = bad_tokens(tokens, jp)
    if bad:
        problems.append('token 过不了 jptok 白名单: %r' % (bad[:5],))
    if os.environ.get('JIANPU_SKIP_SCORE_CHECK') == '1':
        return problems
    try:
        rec, body = score_roundtrip(text, tag)
    except SystemExit as e:                       # score.py 找不到 jptok 时会 SystemExit
        problems.append('score.py 起不来: %s' % (e,))
        return problems
    got = body.split()
    want = [t for t in tokens if t not in BODY_MARKS]
    got_notes = [t for t in got if t not in BODY_MARKS]
    if got_notes != want:
        n = min(len(got_notes), len(want))
        first = next((i for i in range(n) if got_notes[i] != want[i]), n)
        problems.append('score.py 读回的正文与输出不一致(第 %d 个: %r vs %r, 共 %d/%d)'
                        % (first + 1, want[first:first + 1], got_notes[first:first + 1],
                           len(want), len(got_notes)))
    if jp.seq(body) != jp.seq(' '.join(tokens)):
        problems.append('score.py 读回后的音高序列与原 token 不一致')
    return problems


def tokens_pitch_seq(tokens):
    """token 列表 -> 音高序列(走 jptok, 与检索侧同一口径)。"""
    return load_jptok().seq(' '.join(tokens))


def dump_report(rows, path):
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)


# ==========================================================================
# 八、公共口径自检
# ==========================================================================
def run_selfcheck(verbose=True):
    cases = []

    def chk(name, cond, detail=''):
        cases.append((name, bool(cond), detail))

    # ---- 调号: 小调 La-based 与 MIDI 侧同一条规则 ----
    for k, ref in (('Am', 'C'), ('Em', 'G'), ('Dm', 'F'), ('Gm', 'Bb'), ('Bm', 'D'),
                   ('Cm', 'Eb')):
        kk = parse_key(k)
        chk('%s: 1=%s 且 La-based' % (k, ref), kk.ref_label == ref and kk.la_based,
            '1=%s la=%s' % (kk.ref_label, kk.la_based))
    am = parse_key('Am')
    # Am 主音 A4=69 -> 音级应落在 `,6`
    deg, delta, octn = degree_of_abs(am, 5, 0, 4)
    chk('Am 的主音 A4 -> ,6', (deg, delta, octn) == (6, 0, -1), '%r' % ((deg, delta, octn),))
    # MIDI 侧: 主音 69 小调 -> 与 parse_key('Am') 同一把尺
    mk = key_from_tonic_midi(69, True)
    chk('MIDI 小调(主音 69) 与 ABC K:Am 拼写一致',
        (mk.ref_letter, mk.ref_acc, mk.ref_oct, mk.la_based, mk.nsig)
        == (am.ref_letter, am.ref_acc, am.ref_oct, am.la_based, am.nsig),
        'midi=%r abc=%r' % (mk, am))
    g = parse_key('G')
    mg = key_from_tonic_midi(NATURAL_PC[4] + 12 * 4, False)
    chk('MIDI 大调(G) 与 ABC K:G 拼写一致(Do-based, 1=G)',
        (mg.label, mg.ref_label, mg.la_based) == ('G', 'G', False) and g.label == 'G',
        'midi=%r' % (mg,))

    # ---- 音高拼写: 调号内 / 半音阶(十二音级表) ----
    key_c = parse_key('C')
    chk('K:C 的 F# -> `#4`(半音槽 6)', spell_midi(66, key_c) == (4, 1, 0),
        '%r' % (spell_midi(66, key_c),))
    chk('K:C 的 bE -> `b3`(半音槽 3)', spell_midi(63, key_c) == (3, -1, 0),
        '%r' % (spell_midi(63, key_c),))
    chk('K:C 的 bB -> `b7`(半音槽 10)', spell_midi(70, key_c) == (7, -1, 0),
        '%r' % (spell_midi(70, key_c),))
    key_f = parse_key('F')
    chk('K:F 的 B 自然(调号含 bB) -> `#4`(半音槽 6)',
        spell_midi(71, key_f) == (4, 1, 0), '%r' % (spell_midi(71, key_f),))
    chk('K:F 的 C 自然 -> `5`(调号内音级, 无变音)', spell_midi(72, key_f) == (5, 0, 0),
        '%r' % (spell_midi(72, key_f),))
    key_g = parse_key('G')
    chk('K:G 的 F 自然 -> `,b7`(与 ABC 侧按音名字母算出的八度一致)',
        spell_midi(65, key_g) == (7, -1, -1), '%r' % (spell_midi(65, key_g),))
    chk('K:G 的 F# -> `7`(调号内音级, 无变音)', spell_midi(78, key_g) == (7, 0, 0),
        '%r' % (spell_midi(78, key_g),))
    # 与 ABC 侧真正的对齐点: 同一段自然小调音阶, MIDI 主音 69 必须与 K:Am 逐音相同
    midi_minor = [spell_midi(m, key_from_tonic_midi(69, True)) for m in
                  (69, 71, 72, 74, 76, 77, 79, 81)]
    chk('MIDI 侧 A 自然小调音阶 = `,6 ,7 1 2 3 4 5 6`(La-based 与 ABC 同一结果)',
        midi_minor == [(6, 0, -1), (7, 0, -1), (1, 0, 0), (2, 0, 0), (3, 0, 0),
                       (4, 0, 0), (5, 0, 0), (6, 0, 0)],
        '%r' % (midi_minor,))
    chk('ABC 侧 K:Am 同一段音阶逐音相同(两把尺对得上)',
        [degree_of(li, 0, '', low, am) for li, low in
         ((5, False), (6, False), (0, True), (1, True), (2, True), (3, True),
          (4, True), (5, True))] == midi_minor,
        '%r' % ([degree_of(li, 0, '', low, am) for li, low in
                 ((5, False), (6, False), (0, True), (1, True), (2, True), (3, True),
                  (4, True), (5, True))],))
    chk('letter 模式(只按调号方向挑字母) 对 K:F 的 B 自然给 `b5`, 与默认表的 `#4` 不同'
        '(如实记账: 两种写法音高相同)',
        spell_midi(71, parse_key('F'), 'letter') == (5, -1, 0)
        and spell_midi(71, parse_key('F')) == (4, 1, 0),
        '%r vs %r' % (spell_midi(71, parse_key('F'), 'letter'),
                      spell_midi(71, parse_key('F'))))

    # ---- 时值 ----
    chk('时值: 1 拍 -> 无字母; 1.5 拍 -> 附点; 0.25 -> s; 0.75 -> q.',
        split_duration(1.0) == [('', 0)] and split_duration(1.5) == [('', 1)]
        and split_duration(0.25) == [('s', 0)] and split_duration(0.75) == [('q', 1)],
        '%r %r' % (split_duration(1.5), split_duration(0.75)))
    chk('时值: 2 拍 -> 音头 + `-` 延长; 1 拍 + 0.5 拍 -> `q-`',
        split_duration(2.0) == [('', 0), ('-', None)]
        and split_duration(1.5 + 1.0) == [('', 1), ('-', None)],
        '%r' % (split_duration(2.0),))

    # ---- 八度归一 ----
    hi = ['1', "2'", "3'", "4'", "5'", "6'", "7'", "1''"]
    out, d, before, after, _ = normalize_octave(hi)
    chk('八度归一: 高八度堆叠的曲子被整体下移(记号不增)',
        after <= before and d == -1, 'd=%+d %d->%d %r' % (d, before, after, out))
    tie = ['5', '6', "7'", "1'"]
    out2, d2, b2, a2, _ = normalize_octave(tie)
    chk('八度归一: 平手保持原样(shift 0)', d2 == 0 and a2 == b2, 'd=%+d' % d2)
    chk('八度归一: 只是整体平移, 音级序列不动',
        [f[2] for t in out for f in token_figures(t)]
        == [f[2] for t in hi for f in token_figures(t)], '')

    # ---- 和弦 token ----
    chk('和弦 token: `,1\'35` 认 3 个音, 记号各归各的',
        token_figures(",1'35") == [(',', '', '1'), ("'", '', '3'), ('', '', '5')],
        '%r' % (token_figures(",1'35"),))
    chk('和弦 token: 休止不算音; 单音算 1 个',
        token_note_count('0') == 0 and token_note_count('q5') == 1, '')
    sh, ok = shift_token_octave(',1', -1)
    chk('和弦/单音平移: ,1 再降一个八度 -> ,,1',
        ok and sh == ',,1', '%r' % (sh,))
    sh2, ok2 = shift_token_octave("''''1", 1)
    chk('平移超界(>±3 个记号) -> 该方案作废', not ok2, '%r' % (sh2,))

    # ---- source 命名 ----
    s1 = make_source('midi', 'a/b.mid', 1)
    chk('source 形状: midi-<12 位 sha1>, 且含序号(相邻序号不同)',
        SRC_RE.match(s1) is not None and s1 != make_source('midi', 'a/b.mid', 2),
        '%r' % (s1,))

    # ---- 语料排版: 100 列 + 头/尾 ----
    toks = ['1'] * 80
    txt = corpus_text('t', 'midi-abc', 'x.txt', comments=['%c'], meter='4/4',
                      transcriber='midi2jianpu', tokens=toks)
    body_lines = txt.split('%--\n')[1].rstrip('\n').split('\n')
    chk('语料排版: 每行 <=100 列, 头部字段齐全, 以 %END 收尾',
        all(len(l) <= 100 for l in body_lines) and 'transcriber=midi2jianpu\n' in txt
        and 'status=converted\n' in txt and txt.endswith('%END\n'), '')

    # ---- 与 jianpu-db 的唯二实现对齐(白名单 + score.py 真解析) ----
    demo = ["1", "2", "3", ",6", "5'", ",1'35", '0', 'q4', '|', '2.', '-']
    demo_txt = corpus_text('t', 'midi-abc', 'x.txt', meter='4/4',
                           transcriber='midi2jianpu', tokens=demo)
    problems = score_check(demo_txt, demo, tag='common')
    chk('每个 token 过 jptok 白名单, 且 jianpu-db/score.py 能原样解析回来',
        not problems, '; '.join(problems))

    if verbose:
        npass = 0
        for name, ok, detail in cases:
            print('%s  %s%s' % ('PASS' if ok else 'FAIL', name,
                                '' if ok else '  <- ' + detail))
            npass += 1 if ok else 0
        print('-- 公共口径自检 %d/%d 通过 --' % (npass, len(cases)))
    return all(c[1] for c in cases), cases


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(
        description='ABC/MIDI -> 简谱 转换器的公共口径(唯一实现); --selfcheck 只验口径本身')
    ap.add_argument('--selfcheck', '--selftest', dest='selfcheck', action='store_true')
    ap.add_argument('--no-score-check', action='store_true',
                    help='跳过 jianpu-db/score.py 真解析那一步(环境里没有 jianpu-db 时用)')
    a = ap.parse_args(argv)
    if a.selfcheck:
        if a.no_score_check:
            os.environ['JIANPU_SKIP_SCORE_CHECK'] = '1'
        ok, _ = run_selfcheck()
        return 0 if ok else 1
    ap.print_help()
    return 2


if __name__ == '__main__':
    sys.exit(main())
