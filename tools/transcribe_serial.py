# -*- coding: utf-8 -*-
"""逐张转写(每张一个 python 进程), 带超时与进度打印。

为什么要这样: 批量跑时一旦某张图卡住(实测 GPU 0% 但占着 5GB 显存、日志停在 `[2/95]`),
整批就死在那里, 而且看不出是哪张。逐张跑 + 超时 = 卡住的那张会被跳过并记名, 其余照跑。

用法:
  py -3.13 tools/transcribe_serial.py images-prep/qupu123-search [--timeout 300] [--limit 0]
"""
import argparse
import glob
import io
import os
import subprocess
import sys
import time

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("--timeout", type=int, default=300)
ap.add_argument("--limit", type=int, default=0)
a = ap.parse_args()

dirs = sorted(d for d in glob.glob(os.path.join(a.src, "*")) if os.path.isdir(d))
if a.limit:
    dirs = dirs[:a.limit]
have = {os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")}
todo = [d for d in dirs if os.path.basename(d) not in have]
print(f"{a.src}: 共 {len(dirs)} 个目录, 其中已有产物 {len(dirs)-len(todo)}, 待转 {len(todo)}", flush=True)

ok = skip = fail = 0
log = open("train-work/transcribe_serial.log", "a", encoding="utf-8")
for i, d in enumerate(todo, 1):
    name = os.path.basename(d)
    t0 = time.time()
    print(f"[{i}/{len(todo)}] {name[:50]} ...", flush=True)
    try:
        # **不能 capture_output=True**: 沙箱下程序无法开命名管道, 子进程的 stdout/stderr
        # 走管道会被 EPERM 拦掉 -> 子进程静默失败, 出现"完成 0/0、91 张全空"的假象(实测踩过)。
        # 改成把输出**重定向到文件**, 用文件句柄传给子进程。
        with open("train-work/_one_transcribe.log", "w", encoding="utf-8") as fh:
            r = subprocess.run([sys.executable, "tools/transcribe_source.py", d],
                               stdout=fh, stderr=subprocess.STDOUT, timeout=a.timeout)
        try:
            out = io.open("train-work/_one_transcribe.log", encoding="utf-8", errors="replace").read()
        except Exception:
            out = ""
        tag = "OK" if os.path.exists(f"batch-out/{name}.txt") else "空"
        ok += (tag == "OK")
        skip += (tag == "空")
        tail = [x for x in out.splitlines() if x.strip()][-1:] or [""]
        print(f"    -> {tag}  {time.time()-t0:.0f}s  {tail[0][:70]}", flush=True)
        log.write(f"{name}\t{tag}\t{time.time()-t0:.0f}s\n")
    except subprocess.TimeoutExpired:
        fail += 1
        print(f"    -> **超时 {a.timeout}s(疑似卡死)**", flush=True)
        log.write(f"{name}\tTIMEOUT\t{a.timeout}s\n")
        # 杀掉可能残留的 python 子进程占显存
        os.system('taskkill /F /IM python.exe /FI "MEMUSAGE gt 2000000" >nul 2>&1')
        time.sleep(5)
    log.flush()
log.close()
print(f"\n完成: 成功 {ok} / 空结果 {skip} / 超时 {fail}   (日志 train-work/transcribe_serial.log)")
