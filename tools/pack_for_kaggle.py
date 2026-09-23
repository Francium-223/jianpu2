# -*- coding: utf-8 -*-
"""打包 Kaggle 部署所需文件:
  1) deploy/kaggle-images.zip  —— 仅 ranked 谱列表里用到的谱图(上传为 Kaggle Dataset)
  2) deploy/kaggle-tools.zip   —— tools/ 下的代码
  3) deploy/kaggle_run.py      —— Kaggle notebook 里直接粘贴运行的脚本
用法: py -3.13 tools/pack_for_kaggle.py
"""
import glob, json, os, re, sys, zipfile
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.makedirs("deploy", exist_ok=True)


def safe_rel(p):
    """Kaggle 对 zip 内文件名有禁字符(单引号/双引号/括号等) -> 逐段替换为下划线。
    注意: 只改 zip 里的名字, 本地文件不动; kaggle_run.py 不依赖原始目录名。"""
    parts = p.replace("\\", "/").split("/")
    return "/".join(re.sub(r"""['"()\[\]{}<>|:*?]""", "_", x) for x in parts)


# 1) 收集 ranked 目录
dirs = set()
for f in glob.glob("rank-out/ranked*.jsonl"):
    for line in open(f, encoding="utf-8"):
        try:
            dirs.add(os.path.dirname(json.loads(line)["img"]))
        except Exception:
            pass
print(f"ranked 谱目录: {len(dirs)}")

# 2) 打包谱图(保留相对路径)
n_img = 0
with zipfile.ZipFile("deploy/kaggle-images.zip", "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for d in sorted(dirs):
        for p in sorted(glob.glob(os.path.join(d, "*.jpg"))):
            # 只打包该目录最大的那张(谱页), 与 pick_page 一致
            pass
        files = sorted(glob.glob(os.path.join(d, "*.jpg")), key=os.path.getsize)
        if not files:
            continue
        page = files[-1]
        z.write(page, safe_rel(os.path.relpath(page, ".")))
        n_img += 1
print(f"打进 {n_img} 张谱图")

# 3) 打包代码
with zipfile.ZipFile("deploy/kaggle-tools.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for p in sorted(glob.glob("tools/*.py")):
        z.write(p, os.path.relpath(p, ".").replace("\\", "/"))
print("代码已打包")

for f in ["deploy/kaggle-images.zip", "deploy/kaggle-tools.zip"]:
    print(f"  {f}: {os.path.getsize(f)/1024/1024:.1f} MB")
