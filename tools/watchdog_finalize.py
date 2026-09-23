# -*- coding: utf-8 -*-
"""看门狗: 等转写进程结束后自动跑收尾流水线(finalize.py)。
判据: batch-out 的 txt 数连续 4 分钟不变 + 没有 python 在跑。
用法: py tools/watchdog_finalize.py   (放后台)
"""
import glob, os, subprocess, sys, time
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

def nt():
    return len(glob.glob("batch-out/*.txt"))

def py_running():
    r = subprocess.run(["tasklist", "/FI", "IMAGENAME eq python.exe"],
                       capture_output=True, text=True, errors="replace")
    return "python.exe" in (r.stdout or "")

last, stable = nt(), 0
print(f"看门狗启动, 当前 {last} 个 txt", flush=True)
while True:
    time.sleep(60)
    n = nt()
    if n == last and not py_running():
        stable += 1
    else:
        stable = 0
    last = n
    if stable >= 4:
        print(f"转写已结束({n} 个), 开始收尾", flush=True)
        break
    if stable and stable % 1 == 0:
        print(f"  {n} 个, 静止 {stable} 分钟", flush=True)

r = subprocess.run([sys.executable, "tools/finalize.py"],
                   capture_output=True, text=True, encoding="utf-8", errors="replace")
print((r.stdout or "")[-2500:], flush=True)
print("看门狗完成", flush=True)
