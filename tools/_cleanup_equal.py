# -*- coding: utf-8 -*-
"""清理 equal 遗留物:
1) schema.py 里 equal 从"两槽历史形状 [groups, [[]]]"收敛成**一个等同组列表**
   (旧槽来自已删除的 tag_equality.json, 恒为空, 4 处死循环)
2) schema.py 注释里"不再读 tag_implications.json / tag_equality.json"改成"已删除"
3) README.md 里指向那两个文件的链接改成 tags.json
"""
import io
import os
import sys

REPO = r"D:\Documents_D\jianpu-db"
sys.stdout.reconfigure(encoding="utf-8")


def patch(path, pairs, must=True):
    s = io.open(path, encoding="utf-8").read()
    for old, new in pairs:
        if old not in s:
            if must:
                sys.exit(f"标记未命中 {path}: {old[:60]!r}")
            continue
        s = s.replace(old, new)
    io.open(path, "w", encoding="utf-8", newline="").write(s)
    print(f"  已改 {os.path.basename(path)}")


SC = os.path.join(REPO, "schema.py")
RD = os.path.join(REPO, "README.md")

patch(SC, [
    # 1) 返回值: 单列表
    ("\treturn imply, [groups, [[]]]", "\treturn imply, groups"),
    # 2) 契约说明
    ("\t返回 (imply, equal), 与旧的 tag_implications.json / tag_equality.json 逐项等值:\n"
     "\t  imply    = 嵌套 dict, 键取每个节点 name[0]\n"
     "\t  equal[0] = 别名数 >= 2 的节点, 按先序;  equal[1] = [[]] (历史形状, 空)",
     "\t返回 (imply, equal):\n"
     "\t  imply = 嵌套 dict, 键取每个节点 name[0]\n"
     "\t  equal = 别名数 >= 2 的节点(即\"等同组\"), 按先序"),
    # 3) 注释里那两个文件已删除
    ("\t\"\"\"蕴涵/等同规则: 从 tags.json 派生(单一真源), 不再读 tag_implications.json /\n"
     "\ttag_equality.json —— 那两份本就是这个文件的冗余副本, 三处各写一份必然漂移\n"
     "\t(实测\"东方同人曲\"被错挂在\"东方原曲\"下: 同人曲不是原曲)。\n"
     "\t那两份旧文件已归档到 misc/, 仅供查阅, 改了不会生效。",
     "\t\"\"\"蕴涵/等同规则: **只**从 tags.json 派生(单一真源)。\n"
     "\t旧的 tag_implications.json / tag_equality.json **已删除** —— 它们本就是这个文件的\n"
     "\t冗余副本, 三处各写一份必然漂移(实测\"东方同人曲\"被错挂在\"东方原曲\"下: 同人曲不是原曲)。\n"
     "\t字段名也顺带收敛: 原先为了兼容那两份文件, equal 是\"两槽\"形状 [等同组, 空表],\n"
     "\t现在直接是等同组列表。"),
    # 4) 4 处死循环: equal[1] 恒为空
    ("\t\tfor i in equal[1]:\n\t\t\tfor j in i:\n\t\t\t\tif j == n:\n"
     "\t\t\t\t\tself.tag = safe_add(self.tag, j.split('/'))\n"
     "\t\t\t\t\tself.origtag = safe_add(self.origtag, i)\n\t\t\t\t\tbreak\n", ""),
    ("\t\tfor i in equal[1]:\n\t\t\tfor j in i:\n\t\t\t\tif j == n:\n"
     "\t\t\t\t\tself.nottag = safe_add(self.nottag, j.split('/'))\n"
     "\t\t\t\t\tself.orignottag = safe_add(self.orignottag, i)\n\t\t\t\t\tbreak\n", ""),
    ("\t\tfor i in equal[1]:\n\t\t\tfor j in i:\n\t\t\t\tif j == n:\n"
     "\t\t\t\t\ttag = safe_add(tag, j.split('/'))\n\t\t\t\t\tbreak\n", ""),
    ("\t\tfor j in equal[1]:\n\t\t\tif i in j:\n\t\t\t\tfor k in j:\n"
     "\t\t\t\t\tout = safe_add(out, k.split('/'))\n", ""),
    # 5) equal[0] -> equal (等同组现在就是列表本身)
    ("for i in equal[0]:", "for i in equal:"),
    ("for j in equal[0]:", "for j in equal:"),
])

patch(RD, [
    ("[tag_implication.json](tag_implication.json)：标签间的蕴涵关系，如`东方星莲船`蕴涵`东方原曲`。\n\n"
     "[tag_equality.json](tag_equality.json)：标签间的等同关系，如`东方星莲船`等同`th12`。\n",
     "[tags.json](tags.json)：**标签体系的单一真源**（一棵 DAG：节点名/别名 + 父子关系）。"
     "`imply`（蕴涵，如`东方星莲船`→`东方原曲`）与`equal`（等同/别名，如`东方星莲船`=`th12`）"
     "都由它派生，见 [schema.py](schema.py) 的 `load_tag_rules()`。"
     "旧的`tag_implication.json`/`tag_equality.json`已删除（曾是它的冗余副本）。\n"),
    ("见[tag_equality.json](tag_equality.json)）", "见[tags.json](tags.json)）"),
])

# 6) 删除两份已无引用的文件(git rm 保持可追溯)
os.system("git rm -q misc/tag_equality.json misc/tag_implications.json")
print("  已 git rm misc/tag_equality.json misc/tag_implications.json")
