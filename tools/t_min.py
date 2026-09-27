# -*- coding: utf-8 -*-
import os; os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))); os.environ.setdefault('TOKENIZERS_PARALLELISM','false')
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
import torch
from qwen_loader import load_qwen_visual, get_processor
print("loading...")
v=load_qwen_visual()
print("loaded", next(v.parameters()).device)
