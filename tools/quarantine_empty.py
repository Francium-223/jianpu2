# -*- coding: utf-8 -*-
"""收尾安全网 2: 把"0 音符"的转写结果移出语料到 batch-out-empty/。

理由: 纯简谱本该有音符。0 音符只有两种可能 —— (a) 其实是五线谱/伴奏谱, 纯度门漏了
(实测 22 个, 如《丁小琴编-19打起手鼓唱起歌（正谱）》); (b) 转写失败。
两种都不该以"纯简谱"的名义留在语料里。转换器本来也会跳过它们(<10 音符),
这里显式隔离, 让语料只剩"有内容"的谱。
用法: py tools/quarantine_empty.py [--dry]
"""
import glob, os, shutil, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

DRY = "--dry" in sys.argv
os.makedirs("batch-out-empty", exist_ok=True)
n = 0
for f in glob.glob("batch-out/*.txt"):
    b = os.path.basename(f)
    if b in ("progress.txt", "skipped.txt"):
        continue
    toks = open(f, encoding="utf-8").read().split()
    d = sum(1 for x in toks
            if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
    if d == 0:
        n += 1
        if not DRY:
            shutil.move(f, os.path.join("batch-out-empty", b))
            png = f[:-4] + ".png"
            if os.path.exists(png):
                shutil.move(png, os.path.join("batch-out-empty", os.path.basename(png)))
print(f"{'[dry] ' if DRY else ''}0 音符结果移出 {n} 个")
