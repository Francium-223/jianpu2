# -*- coding: utf-8 -*-
"""把"staging 里到底有多少份有 usertag"用两种判据各数一遍，消除歧义。

起因：标签器说 `已有标签(不动) 7189`，而我自己的扫描说"只有 21 份有值" —— 两者对不上，
必须查清是**标签器的判据**错了还是**我的扫描**错了。
"""
import glob
import io
import re

SCORES = r"D:\Documents_D\jianpu2\jianpu-db-out\scores"


def main():
    fs = sorted(glob.glob(SCORES + "/*.txt"))
    n = 0
    tagger_judge = 0     # 标签器用的判据 `^usertag=[^\s]`
    my_scan = 0          # 我的扫描 `^usertag=(.*)$` + strip
    line_empty = 0       # 那一行是不是 `usertag=`(空)
    other = 0
    samples = []
    for p in fs:
        t = io.open(p, encoding="utf-8", errors="replace").read()
        n += 1
        if re.search(r"(?m)^usertag=[^\s]", t):
            tagger_judge += 1
            if len(samples) < 3:
                m = re.search(r"(?m)^usertag=.*$", t)
                samples.append((p.split("\\")[-1], repr(m.group(0)) if m else None))
        m = re.search(r"(?m)^usertag=(.*)$", t)
        v = (m.group(1).strip() if m else "")
        if v:
            my_scan += 1
        elif m:
            line_empty += 1
        else:
            other += 1
    print(f"staging {n} 份:")
    print(f"  标签器判据 `^usertag=[^\\s]` 命中(=它说的'已有标签'): {tagger_judge}")
    print(f"  我的扫描(取值+strip 非空):                          {my_scan}")
    print(f"  有 `usertag=` 行但为空:                             {line_empty}")
    print(f"  连 `usertag=` 行都没有:                             {other}")
    if samples:
        print("  被判'已有标签'的样本:")
        for name, line in samples:
            print(f"    {name}  {line}")


if __name__ == "__main__":
    main()
