# -*- coding: utf-8 -*-
"""全链路回归: 用已生成/构造的模型输出验证 convert 管线 + jianpu-ly。"""
import importlib.util, re, sys
sys.path.insert(0, 'vendor')
spec = importlib.util.spec_from_file_location('convert', 'convert.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
import jianpu_ly

def run(raw, name, ts=None):
    key, time_sig, tempo, body = m.extract_controls(raw)
    body = m.clean_body(body)
    body = m.minor_tonic_fix(body, key)
    body = m.ensure_nextscore(body)
    body = m.fix_bars(body, time_sig)
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
            if m.NOTE_LINE_RE.search(p_nosig):
                kept.append(p)
            else:
                changed = True
        if not changed:
            break
        body = "\nNextScore\n".join(kept).rstrip()
    if time_sig:
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
    score = m.build_score_file('', name, 'work', '', '', '', body)
    body_only = score[score.find('%--') + 3:].strip()
    try:
        jianpu_ly.process_input(body_only)
        return True, body_only
    except Exception as e:
        return False, f"{str(e)[:100]} :: {body_only.replace(chr(10), ' / ')[:220]}"

cases = []
for f in ['寄明月', '学电脑', '太湖水', '八角树', '学工歌', '上海人', '意难平', '我的梦', '少年游', '当兵乐',
          '宜昌队', '小上海', '推车歌', '小小的暖', '太行之歌', '大美乡村', '童年的家', '今生不再', '宾至房山', '对月思乡', '一念暖阳']:
    for d in ('scores-7b', 'scores-7b-2'):
        try:
            raw = open(f'{d}/{f}.trans', encoding='utf-8').read()
            cases.append((raw, f'{d}:{f}'))
            break
        except FileNotFoundError:
            pass
for f in ['爱就一个字二部合唱谱', '一荤一素二声部合唱谱', '我们是运河的流水（女声合唱）', '璀璨冒险人二声部合唱']:
    for d in ('scores-7b-4',):
        try:
            raw = open(f'{d}/{f}.trans', encoding='utf-8').read()
            cases.append((raw, f'{d}:{f}'))
            break
        except FileNotFoundError:
            pass
# 构造用例
cases.append(("#TIME 4/4\nq1 q2 q3 q4 | q5 q6 q7 q1 | 2 3", "synth-q"))
cases.append(("#TIME 4/4\n6, 6,, ,6 ,,6 #4 b7 i I qi- | 1 2 3 4 | 5 6 7 1", "synth-mix"))
cases.append(("#TIME D2/4\n3- 5 - | 6 ~7~8| R{ ... } A{| ... }   #10", "synth-repeat"))

ok = 0
for raw, name in cases:
    passed, info = run(raw, name)
    print(('OK  ' if passed else 'FAIL'), name)
    if not passed:
        print('   ', info)
    else:
        ok += 1
print(f"\n{ok}/{len(cases)} 通过")
