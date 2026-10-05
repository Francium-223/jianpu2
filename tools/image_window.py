# -*- coding: utf-8 -*-
"""图片滑动窗口 —— **只删「已经转写进语料」的图目录**, 最旧优先, 删到空闲达标为止。

为什么需要它(2026-10-06 实测):
    * 本机只有**一块** NVMe, C:(350GiB)+D:(602.6GiB) 是同一块盘的两个分区 —— "搬到别的盘"不释放空间;
      抓取(jianpu.cn 39.6~53.5GiB / qupu123 声乐 86.5GiB / fysongs 22GiB)与转写流水线抢同一个卷。
    * 而 `images-prep/**/<曲名>__<站>-<id>` 这层图**只是转写的输入**: 一旦该谱已经转写进语料,
      图本身就没有再留的价值(`jianpu-db/scores/*.txt` 里 `source=<站>-<id>` 就是"已转写"的凭据)。
      于是按"最旧先删、删到够用"的**滑动窗口**回收, 而不是一刀切删整个图库。

判定口径(缺一不可, 全部当场实测, 不做推理):
    可删 = 目录名匹配 `__<站>-<id>$`  **且** `source=<站>-<id>` 出现在 `jianpu-db/scores/*.txt` 里
           **且** 不在保留区。
    保留区(绝不删):
      ① `_analysis/qa_lists/{qa_lowconf,qa_fragments}.txt` 点名的那批曲子(低置信 161 + 碎片 29),
         按"清单里的谱文件名 -> 该谱 txt 的 source=" 精确映射到图目录;
      ② 最近 `--fresh-days`(默认 7)天内落盘的目录;
      ③ 语料里查不到对应 `source=` 的目录(没转写 / 转写没入库 / 站点没进语料 —— 一律当"不确定"不删);
      ④ 判定时刻**正在被进程读或写**的目录: 扫描运行中的 python 命令行里出现的 `images-prep\\<组>` 前缀,
         外加"目录或其中任一文件的 mtime 在 10 分钟内"的兜底(与 `disk_cleanup_report.md` 同一条纪律)。

对外:
    --plan                       只算账: 可删多少目录 / 多少 GiB, 保留多少(分原因), 并写清单 TSV
    --apply --target-free-gib N  从最旧开始真删, 直到该卷空闲 >= N GiB(默认**干跑**, 要 `--no-dry-run` 才真删)
    --dry-run / --no-dry-run     干跑开关(**默认干跑**)
    --protect <相对路径>          临时把某个图目录或组目录加进保留区(可重复)
    --no-proc-scan               跳过进程扫描(仅在确认没有转写/抓取在跑时用)

台账(每删一个目录立刻落盘, **删之前**写, 免得半路崩了没账):
    D:\\Documents_D\\_analysis\\image_window_deleted.tsv
计划清单:
    D:\\Documents_D\\_analysis\\image_window_plan.tsv

用法:
    py -3.13 tools/image_window.py --plan
    py -3.13 tools/image_window.py --apply --target-free-gib 110            # 干跑, 看会删多少
    py -3.13 tools/image_window.py --apply --target-free-gib 110 --no-dry-run
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime

from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))      # …\jianpu2
IMAGES_ROOT = os.path.join(ROOT, "images-prep")
ANALYSIS = r"D:\Documents_D\_analysis"
LEDGER = os.path.join(ANALYSIS, "image_window_deleted.tsv")
PLAN_TSV = os.path.join(ANALYSIS, "image_window_plan.tsv")

# 语料(只读, 绝不动)
DB_ROOT = r"D:\Documents_D\jianpu-db"
CORPUS_SCORES = os.path.join(DB_ROOT, "scores")
QA_LISTS = os.path.join(ANALYSIS, "qa_lists")

# 目录名里的站点后缀(白名单, 免得把名字里的 `__` 当成站点分隔符)
SITES = ("jianpucn", "qupu123", "jianpujia", "jp114", "fysongs", "qinyipu")
NAME_RE = re.compile(r"__(" + "|".join(SITES) + r")-(\d+)$")
SOURCE_RE = re.compile(r"^source=(\S+)\s*$", re.M)

FRESH_DAYS = 7.0            # 保留区②: 最近这么多天落盘的不删
ACTIVE_MIN = 10.0           # 保留区④: mtime 在这个分钟数内的当"正在写入"
READ_HEAD = 8192            # 读谱 txt 头部多少字节就够拿到 source=


def now_str():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def free_gib(path):
    p = os.path.abspath(path)
    while p and not os.path.exists(p):
        parent = os.path.dirname(p)
        if parent == p:
            break
        p = parent
    return shutil.disk_usage(p).free / (1024.0 ** 3)


def read_source(score_path):
    """读谱 txt 的 `source=` 行(只看头部, 12k 份也很快)。"""
    try:
        with open(score_path, "rb") as f:
            head = f.read(READ_HEAD).decode("utf-8", "replace")
    except OSError:
        return ""
    m = SOURCE_RE.search(head)
    return m.group(1) if m else ""


def load_corpus_sources():
    """语料里所有 `source=` 值 = "已转写"凭据集合。只读, 不写。"""
    by_source = {}
    if not os.path.isdir(CORPUS_SCORES):
        raise SystemExit("找不到语料目录: %s" % CORPUS_SCORES)
    for name in os.listdir(CORPUS_SCORES):
        if not name.lower().endswith(".txt"):
            continue
        src = read_source(os.path.join(CORPUS_SCORES, name))
        if src:
            by_source.setdefault(src, name)
    return by_source


def load_qa_reserved(corpus_by_source):
    """qa_lists 点名的曲子 -> 保留的 source 集合。清单第三列是谱文件名。"""
    reserved, unresolved = set(), []
    if not os.path.isdir(QA_LISTS):
        return reserved, unresolved
    for name in sorted(os.listdir(QA_LISTS)):
        if not name.lower().endswith(".txt"):
            continue
        with open(os.path.join(QA_LISTS, name), "r", encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if not line.strip() or line.lstrip().startswith("#") or line.startswith("#"):
                    continue
                parts = [p for p in re.split(r"[\t ]+", line.strip()) if p]
                if len(parts) < 2:
                    continue
                score_name = parts[-1]              # 末列 = 谱文件名(形如 `小燕子_8.txt`)
                if not score_name.lower().endswith(".txt"):
                    continue
                src = read_source(os.path.join(CORPUS_SCORES, score_name))
                if src:
                    reserved.add(src)
                else:
                    unresolved.append((name, score_name))
    return reserved, unresolved


def active_prefixes():
    """扫描运行中的进程命令行, 取出 `images-prep\\<组>` 前缀 —— 正在被读/写的组目录。

    抓取进程会**新写**文件(靠 mtime 兜底), 而转写进程只**读**图目录(mtime 不会变),
    所以必须单独扫命令行, 否则会把正在转写的目录当"旧目录"删掉。
    """
    prefixes = set()
    ps = ("Get-CimInstance Win32_Process -Filter \"Name='python.exe' or Name='pythonw.exe' "
          "or Name='python3.exe'\" | Select-Object -ExpandProperty CommandLine")
    try:
        out = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", ps],
                             capture_output=True, text=True, timeout=30).stdout or ""
    except Exception as e:                                   # 扫不到就退化为"只用 mtime 兜底"
        return prefixes, "进程扫描失败(%s)" % type(e).__name__
    for line in out.splitlines():
        for m in re.finditer(r"images-prep[\\/]([^\"'\s\\/]+)", line):
            prefixes.add(m.group(1))
    return prefixes, ""


def walk_image_dirs():
    """列出 images-prep 下所有 `<曲名>__<站>-<id>` 目录(命中即不再往下走)。"""
    out = []
    if not os.path.isdir(IMAGES_ROOT):
        raise SystemExit("找不到图库: %s" % IMAGES_ROOT)
    for cur, dirs, _files in os.walk(IMAGES_ROOT):
        keep = []
        for name in dirs:
            if NAME_RE.search(name):
                path = os.path.join(cur, name)
                rel = os.path.relpath(path, IMAGES_ROOT)
                out.append((path, rel))
            else:
                keep.append(name)
        dirs[:] = keep
    return out


def dir_metrics(path):
    """(字节数, 文件数, 最新 mtime) —— 最新 mtime 取"目录本身 + 其中每个文件"的最大值。"""
    total = 0
    n = 0
    newest = os.path.getmtime(path)
    for cur, _dirs, files in os.walk(path):
        try:
            newest = max(newest, os.path.getmtime(cur))
        except OSError:
            pass
        for fn in files:
            fp = os.path.join(cur, fn)
            try:
                st = os.stat(fp)
            except OSError:
                continue
            total += st.st_size
            n += 1
            if st.st_mtime > newest:
                newest = st.st_mtime
    return total, n, newest


def classify(protect_extra, fresh_days, do_proc_scan):
    """把图目录分成 candidate / 各种保留桶。"""
    corpus = load_corpus_sources()
    qa_reserved, qa_unresolved = load_qa_reserved(corpus)
    prefixes, scan_note = (active_prefixes() if do_proc_scan else (set(), "已按 --no-proc-scan 跳过"))

    fresh_cut = time.time() - fresh_days * 86400.0
    cands, buckets = [], {
        "no_source": [],        # 语料里查不到 source=
        "qa": [],               # qa_lists 点名
        "fresh": [],            # 最近 fresh_days 天落盘
        "active": [],           # 进程正在读/写
        "other": [],            # 命名不合规等
    }
    for path, rel in walk_image_dirs():
        m = NAME_RE.search(os.path.basename(path))
        group = rel.split(os.sep)[0]
        if not m:
            buckets["other"].append((rel, 0))
            continue
        source = "%s-%s" % (m.group(1), m.group(2))
        try:
            nbytes, nfiles, newest = dir_metrics(path)
        except OSError:
            buckets["other"].append((rel, 0))
            continue
        rec = {"path": path, "rel": rel, "source": source, "bytes": nbytes,
               "files": nfiles, "newest": newest,
               "score": corpus.get(source, "")}
        if source not in corpus:
            buckets["no_source"].append((rel, nbytes))
        elif source in qa_reserved:
            buckets["qa"].append((rel, nbytes))
        elif group in prefixes or rel in protect_extra or group in protect_extra:
            buckets["active"].append((rel, nbytes))
        elif newest >= fresh_cut:
            buckets["fresh"].append((rel, nbytes))
        else:
            cands.append(rec)
    # 最旧优先: 先按"目录内最新 mtime"升序, 同刻按 (站点, id) 升序
    cands.sort(key=lambda r: (r["newest"], r["source"]))
    return cands, buckets, corpus, qa_reserved, qa_unresolved, prefixes, scan_note


def gib(n):
    return n / (1024.0 ** 3)


def write_plan_tsv(cands, buckets):
    lines = ["# 图片滑动窗口计划清单 (image_window_plan.tsv)",
             "# 生成时间\t%s" % now_str(),
             "# 口径\tsource=<站>-<id> 已在 jianpu-db/scores/*.txt 里 且 不在保留区(qa_lists/最近7天/正在读写/语料查不到)",
             "status\trel_path\tsource\tbytes\tfiles\tnewest\tscore_file"]
    for r in cands:
        lines.append("CANDIDATE\t%s\t%s\t%d\t%d\t%s\t%s" % (
            r["rel"], r["source"], r["bytes"], r["files"],
            datetime.fromtimestamp(r["newest"]).strftime("%Y-%m-%d %H:%M:%S"), r["score"]))
    for key in ("no_source", "qa", "fresh", "active", "other"):
        for rel, nbytes in buckets[key]:
            lines.append("RESERVED_%s\t%s\t\t%d\t\t\t" % (key.upper(), rel, nbytes))
    os.makedirs(ANALYSIS, exist_ok=True)
    with open(PLAN_TSV, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def print_plan(cands, buckets, corpus, qa_reserved, qa_unresolved, prefixes, scan_note, free):
    tot = sum(r["bytes"] for r in cands)
    print("[image-window] 图库 %s" % IMAGES_ROOT)
    print("[image-window] 语料凭据 source= 共 %d 条(读自 %s)" % (len(corpus), CORPUS_SCORES))
    print("[image-window] 保留区: qa_lists 点名 %d 个 source%s / 正在读写组 %d 个 %s%s"
          % (len(qa_reserved),
             ("(清单里有 %d 条找不到对应谱 txt)" % len(qa_unresolved)) if qa_unresolved else "",
             len(prefixes), sorted(prefixes) if prefixes else "",
             ("  [%s]" % scan_note) if scan_note else ""))
    print("[image-window] 可删: %d 个目录 / %.2f GiB" % (len(cands), gib(tot)))
    order = sorted({r["rel"].split(os.sep)[0] for r in cands})
    print("[image-window]   分布在 %d 个组: %s" % (len(order), ", ".join(order[:12]) + (" …" if len(order) > 12 else "")))
    print("[image-window] 保留: " + " / ".join(
        "%s %d个 %.2fGiB" % (k, len(buckets[k]), gib(sum(b for _r, b in buckets[k])))
        for k in ("no_source", "qa", "fresh", "active", "other")))
    print("[image-window] 最旧 10 个待删(先删它们):")
    for r in cands[:10]:
        print("    %s  %8.2f MB  mtime=%s" % (
            r["rel"], r["bytes"] / 1048576.0,
            datetime.fromtimestamp(r["newest"]).strftime("%Y-%m-%d %H:%M")))
    print("[image-window] 当前 %s 空闲 %.2f GiB" % (os.path.splitdrive(IMAGES_ROOT)[0], free))


def ledger_row(rel, nbytes, nfiles, source, score):
    with open(LEDGER, "a", encoding="utf-8", newline="\n") as f:
        f.write("%s\t%s\t%d\t%d\t%s\t%s\t已转写进语料(source=%s 见 %s), 非保留区, 最旧优先\n" % (
            now_str(), os.path.join(IMAGES_ROOT, rel), nbytes, nfiles, source, score, source, score))


def apply_window(cands, buckets, target_gib, dry_run, limit_print=15):
    """从最旧开始删, 直到空闲 >= target_gib。返回 (删了目录数, 释放字节, 空闲 GiB)。"""
    free = free_gib(IMAGES_ROOT)
    free_before = free
    print("[image-window] 目标: 空闲 >= %.2f GiB, 现在 %.2f GiB (模式: %s)"
          % (target_gib, free, "干跑" if dry_run else "真删"))
    if free >= target_gib:
        print("[image-window] 已经达标, 不动任何图目录。")
        return 0, 0, free
    if not os.path.isdir(ANALYSIS):
        os.makedirs(ANALYSIS, exist_ok=True)
    if not dry_run and not os.path.exists(LEDGER):
        with open(LEDGER, "w", encoding="utf-8", newline="\n") as f:
            f.write("# 图片滑动窗口删除台账 (image_window_deleted.tsv)\n"
                    "# 列\tts 首删时间 / dir 目录 / bytes 字节 / files 文件数 / source 语料凭据 / score_file 凭据文件 / basis 依据\n")

    active_cut = time.time() - ACTIVE_MIN * 60.0
    n_done = n_skip = 0
    freed = 0
    for r in cands:
        # 干跑时按"已删字节"模拟空闲, 这样干跑报的数就是真删会得到的数
        cur_free = free + gib(freed) if dry_run else free_gib(IMAGES_ROOT)
        if cur_free >= target_gib:
            break
        rel, path = r["rel"], r["path"]
        # 安全闸(逐条再验一遍, 廉价)
        ap = os.path.abspath(path)
        if not ap.startswith(IMAGES_ROOT + os.sep) or not NAME_RE.search(os.path.basename(ap)):
            print("    !! 跳过(越界或命名不合规): %s" % rel)
            n_skip += 1
            continue
        try:                                    # 兜底: 当场再看一次 mtime(计划是几分钟前算的)
            _b, _n, newest = dir_metrics(path)
        except OSError:
            n_skip += 1
            continue
        if newest >= active_cut:
            print("    -- 跳过(10 分钟内被写入): %s" % rel)
            n_skip += 1
            continue
        if dry_run:
            if n_done < limit_print:
                print("    (干跑)将删 %s  %.2f MB  依据 source=%s" % (rel, r["bytes"] / 1048576.0, r["source"]))
            n_done += 1
            freed += r["bytes"]
            continue
        ledger_row(rel, r["bytes"], r["files"], r["source"], r["score"])   # 先记账, 再删
        try:
            shutil.rmtree(path, ignore_errors=False)
        except OSError as e:
            print("    !! 删除失败 %s -> %s" % (rel, e))
            n_skip += 1
            continue
        n_done += 1
        freed += r["bytes"]
    free = free_gib(IMAGES_ROOT)
    print("[image-window] %s: %d 个目录 / %.2f GiB (跳过 %d 个), 空闲 %.2f -> %.2f GiB"
          % ("将删" if dry_run else "已删", n_done, gib(freed), n_skip, free_before, free))
    if dry_run and n_done > limit_print:
        print("    (干跑只打印前 %d 个, 实际会删 %d 个)" % (limit_print, n_done))
    return n_done, freed, free


def main(argv=None):
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="图片滑动窗口: 只删已转写进语料的图目录", add_help=False)
    ap.add_argument("--plan", action="store_true", help="只算账(可删清单/保留统计), 并写计划 TSV")
    ap.add_argument("--apply", action="store_true", help="执行回收(默认干跑, 要 --no-dry-run 才真删)")
    ap.add_argument("--target-free-gib", type=float, default=110.0, help="删到该卷空闲达到这个 GiB(默认 110)")
    ap.add_argument("--dry-run", action="store_true", default=True, help="干跑(默认开启)")
    ap.add_argument("--no-dry-run", dest="dry_run", action="store_false", help="真的删")
    ap.add_argument("--fresh-days", type=float, default=FRESH_DAYS, help="最近这么多天落盘的保留(默认 7)")
    ap.add_argument("--protect", action="append", default=[], help="临时加进保留区的相对路径(可重复)")
    ap.add_argument("--no-proc-scan", action="store_true", help="跳过「正在被进程读写」的扫描")
    ap.add_argument("--quiet-plan-tsv", action="store_true", help="不写 image_window_plan.tsv")
    ap.add_argument("-h", "--help", action="help", help="显示本帮助")
    args = ap.parse_args(argv)

    free = free_gib(IMAGES_ROOT)
    cands, buckets, corpus, qa_reserved, qa_unresolved, prefixes, scan_note = classify(
        set(args.protect), args.fresh_days, not args.no_proc_scan)
    print_plan(cands, buckets, corpus, qa_reserved, qa_unresolved, prefixes, scan_note, free)
    if not args.quiet_plan_tsv:
        write_plan_tsv(cands, buckets)
        print("[image-window] 清单已写 %s" % PLAN_TSV)

    if args.apply:
        apply_window(cands, buckets, args.target_free_gib, args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
