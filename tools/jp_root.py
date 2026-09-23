# -*- coding: utf-8 -*-
"""可迁移的根路径与配置中心。

原先把 `D:/Documents_D/jianpu2` 硬编码在 20+ 个脚本里, 换台机器就跑不起来。
现在改成: 从本文件位置**自动推断仓库根**(本文件在 <root>/tools/ 下), 不需要任何配置。

    from jp_root import ROOT, chdir_root
    chdir_root()          # 切到仓库根, 并把 <root>/tools 加进 sys.path

配置(模型路径、外部仓库、阈值)从 <root>/pipeline.toml 读; 没有该文件时用默认值,
所以**开箱即用**, 迁移时只改 pipeline.toml。
"""
import os
import sys

# <root>/tools/jp_root.py -> <root>
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools")

_cfg = None

def _load_toml():
    global _cfg
    if _cfg is not None:
        return _cfg
    _cfg = {}
    p = os.path.join(ROOT, "pipeline.toml")
    if os.path.exists(p):
        try:
            try:
                import tomllib                      # Python 3.11+
            except ImportError:
                import tomli as tomllib             # 兼容
            with open(p, "rb") as f:
                _cfg = tomllib.load(f)
        except Exception as e:
            print(f"[jp_root] 读 {p} 失败, 用默认值: {e}", file=sys.stderr)
            _cfg = {}
    return _cfg

def cfg(*keys, default=None):
    """取配置: cfg("paths", "batch_out", default="batch-out")"""
    d = _load_toml()
    for k in keys:
        if not isinstance(d, dict) or k not in d:
            return default
        d = d[k]
    return d

def chdir_root():
    """切到仓库根 + 把 tools 加进 sys.path(替代原脚本里硬编码的 chdir)。"""
    os.chdir(ROOT)
    if TOOLS not in sys.path:
        sys.path.insert(0, TOOLS)
    return ROOT

# 常用子目录(可用 pipeline.toml 覆盖)
def path(key, default):
    v = cfg("paths", key, default=default)
    return v if os.path.isabs(v) else os.path.join(ROOT, v)

if __name__ == "__main__":
    print(f"ROOT      = {ROOT}")
    print(f"TOOLS     = {TOOLS}")
    print(f"pipeline.toml = {'有' if os.path.exists(os.path.join(ROOT, 'pipeline.toml')) else '无(用默认值)'}")
    for k, d in (("images_dir", "images-prep"), ("batch_out", "batch-out"),
                 ("scores_out", "jianpu-db-out/scores"), ("work_dir", "train-work")):
        print(f"  {k:12s} = {path(k, d)}")
    print(f"  model       = {cfg('model', 'path', default='models/Qwen3-VL-2B-Instruct')}")
    print(f"  jianpu_db   = {cfg('external', 'jianpu_db', default='(未配置)')}")
