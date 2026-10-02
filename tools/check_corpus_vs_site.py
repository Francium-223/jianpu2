# -*- coding: utf-8 -*-
"""跨仓库行级一致性：语料 `jianpu-db/data.jsonl` vs 站点索引 `songs.jsonl.gz`。

两边字段名不同（站点行是短键: `t`/`g`/`n`/`st`/`s`；语料是 `title`/`status`/`n_notes`/`source`(list)），
所以先用真实字段名建索引再比，别按想当然的键名比。比三件事:
  ① 行数  ② 按 id 的集合差  ③ 对得上的那些，`t`(标题) 与 `n`(音符数) 是否逐行相同。
"""
import gzip
import io
import json
import os
import sys
from guard import guard_help        # noqa: E402
guard_help(__doc__)

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORPUS = os.path.join(os.path.dirname(ROOT), "jianpu-db", "data.jsonl")
SITE = os.path.join(os.path.dirname(ROOT), "jianpu-db.github.io", "data", "songs.jsonl.gz")


def corpus_rows():
    with io.open(CORPUS, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                yield json.loads(line)


def site_rows():
    with gzip.open(SITE, "rt", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                yield json.loads(line)


def first_id(v):
    if isinstance(v, list):
        return v[0] if v else ""
    return v or ""


def base_name(v):
    """文件名（去掉目录与扩展名）—— 两边唯一靠得住的连接键。

    ⚠ 别拿 `source` 当键: 语料里 `source` 是 **list** 且**同一 id 会出现很多次**
    （实测 11495 行里有 1569 行 id 重复），拿 source[0] 连接会把不同行对上，
    于是"标题/音符数不同"全是假的（我第一次就是这么错的）。
    """
    f = first_id(v)
    return os.path.splitext(os.path.basename(f))[0]


c = {}
dupc = 0
n_c = 0
for r in corpus_rows():
    n_c += 1
    k = base_name(r.get("file"))
    if k in c:
        dupc += 1
    c[k] = r

s = {}
dups = 0
n_s = 0
for r in site_rows():
    n_s += 1
    k = base_name(r.get("file"))
    if k in s:
        dups += 1
    s[k] = r

print("语料 %d 行（重复 id %d）/ 站点 %d 行（重复 id %d）" % (n_c, dupc, n_s, dups))
only_c = sorted(set(c) - set(s))
only_s = sorted(set(s) - set(c))
print("只在语料里的 id: %d 个 %s" % (len(only_c), only_c[:5]))
print("只在站点里的 id: %d 个 %s" % (len(only_s), only_s[:5]))

bad_t = bad_n = 0
ex_t, ex_n = [], []
for k in set(c) & set(s):
    rc, rs = c[k], s[k]
    if (rc.get("title") or "") != (rs.get("t") or ""):
        bad_t += 1
        if len(ex_t) < 3:
            ex_t.append((k, rc.get("title"), rs.get("t")))
    if int(rc.get("n_notes") or 0) != int(rs.get("n") or 0):
        bad_n += 1
        if len(ex_n) < 3:
            ex_n.append((k, rc.get("n_notes"), rs.get("n")))
print("对得上的 %d 行里：标题不同 %d 行、音符数不同 %d 行" % (len(set(c) & set(s)), bad_t, bad_n))
for k, a, b in ex_t:
    print("   标题: %s 语料 %r vs 站点 %r" % (k, a, b))
for k, a, b in ex_n:
    print("   音符: %s 语料 %s vs 站点 %s" % (k, a, b))
