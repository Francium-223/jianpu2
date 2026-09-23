# -*- coding: utf-8 -*-
"""清理"按曲名扫描"里误命中的下载目录(短标题 substring 撞车的后果)。

背景: 早期版本的匹配用 `目标 in 曲名`, 于是《红豆》会下到《红豆杉》《红豆情》, 《大海》会下到
《大海啊故乡》。这些谱标题本身是别的歌, 留着会往语料里塞无关曲目(不影响覆盖率统计, 但是噪音)。
规则: 短目标(<=3 字)要求**精确相等**; 长目标允许包含。
可逆: 只移不删 -> images-prep/_offtarget/, 记 train-work/prune_offtarget.log。
用法: py -3.13 tools/prune_offtarget.py [--dry]
"""
import glob
import io
import os
import re
import shutil
import sys

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
DRY = "--dry" in sys.argv
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！?？:：;；·・\-—_…~～'\"“”‘’/\\|&]+")
ENT = re.compile(r"&[a-zA-Z]{2,8};|&#\d+;")
PAREN = re.compile(r"[（(【\[][^)）】\]]*[)）】\]]|[（(【\[].*$")


def norm(s):
    """曲名归一化 —— **站点的曲名带各种限定语, 必须先剥干净再比**, 否则会把正确下载当误命中:
      `绿光&nbsp;&nbsp;`   -> HTML 实体(&nbsp;)     实测导致 4 张正确的《绿光》被误移
      `红茶馆(粤语)`       -> 括号语言限定
      `恋人未满２`         -> 尾部全角编号
      `恋人未满 (she)`     -> 括号里的未知歌手
    但**不能**只按"前缀相同"就算命中 —— 那样 `红豆杉` 会被当成 `红豆`(这是本来要清的假阳性)。
    """
    s = ENT.sub("", s)
    s = re.sub(r"\[[^\]]*\]", "", s)
    s = PAREN.sub("", s)
    s = re.sub(r"[0-9０-９]+$", "", s)
    return DROP.sub("", s.translate(ZW)).casefold()


# 收集所有扫描日志里的 (目标, 命中标题)
pairs = []
for lg in ("train-work/qupu123_title_scan.tsv", "train-work/qupu123_title_scan2.tsv",
           "train-work/jianpucn_title_scan.tsv"):
    if not os.path.exists(lg):
        continue
    for line in io.open(lg, encoding="utf-8"):
        c = line.rstrip("\n").split("\t")
        if len(c) >= 2 and c[0] and c[1]:
            pairs.append((c[0].strip(), c[1].strip()))
print(f"扫描日志里的命中记录 {len(pairs)} 条")

os.makedirs("images-prep/_offtarget", exist_ok=True)
log = io.open("train-work/prune_offtarget.log", "a", encoding="utf-8")
seen, n = set(), 0
for want, title in pairs:
    wn, tn = norm(want), norm(title)
    ok = (wn == tn) or (len(wn) > 3 and wn in tn)
    if ok:
        continue
    # 找到对应的下载目录(目录名以 标题__站点-id 结尾)
    for d in glob.glob("images-prep/qupu123-title/*") + glob.glob("images-prep/jianpucn-title/*"):
        if not os.path.isdir(d):
            continue
        base = os.path.basename(d)
        if base in seen:
            continue
        if norm(base.split("__")[0]) == tn or title[:20] in base:
            seen.add(base)
            if DRY:
                print(f"   [dry] {want} <- {base[:56]}")
            else:
                shutil.move(d, os.path.join("images-prep/_offtarget", base))
                log.write(f"{want}\t{title}\t{base}\n")
                log.flush()
                print(f"   移出 {want} <- {base[:56]}")
            n += 1
print(f"\n{'将移出' if DRY else '已移出'} {n} 个误命中目录 -> images-prep/_offtarget/")
