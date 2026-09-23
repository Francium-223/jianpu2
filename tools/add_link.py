#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""人工补收录页(命令行入口) —— 把某首歌在某一站的**具体页面**写进语料。

用户口径(2026-09-23): 「我要的不是个自动跳转到搜索页面的按钮, 我要的是跳转到它
**具体收录的那一页**」—— 网页上有「＋ 补收录页」, 这个脚本是它的批量/离线版本;
两边共用同一份校验与写入实现(`jianpu-db/linkurl.py`), **搜索页一律拒收**。

用法:
  # 一首一首补(文件 = jianpu-db/scores/ 里的文件名, 可只写前面几个字, 唯一匹配即可)
  python3 jianpu2/tools/add_link.py th10_06 https://music.163.com/song?id=186016
  python3 jianpu2/tools/add_link.py 神々 https://www.bilibili.com/video/BV1xx411c7mD

  # 看某首现有链接(顺便显示原谱站核对过的页面)
  python3 jianpu2/tools/add_link.py th10_06 --show

  # 批量: TSV, 每行 "<文件或曲名>\t<URL>"; --dry 只看结果不落盘
  python3 jianpu2/tools/add_link.py --from-tsv links.tsv [--dry]

  # 写完默认**重算索引**(parse_scores.py + 前端 build_web_data), --no-refresh 可跳过
"""
import argparse
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                                    # jianpu2/
DB = os.environ.get("JIANPU_DB") or os.path.join(os.path.dirname(ROOT), "jianpu-db")
SCORES = os.path.join(DB, "scores")
sys.path.insert(0, DB)
sys.stdout.reconfigure(encoding="utf-8")

try:
    import linkurl
except Exception as e:                                          # pragma: no cover
    sys.exit(f"找不到 {DB}/linkurl.py —— JIANPU_DB 指对了吗?(写进曲谱的唯一实现在那里)")


def all_scores():
    return [f for f in sorted(os.listdir(SCORES))
            if f.endswith(".txt") and not f.endswith(("_expand.txt", "_buf.txt"))]


def resolve(name):
    """文件名或曲名 -> 唯一的一份曲谱文件名。"""
    name = (name or "").strip()
    if not name:
        raise SystemExit("没给文件/曲名")
    if name.endswith(".txt") and os.path.isfile(os.path.join(SCORES, name)):
        return name
    cands = [f for f in all_scores() if name in f]
    if not cands:                                   # 再按 title= 匹配
        for f in all_scores():
            t = open(os.path.join(SCORES, f), encoding="utf-8", errors="ignore").read(4000)
            m = re.search(r"(?m)^title=(.+)$", t)
            if m and name in m.group(1):
                cands.append(f)
    if not cands:
        raise SystemExit(f"语料里找不到: {name!r}")
    if len(cands) > 1:
        raise SystemExit(f"{name!r} 不唯一, 命中 {len(cands)} 份: {cands[:5]}")
    return cands[0]


def show(fname):
    path = os.path.join(SCORES, fname)
    txt = open(path, encoding="utf-8").read()
    print(f"== {fname}")
    for ln in txt.splitlines():
        if ln.startswith("link="):
            for u in ln[5:].split(","):
                print("   收录页  " + u)
    if "link=" not in txt:
        print("   收录页: (还没有 —— 待补充)")
    t = open(path, encoding="utf-8").read()
    s = re.search(r"(?m)^source=(\S+)", t)
    sp = os.path.join(DB, "source_pages.json")
    if s and os.path.isfile(sp):
        got = json.load(open(sp, encoding="utf-8")).get(s.group(1))
        if got:
            print(f"   原谱站  {got['url']}   (已核对: {got.get('via')} · {got.get('t','')[:40]})")


def refresh():
    web = os.path.join(os.path.dirname(ROOT), "jianpu-web")
    print("重算索引 (parse_scores.py)…")
    r = subprocess.run([sys.executable, "parse_scores.py"], cwd=DB)
    if r.returncode:
        return r.returncode
    src = os.path.join(DB, "data.jsonl")
    dst = os.path.join(ROOT, "skills", "jianpu-melody-lookup", "data.jsonl")
    if os.path.isfile(dst):
        import shutil
        shutil.copyfile(src, dst)
        print("已同步 skill 的 data.jsonl")
    build = os.path.join(web, "tools", "build_web_data.py")
    if os.path.isfile(build):
        print("重建前端索引 (build_web_data.py)…")
        subprocess.run([sys.executable, build, "--data", src, "--out", os.path.join(web, "data")])
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("target", nargs="?", help="曲谱文件名或曲名(唯一匹配即可)")
    ap.add_argument("urls", nargs="*", help="收录页 URL(可多个; 搜索页会被拒收)")
    ap.add_argument("--show", action="store_true", help="只看现有链接, 不写")
    ap.add_argument("--from-tsv", help="批量: 每行 `<文件或曲名>\\t<URL>`")
    ap.add_argument("--dry", action="store_true", help="只校验, 不落盘")
    ap.add_argument("--no-refresh", action="store_true", help="写完不重算索引")
    a = ap.parse_args()

    jobs = []
    if a.from_tsv:
        for i, ln in enumerate(open(a.from_tsv, encoding="utf-8"), 1):
            ln = ln.strip()
            if not ln or ln.startswith("#"):
                continue
            parts = re.split(r"\t+", ln)
            if len(parts) < 2:
                print(f"  第 {i} 行格式不对(要 TAB 分隔): {ln[:60]}")
                continue
            jobs.append((parts[0], parts[1]))
    else:
        if not a.target:
            ap.error("要么给 <文件> <URL…>, 要么 --from-tsv")
        jobs.append((a.target, ",".join(a.urls)))

    if a.show and not a.from_tsv:
        show(resolve(a.target))
        return 0

    changed = 0
    for target, urls in jobs:
        try:
            fname = resolve(target)
            path = os.path.join(SCORES, fname)
            if a.dry:
                print(f"  [dry] {fname} <- {linkurl.parse_link(urls)}")
                continue
            added, already = linkurl.add_to_score_file(path, urls)
            changed += bool(added)
            tag = "已写入" if added else "已存在(未动)"
            print(f"  {tag}  {fname}: {added or already}")
        except (SystemExit, ValueError) as e:
            print(f"  跳过 {target!r}: {e}")
    if changed and not a.dry and not a.no_refresh:
        return refresh()
    if not a.dry:
        print("(没有新增, 不重算索引)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
