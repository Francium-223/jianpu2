# -*- coding: utf-8 -*-
"""精准重跑: 只重跑"含双高八度('')的文件"(用修复后的 geo_detect)。
读 train-work/affected.json, 找原谱页(最大 jpg), 重跑并覆盖 txt/png。
用法: py -3.13 tools/rerun_affected.py
"""
import os, sys, json, glob
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP

def find_page(name):
    hits = glob.glob(f"images-prep/*/{name}/*.jpg")
    if not hits:
        return None
    return max(hits, key=os.path.getsize)

def main():
    aff = json.load(open("train-work/affected.json", encoding="utf-8"))
    limit = len(aff)
    if "--limit" in sys.argv:
        limit = int(sys.argv[sys.argv.index("--limit") + 1])
    aff = aff[:limit]
    print(f"待重跑 {len(aff)} 个", flush=True)
    ok = miss = 0
    for i, txt in enumerate(aff):
        name = os.path.splitext(os.path.basename(txt))[0]
        page = find_page(name)
        if not page:
            miss += 1
            print(f"[{i+1}/{len(aff)}] 找不到谱页: {name[:40]}", flush=True)
            continue
        try:
            toks, meta = JP.render(page, txt[:-4] + ".png")
            with open(txt, "w", encoding="utf-8") as f:
                f.write(" ".join(toks))
            dbl = sum(1 for t in toks if "''" in t)
            print(f"[{i+1}/{len(aff)}] {name[:34]:34s} 音{len(toks):4d} 双撇{dbl}", flush=True)
            ok += 1
        except Exception as ex:
            print(f"[{i+1}/{len(aff)}] 失败 {type(ex).__name__}: {name[:30]}", flush=True)
    print(f"重跑完成: 成功 {ok}, 缺图 {miss}", flush=True)

if __name__ == "__main__":
    main()
