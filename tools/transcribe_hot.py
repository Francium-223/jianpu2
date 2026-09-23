# -*- coding: utf-8 -*-
"""转写 images-prep/hot-crawl/ 下的热门歌曲谱(多页合并成一条序列)。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP

dirs = sorted(glob.glob("images-prep/hot-crawl/*/"))
print(f"热门谱目录: {len(dirs)}")
for d in dirs:
    name = os.path.basename(d.rstrip("/\\"))
    imgs = sorted(glob.glob(os.path.join(d, "*.jpg")) + glob.glob(os.path.join(d, "*.png")))
    if not imgs:
        print(f"  {name}: 无图, 跳过")
        continue
    all_toks = []
    for i, im in enumerate(imgs):
        try:
            toks, _ = JP.render(im, f"batch-out/hot_{name}_p{i}.png")
            all_toks += toks
        except Exception as ex:
            print(f"    页{i+1} 失败: {type(ex).__name__}")
    with open(f"batch-out/hot_{name}.txt", "w", encoding="utf-8") as f:
        f.write(" ".join(all_toks))
    print(f"  {name}: {len(all_toks)} 音  ({len(imgs)} 页)", flush=True)
print("完成")
