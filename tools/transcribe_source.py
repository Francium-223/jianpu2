# -*- coding: utf-8 -*-
"""转写某个新源目录下的所有谱(不走热度榜), 输出到 batch-out。
用法: py -3.13 tools/transcribe_source.py images-prep/jianpucn-pop [限制数]
"""
import glob, os, sys, time, traceback
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP
import batch_transcribe as BT

SRC = sys.argv[1] if len(sys.argv) > 1 else "images-prep/jianpucn-pop"
LIMIT = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 100000
OUT = "batch-out"
os.makedirs(OUT, exist_ok=True)

if os.path.isfile(SRC):
    # SRC 是名单文件: 每行一个目录名(可跨源), 按名字在所有源里找
    names = [l.strip() for l in open(SRC, encoding="utf-8") if l.strip()]
    dirs = []
    for n in names:
        dirs += [d for d in glob.glob("images-prep/*/" + glob.escape(n)) if os.path.isdir(d)]
    print(f"名单 {len(names)} 个 -> 命中 {len(dirs)} 个目录")
else:
    dirs = sorted(d for d in glob.glob(os.path.join(SRC, "*")) if os.path.isdir(d))[:LIMIT]
    print(f"{SRC}: {len(dirs)} 个谱")
done = 0
for i, d in enumerate(dirs):
    page = BT.pick_page(d)
    if not page:
        continue
    name = BT.safe_name(os.path.basename(d))
    txt = f"{OUT}/{name}.txt"
    png = f"{OUT}/{name}.png"
    if os.path.exists(txt):
        done += 1
        continue
    try:
        from PIL import Image as _I
        _w, _h = _I.open(page).size
    except Exception:
        continue
    if _h > int(os.environ.get("JP_MAX_H", "5000")):
        continue
    t0 = time.time()
    try:
        # 被"纯简谱门"挡掉的谱会返回空结果 —— 不要写成空 txt, 否则语料里多出一堆
        # 空谱(实测 161 个"0 音符"里大半是这类吉他混合谱)。
        try:
            _blocked = JP.is_impure(page)
        except Exception:
            _blocked = False
        toks, meta = BT.transcribe_paged(page, txt, png)
        if _blocked:
            if os.path.exists(png):
                os.remove(png)
            print(f"[{i+1}/{len(dirs)}] {name[:40]}: 非纯简谱, 跳过 ({time.time()-t0:.0f}s)", flush=True)
            continue
        with open(txt, "w", encoding="utf-8") as f:
            f.write(" ".join(toks))
        d2 = sum(1 for t in toks if t.lstrip("qsdh,").rstrip("'.") and t.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
        print(f"[{i+1}/{len(dirs)}] {name[:40]}: token {len(toks)} 数字 {d2} ({time.time()-t0:.0f}s)", flush=True)
    except Exception as ex:
        print(f"[{i+1}/{len(dirs)}] {name[:40]}: 失败 {type(ex).__name__}", flush=True)
    done += 1
print(f"完成 {done}/{len(dirs)}")
