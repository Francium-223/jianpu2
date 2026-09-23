# -*- coding: utf-8 -*-
"""渲染问候歌的标注图: 每个识别块框出 + 标 token。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP

page = glob.glob("images-prep/jianpujia-crawl/*74580/*.jpg")[0]
out = "train-work/问候歌_标注.png"
toks, meta = JP.render(page, out)
print("谱:", page)
print("token 数:", len(toks))
print("标注图:", out)
print("tokens:", " ".join(toks))
