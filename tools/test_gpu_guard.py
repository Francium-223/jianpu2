# -*- coding: utf-8 -*-
"""GPU 守卫的回归测试: 别把"跟显存无关的 python"当成占显存的管线进程。

背景(2026-09-20 夜实际踩到): 用户常驻三个 `python -m http.server`(截图预览),
原来的 `other_python_running()` 只看镜像名, 于是**永远为真** -> finalize 连拒两次
(退出码 3), scores 没重建, verify 报"未通过", 而人不在旁边看不出来。

用法: py -3.13 tools/test_gpu_guard.py
"""
import os
import sys

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(_ROOT)
sys.path.insert(0, _ROOT)
sys.stdout.reconfigure(encoding="utf-8")
import run

CASES = [
    ("用户常驻预览服务", r"C:\Python314\python.exe -m http.server 8765 --bind 127.0.0.1", False),
    ("IDLE 编辑器", r"C:\Python314\pythonw.exe -c __import__('idlelib.run').run.main(True) 16555", False),
    ("jupyter 内核", r"python -m ipykernel_launcher -f kernel.json", False),
    ("本管线转写(批量)", r"py -3.13 tools/transcribe_source.py train-work/purity2_admit.txt", True),
    ("本管线 finalize", r"py -3.13 tools/finalize.py", True),
    ("本管线单图", r"py -3.13 D:\Documents_D\jianpu2\tools\jp_transcribe.py a.jpg", True),
    ("本管线纯度扫描", r"py -3.13 tools/kind_detect2.py", True),
    ("本管线 run.py", r"py -3.13 run.py transcribe", True),
    ("训练脚本", r"python train_lora.py --epochs 3", True),
    ("别的项目训练", r"python C:\other\mytrain.py", True),
]


def main():
    ok = 0
    for name, cmd, want in CASES:
        got = run._is_pipeline_python(cmd)
        mark = "✓" if got == want else "✗"
        if got == want:
            ok += 1
        print(f"  {mark} {name:16s} -> {'算占显存' if got else '忽略'}")
    print(f"  {ok}/{len(CASES)} 判对")
    live = run.other_python_running()
    free = run.gpu_free_enough()
    print(f"\n当前 other_python_running() = {live}   gpu_free_enough() = {free}")
    print("  （只作参考, 不参与判定: 管线正在跑时 other 本就该是 True）")
    print("  守卫是否放行 = (not other) and free"
          f"  -> 现在{'会放行' if (not live) and free else '会拒绝'}")
    return 0 if ok == len(CASES) else 1


if __name__ == "__main__":
    sys.exit(main())
