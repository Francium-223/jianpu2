# -*- coding: utf-8 -*-
"""MIDI -> 简谱数字串转换器(入库形态, `status=converted`)。

它跟 `abc_to_jianpu.py` 是**同一条口径**下的两个入口: 调号/音级映射、时值切分、token 形态、
八度归一、和弦写法、source 命名、语料头部排版、以及"每个 token 过 jptok 白名单 + `score.py`
能解析"这两道校验, 全部在 `tools/convert_common.py`(**唯一一份**), 本文件不复制任何一条。

MIDI 比 ABC 少两样东西, 所以必须**明确写出依据**, 不许硬猜:
  ① **没有音名拼写** —— 只有半音。拼写规则取 `convert_common.DEGREE_TABLE`(大调十二音级表),
     依据是**实测**: 全库 270 首 `status=midi` 的谱里 5 个半音槽的两可写法计数,
     `#1 183107/b2 169852`、`b3 244991/#2 125684`、`#4 485353/b5 218949`、
     `b6 239791/#5 179310`、`b7 344009/#6 135076` —— **5 个槽全部与那张表同向**。
     想要"按调号方向挑字母"的另一种写法用 `--spell letter`(实测差异: `K:F` 的 B 自然
     默认表给 `#4`、letter 模式给 `b5`, 音高相同)。
  ② **没有"哪个声部是主旋律"** —— 多轨时必须给策略。默认 `--melody auto`, 判据按优先级:
     (a) **轨道名**命中 `melody|lead|vocal|solo|main|主旋律|旋律`(POP909 的 `index.mid`
         公开说明就是"MELODY track for the main melody, BRIDGE for the sub-melody,
         PIANO for the accompaniment" —— https://github.com/music-x-lab/POP909-Dataset);
     (b) 没有命名时, 取**同时发声率为 0**(单声部)且**平均音高最高**的那一轨;
         依据是本仓库的口径"只记具有特征性的、响度最大的**线性**旋律"(jianpu-db/README.md)
         —— 主旋律是单声部、且通常在高音区;
     (c) 仍然分不出来就取音数最多的一轨, 并记 `melody_ambiguous`(不静默猜)。
     其它策略: `--melody 2`(第 2 轨, 含它所有通道)、`--melody name:PIANO`、`top`/`most`/`all`。
  ③ **调号**: MIDI 的 `FF 59` 调号 meta 有就**照用**(它是源里写死的, 不是猜的);
     没有就用 Krumhansl-Schmuckler 音级分布相关(Krumhansl 1990)推断并记 `key_inferred`,
     想稳就用 `--key Gb` 直接指定(记 `key_forced`)。
     ⚠ **`--key` 收的是"参考音 / `1=` 的音名", 不是"曲子主音"** —— 于是 `--key Am` 与
     `--key C` 是同一个 `1=C`,`--key Eb` 给 `1=Eb`。想按**主音 + 调式**写(ABC 的 `K:` 语法,
     如 `--key Eb:min`)也认: 那时按"Eb 是主音的小调"解释成 `1=Gb`, 并记一条
     `key_mode_expanded` 说明它被展开成了哪个参考音 —— **绝不静默当大调**。

口径(与 ABC 侧同一份, 见 `docs/CONVERTERS.md`)
============================================
`status=converted`; 小调 La-based(主音 `,6`)、大调 Do-based; 八度归一(整首 ±12 半音取
`,+'\''` 最少者, 平手保持原样); 和弦按**和弦 token**输出; 正文**没有反复记号**;
休止 `0` **不静默丢**(MIDI 没有"念白"语义, 所以不出 `x`, 只出 `0`)。

用法
----
    py -3.13 midi_to_jianpu.py <file.mid>                 # 看它选哪一轨 + 转换结果
    py -3.13 midi_to_jianpu.py <file.mid> --corpus        # 出语料形态文本(不写盘)
    py -3.13 midi_to_jianpu.py <file.mid> --key Am --melody name:MELODY --json
    py -3.13 midi_to_jianpu.py --selftest                 # 合成用例自检(含 jptok/score.py 校验)
    py -3.13 midi_to_jianpu.py *.mid --corpus --outdir <dir>   # 只写你给的目录, 绝不写 scores/
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import struct
import sys
import tempfile

# 公共口径(唯一一份): tools/convert_common.py
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import convert_common as cc                                     # noqa: E402

ABOUT_TRANSCRIBER = 'midi2jianpu'
SITE_TOKEN = 'midi'

# 会改**实际演奏顺序**的文本/标记(与 ABC 侧同一份判据: 这类记号不能当普通注释剥掉)
JUMP_NAMES = re.compile(r'(?i)\b(segno|coda|fine|d\.?\s*c\.?|d\.?\s*s\.?|da\s*capo|'
                        r'dal\s*segno|to\s*coda|repeat|反复|跳房子)\b')
# 轨道名 -> "这是主旋律"的关键词(POP909 的 MELODY / 一般 DAW 的 Lead、Vocal、主旋律)
MELODY_NAMES = re.compile(r'(?i)(melody|lead|vocal|solo|main|tune|主旋律|旋律|主奏|唱)')
ACCOMP_NAMES = re.compile(r'(?i)(piano|accomp|chord|bass|drum|perc|bridge|pad|guitar|伴奏|和声|鼓)')


class MidiError(cc.ConvertError):
    pass


def resolve_key_arg(raw):
    """`--key` 的值 -> (交给 `cc.parse_key` 的字符串, 调参说明 flag|None)。

    语义(**与自动路径一致**): `--key` 收的是**参考音 / `1=` 的音名** —— `Am`、`Gb`、`Eb`
    都直接就是"`1=` 在那个音上"。这与 `cc.parse_key()` 的口径天然一致(`K:Am` 给的也是
    `1=C`), 所以不带调式词时**原样透传**, 不改任何既有行为。

    ⚠ 带调式词时**必须解释, 不许静默当大调**(2026-10-07 实测踩到的坑):
      `--key Eb:min` 落到 `cc.parse_key()` 里 mode='min' 但 `ref_letter` 仍是 **Eb**(主音),
      于是 `1=Eb` —— 那是**大调**的写法, 与"Eb 小调"应有的 `1=Gb`(关系大调)差一个小三度,
      整首音级会错一格。这里把它按"Eb 是主音的小调"展开成参考音 `Gb`, 并记
      `key_mode_expanded` 说明展开了什么, 报告里看得见。
    """
    s = (raw or '').strip()
    if ':' not in s:
        return s, None                       # 没有调式词: 原样透传(既有行为不变)
    bare, _, word = s.partition(':')
    bare, word = bare.strip(), word.strip().lower()
    if not bare or not word:
        raise MidiError('--key 的调式写法要写成 `<音名>:<调式>`(如 `Eb:min`); '
                        '只想给参考音就直接写音名(如 `Gb`)。收到: %r' % raw)
    m = re.match(r'^([A-Ga-g])([#b]?)$', bare)
    if not m:
        raise MidiError('--key 的音名不认识: %r(形如 Eb / F# / C)' % bare)
    if word not in cc.MODE_STEPS:
        raise MidiError('--key 的调式词不认识: %r(可用: %s; 如 --key Eb:min 或 --key Gb)'
                        % (word, '/'.join(sorted(set(cc.MODE_STEPS) - {''}))))
    li = cc.LETTER_IDX[m.group(1).upper()]
    acc = 1 if m.group(2) == '#' else (-1 if m.group(2) == 'b' else 0)
    mode_steps, mode_semis = cc.MODE_STEPS[word]        # (往下数几个音名字母, 往下几个半音)
    if word in ('', 'maj', 'major', 'ion', 'ionian'):   # 大调族: 参考音就是主音自己
        return cc.key_label(li, acc, 'major'), None
    # 大调主音 pc 必须对得上"往回数 mode_semis 个半音的那个音名字母" —— parse_key 里
    # 同一条断言(差 2~10 个半音时算不出关系大调的变音, 那种调式这里不猜)。
    tonic_pc = (cc.NATURAL_PC[li] + acc) % 12
    maj_letter = (li - mode_steps) % 7
    d = ((tonic_pc - mode_semis) % 12 - cc.NATURAL_PC[maj_letter]) % 12
    if d not in (0, 1, 11):
        raise MidiError(
            "--key 的调式词 %r 本工具没定义参考音(关系大调算不出音名拼写): 请直接给参考音"
            "(如 --key %s), 或改用 --key <音名>:<maj|min>"
            % (word, cc.fifths_label(cc.major_fifths(tonic_pc))))
    if word not in ('minor', 'min', 'm', 'aeolian', 'aeo', 'dorian', 'dor',
                    'phrygian', 'phry', 'locrian', 'loc'):
        raise MidiError(
            "--key 的调式词 %r 本工具没定义参考音: 本侧只按“关系大调主音”定义了小调族; "
            "请直接给参考音(如 --key %s), 或改用 --key <音名>:<maj|min>"
            % (word, cc.fifths_label(cc.major_fifths(tonic_pc))))
    # 小调族: 参考音 = 主音上方小三度(= 关系大调主音)。与 key_from_tonic_midi(minor=True)
    # 同一口径 —— 实测两者给出的参考音 pc 完全相同(Am->C、Gm->Bb、Ebm->Gb)。
    ref = (tonic_pc + 3) % 12
    ref_label = cc.fifths_label(cc.major_fifths(ref))
    return ref_label, ('key_mode_expanded', '%s:%s -> 参考音 1=%s(小调 La-based; %s)'
                       % (bare, word, ref_label, '如只需要 1= 就写 --key ' + ref_label))


# ==========================================================================
# 一、标准 MIDI 文件解析(自己写, 不引第三方)
# 实测依据: 本机 `python -c "import mido"` 与 `import music21` 都 ImportError(2026-10-06),
# 而本仓库要的是"离线可复现、不添依赖"; SMF 的结构本身很小(MThd/MTrk + 变长时值 + 事件),
# 自己解析还能把"未闭合音符/重复 note-on"这些脏数据处理得明明白白。
# ==========================================================================
def _vlq(data, i):
    """变长时值(每字节 7 位, 最高位=还有后续)。"""
    v = 0
    n = 0
    while True:
        if i >= len(data):
            raise MidiError('变长时值越界')
        b = data[i]
        i += 1
        v = (v << 7) | (b & 0x7F)
        n += 1
        if not (b & 0x80):
            return v, i
        if n > 4:
            raise MidiError('变长时值超过 4 字节')


def _text(payload):
    for enc in ('utf-8', 'latin-1'):
        try:
            return payload.decode(enc)
        except UnicodeDecodeError:
            continue
    return payload.decode('latin-1', 'replace')


def parse_smf(data):
    """标准 MIDI 文件 -> {'format':…, 'division':…, 'tracks':[…]}

    每轨: {'index'(1 起), 'name', 'notes':[{onset,dur,pitch,ch,vel}], 'keysig':(sf,mi)|None,
           'timesig':(nn,dd)|None, 'texts':[…], 'channels':[…]}
    """
    if len(data) < 14 or data[:4] != b'MThd':
        raise MidiError('不是标准 MIDI 文件(缺 MThd)')
    hlen = struct.unpack('>I', data[4:8])[0]
    fmt, ntrk, division = struct.unpack('>HHH', data[8:14])
    if division & 0x8000:
        raise MidiError('SMPTE 时基(division=0x%04x)不支持: 没有"每四分音符多少 tick"' % division)
    if division == 0:
        raise MidiError('division=0 非法')
    pos = 8 + hlen
    tracks = []
    while pos + 8 <= len(data):
        cid = data[pos:pos + 4]
        clen = struct.unpack('>I', data[pos + 4:pos + 8])[0]
        body = data[pos + 8:pos + 8 + clen]
        pos += 8 + clen
        if cid != b'MTrk':
            continue
        tracks.append(_parse_track(body, len(tracks) + 1))
    if not tracks:
        raise MidiError('一个 MTrk 都没有')
    return {'format': fmt, 'division': division, 'ntrk': ntrk, 'tracks': tracks}


def _parse_track(d, index):
    tr = {'index': index, 'name': '', 'notes': [], 'keysig': None, 'timesig': None,
          'texts': [], 'channels': [], 'tick_end': 0}
    tick = 0
    i = 0
    status = None
    open_notes = {}                     # (ch, pitch) -> [[tick, vel], …] 同音重复 note-on 用队列
    n_unclosed = 0
    n_dup = 0
    while i < len(d):
        delta, i = _vlq(d, i)
        tick += delta
        if i >= len(d):
            break
        b = d[i]
        if b & 0x80:
            status = b
            i += 1
        elif status is None:
            raise MidiError('第 %d 轨: 一上来就是 running status, 非法' % index)
        if status == 0xFF:
            mtype = d[i]
            i += 1
            ln, i = _vlq(d, i)
            payload = d[i:i + ln]
            i += ln
            if mtype == 0x03 and not tr['name']:
                tr['name'] = _text(payload).strip()
            elif mtype == 0x59 and len(payload) >= 2:
                sf = payload[0] - 256 if payload[0] > 127 else payload[0]
                tr['keysig'] = (sf, payload[1])
            elif mtype == 0x58 and len(payload) >= 2:
                tr['timesig'] = (payload[0], 2 ** payload[1])
            elif mtype in (0x01, 0x02, 0x05, 0x06, 0x07):
                t = _text(payload).strip()
                if t:
                    tr['texts'].append(t)
            continue
        if status in (0xF0, 0xF7):      # sysex: 跳过
            ln, i = _vlq(d, i)
            i += ln
            continue
        hi = status & 0xF0
        ch = status & 0x0F
        if hi in (0x80, 0x90, 0xA0, 0xB0, 0xE0):
            if i + 1 >= len(d):
                break
            d1, d2 = d[i], d[i + 1]
            i += 2
        elif hi in (0xC0, 0xD0):
            d1, d2 = d[i], 0
            i += 1
        else:
            raise MidiError('第 %d 轨: 未知状态字节 0x%02x' % (index, status))
        if ch not in tr['channels']:
            tr['channels'].append(ch)
        if hi == 0x90 and d2 > 0:
            open_notes.setdefault((ch, d1), []).append([tick, d2])
        elif hi in (0x80, 0x90):
            q = open_notes.get((ch, d1))
            if not q:
                continue                    # 没有对应 note-on 的 note-off: 忽略(脏数据)
            if len(q) > 1:
                n_dup += 1
            on, vel = q.pop(0)
            tr['notes'].append({'onset': on, 'dur': max(0, tick - on), 'pitch': d1,
                                'ch': ch, 'vel': vel})
    for (ch, pitch), q in open_notes.items():
        for on, vel in q:
            n_unclosed += 1
            tr['notes'].append({'onset': on, 'dur': max(0, tick - on), 'pitch': pitch,
                                'ch': ch, 'vel': vel})
    tr['tick_end'] = tick
    tr['n_unclosed'] = n_unclosed
    tr['n_dup_on'] = n_dup
    tr['notes'].sort(key=lambda n: (n['onset'], n['pitch']))
    return tr


# ==========================================================================
# 二、选主旋律(策略 + 依据)
# ==========================================================================
def _mono_ratio(notes):
    """同时发声率 = 1 - (与已响音符重叠的 note-on 占比)。1.0 = 完全单声部。"""
    if not notes:
        return 0.0
    by_on = sorted(notes, key=lambda n: n['onset'])
    ends = []
    overlap = 0
    for n in by_on:
        if any(e > n['onset'] for e in ends):
            overlap += 1
        ends = [e for e in ends if e > n['onset']]
        ends.append(n['onset'] + n['dur'])
    return 1.0 - overlap / float(len(by_on))


def candidates_of(smf):
    """-> [候选 …]; 候选 = 一个可当主旋律的声部。

    分法(实测需要): format 1/2 的每个 MTrk 是一个候选; **format 0** 常见"全塞在一轨里、
    靠通道分开", 所以那一轨按**通道**再拆 —— 否则钢琴伴奏会和主旋律混成一片和弦。
    """
    out = []
    for tr in smf['tracks']:
        chs = [c for c in tr['channels'] if any(n['ch'] == c for n in tr['notes'])]
        if not tr['notes']:
            continue
        if len(chs) <= 1:
            out.append(_mk_cand(tr, None, tr['notes'], tr))
        else:
            for c in chs:
                ns = [n for n in tr['notes'] if n['ch'] == c]
                out.append(_mk_cand(tr, c, ns, tr))
    return out


def _mk_cand(tr, ch, notes, meta_tr):
    pitches = [n['pitch'] for n in notes]
    return {
        'track': tr['index'], 'channel': ch, 'name': tr['name'],
        'notes': notes, 'n_notes': len(notes),
        'mean_pitch': (sum(pitches) / float(len(pitches))) if pitches else 0.0,
        'mono': _mono_ratio(notes), 'keysig': meta_tr.get('keysig'),
        'timesig': meta_tr.get('timesig'), 'texts': meta_tr.get('texts') or [],
        'n_unclosed': tr.get('n_unclosed', 0), 'n_dup_on': tr.get('n_dup_on', 0),
    }


def pick_melody(cands, policy='auto'):
    """-> (候选, 说法字符串, 需要记账的 flag 列表)。选不出来就抛 MidiError(不硬猜)。"""
    if not cands:
        raise MidiError('这份 MIDI 里一个音符都没有')
    p = (policy or 'auto').strip()
    flags = []
    if p == 'auto':
        named = [c for c in cands if c['name'] and MELODY_NAMES.search(c['name'])]
        if named:
            return named[0], 'name:%s' % named[0]['name'], flags
        pure = [c for c in cands if c['mono'] >= 1.0 - 1e-9]
        pool = pure or cands
        if not pure:
            flags.append('melody_ambiguous')
        best = max(pool, key=lambda c: (c['mean_pitch'], c['n_notes'], -c['track']))
        return best, ('mono+高音区' if pure else '无单声部轨 -> 平均音高最高(记账)'), flags
    if p == 'top':
        return max(cands, key=lambda c: c['mean_pitch']), 'top:平均音高最高(启发式)', flags
    if p == 'most':
        return max(cands, key=lambda c: c['n_notes']), 'most:音数最多(启发式)', flags
    if p == 'all':
        merged = []
        for c in cands:
            merged.extend(c['notes'])
        base = dict(cands[0])
        base = dict(base, notes=merged, n_notes=len(merged), channel=None, name='+'.join(
            x['name'] or ('trk%d' % x['track']) for x in cands))
        flags.append('melody_merged')
        return base, 'all:合并全部候选(记账)', flags
    if p.isdigit():
        want = int(p)
        hit = [c for c in cands if c['track'] == want]
        if not hit:
            raise MidiError('没有第 %d 轨(候选轨道: %s)'
                            % (want, sorted({c['track'] for c in cands})))
        if len(hit) == 1:
            return hit[0], 'track:%d' % want, flags
        merged = []
        for c in hit:
            merged.extend(c['notes'])
        flags.append('melody_merged')
        return dict(hit[0], notes=merged, n_notes=len(merged), channel=None,
                    name=hit[0]['name']), 'track:%d(该轨 %d 个通道合并)' % (want, len(hit)), flags
    if p.lower().startswith('name:'):
        sub = p.split(':', 1)[1]
        hit = [c for c in cands if sub.lower() in (c['name'] or '').lower()]
        if not hit:
            raise MidiError('没有轨道名含 %r 的(轨道名: %s)'
                            % (sub, [c['name'] for c in cands]))
        return hit[0], 'name:%s' % hit[0]['name'], flags
    raise MidiError('未知 --melody 策略: %r(auto/N/name:SUB/top/most/all)' % policy)


# ==========================================================================
# 三、调号 / 调式
# ==========================================================================
# Krumhansl-Schmuckler 音级分布权重(Krumhansl 1990, 认知实验得到的稳定profile)。
# 用途: MIDI 里**没有**调号 meta 时, 按"实际响了多久 + 落在哪个音级"推断调式。
KS_MAJOR = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
KS_MINOR = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]


def _corr(a, b):
    n = len(a)
    ma, mb = sum(a) / n, sum(b) / n
    num = sum((a[i] - ma) * (b[i] - mb) for i in range(n))
    da = sum((x - ma) ** 2 for x in a) ** 0.5
    db = sum((x - mb) ** 2 for x in b) ** 0.5
    return num / (da * db) if da * db else 0.0


def infer_key(notes):
    """音级分布(按时值加权) -> (主音 pc, 是否小调, 相关系数)。

    ⚠ 这是**启发式**(Krumhansl-Schmuckler 相关), 所以调用方必须记 `key_inferred`;
      有 `FF 59` 调号 meta 时**不走这里**(那是源里写死的)。
    """
    w = [0.0] * 12
    for n in notes:
        w[n['pitch'] % 12] += max(1, n['dur'])
    best = (-2.0, 0, False)
    for pc in range(12):
        maj = [w[(pc + i) % 12] for i in range(12)]
        cm = _corr(maj, KS_MAJOR)
        mino = [w[(pc + i) % 12] for i in range(12)]
        cn = _corr(mino, KS_MINOR)
        if cm > best[0]:
            best = (cm, pc, False)
        if cn > best[0]:
            best = (cn, pc, True)
    return best[1], best[2], best[0]


def key_from_smf(keysig, notes, forced=None, spell='degree'):
    """-> (Key, 说法, flag 列表)。

    `keysig=(sf, mi)`: sf 是五度圈数(带符号), mi=1 表示小调 —— 这是 MIDI 标准写法, 直接用。
    """
    flags = []
    if forced:
        k = cc.parse_key(forced)
        how = 'cli:%s' % forced
        flags.append('key_forced')
    elif keysig is not None:
        sf, mi = keysig
        pc = (sf * 7) % 12
        minor = bool(mi)
        if minor:
            pc = (pc + 9) % 12               # sf 说的是关系大调
        tonic = _nearest_octave(pc, notes)
        k = cc.key_from_tonic_midi(tonic, minor)
        how = 'meta:sf=%+d mi=%d' % (sf, mi)
    else:
        pc, minor, r = infer_key(notes)
        tonic = _nearest_octave(pc, notes)
        k = cc.key_from_tonic_midi(tonic, minor)
        how = 'inferred:K-S r=%.3f' % r
        flags.append('key_inferred')
    # 参考音锚到旋律的中位音高附近(归一之前先放到中间, 免得一上来就一堆八度记号)
    k = _reanchor(k, notes)
    return k, how, flags


def _nearest_octave(pc, notes):
    """主音 pc -> 离旋律(按时值加权)中位音高最近的那个同音级音高的 MIDI 号。"""
    if not notes:
        return pc + 60
    ps = sorted(n['pitch'] for n in notes for _ in range(max(1, min(4, n['dur'] // 8))))
    mid = ps[len(ps) // 2]
    return pc + 12 * round((mid - pc) / 12.0)


def _reanchor(key, notes):
    """把 `1=`(参考音)整体挪到离旋律中位音高最近的那个八度(只挪八度, 不动调号/拼写)。"""
    if not notes:
        return key
    ps = sorted(n['pitch'] for n in notes)
    mid = ps[len(ps) // 2]
    target = mid + (3 if key.la_based else 0)
    shift = round((target - key.ref_midi) / 12.0)
    if shift == 0:
        return key
    k = cc.Key(key.li, key.acc, key.mode, key.sig, key.nsig, key.ref_letter, key.ref_acc,
               key.ref_reg + int(shift), la_based=key.la_based)
    return k


# ==========================================================================
# 四、事件流 -> 简谱 token
# ==========================================================================
def _group_by_onset(notes, tol):
    """按起音分组(同一时刻 = 一个和弦)。tol = 允许的 tick 抖动(0 = 严格同刻)。"""
    groups = []
    for n in sorted(notes, key=lambda n: (n['onset'], n['pitch'])):
        if groups and n['onset'] - groups[-1]['onset'] <= tol:
            groups[-1]['notes'].append(n)
        else:
            groups.append({'onset': n['onset'], 'notes': [n]})
    return groups


def _rough_parts(q, r, flags):
    """时值 -> 分量; 表示不出来时按**与 ABC 侧同一档**近似, 绝不因为"写不下"就丢音。

    实测(2026-10-06, 真素材): 本仓库 train-data-*/pdf 里的真 `.mid` 里有一批 note_on/note_off
    落在**同一个 tick**(dur=0, 是"原子"夹具/点击音) —— 那时 `q <= 0`, 简谱没有任何 token 能记
    "零时值"。处理: 用最短的 `h`(1/16 拍)记下来 + 记 `note_too_short` + `dur_approx`;
    若因为"时长写不下"而把音丢掉, 就正好踩中本项目最怕的"静默丢音"(自检里那条"音数不符"
    就是抓这个的)。
    """
    parts, exact = cc.duration_parts(q)
    if exact and parts:
        return parts, True
    r.dur_approx += 1
    if q <= 0:
        flags.append('note_too_short')
        return [('h', 0, 0.0625, True)], False
    letter = '' if q >= 1.0 else 'q'
    return [(letter, 0, 1.0 if q >= 1.0 else 0.5, True)], False


def _head_token(letter, dots, inner):
    """音头 token = 时值字母 + 音高写法 + 附点(**附点必须在音级后面**)。"""
    return letter + inner + '.' * dots


def render(cand, key, ppq, meter_quarters, r, flags, spell='degree', chord_tol=0,
           quantize=0, bars=True):
    """候选声部 -> token 列表(写进 r.tokens), 顺带记账。

    时间口径: tick -> 四分音符 = tick / ppq。**每个起音组一个 token**;
    组内多个音 = 和弦 token(与 ABC 侧同一种写法); 组间空隙 = 休止 `0`。
    重叠(单声部 legato)按"下一个起音"截断并记 `overlap_trimmed` —— 简谱一行记不下重叠。
    小节线按拍号**插在时值分量之间**: 一个音跨两小节时, `|` 落在它的延长记号中间。
    """
    notes = [dict(n) for n in cand['notes']]
    if quantize:
        grid = ppq / float(quantize)
        for n in notes:
            n['onset'] = int(round(n['onset'] / grid)) * grid
            n['dur'] = max(grid, int(round(n['dur'] / grid)) * grid)
        flags.append('quantized')
    groups = _group_by_onset(notes, chord_tol)
    ticks = [t['onset'] for t in groups]
    if ticks and ticks[0] > 0:
        # 前导静音: 常见的"起唱前的空白", 不是谱面上的休止 -> 丢掉但记账(绝不静默)
        flags.append('leading_silence')
        r.leading_silence = ticks[0] / float(ppq)
    toks = []
    bar = [0.0]                      # 可变的小节累计(用 list 让内层函数能改)

    def _push(tok, beats):
        toks.append(tok)
        bar[0] += beats
        while bars and bar[0] >= meter_quarters - 1e-9:
            toks.append('|')
            bar[0] -= meter_quarters

    n_overlap = 0
    for gi, g in enumerate(groups):
        nxt = ticks[gi + 1] if gi + 1 < len(ticks) else None
        end = max(n['onset'] + n['dur'] for n in g['notes'])
        if nxt is not None and end > nxt:
            end = nxt
            n_overlap += 1
        gap = (nxt - end) if nxt is not None else 0
        q = (end - g['onset']) / float(ppq)
        # ---- 音 / 和弦(先出音, 空隙是它**后面**的休止) ----
        figs = [cc.spell_midi(n['pitch'], key, spell) for n in g['notes']]
        parts, _exact = _rough_parts(q, r, flags)
        letter, dots, hb, _head = parts[0]
        if len(figs) > 1:
            if len({n['dur'] for n in g['notes']}) > 1:
                flags.append('chord_mixed_len')         # 和弦只有一个时值 -> 记账
            body = []
            for deg, delta, octn in figs:
                marks = ',' * (-octn) if octn < 0 else "'" * octn
                body.append(marks + ('#' if delta > 0 else ('b' if delta < 0 else ''))
                            + str(deg))
            # 和弦: 八度/变音写在**各自音级左边**(与语料 261611 个和弦 token 一致)
            _push(_head_token(letter, dots, ''.join(body)), hb)
            r.n_pitch_raw += len(figs)
            r.notes_total += len(figs)
            r.n_chord += 1
            r.n_chord_notes += len(figs)
        else:
            deg, delta, octn = figs[0]
            acc_s = '#' if delta > 0 else ('b' if delta < 0 else '')
            oct_pre = ',' * (-octn) if octn < 0 else ''
            oct_post = "'" * octn if octn > 0 else ''
            _push(_head_token(letter, dots, oct_pre + acc_s + str(deg) + oct_post), hb)
            r.n_pitch_raw += 1
            r.notes_total += 1
        for tok, _d, beats, _h in parts[1:]:
            _push(tok, beats)
        # ---- 休止(这个音与下一个起音之间的空隙): 不得静默丢 ----
        if gap > 0:
            r.n_rest_seen += 1
            rq = gap / float(ppq)
            rparts, _exact = _rough_parts(rq, r, flags)
            rletter, rdots, rhb, _h = rparts[0]
            _push(_head_token(rletter, rdots, '0'), rhb)
            for tok, _d, beats, _h in rparts[1:]:
                _push(tok, beats)
            r.n_rest_emitted += 1
    if n_overlap:
        flags.append('overlap_trimmed')
    if bars:
        flags.append('bars_synthesized')
    while toks and toks[-1] == '|':
        toks.pop()
    return toks


# ==========================================================================
# 五、单份 MIDI -> 结果
# ==========================================================================
class TuneResult(cc.TuneResult):
    """MIDI 侧的转换结果: 公共字段在 convert_common, 这里加 MIDI 特有的记账。"""

    def __init__(self):
        cc.TuneResult.__init__(self)
        self.key_label = ''
        self.key_1 = ''
        self.key_sig_text = ''
        self.la_based = False
        self.meter = ''
        self.meter_quarters = 4.0
        self.title = ''
        self.source_id = ''
        self.midi_path = ''
        self.ppq = 0
        self.n_tracks = 0
        self.n_candidates = 0
        self.melody = ''
        self.melody_why = ''
        self.key_how = ''
        self.spell = 'degree'
        self.leading_silence = 0.0
        self.n_notes_src = 0
        self.track_name = ''
        self.key_arg_raw = ''            # `--key` 原样(用户写的)
        self.key_arg = ''                # 展开成"参考音"之后真正交给 parse_key 的

    def to_dict(self, name=''):
        return {
            'name': name,
            'title': self.title,
            'source': self.source_id,
            'midi': self.midi_path,
            'key': self.key_label,
            'key_1': self.key_1,
            'la_based': self.la_based,
            'key_signature': self.key_sig_text,
            'key_how': self.key_how,
            'meter': self.meter,
            'ppq': self.ppq,
            'n_tracks': self.n_tracks,
            'n_candidates': self.n_candidates,
            'melody': self.melody,
            'melody_why': self.melody_why,
            'track_name': self.track_name,
            'spell': self.spell,
            'ok': self.ok,
            'clean': self.clean,
            'pitch_safe': self.pitch_safe,
            'lossy_kinds': self.lossy,
            'dur_lossy_kinds': self.dur_lossy,
            'errors': self.errors,
            'unsupported': self.unsupported,
            'n_notes_src': self.n_notes_src,
            'n_pitch_raw': self.n_pitch_raw,
            'n_pitch': self.n_pitch,
            'n_rest_seen': self.n_rest_seen,
            'n_rest_emitted': self.n_rest_emitted,
            'n_dur_approx': self.dur_approx,
            'leading_silence': self.leading_silence,
            'n_chord': self.n_chord,
            'n_chord_notes': self.n_chord_notes,
            'oct_shift': self.oct_shift,
            'oct_marks_before': self.oct_marks_before,
            'oct_marks_after': self.oct_marks_after,
            'score': ' '.join(self.tokens),
        }


def convert_midi_bytes(data, name='', melody='auto', key=None, spell='degree',
                       quantize=0, chord_tol=0, bars=True, title=None,
                       midi_path='', normalize=True, time_sig=None):
    """一份 MIDI(bytes) -> TuneResult。"""
    r = TuneResult()
    r.midi_path = midi_path or name
    smf = parse_smf(data)
    r.ppq = smf['division']
    r.n_tracks = len(smf['tracks'])
    r.title = title or os.path.splitext(os.path.basename(name or midi_path or 'midi'))[0]
    cands = candidates_of(smf)
    r.n_candidates = len(cands)
    cand, why, flags = pick_melody(cands, melody)
    r.melody = ('track%d' % cand['track']) + ('' if cand['channel'] is None
                                              else ':ch%d' % cand['channel'])
    r.melody_why = why
    r.track_name = cand['name'] or ''
    r.spell = spell
    r.n_notes_src = cand['n_notes']
    if cand['n_unclosed']:
        flags.append('unclosed_note')
    if cand['n_dup_on']:
        flags.append('duplicate_note_on')
    for t in cand['texts']:
        if JUMP_NAMES.search(t):
            r.flag('jump_mark', t)
    keysig = cand['keysig'] or (smf['tracks'][0].get('keysig') if smf['tracks'] else None)
    key_arg, key_note = resolve_key_arg(key)
    r.key_arg_raw = key or ''
    r.key_arg = key_arg or ''
    k, how, kflags = key_from_smf(keysig, cand['notes'], forced=key_arg, spell=spell)
    if key_note:
        r.flag(key_note[0], key_note[1])
    flags.extend(kflags)
    r.key = k
    r.key_label = k.label
    r.key_1 = k.ref_label
    r.key_sig_text = k.sig_text
    r.la_based = k.la_based
    r.key_how = how
    ts = cand['timesig'] or (smf['tracks'][0].get('timesig') if smf['tracks'] else None)
    if time_sig:
        m = re.match(r'^(\d+)\s*/\s*(\d+)$', time_sig.strip())
        if not m:
            raise MidiError('--time-sig 要写成 4/4 这样')
        ts = (int(m.group(1)), int(m.group(2)))
    if ts:
        r.meter = '%d/%d' % (ts[0], ts[1])
        r.meter_quarters = 4.0 * ts[0] / float(ts[1])
    else:
        r.meter = ''                      # 源里没写 -> 由 corpus_text 写默认 4/4 并注明
        r.meter_quarters = 4.0
        flags.append('no_meter')
    r.tokens = render(cand, k, smf['division'], r.meter_quarters, r, flags, spell=spell,
                      chord_tol=chord_tol, quantize=quantize, bars=bars)
    for f in flags:
        r.flag(f)
    # 零丢失自检 + 八度归一(与 ABC 侧**同一份实现**)
    r.n_pitch = sum(cc.token_note_count(t) for t in r.tokens)
    n_rest_tok = cc.count_rest_tokens(r.tokens)
    if r.n_rest_emitted != n_rest_tok:
        r.errors.append('休止数不符: 输出 %d, token 里 %d(静默丢音!)'
                        % (r.n_rest_emitted, n_rest_tok))
    if r.n_pitch != r.n_pitch_raw:
        r.errors.append('音数不符: 事件 %d, token 里 %d(静默丢音!)'
                        % (r.n_pitch_raw, r.n_pitch))
    if r.errors:
        r.tokens = []
        return r
    cc.check_no_note_loss(r, r.n_pitch, normalize=normalize)
    return r


def convert_midi_file(path, **kw):
    with open(path, 'rb') as f:
        data = f.read()
    kw.setdefault('midi_path', path)
    return convert_midi_bytes(data, name=os.path.basename(path), **kw)


# ==========================================================================
# 六、语料形态(与 ABC 侧同一份排版, 只有"记账注释"换成 MIDI 的)
# ==========================================================================
def corpus_text(res, name, source, midi_ref, transcriber=ABOUT_TRANSCRIBER,
                default_meter='4/4'):
    """一首 -> 语料形态文本(`%--` 之后是正文); 头部字段/折行都在 `convert_common.corpus_text`。

    `link=` **不写**: 作者给的头部清单里没有它, 而 README 口径是"必须人工核对过的收录页"
    —— MIDI 文件路径不是收录页。来源信息放在 `%` 注释行里。
    """
    comments = ['%%1=%s  原调=%s  调号=%s  拍号=%s  音数=%d  调号来源=%s  La-based=%s'
                % (res.key_1, res.key_label, res.key_sig_text, res.meter or '(未给)',
                   res.n_pitch, res.key_how, '是' if res.la_based else '否'),
                '%%八度归一=%+d  八度记号 %d->%d  和弦 %d 个(%d 音)'
                % (res.oct_shift, res.oct_marks_before, res.oct_marks_after,
                   res.n_chord, res.n_chord_notes),
                '%%选轨=%s(%s)  轨道名=%s  源音符=%d  PPQ=%d  %d 轨/%d 候选  拼写=%s'
                % (res.melody, res.melody_why, res.track_name or '(无)', res.n_notes_src,
                   res.ppq, res.n_tracks, res.n_candidates, res.spell)]
    if res.leading_silence:
        comments.append('%%前导静音=%.3f 拍(未写成休止: 它不是谱面上的休止)'
                        % res.leading_silence)
    # 只在 `--key` 写了**调式词**时多一条: 那时的"调号来源"必须写清它被展开成了哪个参考音
    # (否则日后看到 `1=Gb` 无法知道用户写的是 `--key Eb:min`)。裸音名的既有输出**逐字节不变**。
    if res.key_arg_raw and res.key_arg and res.key_arg_raw != res.key_arg:
        comments.append('%%--key=%s 按"主音+调式"展开成参考音 1=%s(小调 La-based)'
                        % (res.key_arg_raw, res.key_arg))
    if midi_ref:
        comments.append('%MIDI 文件=' + midi_ref)
    return cc.corpus_text(title=res.title or name, source=source, name=name,
                          comments=comments, meter=res.meter or None,
                          default_meter=default_meter, link='',
                          status='converted', transcriber=transcriber,
                          tokens=res.tokens)


def repo_ref_of(path):
    """MIDI 文件 -> source 里那个"仓库路径"。

    口径与 ABC 侧一致(`source = <站点token>-<sha1(仓库路径 + '#' + 序号)[:12]>`), 但 MIDI 的
    "文件内序号"取**选中的轨道号**(1 起): 同一份 MIDI 换一条轨就应当是不同的 source, 否则
    "同一文件的另一条旋律"会在库里撞成同一首。清单里写了仓库相对路径就用它, 否则用绝对路径。
    """
    return path.replace('\\', '/')


# ==========================================================================
# 七、自检(合成用例; 每个 token 过 jptok 白名单 + score.py 真解析)
# ==========================================================================
def build_smf(tracks, ppq=480, fmt=1):
    """自检用的最小 SMF 生成器(**只服务自检**, 不参与正式转换)。

    tracks: [ {'name': 'MELODY', 'channel': 0, 'notes': [(onset_tick, dur_tick, pitch), …],
               'keysig': (sf, mi) 或 None, 'timesig': (nn, dd) 或 None, 'texts':[..]} ]
    """
    out = [struct.pack('>4sIHHH', b'MThd', 6, fmt, len(tracks), ppq)]
    for t in tracks:
        evs = []
        if t.get('name'):
            b = t['name'].encode('utf-8')
            evs.append((0, b'\xff\x03' + _vlqb(len(b)) + b))
        if t.get('texts'):
            for s in t['texts']:
                b = s.encode('utf-8')
                evs.append((0, b'\xff\x01' + _vlqb(len(b)) + b))
        if t.get('timesig'):
            nn, dd = t['timesig']
            evs.append((0, bytes([0xFF, 0x58, 0x04, nn, dd.bit_length() - 1, 24, 8])))
        if t.get('keysig'):
            sf, mi = t['keysig']
            evs.append((0, bytes([0xFF, 0x59, 0x02, sf & 0xFF, mi])))
        ch = t.get('channel', 0)
        for (on, dur, pitch) in t.get('notes', []):
            evs.append((on, bytes([0x90 | ch, pitch, 100])))
            if not t.get('drop_off'):
                evs.append((on + max(1, dur), bytes([0x80 | ch, pitch, 0])))
        evs.append((max([e[0] for e in evs] + [0]) if evs else 0, b'\xff\x2f\x00'))
        evs.sort(key=lambda x: x[0])
        body = b''
        prev = 0
        status = None
        for tick, ev in evs:
            body += _vlqb(tick - prev)
            prev = tick
            if ev[0] != 0xFF and status == ev[0]:
                body += ev[1:]                       # running status
            else:
                body += ev
                status = ev[0] if ev[0] != 0xFF else None
        out.append(struct.pack('>4sI', b'MTrk', len(body)) + body)
    return b''.join(out)


def _vlqb(v):
    out = bytearray([v & 0x7F])
    v >>= 7
    while v:
        out.insert(0, 0x80 | (v & 0x7F))
        v >>= 7
    return bytes(out)


def _notes(seq, dur=480):
    """[(pitch, 起点 tick), …] -> [(onset, dur, pitch), …]"""
    return [(on, dur, p) for (p, on) in seq]


def _canon_marks(tok):
    """把"正八度记号写在数字**前面**"的写法规范成写在后面 —— 只为了让自检好读。

    实测: 八度归一(`convert_common.shift_token_octave`)对**原本一个记号都没有**的音, 会把
    正记号写在数字前面(`1` -> `'1`)。这是既有 492 首 ABC 产物的形态(我改过一次, 真素材回归
    立刻从 492/492 掉到 485/492, 于是改回), 两个转换器共用同一份实现; `jptok` 两种都认。
    """
    m = re.match(r"^([cqsdh]*)([',]+)([#b]?)([1-7])([',]*)([.]*)$", tok or '')
    if not m:
        return tok
    pre, acc, dig, post, dots = m.group(2), m.group(3), m.group(4), m.group(5), m.group(6)
    k = cc.fig_oct(pre) + cc.fig_oct(post)
    marks = ',' * (-k) if k < 0 else "'" * k
    if k < 0:
        return m.group(1) + marks + acc + dig + dots     # 负八度: 记号写前
    return m.group(1) + acc + dig + marks + dots         # 正八度: 记号写后


def _sounding(res):
    """发声 token(记号位置规范化) —— 自检里比音高/音级用。"""
    return [_canon_marks(t) for t in res.tokens if cc.token_figures(t)]


def run_selftest(verbose=True):
    cases = []

    def chk(name, cond, detail=''):
        cases.append((name, bool(cond), detail))

    def conv(tracks, **kw):
        return convert_midi_bytes(build_smf(tracks, ppq=kw.pop('ppq', 480)), name='t.mid', **kw)

    # ---- ① 单音: C 大调音阶, 调号 meta 说明是 C 大调 ----
    C_MAJ = (0, 0)
    r = conv([{'keysig': C_MAJ, 'timesig': (4, 4), 'notes':
               _notes([(60, 0), (62, 480), (64, 960), (65, 1440), (67, 1920), (69, 2400),
                       (71, 2880), (72, 3360)])}])
    chk('① 单音: C 大调音阶 -> 1 2 3 4 5 6 7 1\'',
        _sounding(r) == ['1', '2', '3', '4', '5', '6', '7', "1'"],
        'out=%r errors=%r' % (r.tokens, r.errors))
    chk('① 调号来自 MIDI 的 FF 59 meta(不是猜的)',
        r.key_how.startswith('meta:') and 'key_inferred' not in r.unsupported,
        'how=%s' % r.key_how)

    # ---- ② 和弦: 三个音同刻 -> 一个和弦 token, 不摊平不丢音 ----
    r = conv([{'keysig': C_MAJ, 'notes': [(0, 480, 60), (0, 480, 64), (0, 480, 67)]}])
    chk('② 和弦: [C E G] 同刻 -> 一个和弦 token `135`',
        _sounding(r) == ['135'] and r.n_chord == 1 and r.n_chord_notes == 3,
        'out=%r n_chord=%d' % (r.tokens, r.n_chord))
    r = conv([{'keysig': C_MAJ, 'notes': [(0, 480, 48), (0, 480, 60), (0, 480, 64),
                                          (0, 480, 67)]}])
    chk('② 和弦带八度: 记号写在各自音级左边 -> `,1` + `1` + `3` + `5`',
        _sounding(r) == [",1135"], 'out=%r' % (r.tokens,))

    # ---- ③ 休止: 中间空一拍 -> 出 `0`, 且"见到 = 输出" ----
    r = conv([{'keysig': C_MAJ, 'notes': [(0, 480, 60), (960, 480, 62)]}])
    chk('③ 休止: 中间的 1 拍空隙写成 `0`(不静默丢)',
        [t for t in r.tokens if t != '|'] == ['1', '0', '2']
        and r.n_rest_seen == 1 and r.n_rest_emitted == 1,
        'out=%r %d/%d' % (r.tokens, r.n_rest_seen, r.n_rest_emitted))
    r = conv([{'keysig': C_MAJ, 'notes': [(480, 240, 60), (960, 240, 62)]}])
    chk('③ 前导静音: 丢掉但记 `leading_silence`(绝不静默)',
        'leading_silence' in r.unsupported and r.leading_silence > 0,
        'flags=%r' % (sorted(r.unsupported),))
    chk('③ MIDI 没有念白语义 -> 只出 `0`, 一个 `x` 都不出',
        not any('x' in t for t in r.tokens), 'out=%r' % (r.tokens,))

    # ---- ④ 变音: 半音槽拼写(实测口径: #1 b3 #4 b6 b7) ----
    r = conv([{'keysig': C_MAJ, 'notes': _notes([(60, 0), (66, 480), (63, 960), (70, 1440),
                                                 (68, 1920), (61, 2400)])}])
    chk('④ 变音: C 大调里的 F#/bE/bB/bA/C# -> #4 b3 b7 b6 #1',
        _sounding(r) == ['1', '#4', 'b3', 'b7', 'b6', '#1'],
        'out=%r' % (_sounding(r),))
    r = conv([{'keysig': (1, 0), 'notes': _notes([(67, 0), (65, 480)])}])       # G 大调: G F自然
    chk('④ 调号内音级不带变音; K:G 的 F 自然 -> `,b7`(与 ABC 侧同一格)',
        _sounding(r) == ['1', ',b7'], 'out=%r' % (_sounding(r),))

    # ---- ⑤ 升降八度 + 八度归一 ----
    r = conv([{'keysig': C_MAJ, 'notes': _notes([(84, 0), (86, 480), (88, 960), (89, 1440),
                                                 (91, 1920), (93, 2400), (95, 2880),
                                                 (96, 3360)])}])
    chk('⑤ 高八度: 归一后 `,`+`\'` 不增(实测 %d -> %d), 音级序列仍是 1..1\''
        % (r.oct_marks_before, r.oct_marks_after),
        r.oct_marks_after <= r.oct_marks_before
        and _sounding(r) == ['1', '2', '3', '4', '5', '6', '7', "1'"],
        'shift=%+d %d->%d out=%r' % (r.oct_shift, r.oct_marks_before, r.oct_marks_after,
                                     r.tokens))
    r = conv([{'keysig': C_MAJ, 'notes': _notes([(36, 0), (38, 480), (40, 960), (41, 1440)])}])
    chk('⑤ 低八度: 归一后记号不增(实测 %d -> %d), 音级序列 = 1 2 3 4'
        % (r.oct_marks_before, r.oct_marks_after),
        r.oct_marks_after <= r.oct_marks_before and _sounding(r) == ['1', '2', '3', '4'],
        'shift=%+d %d->%d out=%r' % (r.oct_shift, r.oct_marks_before, r.oct_marks_after,
                                     r.tokens))

    # ---- ⑥ 不同调号 / 小调 La-based ----
    for sf, body, want in (
            (1, [(67, 0), (69, 480), (71, 960), (72, 1440)], ['1', '2', '3', '4']),   # G 大调
            (-1, [(65, 0), (67, 480), (69, 960), (70, 1440)], ['1', '2', '3', '4']),  # F 大调
            (-2, [(70, 0), (72, 480), (74, 960), (75, 1440)], ['1', '2', '3', '4'])):  # Bb 大调
        r = conv([{'keysig': (sf, 0), 'notes': _notes(body)}])
        chk('⑥ 调号 sf=%+d: 主音是 `1`(Do-based), 音阶 1 2 3 4' % sf,
            _sounding(r) == want and r.la_based is False,
            'out=%r 1=%s' % (_sounding(r), r.key_1))
    r = conv([{'keysig': (0, 1), 'notes': _notes([(69, 0), (71, 480), (72, 960), (74, 1440),
                                                  (76, 1920), (77, 2400), (79, 2880),
                                                  (81, 3360)])}])
    chk('⑥ 小调(mi=1): A 自然小调 -> ,6 ,7 1 2 3 4 5 6(La-based, 主音 `,6`)',
        _sounding(r) == [',6', ',7', '1', '2', '3', '4', '5', '6'] and r.la_based,
        'out=%r 1=%s' % (_sounding(r), r.key_1))
    r = conv([{'keysig': (-5, 1), 'notes': _notes([(58, 0), (60, 480), (61, 960), (63, 1440),
                                                   (65, 1920), (66, 2400), (68, 2880),
                                                   (70, 3360)])}])           # bB 自然小调
    chk('⑥ 小调 sf=-5(mi=1) -> bB 自然小调 = ,6 ,7 1 2 3 4 5 6(La-based, 1=bD)',
        _sounding(r) == [',6', ',7', '1', '2', '3', '4', '5', '6'] and r.la_based
        and r.key_1 == 'Db',
        'out=%r 1=%s' % (_sounding(r), r.key_1))

    # ---- ⑦ 多轨选轨策略(POP909 三轨布局: MELODY/BRIDGE/PIANO) ----
    three = [
        {'name': 'PIANO', 'channel': 0, 'keysig': C_MAJ,
         'notes': [(0, 480, 48), (0, 480, 52), (0, 480, 55), (480, 480, 50), (480, 480, 53)]},
        {'name': 'MELODY', 'channel': 1, 'keysig': C_MAJ,
         'notes': _notes([(72, 0), (74, 480), (76, 960)])},
        {'name': 'BRIDGE', 'channel': 2, 'keysig': C_MAJ,
         'notes': _notes([(60, 0), (60, 480)])},
    ]
    r = conv(three)
    chk('⑦ auto: 按轨道名命中 MELODY(POP909 的 index.mid 就是 MELODY/BRIDGE/PIANO)',
        r.melody == 'track2' and r.track_name == 'MELODY'
        and _sounding(r) == ['1', '2', '3'],
        'melody=%s why=%s out=%r' % (r.melody, r.melody_why, _sounding(r)))
    r = conv(three, melody='2')
    chk('⑦ --melody 2: 指定第 2 轨(MELODY)', r.track_name == 'MELODY', r.track_name)
    r = conv(three, melody='name:PIANO')
    chk('⑦ --melody name:PIANO: 取名字命中的那一轨(它是和弦轨道, 于是出和弦 token)',
        r.track_name == 'PIANO' and r.n_chord >= 1, 'name=%s n_chord=%d'
        % (r.track_name, r.n_chord))
    unnamed = [
        {'channel': 0, 'keysig': C_MAJ, 'notes': [(48, 480, 55), (0, 480, 52), (0, 480, 48),
                                                  (480, 480, 50), (480, 480, 53)]},
        {'channel': 1, 'keysig': C_MAJ, 'notes': _notes([(72, 0), (74, 480), (76, 960)])},
    ]
    r = conv(unnamed)
    chk('⑦ auto 无命名时: 取单声部且平均音高最高的那一轨(依据: README"只记线性旋律")',
        r.melody == 'track2' and _sounding(r) == ['1', '2', '3'],
        'melody=%s why=%s out=%r' % (r.melody, r.melody_why, _sounding(r)))

    # ---- ⑧ format 0 单轨多通道 -> 按通道拆 ----
    one = {'keysig': C_MAJ,
           'notes': [(0, 480, 48), (0, 480, 52), (0, 480, 72), (480, 480, 74), (960, 480, 76)]}
    data = _build_format0(one['notes'], keysig=C_MAJ)
    r = convert_midi_bytes(data, name='f0.mid')
    chk('⑧ format 0(全塞一轨): 候选按通道拆, auto 选中单声部的高音通道',
        r.n_candidates >= 2 and r.melody.endswith('ch1') and _sounding(r) == ['1', '2', '3'],
        'cands=%d melody=%s out=%r' % (r.n_candidates, r.melody, _sounding(r)))

    # ---- ⑨ 没有调号 meta -> 推断或 --key 强制, 都不许静默 ----
    data = build_smf([{'timesig': (4, 4), 'notes':
                       _notes([(67, 0), (69, 480), (71, 960), (72, 1440), (74, 1920),
                               (76, 2400), (78, 2880), (79, 3360)])}])
    r = convert_midi_bytes(data, name='nokey.mid')
    chk('⑨ 无调号 meta: 走 K-S 推断并记 `key_inferred`(不静默当 C 大调)',
        'key_inferred' in r.unsupported and r.key_how.startswith('inferred'),
        'how=%s flags=%r' % (r.key_how, sorted(r.unsupported)))
    r = convert_midi_bytes(data, name='nokey.mid', key='G')
    chk('⑨ --key G: 强制调号(记 `key_forced`), 音阶读成 1 2 3 4 5 6 7 1\'',
        r.key_label == 'G' and 'key_forced' in r.unsupported
        and _sounding(r) == ['1', '2', '3', '4', '5', '6', '7', "1'"],
        'key=%s out=%r' % (r.key_label, _sounding(r)))
    r = convert_midi_bytes(data, name='nokey.mid', key='Em')
    chk('⑨ --key Em: La-based(1=G), 主音记 `,6`', r.la_based and r.key_1 == 'G',
        '1=%s la=%s' % (r.key_1, r.la_based))
    # ---- ⑨b `--key` 的调式写法(2026-10-07 定案): 收"参考音", 带调式词必须**解释**不许静默当大调 ----
    chk('⑨ `--key` 收的是参考音: --key Am 与 --key C 给同一个 1=(C), 音级序列全同',
        convert_midi_bytes(data, key='Am').tokens
        == convert_midi_bytes(data, key='C').tokens,
        'Am=%r C=%r' % (convert_midi_bytes(data, key='Am').tokens,
                        convert_midi_bytes(data, key='C').tokens))
    _min = convert_midi_bytes(data, name='nokey.mid', key='Eb:min')
    _ref = convert_midi_bytes(data, name='nokey.mid', key='Gb')
    chk('⑨ `--key Eb:min` 解释成"Eb 是主音的小调" -> 与 `--key Gb` 同一参考音, '
        '音级+八度逐 token 相同(绝不静默当大调 `1=Eb`)',
        _min.key_1 == 'Gb' and _min.key_1 == _ref.key_1
        and _min.tokens == _ref.tokens
        and any(k == 'key_mode_expanded' for k in _min.unsupported),
        'Eb:min 1=%s / Gb 1=%s; eb=%r gb=%r' % (_min.key_1, _ref.key_1,
                                                _min.tokens, _ref.tokens))
    chk('⑨ `--key Eb:min` 与 `--key Eb` 不是同一件事(前者按小调展开成 1=Gb, 后者 1=Eb)',
        _min.key_1 == 'Gb' and convert_midi_bytes(data, key='Eb').key_1 == 'Eb'
        and _min.tokens != convert_midi_bytes(data, key='Eb').tokens,
        'min 1=%s maj 1=%s' % (_min.key_1, convert_midi_bytes(data, key='Eb').key_1))
    try:
        convert_midi_bytes(data, key='Eb:lyd')
        _bad = ''
    except MidiError as e:
        _bad = str(e)
    chk('⑨ 未定义参考音的调式词(如 --key Eb:lyd)响亮报错, 不静默当大调',
        bool(_bad) and '--key' in _bad, 'err=%r' % _bad)

    # ---- ⑩ 小节线按拍号合成; 总音数/休止数零丢失 ----
    r = conv([{'keysig': C_MAJ, 'timesig': (3, 4), 'notes':
               _notes([(60, 0), (62, 480), (64, 960), (65, 1440), (67, 1920), (69, 2400)])}])
    chk('⑩ 小节线按拍号(3/4)合成: 6 拍 -> 1 条 `|`',
        r.tokens.count('|') == 1 and r.tokens[-1] != '|', 'out=%r' % (r.tokens,))
    chk('⑩ 零丢失: 源 %d 音 = token 里 %d 音; 休止 %d/%d'
        % (r.n_notes_src, sum(cc.token_note_count(t) for t in r.tokens),
           r.n_rest_seen, r.n_rest_emitted),
        sum(cc.token_note_count(t) for t in r.tokens) == r.n_notes_src
        and r.n_rest_seen == r.n_rest_emitted, '')

    # ---- ⑪ 脏数据不静默: 未闭合音符 / 跳转文本 ----
    data = build_smf([{'keysig': C_MAJ, 'notes': [(0, 480, 60), (480, 480, 62)], 'drop_off': True}])
    r = convert_midi_bytes(data, name='nooff.mid')
    chk('⑪ 未闭合音符(没等到 note-off): 按轨尾收尾并记 `unclosed_note`, 不静默丢',
        'unclosed_note' in r.unsupported and r.n_notes_src == 2,
        'flags=%r n=%d' % (sorted(r.unsupported), r.n_notes_src))
    r = conv([{'keysig': C_MAJ, 'texts': ['D.C. al Fine'], 'notes': _notes([(60, 0), (62, 480)])}])
    chk('⑪ 文本里的跳转记号(D.C./Fine)判为结构性, 不当普通注释放过',
        'jump_mark' in r.lossy, 'lossy=%r' % (r.lossy,))

    # ---- ⑫ 与平台唯一实现对齐(jptok 白名单 + score.py 真解析) ----
    r = conv([{'keysig': (0, 1), 'timesig': (4, 4), 'notes':
               [(0, 480, 69), (0, 480, 72), (480, 480, 71), (960, 480, 74), (1440, 960, 76),
                (2400, 480, 48), (2880, 480, 77)]}])
    sid = cc.make_source(SITE_TOKEN, repo_ref_of('x/y.mid'), 1)
    txt = corpus_text(r, 'selftest.mid', sid, 'x/y.mid')
    problems = cc.score_check(txt, r.tokens, tag='midi_selftest')
    chk('⑫ 每个 token 过 jptok 白名单, 且 jianpu-db/score.py 能原样解析回来',
        not problems, '; '.join(problems))
    chk('⑫ 语料头部: status=converted / transcriber=midi2jianpu / source 形状合规',
        'status=converted\n' in txt and 'transcriber=midi2jianpu\n' in txt
        and cc.SRC_RE.match(sid) is not None, 'source=%r' % sid)
    chk('⑫ 正文里没有反复记号(一律展开: MIDI 侧本来就没有, 这条防回归)',
        not any(t in (':|', '|:', '::') for t in r.tokens), '')

    # ---- ⑬ 归一后的记号位置(既有形态, 别改) ----
    r = conv([{'keysig': C_MAJ, 'notes': _notes([(60, 0), (62, 480), (64, 960), (65, 1440),
                                                 (67, 1920), (69, 2400), (71, 2880),
                                                 (72, 3360)])}])
    chk('⑬ 正向归一后, 原本没记号的那个音写成 `\'1`(记号在前) —— 这是既有 492 首产物的形态, '
        '与 ABC 侧同一份 normalize_octave; jptok 两种都认',
        r.tokens[-1] in ("'1", "1'") and _sounding(r)[-1] == "1'",
        'raw=%r' % (r.tokens,))
    chk('⑬ 记号位置只影响写法, 不影响音高: 规范化后两种写法音级+八度相同',
        cc.tokens_pitch_seq(r.tokens) == cc.tokens_pitch_seq(_sounding(r)), '')

    if verbose:
        npass = 0
        for name, ok, detail in cases:
            print('%s  %s%s' % ('PASS' if ok else 'FAIL', name,
                                '' if ok else '  <- ' + detail))
            npass += 1 if ok else 0
        print('-- MIDI 自检 %d/%d 通过 --' % (npass, len(cases)))
    return all(c[1] for c in cases), cases


def _build_format0(notes, keysig=None, ppq=480):
    """format 0 的夹具: 同一轨里混两个通道(通道 0 和弦伴奏, 通道 1 单声部旋律)。"""
    evs = []
    if keysig:
        sf, mi = keysig
        evs.append((0, bytes([0xFF, 0x59, 0x02, sf & 0xFF, mi])))
    for (on, dur, pitch) in notes:
        ch = 1 if pitch >= 60 else 0
        evs.append((on, bytes([0x90 | ch, pitch, 100])))
        evs.append((on + max(1, dur), bytes([0x80 | ch, pitch, 0])))
    evs.append((max(e[0] for e in evs) if evs else 0, b'\xff\x2f\x00'))
    evs.sort(key=lambda x: x[0])
    body = b''
    prev = 0
    for tick, ev in evs:
        body += _vlqb(tick - prev)
        prev = tick
        body += ev
    return struct.pack('>4sIHHH', b'MThd', 6, 0, 1, ppq) + \
        struct.pack('>4sI', b'MTrk', len(body)) + body


# ==========================================================================
# 八、CLI
# ==========================================================================
def _emit(res, name, source, midi_ref, args):
    if args.json:
        print(json.dumps(res.to_dict(name), ensure_ascii=False, indent=2))
        return
    if args.corpus:
        txt = corpus_text(res, name, source, midi_ref)
        if args.outdir:
            os.makedirs(args.outdir, exist_ok=True)
            with open(os.path.join(args.outdir, name), 'w', encoding='utf-8',
                      newline='\n') as f:
                f.write(txt)
        else:
            print(txt, end='')
        return
    print('== %s' % midi_ref)
    print('  选轨=%s(%s)  轨道名=%s  %d 轨/%d 候选  源音符=%d  PPQ=%d'
          % (res.melody, res.melody_why, res.track_name or '(无)', res.n_tracks,
             res.n_candidates, res.n_notes_src, res.ppq))
    print('  原调=%s  1=%s (La-based=%s)  调号 %s(%s)  拍号 %s'
          % (res.key_label, res.key_1, res.la_based, res.key_sig_text, res.key_how,
             res.meter or '(未给)'))
    print('  ok=%s pitch_safe=%s  音数 %d -> %d  休止 %d/%d  时值近似=%d  和弦 %d 个(%d 音)'
          % (res.ok, res.pitch_safe, res.n_pitch_raw, res.n_pitch, res.n_rest_emitted,
             res.n_rest_seen, res.dur_approx, res.n_chord, res.n_chord_notes))
    print('  八度归一=%+d  记号 %d->%d' % (res.oct_shift, res.oct_marks_before,
                                           res.oct_marks_after))
    if res.errors:
        print('  错误: ' + '; '.join(res.errors))
    if res.unsupported:
        print('  子集外/记账: ' + '; '.join('%s×%d' % (k, len(v))
                                             for k, v in sorted(res.unsupported.items())))
    print('  ' + ' '.join(res.tokens))


def main(argv=None):
    ap = argparse.ArgumentParser(
        description='MIDI -> 简谱数字串转换器(与 abc_to_jianpu.py 共用 convert_common 口径)')
    ap.add_argument('midifile', nargs='*')
    ap.add_argument('--selftest', '--selfcheck', dest='selftest', action='store_true')
    ap.add_argument('--melody', default='auto',
                    help='auto(默认)/第 N 轨/name:子串/top/most/all')
    ap.add_argument('--key', default=None, help="强制调号(ABC 写法, 如 C/Am/bE/F#m)")
    ap.add_argument('--spell', default='degree', choices=('degree', 'letter'),
                    help='半音拼写: degree(默认, 实测语料口径)/letter(按调号方向挑字母)')
    ap.add_argument('--quantize', type=int, default=0,
                    help='把起音/时值吸附到 1/N 四分音符的网格(0=不吸附)')
    ap.add_argument('--chord-tol', type=int, default=0, help='同刻和弦允许的 tick 抖动')
    ap.add_argument('--time-sig', default=None, help='覆盖拍号(如 3/4)')
    ap.add_argument('--no-bars', action='store_true', help='不合成小节线')
    ap.add_argument('--title', default=None)
    ap.add_argument('--name', default=None, help='语料文件名(--corpus 用)')
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--corpus', action='store_true', help='输出语料形态文本(默认只打印)')
    ap.add_argument('--outdir', default=None, help='--corpus 时写到这个目录(**绝不写 scores/**)')
    a = ap.parse_args(argv)

    if a.selftest:
        ok, _ = run_selftest()
        return 0 if ok else 1

    files = []
    for p in a.midifile:
        files.extend(sorted(glob.glob(p)) or [p])
    if not files:
        ap.print_help()
        return 2
    rc = 0
    for path in files:
        try:
            res = convert_midi_file(path, melody=a.melody, key=a.key, spell=a.spell,
                                    quantize=a.quantize, chord_tol=a.chord_tol,
                                    bars=not a.no_bars, title=a.title, time_sig=a.time_sig)
        except MidiError as e:
            print('!! %s: %s' % (path, e), file=sys.stderr)
            rc = 1
            continue
        name = a.name or (os.path.splitext(os.path.basename(path))[0] + '.txt')
        # source: `midi-<sha1(仓库路径 + '#' + 轨道号)[:12]>`(序号=选中的轨道号, 见 repo_ref_of)
        track_no = int(re.search(r'track(\d+)', res.melody).group(1)) if res.melody else 1
        sid = cc.make_source(SITE_TOKEN, repo_ref_of(path), track_no)
        res.source_id = sid
        _emit(res, name, sid, path, a)
        if not res.ok:
            rc = 1
    return rc


if __name__ == '__main__':
    sys.exit(main())
