# -*- coding: utf-8 -*-
"""`to_jianpu_db.py` 重跑会不会**把现成成品的名字换给别人**？(只读, 不写任何文件)

为什么要查: 成品文件名按曲名定, 撞名才加 `_2` / `_3`, 加不加取决于
`sorted(batch-out/*.txt)` 的**遍历顺序**。往 batch-out 里新丢一批谱之后再整份重转,
新谱若排在前面就会**占掉**原来的 `X.txt`, 老谱被挤成 `X_2.txt`。而导入是"只拷不覆盖":
  * `X.txt` 在 db 里已存在 -> 新歌被**丢掉**;
  * `X_2.txt` 不在 db 里 -> 老歌被**再拷一份** -> 同一个内容出现两次。
所以"整份原地重转"不是无害操作, 必须先量出来。

做法(**不动磁盘**): 把 to_jianpu_db 的命名过程抄一遍, 跑两次 ——
  A) 全部 batch-out;  B) 只算"今天之前就存在的"旧 batch。
比较**旧文件**在 A/B 两次里拿到的名字: 名字变了的就是漂移受害者; 新谱里占了旧名字的
就是肇事者。全过程只读 + 只在内存里算。

用法:
    py -3.13 tools/check_convert_rename_drift.py            # 今天之前 = 旧
    py -3.13 tools/check_convert_rename_drift.py --days 2   # 两天之前 = 旧
"""
import argparse
import datetime
import glob
import io
import importlib.util
import os
import re
import sys

J2 = r"D:\Documents_D\jianpu2"
sys.path.insert(0, os.path.join(J2, "tools"))
os.chdir(J2)

from guard import guard_help        # noqa: E402
guard_help(__doc__)


def load_conv():
    """把 to_jianpu_db.py 当模块读进来(它有 __main__ 守卫, 不会跑 main)。"""
    spec = importlib.util.spec_from_file_location("to_jianpu_db", os.path.join(J2, "tools", "to_jianpu_db.py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def simulate(m, CLEAN, files):
    """抄 to_jianpu_db 的命名循环 -> {batch 名: 输出名}。太短的跳过(不占名)。"""
    used, out, short = set(), {}, 0
    for f in files:
        name = os.path.splitext(os.path.basename(f))[0]
        if name == "progress":
            continue
        try:
            toks = m.clean_tokens(io.open(f, encoding="utf-8", errors="replace").read())
        except OSError:
            continue
        if len(toks) < 10:
            short += 1
            continue
        title = CLEAN.get(name) or m.title_of(name)
        base = re.sub(r'[\\/:*?"<>|\s]+', "_", title).strip("_")[:60] or name
        safe, k = base, 2
        while safe in used:
            safe = f"{base}_{k}"
            k += 1
        used.add(safe)
        out[name] = safe
    return out, short


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=float, default=0.0, help="mtime 早于该天数算'旧谱'(0=今天之前)")
    ap.add_argument("--dir", default=os.path.join(J2, "jianpu-db-out", "scores"), help="现成成品目录")
    ap.add_argument("--top", type=int, default=15)
    a = ap.parse_args()

    m = load_conv()
    CLEAN = m.load_clean_titles_soft()
    cut = datetime.datetime.now().timestamp() - a.days * 86400
    if a.days == 0:
        cut = datetime.datetime.now().replace(hour=0, minute=0, second=0, microsecond=0).timestamp()

    files = sorted(glob.glob(os.path.join(J2, "batch-out", "*.txt")))
    old_files = [f for f in files if os.path.getmtime(f) < cut]
    new_files = [f for f in files if os.path.getmtime(f) >= cut]
    existing = {os.path.basename(p)[:-4] for p in glob.glob(os.path.join(a.dir, "*.txt"))}
    print(f"batch-out {len(files)} 个(旧 {len(old_files)} / 新 {len(new_files)})   现成成品 {len(existing)} 份")

    A, shortA = simulate(m, CLEAN, files)
    B, shortB = simulate(m, CLEAN, old_files)
    print(f"模拟 A(全部) {len(A)} 个名字, 跳过太短 {shortA}; 模拟 B(只有旧谱) {len(B)} 个, 跳过 {shortB}")

    drift = [(n, B[n], A[n]) for n in B if n in A and B[n] != A[n]]
    print()
    print(f"### 漂移: 老谱在'加了新谱之后'名字被换掉的有 **{len(drift)}** 首")
    for name, was, now in drift[:a.top]:
        print(f"   {was}.txt  ->  {now}.txt      (batch-out/{name}.txt)")
    if len(drift) > a.top:
        print(f"   ... 还有 {len(drift) - a.top} 首")

    # 肇事者: 新谱里拿到了"旧谱原本的名字"
    oldnames = set(B.values())
    steal = [(n, A[n]) for n in A if n not in B and A[n] in oldnames]
    print()
    print(f"### 肇事新谱: 占掉了旧名字的 **{len(steal)}** 首")
    for name, got in steal[:a.top]:
        print(f"   {got}.txt      <- batch-out/{name}.txt")
    if len(steal) > a.top:
        print(f"   ... 还有 {len(steal) - a.top} 首")

    # 结论: 现成成品里有多少名字会被换内容
    hit = [v for _n, _w, v in drift if v in existing]
    print()
    print(f"### 判读: 现成成品里有 {len(hit)} 份的名字会被新歌占用(内容被换), "
          f"{len(drift) - len(hit)} 份老谱只是改个后缀。")
    print("   非 0 -> **不要原地整份重转**; 只转新谱(隔离落点)再导。")


if __name__ == "__main__":
    main()
