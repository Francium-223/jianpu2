# -*- coding: utf-8 -*-
"""给"默认写到工作台 `_analysis/`"的工具一个安全默认值。

**为什么**: 2026-09-24 我用 `JIANPU_DB=/tmp/... ` 在隔离副本里跑 `audit_corpus_quality.py`
做功能自测，它把提案写到了默认的 `_analysis/quality_proposal.tsv` —— **把真工作台的
104 行提案覆盖成了 1 行表头**（好在 `jianpu-db/misc/records/` 里有版本化的副本）。
凡是"默认输出指向工作台"的工具都有这个坑。

规则: `DB` 就是工作区里的 `jianpu-db` -> 照旧写 `_analysis/<name>`；
      否则(隔离/测试跑) -> 写 **那个 DB 目录里**，绝不碰真工作台。
"""
import os


def is_canonical_db(db_dir):
    """是不是工作区里那个真语料目录（`<工作区>/jianpu-db`）。

    判据用"**兄弟目录**"而不是"往上数一层"：`dirname(db)` 里应该能看到 `jianpu2` 与 `jianpu-web`。
    （第一版写成 `dirname(dirname(db))` 去比对，结果把真 DB 也判成了"不是"，
      提案被写进 `jianpu-db/` 里 —— 见本文件头部注释的同一个教训。）
    """
    d = os.path.abspath(db_dir or ".")
    if os.path.basename(d) != "jianpu-db":
        return False
    parent = os.path.dirname(d)
    # 站点仓库 2026-09-25 起搬到 `jianpu-db.github.io`(组织站), 旧的 `jianpu-web` 已被取代。
    # **两个都认**: 不然清理掉旧目录后, 所有用 safeout 的工具都会判成"不是真工作区",
    # 于是把提案写进语料库本身 —— 正是本文件头部那个事故的翻版。
    return (os.path.isdir(os.path.join(parent, "jianpu2"))
            and any(os.path.isdir(os.path.join(parent, x))
                    for x in ("jianpu-web", "jianpu-db.github.io")))


def default_out(db_dir, name):
    """返回默认输出路径（绝对）。"""
    db_dir = os.path.abspath(db_dir or ".")
    if is_canonical_db(db_dir):
        return os.path.join(os.path.dirname(db_dir), "_analysis", name)
    return os.path.join(db_dir, name)
