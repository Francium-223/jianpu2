# -*- coding: utf-8 -*-
import os; os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))); os.environ.setdefault('TOKENIZERS_PARALLELISM','false')
import torch
from qwen_loader import load_qwen_visual, get_processor
print("loading...")
v=load_qwen_visual()
print("loaded", next(v.parameters()).device)
