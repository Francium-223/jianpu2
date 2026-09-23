#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""jianpu2 简谱转写生产线 —— 统一入口。

从任何目录运行都可以(根路径自动发现):
    py -3.13 run.py crawl 400      # 爬 jianpu.cn 的流行歌
    py -3.13 run.py transcribe     # 增量转写(已存在的跳过)
    py -3.13 run.py finalize       # 收尾: 纯度过滤→版本择优→重建 scores→下游
    py -3.13 run.py verify         # 交付物总验收(7 项)
    py -3.13 run.py stats          # 语料统计
    py -3.13 run.py gt             # GT 评测(用 train-work/gt 的图+同名txt)
    py -3.13 run.py detect         # 重扫全库纯度
    py -3.13 run.py eta            # 当前批次还剩多少
    py -3.13 run.py find 33565653253   # 旋律反查(只输数字, 模糊匹配, 段落加权)
    py -3.13 run.py all            # 全自动: 等转写→收尾→评测→再爬→转写→再收尾→验收

配置见 pipeline.toml(可删, 有默认值)。
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.join(ROOT, "tools")
sys.path.insert(0, TOOLS)
try:
    from jp_root import cfg
except Exception:
    def cfg(*a, **k):
        return k.get("default")

PY = sys.executable

# 要用 GPU 的命令 —— 跑之前必须确认没有别的进程占着显存, 否则两个模型同时加载会 OOM
GPU_CMDS = {"transcribe", "gt", "finalize", "all", "finish"}


def _is_pipeline_python(cmdline):
    """这个 python 进程是不是"会抢显存的管线进程"。

    **不能只看"有没有 python.exe"** —— 实测用户常驻三个 `python -m http.server`
    (截图预览) 和 IDLE, 只看镜像名会让本判据**永远为真**, 于是 finalize/stats/verify
    静默地被拒(退出码 3), 而人不在旁边根本看不出来(2026-09-20 夜实际踩到:
    转写跑完后 finalize 连拒两次, scores 没重建, verify 报"未通过")。

    故改为按**命令行关键词**判: 只有跑本项目管线/训练脚本的 python 才算占显存。"""
    c = (cmdline or "").lower().replace("\\", "/")
    if any(b in c for b in ("http.server", "idlelib", "idle.py", "ipykernel", "jupyter")):
        return False
    keys = ("jp_transcribe", "batch_transcribe", "transcribe_source", "transcribe_priority",
            "transcribe_qwen", "transcribe_newartists", "kind_detect", "finalize.py",
            "train", "finetune", "lora", "run.py", "/tools/")
    return any(k in c for k in keys)


def other_python_running():
    """是否有**别的管线 python** 在跑(排除自己)。用于防"两个模型抢显存"。"""
    try:
        ps = ("Get-CimInstance Win32_Process -Filter \"Name like '%python%'\" | "
              "ForEach-Object { \"$($_.ProcessId)|$($_.CommandLine)\" }")
        r = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", ps],
                           capture_output=True, text=True, errors="replace")
    except Exception:
        return False
    me = os.getpid()
    for line in (r.stdout or "").splitlines():
        line = line.strip()
        if "|" not in line:
            continue
        pid_s, cmd = line.split("|", 1)      # 命令里可能自带 '|', 只切第一个
        try:
            pid = int(pid_s.strip())
        except ValueError:
            continue
        if pid == me:
            continue
        if _is_pipeline_python(cmd):
            return True
    return False


def gpu_free_enough():
    """显存够不够(粗略: 已用 < 5GB 视为能再起一个 2B 模型)。查不到就放行。"""
    try:
        r = subprocess.run(["nvidia-smi", "--query-gpu=memory.used", "--format=csv,noheader,nounits"],
                           capture_output=True, text=True, errors="replace")
        used = int((r.stdout or "0").strip().splitlines()[0])
        return used < 5000
    except Exception:
        return True


def env():
    """把 pipeline.toml 的参数转成环境变量, 供各脚本读取(免去手工 export)。"""
    e = dict(os.environ)
    e.setdefault("TOKENIZERS_PARALLELISM", "false")
    mp = cfg("model", "path", default="") or ""
    if mp:
        e["QWEN_VL_MODEL"] = mp
    e["JP_BATCH"] = str(cfg("model", "batch", default=8))
    e["JP_MAX_H"] = str(cfg("transcribe", "max_h", default=5000))
    e["JP_MAXW"] = str(cfg("transcribe", "max_w", default=2000))
    e["JP_MINW"] = str(cfg("transcribe", "min_w", default=950))
    e["JP_SMALLW"] = str(cfg("transcribe", "small_w", default=1200))
    e["JP_X_RECHECK"] = "1" if cfg("transcribe", "x_recheck", default=True) else "0"
    e["JP_KINDFILTER"] = "1" if cfg("purity", "enabled", default=True) else "0"
    e["JP_BADLINE"] = str(cfg("purity", "badline", default=5))
    return e


def run(args, label=None):
    print(f"\n>>> {' '.join(args)}" + (f"   [{label}]" if label else ""), flush=True)
    r = subprocess.run([PY] + args, cwd=ROOT, env=env())
    return r.returncode


CMDS = {
    "crawl":      lambda a: [os.path.join(TOOLS, "crawl_pop.py")] + (a or ["400", "40"]),
    "transcribe": lambda a: [os.path.join(TOOLS, "transcribe_source.py")] + (a or ["images-prep/jianpucn-pop"]),
    "detect":     lambda a: [os.path.join(TOOLS, "kind_detect2.py")] + a,
    "finalize":   lambda a: [os.path.join(TOOLS, "finalize.py")] + a,
    "verify":     lambda a: [os.path.join(TOOLS, "verify_deliverable.py")] + a,
    "stats":      lambda a: [os.path.join(TOOLS, "full_stats.py")] + a,
    "gt":         lambda a: [os.path.join(TOOLS, "eval_gt_images.py")] + a,
    "eta":        lambda a: [os.path.join(TOOLS, "batch_eta.py")] + a,
    "find":       lambda a: [os.path.join(TOOLS, "melody_find.py")] + a,
    "all":        lambda a: [os.path.join(TOOLS, "autopilot.py")] + a,
    "finish":     lambda a: [os.path.join(TOOLS, "finish.py")] + a,
}

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "help"):
        print(__doc__)
        print("可用命令: " + " | ".join(CMDS))
        return 0
    cmd = sys.argv[1]
    if cmd not in CMDS:
        print(f"未知命令: {cmd}\n可用: {' | '.join(CMDS)}")
        return 2
    # 防"两个模型抢显存": GPU 命令前先查(实测踩过 —— 转写跑着时又起一个, 显存 7708/8188)
    if cmd in GPU_CMDS and os.environ.get("JP_FORCE", "") != "1":
        if other_python_running() or not gpu_free_enough():
            print(f"[拒绝] 有别的 python 在跑或显存已被占用 —— 再起一个模型会 OOM。\n"
                  f"       确认要强制跑就设 JP_FORCE=1。\n"
                  f"       查看: py -3.13 run.py eta / nvidia-smi")
            return 3
    return run(CMDS[cmd](sys.argv[2:]), label=cmd)

if __name__ == "__main__":
    sys.exit(main())
