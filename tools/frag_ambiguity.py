# -*- coding: utf-8 -*-
"""片段"不唯一率"(修正版): 与 melody_query.py **完全同口径** —— 按曲名分组(同一首歌的多版本算一首)。

上一版错在哪: 用**文件名**当主体, 于是同一首歌的两份谱被算成"两首不同的歌", 不唯一率被抬高。
本版三档都报:
  不唯一(含标题变体)  —— 命中的曲名有 >=2 个
  真不同歌            —— 命中的曲名两两之间不存在"一个是另一个的子串"关系
                        (《蜗牛与黄鹂鸟》 vs 《口琴六级：蜗牛与黄鹂鸟》 -> 标题变体, 对用户无害)
含义: 不唯一率就是判别力上限 —— 命中的歌 >=2 首时, Top-1 只能靠破并列规则赌。

用法: py -3.13 tools/frag_ambiguity.py [每条长度抽几个=400]
"""
import glob
import io
import os
import random
import re
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

NQ = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 400
SKIP = "0x"
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！?？:：;；·・\-—_…~～'\"“”‘’/\\|]+")
random.seed(20260922)


def group_of(name):
    base = re.sub(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]", "", name.split("__")[0])
    return re.split(r"[（(\s　【\[《]", base)[0].strip() or base.strip()


def norm(s):
    return DROP.sub("", s.translate(ZW)).casefold()


songs = {}
for pat in ("batch-out/*.txt", "batch-out-dup/*.txt"):
    for f in glob.glob(pat):
        b = os.path.basename(f)[:-4]
        try:
            e, _ = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
        except Exception:
            continue
        a = "".join(x[0] for x in e if x[0] not in SKIP)
        o = "".join(x for x in e if x[0] not in SKIP)
        if len(a) >= 25:
            songs.setdefault(group_of(b), []).append((b, a, o))
G = sorted(songs)
print(f"曲目 {len(G)} 首 / 谱 {sum(len(v) for v in songs.values())} 份 / "
      f"音符 {sum(len(a) for v in songs.values() for _, a, _ in v)}   每条抽 {NQ} 个片段\n")


def measure(L, octave=False):
    step = 3 if octave else 1
    first, amb = {}, set()
    for g in G:
        for _b, a, o in songs[g]:
            s = o if octave else a
            for i in range(0, len(s) - L * step + 1, step):
                k = s[i:i + L * step]
                if first.setdefault(k, g) != g:
                    amb.add(k)
    pool = [(g, s) for g in G for _b, a, o in songs[g]
            for s in [(o if octave else a)] if len(s) >= L * step]
    hit = real = n = 0
    for _ in range(NQ):
        g, s = random.choice(pool)
        i = random.randrange(len(s) - L * step + 1)
        k = s[i:i + L * step]
        n += 1
        if k not in amb:
            continue
        hit += 1
        keys = [gg for gg in G if any(k in (o if octave else a) for _b, a, o in songs[gg])]
        nk = [norm(x) for x in keys]
        if any(not (nk[i] in nk[j] or nk[j] in nk[i])
               for i in range(len(nk)) for j in range(i + 1, len(nk))):
            real += 1
    return (hit / n, real / n, n, len(amb))


print(f"{'L':>4}{'口径':>8}{'不唯一':>9}{'其中真不同歌':>13}{'样本':>7}")
for L in (9, 11, 13, 15, 17, 21):
    h, r, n, na = measure(L)
    print(f"{L:>4}{'丢八度':>8}{h*100:>8.1f}%{r*100:>12.1f}%{n:>7}", flush=True)
h, r, n, na = measure(13, octave=True)
print(f"{13:>4}{'带八度':>8}{h*100:>8.1f}%{r*100:>12.1f}%{n:>7}")
print("\n丢八度 = melody_query.py 现行口径; 带八度 = 用户补 `,`/`'` 记号后的口径。")
