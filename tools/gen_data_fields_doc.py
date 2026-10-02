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

# 含义: 数据字段 -> 说明。**类型不写在这里** —— 类型是从数据里推的（见 types_of），
# 因为手写类型实测会错：`file`/`bars`/`source`/`transcriber` 都是 list、`beats_per_bar` 是 float、
# `confidence`/`conf_p10` 是 str（2026-10-03 实测 11495 行的类型画像）。
MEAN = [
    ("file", "文件名列表（入库时按曲名生成；改名会牵动 `by_*` 与前端链接，不由人手改）"),
    ("title", "曲名（在曲谱头里是 `title=`；站上叫“曲名/分组键”，同名多版本靠它归组）"),
    ("artist", "歌手/演奏者（从原谱站页面抽，也可人工补；通用曲名靠它消歧）"),
    ("status", "`ok`=人工校对过 / `ocr`=图片机器转写（发布白名单见上一节）"),
    ("n_notes", "音符数 = jptok 判为音符的 token 数 —— **含休止 `0` 与念白 `x`**；不含 `-`/`~`/`|`。"
                "⚠ 站点索引的 `n` 只数**真音高**（`parse_token` 对 `0`/`x` 返回空），所以同一份谱两边会差 —— "
                "全库合计：语料 **2,532,332** vs 站点 **2,282,964**（90.2%）；差值 249,368 里休止 159,915 + 念白 69,120 = 229,035（2026-10-03 实测）"),
    ("bars", "各段的小节数（逐段一个数，故是列表）"),
    ("beats_per_bar", "每小节拍数（拍号的分母部分；实测是浮点）"),
    ("source", "出处列表，元素形如 `<站>-<站内 id>`（例 `qupu123-268596`；那一页的确切 URL 在 `link`）"),
    ("transcriber", "转写者列表：`jianpu2-auto`=流水线转的；人工投稿由投稿流程写入"),
    ("confidence", "转写置信度：每个数字 top-1 概率的平均（0~1；老谱没有此字段，前端按中性 0.5 处理；实测以字符串存放）"),
    ("conf_p10", "置信度最低那 10% 的分位 —— 平均看着还行、个别音很虚时靠它发现"),
    ("tag", "标签闭包列表（由 `usertag` 按 `tags.json` 推导，别直接手写；站上叫 tags）"),
    ("usertag", "人写的原始标签列表（叶子；分类写 `分类/儿歌` 这种既有约定）"),
    ("alias", "别名列表（同一首歌的别的叫法，检索时一起归组）"),
    ("MBID", "MusicBrainz **work** 的 UUID（注意不是 recording）"),
    ("link", "该曲在某一站的收录页 URL 列表（人工核对过，可多个；搜索页不进数据）"),
    ("sections", "分段：`[{\"subtitle\": \"chorus\", \"score\": \"…\"}]`"),
    ("score", "全文旋律（各段用 ` | ` 连接），记法见「规范/曲谱文件」一节"),
]

_SCALAR = {str: "str", int: "int", float: "float", bool: "bool", type(None): "null"}


def _type_name(v):
    """把一个值渲染成类型名（只认到"标量 / list[标量] / list[dict]"这一层，够用）。

    **空列表不当类型证据** —— 否则会出现 `list|list[str]` 这种噪声（有些行是空列表而已）。
    "有多少行是空的"由**非空率**那一列回答，类型列只说元素是什么。
    """
    if isinstance(v, list):
        if not v:
            return "list"
        inner = {_type_name(x) for x in v if x is not None}
        inner.discard("null")
        return "list[%s]" % "|".join(sorted(inner)) if inner else "list"
    return _SCALAR.get(type(v), type(v).__name__)


def types_of():
    """每个字段的**实测类型**（同一字段出现多种类型时用 `|` 连起来，不掩盖）。"""
    per = collections.defaultdict(collections.Counter)
    for line in io.open(DATA, encoding="utf-8"):
        if not line.strip():
            continue
        for k, v in json.loads(line).items():
            t = _type_name(v)
            if t == "list":            # 空列表：先记着，但**别用它**盖过有内容的那些行
                per[k].setdefault("(空列表)", 0)
                per[k]["(空列表)"] += 1
                continue
            per[k][t] += 1
    out = {}
    for k, c in per.items():
        names = [t for t, _n in c.most_common() if t != "(空列表)"]
        out[k] = "|".join(names) or "list"
    return out


def coverage():
    """返回 (行数, 出现次数, 非空次数)。

    **为什么要分"覆盖"和"非空"**: 字段存在不等于有内容。实测 `link` 在 11495 行里
    **全部是空列表**（曲谱文件头里压根没有 `link=` 这一项，它只可能由人工投稿流程写入）——
    只报覆盖率的话，表上会写"link 100%"，等于把"这个字段现在没数据"藏起来了。
    """
    cnt = collections.Counter()
    nonempty = collections.Counter()
    n = 0
    for line in io.open(DATA, encoding="utf-8"):
        if not line.strip():
            continue
        n += 1
        for k, v in json.loads(line).items():
            cnt[k] += 1
            if v is None:
                continue
            if isinstance(v, (list, dict, str)):
                if len(v.strip() if isinstance(v, str) else v) > 0:
                    nonempty[k] += 1
            else:
                nonempty[k] += 1
    return n, cnt, nonempty


def table(n, cnt, nonempty, tys):
    out = ["", "**`data.jsonl` 字段**（%d 行；覆盖率、非空率与类型都是按当前文件**实测**的，重跑本脚本会自动更新）:" % n, "",
           "| 字段 | 类型 | 覆盖 | 非空 | 含义 |", "|---|---|---|---|---|"]
    unknown = sorted(set(cnt) - {k for k, _ in MEAN})
    empty_but_documented = []
    for k, note in MEAN:
        if k not in cnt:
            continue
        ne = nonempty[k]
        if ne == 0:
            empty_but_documented.append(k)
        out.append("| `%s` | %s | %.1f%% | %.1f%% | %s |"
                   % (k, tys.get(k, "?"), cnt[k] * 100.0 / n, ne * 100.0 / n, note))
    if unknown:
        out.append("| %s | — | — | — | ⚠ 数据里有但本表没写：请补 `tools/gen_data_fields_doc.py` 的 MEAN |"
                   % " ".join("`%s`" % u for u in unknown))
    if empty_but_documented:
        out.append("")
        out.append("> ⚠ **非空 0.0%%** 的字段：%s —— 字段在、但当前语料里没有内容，"
                   "别按「已经有数据」来读（`link` 只由人工核对过的投稿流程写入，"
                   "曲谱文件头里根本没有 `link=` 这一项）。"
                   % "、".join("`%s`" % k for k in empty_but_documented))
    out.append("")
    return "\n".join(out)


def main() -> int:
    n, cnt, nonempty = coverage()
    tys = types_of()
    block = BEGIN + "\n" + table(n, cnt, nonempty, tys) + END
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
