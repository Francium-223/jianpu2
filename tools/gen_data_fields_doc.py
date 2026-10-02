# -*- coding: utf-8 -*-
"""把 `jianpu-db/README.md` 里缺的那张 **`data.jsonl` 字段表**按**实际数据**生成并插入。

为什么要有: README 一直只讲"曲谱文件头"的字段（`title=`/`tag=`/`NextScore`…），
而 `data.jsonl` 是仓库的中心产物却没有字段表 —— 实测 18 个字段里有 11 个（`file`/`status`/
`artist`/`n_notes`/`bars`/`beats_per_bar`/`confidence`/`conf_p10`/`score`/`sections`/`source`）
在 README 里查不到。含义取自 `schema.py` 的 FIELDS（曲谱卡片那套 label/note，是权威口径）
与数据集卡片（`export_hf.py` 的 COLS）。

覆盖率是**跑出来的**，不是写死的：每次重跑都会按当时的 data.jsonl 更新。
插入位置: 标记 `<!-- data-fields:begin -->` / `<!-- data-fields:end -->` 之间（幂等）。
用法: py -3.13 tools/gen_data_fields_doc.py [--check]
      --check 只比对，不写（差多少报多少）
"""
import collections
import io
import json
import os
import re
import sys
from guard import guard_help        # noqa: E402
guard_help(__doc__)

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.join(os.path.dirname(ROOT), "jianpu-db")
DATA = os.path.join(REPO, "data.jsonl")
README = os.path.join(REPO, "README.md")
CHECK = "--check" in sys.argv

BEGIN, END = "<!-- data-fields:begin -->", "<!-- data-fields:end -->"

# 含义: 数据字段 -> (类型, 说明)。说明与 schema.py 的解释保持一致（那里是给人看的权威口径）。
MEAN = [
    ("file", "str", "文件名（入库时按曲名生成；改名会牵动 `by_*` 与前端链接，不由人手改）"),
    ("title", "str", "曲名（在曲谱头里是 `title=`；站上叫“曲名/分组键”，同名多版本靠它归组）"),
    ("artist", "list[str]", "歌手/演奏者（从原谱站页面抽，也可人工补；通用曲名靠它消歧）"),
    ("status", "str", "`ok`=人工校对过 / `ocr`=图片机器转写（发布白名单见上一节）"),
    ("n_notes", "int", "音符数（jptok 唯一 token 口径，不含 `-`/`~`/`|`）"),
    ("bars", "int", "小节数（由拍号与音符时值推出）"),
    ("beats_per_bar", "int", "每小节拍数（拍号的分母部分）"),
    ("source", "str", "出处 `<站>-<站内 id>`（例 `qupu123-268596`；那一页的确切 URL 在 `link`）"),
    ("transcriber", "str", "转写者：`jianpu2-auto`=流水线转的；人工投稿由投稿流程写入"),
    ("confidence", "float", "转写置信度：每个数字 top-1 概率的平均（0~1；老谱没有此字段，前端按中性 0.5 处理）"),
    ("conf_p10", "float", "置信度最低那 10% 的分位 —— 平均看着还行、个别音很虚时靠它发现"),
    ("tag", "list[str]", "标签闭包（由 `usertag` 按 `tags.json` 推导，别直接手写；站上叫 tags）"),
    ("usertag", "list[str]", "人写的原始标签（叶子；分类写 `分类/儿歌` 这种既有约定）"),
    ("alias", "list[str]", "别名（同一首歌的别的叫法，检索时一起归组）"),
    ("MBID", "str", "MusicBrainz **work** 的 UUID（注意不是 recording）"),
    ("link", "list[str]", "该曲在某一站的收录页 URL（人工核对过，可多个；搜索页不进数据）"),
    ("sections", "list[dict]", "分段：`[{\"subtitle\": \"chorus\", \"score\": \"…\"}]`"),
    ("score", "str", "全文旋律（各段用 ` | ` 连接），记法见「规范/曲谱文件」一节"),
]


def coverage():
    cnt = collections.Counter()
    n = 0
    for line in io.open(DATA, encoding="utf-8"):
        if not line.strip():
            continue
        n += 1
        for k in json.loads(line):
            cnt[k] += 1
    return n, cnt


def table(n, cnt):
    out = ["", "**`data.jsonl` 字段**（%d 行；覆盖率是按当前文件实测的，重跑本脚本会自动更新）:" % n, "",
           "| 字段 | 类型 | 覆盖 | 含义 |", "|---|---|---|---|"]
    unknown = sorted(set(cnt) - {k for k, _, _ in MEAN})
    for k, ty, note in MEAN:
        if k not in cnt:
            continue
        out.append("| `%s` | %s | %.1f%% | %s |" % (k, ty, cnt[k] * 100.0 / n, note))
    if unknown:
        out.append("| %s | — | — | ⚠ 数据里有但本表没写：请补 `tools/gen_data_fields_doc.py` 的 MEAN |"
                   % " ".join("`%s`" % u for u in unknown))
    out.append("")
    return "\n".join(out)


def main() -> int:
    n, cnt = coverage()
    block = BEGIN + "\n" + table(n, cnt) + END
    txt = io.open(README, encoding="utf-8").read()
    if BEGIN in txt and END in txt:
        new = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END), lambda _m: block, txt, flags=re.S)
    else:
        # 首次插入: 放在"所有元数据（包括data.jsonl）…"那一行之后
        m = re.search(r"^.*包括data\.jsonl.*$", txt, flags=re.M)
        if not m:
            print("✗ README 里找不到插入锚点"); return 1
        new = txt[:m.end()] + "\n" + block + txt[m.end():]
    if new == txt:
        print("✓ README 的字段表已是最新（%d 行数据 / %d 个字段）" % (n, len(cnt)))
        return 0
    if CHECK:
        print("✗ README 的字段表与实际数据不一致（--check 不写盘）")
        return 1
    io.open(README, "w", encoding="utf-8", newline="").write(new)
    print("✓ 已更新 README 的字段表：%d 行数据 / %d 个字段" % (n, len(cnt)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
