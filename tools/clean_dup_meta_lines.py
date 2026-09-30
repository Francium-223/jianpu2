# -*- coding: utf-8 -*-
"""清掉头部里**重复的空元数据行**（只删"空的那一行"，有值的那一行留着）。

## 为什么会有（2026-09-30 实测）

`to_jianpu_db` 重建时要把旧成品里的人工元数据搬过来。它的老写法是"整行不在新文件里就插到 `%--` 前"，
而新文件头部**本来就有**一行空的 `usertag=` —— 于是变成两行：

```
usertag=          <- 生成时就有的空行
...
usertag=毛不易     <- 从 scores-prev 搬过来的
%--
```

**功能上无害**（`score.py` 对列表字段走 `safe_add` 去重、空值会被忽略），但很脏，而且会被导出到
语料的新文件里。实测 staging **7,168 份**有这种重复；**语料里 0 份**（语料那批是
`merge_metadata_into_corpus.py` 填的，它是"替换空行"而不是"插一行"）。

根因已在 `to_jianpu_db.py` 修掉（改成按字段判：有值跳过 / 空行替换 / 没这行才插）。
本工具只用于**清理已经生成的脏文件**。

用法:
  py -3.13 tools/clean_dup_meta_lines.py [--dir jianpu-db-out/scores]         # 只报告
  py -3.13 tools/clean_dup_meta_lines.py --dir jianpu-db-out/scores --apply   # 真清
"""
import argparse
import glob
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

ROOT = r"D:\Documents_D\jianpu2"
FIELDS = ("usertag", "artist", "alias", "link", "MBID", "tagroute")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=os.path.join(ROOT, "jianpu-db-out", "scores"))
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    hit = []
    for p in sorted(glob.glob(os.path.join(a.dir, "*.txt"))):
        t = io.open(p, encoding="utf-8", errors="replace").read()
        for f in FIELDS:
            # 这一栏出现 >=2 次, 且其中至少一次是空的 -> 该清
            vals = re.findall(r"(?m)^" + f + r"=(.*)$", t)
            if len(vals) > 1 and any(not v.strip() for v in vals):
                hit.append((p, f))
                break
    print(f"{a.dir}: 有「重复空行」的文件 **{len(hit)}** 份")
    for p, f in hit[:10]:
        print(f"   {os.path.basename(p)[:34]:<36} {f}")
    if not a.apply:
        print("\n(dry-run; 加 --apply 才清 —— 只删空的那一行, 有值的留着)")
        return 0

    done = 0
    for p, _f in hit:
        raw = io.open(p, encoding="utf-8", errors="replace", newline="").read()
        nl = "\r\n" if "\r\n" in raw else "\n"
        lines = raw.split(nl)
        # 每栏: 若该栏既有值又有空行 -> 丢掉空行
        out, changed = [], False
        for f in FIELDS:
            idxs = [i for i, ln in enumerate(lines) if ln.strip().startswith(f + "=")]
            has_val = any(lines[i].strip()[len(f) + 1:].strip() for i in idxs)
            if has_val:
                drop = {i for i in idxs if not lines[i].strip()[len(f) + 1:].strip()}
                if drop:
                    changed = True
                    out.append((f, drop))
        if not changed:
            continue
        drop_all = set()
        for _f, drop in out:
            drop_all |= drop
        new = [ln for i, ln in enumerate(lines) if i not in drop_all]
        io.open(p, "w", encoding="utf-8", newline="").write(nl.join(new))
        done += 1
    print(f"\n清了 {done} 份")
    return 0


if __name__ == "__main__":
    sys.exit(main())
