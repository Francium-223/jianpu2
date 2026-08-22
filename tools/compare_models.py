# -*- coding: utf-8 -*-
"""7b vs 3b 质量对比: 格式通过率 / 音符量 / 时值 / 结构 / 同曲对照。
用法: python tools/compare_models.py > 对比结果.txt
"""
import collections
import importlib.util
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "vendor"))
import jianpu_ly  # noqa: E402

spec = importlib.util.spec_from_file_location('convert', 'convert.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

PAIRS = [
    ("scores-draft", "scores-7b"),
    ("scores-draft2", "scores-7b-2"),
    ("scores-draft3", "scores-7b-3"),
    ("scores-draft4", "scores-7b-4"),
    ("scores-draft5", "scores-7b-5"),
    ("scores-draft-pucn", "scores-7b-pucn"),
    ("scores-draft-pujia", "scores-7b-pujia"),
]

NOTE_RE = re.compile(r"[0-7]")
TIME_SIGS = ["4/4", "3/4", "2/4", "6/8", "3/8", "4/8"]


def jly_ok(body):
    """原样验证; 失败且无拍号时依次试常见拍号 (同 validate_drafts.py)。"""
    try:
        jianpu_ly.process_input(body)
        return True
    except Exception:
        pass
    if re.search(r"(?m)^\d+/\d+\s*$", body):
        return False
    for ts in TIME_SIGS:
        try:
            jianpu_ly.process_input(ts + "\n" + body)
            return True
        except Exception:
            pass
    return False


def analyze(d):
    if not os.path.isdir(d):
        return None
    stats = {"files": 0, "ly": 0, "err": 0, "notes": 0, "bars": 0,
             "q": 0, "s": 0, "d": 0, "dash": 0, "dot": 0, "high": 0, "low": 0,
             "acc": 0, "subtitle": 0, "nextscore": 0, "repeat": 0, "lines": 0}
    for name in sorted(os.listdir(d)):
        if not name.endswith(".txt"):
            continue
        stats["files"] += 1
        base = name[:-4]
        if os.path.exists(os.path.join(d, base + ".err")):
            stats["err"] += 1
        text = open(os.path.join(d, name), encoding="utf-8").read()
        body = text[text.find("%--") + 3:] if "%--" in text else text
        body = body.replace("%END", "")
        if jly_ok(body):
            stats["ly"] += 1
        stats["lines"] += len([l for l in body.splitlines() if l.strip()])
        for ln in body.splitlines():
            s = ln.strip()
            if s.startswith("subtitle="):
                stats["subtitle"] += 1
            elif s == "NextScore":
                stats["nextscore"] += 1
            elif re.match(r"^R\d*\s*\{", s):
                stats["repeat"] += 1
            for tok in s.split():
                if re.match(r"^[#b',]*[qsdhQ]?[0-7iI][.,'\-]*$", tok) or re.match(r"^[\-|]+$", tok):
                    pass
                if re.match(r"^[qsdh]", tok):
                    stats[{"q": "q", "s": "s", "d": "d"}.get(tok[0], "q") if tok[0] in "qsd" else "q"] += 1
                    if tok[0] == "q": stats["q"] += 1
                    elif tok[0] == "s": stats["s"] += 1
                    elif tok[0] == "d": stats["d"] += 1
                if "-" in tok:
                    stats["dash"] += 1
                if "." in tok:
                    stats["dot"] += 1
                if "'" in tok:
                    stats["high"] += 1
                if "," in tok:
                    stats["low"] += 1
                if tok[:1] in "#b":
                    stats["acc"] += 1
                stats["notes"] += len(NOTE_RE.findall(tok))
                if tok == "|":
                    stats["bars"] += 1
    return stats


def main():
    print("=" * 72)
    print("7b vs 3b 质量对比 (格式通过率 / 音符量 / 时值 / 结构)")
    print("=" * 72)
    rows = []
    for d3, d7 in PAIRS:
        a3, a7 = analyze(d3), analyze(d7)
        if not a3 or not a7:
            continue
        rows.append((d3, a3, a7))
        print(f"\n[{d3} → {d7}]")
        print(f"  文件数:     3b {a3['files']:3d}   7b {a7['files']:3d}")
        print(f"  通过校验:   3b {a3['ly']:3d} ({a3['ly']/max(a3['files'],1)*100:.0f}%)   7b {a7['ly']:3d} ({a7['ly']/max(a7['files'],1)*100:.0f}%)")
        print(f"  失败 .err:  3b {a3['err']:3d}   7b {a7['err']:3d}")
        print(f"  总音符数:   3b {a3['notes']:6d}   7b {a7['notes']:6d}")
        print(f"  每首平均:   3b {a3['notes']/max(a3['files'],1):6.1f}   7b {a7['notes']/max(a7['files'],1):6.1f}")
        print(f"  小节数:     3b {a3['bars']:6d}   7b {a7['bars']:6d}")
        print(f"  八分(q):    3b {a3['q']:6d}   7b {a7['q']:6d}")
        print(f"  十六分(s):  3b {a3['s']:6d}   7b {a7['s']:6d}")
        print(f"  三十二(d):  3b {a3['d']:6d}   7b {a7['d']:6d}")
        print(f"  延音线(-):  3b {a3['dash']:6d}   7b {a7['dash']:6d}")
        print(f"  附点(.):    3b {a3['dot']:6d}   7b {a7['dot']:6d}")
        print(f"  高八度('):  3b {a3['high']:6d}   7b {a7['high']:6d}")
        print(f"  低八度(,):  3b {a3['low']:6d}   7b {a7['low']:6d}")
        print(f"  升降号:     3b {a3['acc']:6d}   7b {a7['acc']:6d}")
        print(f"  段落:       3b subtitle={a3['subtitle']} NextScore={a3['nextscore']} R{{}}={a3['repeat']}")
        print(f"              7b subtitle={a7['subtitle']} NextScore={a7['nextscore']} R{{}}={a7['repeat']}")
    t3 = sum(a["notes"] for _, a, _ in rows)
    t7 = sum(a["notes"] for _, _, a in rows)
    f3 = sum(a["files"] for _, a, _ in rows)
    f7 = sum(a["files"] for _, _, a in rows)
    ly3 = sum(a["ly"] for _, a, _ in rows)
    ly7 = sum(a["ly"] for _, _, a in rows)
    print("\n" + "=" * 72)
    print(f"合计: 文件 {f3} vs {f7} | 通过 {ly3}/{f3} vs {ly7}/{f7} | 音符 {t3} vs {t7}")

    # 同曲对照
    print("\n" + "=" * 72)
    print("同曲对照 (前 5 首 7b 有而 3b 也有的)")
    shown = 0
    for d3, d7 in PAIRS:
        for name in sorted(os.listdir(d7)):
            if not name.endswith(".txt"):
                continue
            if os.path.exists(os.path.join(d3, name)):
                t3 = open(os.path.join(d3, name), encoding="utf-8").read()
                t7 = open(os.path.join(d7, name), encoding="utf-8").read()
                b3 = t3[t3.find("%--") + 3:].replace("%END", "").strip()
                b7 = t7[t7.find("%--") + 3:].replace("%END", "").strip()
                print(f"\n### {name}   (3b {len(NOTE_RE.findall(b3))} 音符 vs 7b {len(NOTE_RE.findall(b7))} 音符)")
                print("--- 3b:"); print("\n".join(b3.splitlines()[:6]))
                print("--- 7b:"); print("\n".join(b7.splitlines()[:6]))
                shown += 1
                if shown >= 5:
                    sys.exit(0)


if __name__ == "__main__":
    main()
