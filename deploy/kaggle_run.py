# ============================================================
# Kaggle Notebook: 简谱批量转写 (jianpu2) —— 适配"已自动解压"的 input
# ------------------------------------------------------------
# Kaggle 设置(右侧 Session options):
#   Accelerator : GPU P100  (或 T4 x2)
#   Internet    : On
# 已挂载 Dataset: caesium132/jianpu2  (Kaggle 已把两个 zip 解压开)
#   /kaggle/input/datasets/caesium132/jianpu2/kaggle-tools/tools/*.py
#   /kaggle/input/datasets/caesium132/jianpu2/kaggle-images/images-prep/...
# ============================================================

import glob, os, shutil, subprocess, sys

BASE = "/kaggle/input/datasets/caesium132/jianpu2"
TOOLS_SRC = f"{BASE}/kaggle-tools"            # 里面有 tools/
IMAGES_SRC = f"{BASE}/kaggle-images"          # 里面有 images-prep/
WORK = "/kaggle/working"

# ---------- 0. 自检: 先看清 input 结构 ----------
print("=== input 结构 ===")
for root, dirs, files in os.walk(BASE):
    if root[len(BASE):].count(os.sep) > 1:
        continue
    print(" ", root, f"({len(files)} files)")

# ---------- 1. 代码拷到可写目录 ----------
os.makedirs(WORK, exist_ok=True)
if not os.path.exists(f"{WORK}/tools/batch_transcribe.py"):
    shutil.copytree(TOOLS_SRC, WORK, dirs_exist_ok=True)
print("tools 就绪:", len(glob.glob(f"{WORK}/tools/*.py")), "个 py")

# ---------- 1b. 关键: 把脚本里硬编码的 Windows 路径改成 Kaggle 路径 ----------
#   tools/*.py 里都有 os.chdir("D:/Documents_D/jianpu2") —— Linux 上不存在会直接报错
import re as _re
_patched = 0
for _f in glob.glob(f"{WORK}/tools/*.py"):
    _s = open(_f, encoding="utf-8").read()
    _s2 = _re.sub(r'os\.chdir\(\s*[\'"][A-Za-z]:[/\\\\][^\'"]*[\'"]\s*\)',
                  f'os.chdir("{WORK}")', _s)
    # 同时兜住 "D:/Documents_D/jianpu2" 出现在其它位置的写法
    _s2 = _s2.replace('D:/Documents_D/jianpu2', WORK).replace('D:\\\\Documents_D\\\\jianpu2', WORK)
    if _s2 != _s:
        open(_f, "w", encoding="utf-8").write(_s2)
        _patched += 1
print(f"路径补丁: 改了 {_patched} 个脚本")

# ---------- 1c. GPU 补丁(最重要!) ----------
#   原代码 AutoModel...from_pretrained(..., device_map=None, ...) 会把模型留在 CPU,
#   推理慢 10-50 倍。改成显式 .to("cuda")。
_f = f"{WORK}/tools/jp_transcribe.py"
_s = open(_f, encoding="utf-8").read()
_s = _s.replace(
    "MODEL, device_map=None, trust_remote_code=True, dtype=_dtype).eval()",
    "MODEL, trust_remote_code=True, dtype=_dtype).eval()\n"
    "    if torch.cuda.is_available():\n"
    "        _model = _model.to('cuda')\n"
    "    print(f'[jp] device={_model.device}', flush=True)"
)
if 'device_map=None' not in _s:
    open(_f, "w", encoding="utf-8").write(_s)
    print("GPU 补丁: 已应用")
else:
    print("GPU 补丁: 未匹配到目标字符串(可能已打过), 保持原样")

# ---------- 2. 谱图(input 只读) -> 软链接, 省时间省空间 ----------
link = f"{WORK}/images-prep"
if not os.path.exists(link):
    os.symlink(f"{IMAGES_SRC}/images-prep", link)
print("谱图:", len(glob.glob(f"{WORK}/images-prep/*/*/*.jpg")), "张")

# ---------- 3. 依赖 ----------
# 绝对不要用 -U: Kaggle 预装的 torch 带 P100(sm_60) 的 kernel,
# 一旦升级 torch, 在 P100 上会报 "no kernel image is available"。
subprocess.run(f"{sys.executable} -m pip install -q transformers accelerate", shell=True)

# ---------- 4. 模型(镜像加速) ----------
os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"
os.environ["HF_HUB_DISABLE_XET"] = "1"
MODEL_DIR = f"{WORK}/models/Qwen3-VL-2B-Instruct"
if not os.path.exists(f"{MODEL_DIR}/config.json"):
    subprocess.run(
        f"{sys.executable} -m pip install -q -U huggingface_hub && "
        f"hf download Qwen/Qwen3-VL-2B-Instruct --local-dir {MODEL_DIR}",
        shell=True)
print("模型就绪:", os.path.exists(f"{MODEL_DIR}/config.json"))

# ---------- 5. 环境变量 ----------
os.environ["QWEN_VL_MODEL"] = MODEL_DIR
os.environ["JP_DTYPE"] = "float16"     # Kaggle 的 P100/T4 不支持 bfloat16
os.environ["JP_BATCH"] = "8"
os.environ["JP_MAX_H"] = "3000"
os.environ["TOKENIZERS_PARALLELISM"] = "false"

# ---------- 6. 开始转写(断点续传: 已有 txt 自动跳过) ----------
os.chdir(WORK)
for p in glob.glob(f"{WORK}/rank-out/*.jsonl"):
    os.remove(p)                       # 没打包热度榜 -> 走"全目录"分支
subprocess.run(f"{sys.executable} tools/batch_transcribe.py 0 1700", shell=True)

# ---------- 7. 打包结果 ----------
subprocess.run("zip -q -r /kaggle/working/jianpu-out.zip batch-out", shell=True)
print("\n完成! 结果: /kaggle/working/jianpu-out.zip")
print("下载: 右上 Save Version -> 完成后在 Output 标签下载")
