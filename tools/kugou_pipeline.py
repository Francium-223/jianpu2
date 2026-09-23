# -*- coding: utf-8 -*-
"""转写完成 -> 入库 -> 重建索引 -> 重测酷狗榜单覆盖率。一条龙(可后台跑)。

步骤:
  1. 等当前 transcribe_dirs 跑完(轮询 batch-out 里的目标目录是否都产出了, 或进程消失)
  2. 把 batch-out/*.txt(裸 token) 转成 jianpu-db 的 scores/*.txt, 并**同步进 jianpu-db**
  3. 在 jianpu-db 里跑 parse_scores.py 重建 data.json / data.jsonl / by_*
  4. 重跑 eval_golden.py(酷狗 2025 榜) 与三套榜单, 把数字写进报告

注意: 这个脚本**只做本次补漏的增量**(不跑 finalize 那套 6 分钟的重建整个语料管线的活,
那种活交给 absorb2/3)。同步方式: 只把本批对应的 scores 文件复制过去, 再在库侧重建索引。
"""
import glob
import io
import json
import os
import re
import shutil
import subprocess
import sys
import time

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
DB = r"D:\Documents_D\jianpu-db"
SRC_DIR = "images-prep/qupu123-search"
REPORT = "train-work/kugou_improve_report.md"

sys.path.insert(0, "tools")
import batch_transcribe as BT  # noqa: E402


def say(msg):
    line = f"{time.strftime('%H:%M:%S')}  {msg}"
    print(line, flush=True)
    with io.open("train-work/kugou_pipeline.log", "a", encoding="utf-8") as g:
        g.write(line + "\n")


def wait_transcribe():
    """等到目标目录都有 batch-out 产物(或疑似已停)。"""
    want = {BT.safe_name(os.path.basename(d)) for d in glob.glob(SRC_DIR + "/*") if os.path.isdir(d)}
    t0 = time.time()
    while time.time() - t0 < 4 * 3600:
        got = {os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")}
        missing = want - got
        if not missing:
            return True
        # 没有任何转写进程在跑 -> 停了
        r = subprocess.run(["powershell", "-NoProfile", "-Command",
                            "(Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | "
                            "Where-Object { $_.CommandLine -like '*transcribe_dirs*' } | Measure-Object).Count"],
                           capture_output=True, text=True)
        n = (r.stdout or "0").strip()
        say(f"  还在转: 已有 {len(want)-len(missing)}/{len(want)}, 剩 {len(missing)}  (转写进程 {n})")
        if n == "0":
            say(f"  转写进程已退出, 按现状继续(缺 {len(missing)})")
            return False
        time.sleep(120)
    return False


def to_score(name, toks, source_hint=""):
    """裸 token -> jianpu-db 的曲谱文本(带 source=)。"""
    title = re.sub(r"__.*$", "", name)
    try:
        import to_jianpu_db as T
        return T.to_score(name, toks, "jianpu2-auto")
    except Exception:
        pass
    # 兜底: 手写最小格式
    lines = [f"%{name}.txt", f"title={title}", "tag=", "usertag=", "tagroute=",
             "transcriber=jianpu2-auto", "status=ocr", "%--", "4/4", "subtitle=score"]
    lines.append(" ".join(toks))
    lines.append("%END")
    return "\n".join(lines) + "\n"


def import_to_db():
    """把本批新产物转成曲谱并同步进 jianpu-db/scores。"""
    names = {BT.safe_name(os.path.basename(d)) for d in glob.glob(SRC_DIR + "/*") if os.path.isdir(d)}
    n = 0
    for f in glob.glob("batch-out/*.txt"):
        base = os.path.basename(f)[:-4]
        if base not in names:
            continue
        toks = io.open(f, encoding="utf-8").read().split()
        if not toks:
            continue
        txt = to_score(base, toks)
        out = os.path.join(DB, "scores", f"{base}.txt")
        if os.path.exists(out):
            continue
        with io.open(out, "w", encoding="utf-8", newline="\n") as g:
            g.write(txt)
        n += 1
    return n


def rebuild_db():
    r = subprocess.run([sys.executable, "-u", "parse_scores.py"], cwd=DB,
                       capture_output=True, text=True)
    tail = [x for x in (r.stdout or "").splitlines() if x.strip()][-3:]
    return r.returncode, tail


def measure():
    out = []
    sets = ["eval_set_kugou_hualiu_2025", "eval_set_cn_pop_100classics", "eval_set_cma_30years30songs"]
    for s in sets:
        r = subprocess.run([sys.executable, "eval_golden.py", "--list",
                            rf"D:\Documents_D\jianpu2\train-work\{s}.tsv",
                            "--lens", "11,15", "--errs", "0"],
                           cwd="skills/jianpu-melody-lookup", capture_output=True, text=True)
        out.append(f"### {s}\n```\n{(r.stdout or '').strip()}\n```\n")
    return out


def main():
    say("=== 酷狗补漏流水线开始 ===")
    wait_transcribe()
    n = import_to_db()
    say(f"入库新增 {n} 首")
    rc, tail = rebuild_db()
    say(f"重建索引 退出码 {rc}: {tail}")
    blocks = measure()
    with io.open(REPORT, "w", encoding="utf-8", newline="\n") as g:
        g.write("# 酷狗 2025 华流 Top100 补漏后复测\n\n")
        g.write(f"生成时间: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        for b in blocks:
            g.write(b + "\n")
    say(f"完成 -> {REPORT}")
    print("\n".join(blocks), flush=True)


if __name__ == "__main__":
    main()
