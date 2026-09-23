# -*- coding: utf-8 -*-
"""内容级去重: 把"整串完全相同"的重复谱移到 batch-out-dup(**只移不删**, 留可逆清单)。

与 pick_best 的分工:
  * `pick_best.py` 按**曲名**归并 —— 同名取最优版本(交付要求里的那条);
  * 本脚本按**内容**(音高串整串相同, 长度 >=40 音)归并 —— 覆盖"同一首歌在不同站点/不同
    曲名格式下挂了两遍"的情况(实测 batch-out 里 254 组 / 515 份), 这些曲名不同所以绕过了 pick_best。
为什么值得做: ①虚高语料规模 ②检索评测里, 目标歌的孪生副本会作为**另一个"歌"**参与排名,
把指标压低(不是把指标做好看, 是把口径弄干净)。

保留哪一个(可解释的规则, 不随机):
  ① 名字没 mojibake 的优先(能读) ②有清名(title_clean)的优先 ③曲名短的优先
  ④qupu123 优先(实测该站 84% 是单声部简谱) ⑤名字字典序(保证可复现)
用法: py -3.13 tools/dedupe_by_content.py [--apply]     (默认只报告不动文件)
产物: train-work/dedupe_content.tsv (保留者/被移走者, 可逆)
"""
import glob
import os
import re
import shutil
import sys
from collections import defaultdict

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, "tools")
import melody_oct as M
from to_jianpu_db import load_clean_titles_soft, fix_mojibake

APPLY = "--apply" in sys.argv
SKIP = "0x"
CLEAN = load_clean_titles_soft()


def pitch_of(txt):
    e, _raw = M.enc(txt)
    return "".join(x[0] for x in e if x[0] not in SKIP)


def site_of(n):
    m = re.search(r"__([a-z0-9]+)-\d+$", n)
    return m.group(1) if m else "?"


def bad_name(base):
    """名字是否"读不出来"(mojibake 残渣)。

    注意**不能**只用 `fix_mojibake(base) != base` 判断: 那些字节被换成 `_` 的乱码
    (如 `äº_æ__é__æ_¥…`)严格解码会失败, fix_mojibake 原样返回 -> 看起来"没乱码" ✗,
    结果去重时把乱码名留下、把能读的中文名移走了(实测出现过)。
    判据用"乱码特征": 含 Latin-1 高位字符 且 几乎没有中文; 或者整个名字没有中文/字母/数字。
    """
    fixed = fix_mojibake(base)
    cjk = len(re.findall(r"[\u4e00-\u9fff]", fixed))
    hi = len(re.findall(r"[\u00c0-\u00ff]", fixed))
    if hi >= 2 and cjk == 0:
        return 1
    if not re.search(r"[\u4e00-\u9fffA-Za-z0-9]", fixed):
        return 1
    return 0


def keep_key(name):
    base = name.split("__")[0]
    return (bad_name(base),                            # ① 能读的优先
            0 if name in CLEAN else 1,                 # ② 有清名的优先
            len(base),                                 # ③ 名字短的优先
            site_of(name) != "qupu123",                # ④ qupu123 优先
            name)                                      # ⑤ 字典序(可复现)


recs = []
for f in glob.glob("batch-out/*.txt"):
    b = os.path.basename(f)[:-4]
    if b in ("progress", "skipped"):
        continue
    try:
        d = pitch_of(open(f, encoding="utf-8", errors="replace").read())
    except Exception:
        continue
    if len(d) >= 40:
        recs.append((b, d))
print(f"batch-out 参与体检 {len(recs)} 份(>=40 音)")

groups = defaultdict(list)
for b, d in recs:
    groups[d].append(b)
dupes = {k: v for k, v in groups.items() if len(v) > 1}
moves = []
for k, v in dupes.items():
    v = sorted(v, key=keep_key)
    keep = v[0]
    for b in v[1:]:
        moves.append((keep, b, len(k)))
print(f"整串完全相同的组 {len(dupes)} 组, 可移走 {len(moves)} 份")
print("保留规则: 无mojibake > 有清名 > 名字短 > qupu123 > 字典序")

with open("train-work/dedupe_content.tsv", "a", encoding="utf-8") as f:
    # **追加**而不是覆盖: 第二次跑(0 新增)会把第一次的 261 条清单冲掉, 可逆审计就没了 ✗
    if not os.path.exists("train-work/dedupe_content.tsv") or os.path.getsize(
            "train-work/dedupe_content.tsv") == 0:
        f.write("保留\t移走\t音符数\t保留者站点\t移走者站点\n")
    for keep, b, n in moves:
        f.write(f"{keep}\t{b}\t{n}\t{site_of(keep)}\t{site_of(b)}\n")

if not APPLY:
    print("(未加 --apply, 只列清单)")
    for keep, b, n in moves[:6]:
        print(f"   留 {keep[:36]:<38} 移 {b[:36]}  ({n} 音)")
    sys.exit(0)

os.makedirs("batch-out-dup", exist_ok=True)
n = 0
for keep, b, _nn in moves:
    src = f"batch-out/{b}.txt"
    dst = f"batch-out-dup/{b}.txt"
    if not os.path.exists(src):
        continue
    shutil.move(src, dst)
    for ext in (".png",):
        if os.path.exists(f"batch-out/{b}{ext}"):
            shutil.move(f"batch-out/{b}{ext}", f"batch-out-dup/{b}{ext}")
    n += 1
print(f"已移走 {n} 份 -> batch-out-dup (清单 train-work/dedupe_content.tsv, 可逆)")
