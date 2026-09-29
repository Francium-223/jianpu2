# -*- coding: utf-8 -*-
"""转写某个新源目录下的所有谱(不走热度榜), 输出到 batch-out。
用法: py -3.13 tools/transcribe_source.py images-prep/jianpucn-pop [限制数]

环境变量:
  JP_MULTIPAGE=1  **多页拼接**(2026-09-29 加): 一个目录里有多张竖版谱页时逐页转写再拼,
                  每页单独过"纯简谱门"(qupu123 的"双谱"目录里 004/006/008 是五线谱页)。
                  默认关闭 = 老行为(只挑一张页)。
  为什么: `爱错（简和谱）__qupu123-350544` 有两页, 老行为成品只有 `1 7 - 3 6 5 1` 六个音。
"""
import glob, json, os, sys, time, traceback
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP
import batch_transcribe as BT

SRC = sys.argv[1] if len(sys.argv) > 1 else "images-prep/jianpucn-pop"
LIMIT = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 100000
MULTIPAGE = os.environ.get("JP_MULTIPAGE", "") == "1"
# 多页最多转几页(2026-09-29 加): 实测一份 8 页的"钢琴简谱"要 244 秒、转出 3504 个音(那不是旋律,
# 是钢琴织体) —— 页数上限既能砍掉这类噪声的大头, 又把每份的耗时压回可接受范围。
PAGE_MAX = int(os.environ.get("JP_MULTIPAGE_MAX", "4"))
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
    pages = BT.pick_pages(d) if MULTIPAGE else [p for p in [BT.pick_page(d)] if p]
    pages = [p for p in pages if p]
    if MULTIPAGE and len(pages) > PAGE_MAX:      # 只转前 PAGE_MAX 页(见上面 PAGE_MAX 的实测理由)
        pages = pages[:PAGE_MAX]
    if not pages:
        continue
    name = BT.safe_name(os.path.basename(d))
    txt = f"{OUT}/{name}.txt"
    png = f"{OUT}/{name}.png"
    if os.path.exists(txt):
        done += 1
        continue
    try:
        from PIL import Image as _I
        hh = [_I.open(p).size for p in pages]
    except Exception:
        continue
    if max(h for _w, h in hh) > int(os.environ.get("JP_MAX_H", "5000")):
        continue
    t0 = time.time()
    try:
        # 被"纯简谱门"挡掉的谱会返回空结果 —— 不要写成空 txt, 否则语料里多出一堆
        # 空谱(实测 161 个"0 音符"里大半是这类吉他混合谱)。
        # 多页模式下**逐页**过门: qupu123"双谱"目录里 004/006/008 是五线谱页, 要单独挡掉。
        def _pure(p):
            try:
                return not JP.is_impure(p)
            except Exception:
                return True

        good = [p for p in pages if _pure(p)]
        if not good:
            if os.path.exists(png):
                os.remove(png)
            print(f"[{i+1}/{len(dirs)}] {name[:40]}: 非纯简谱, 跳过 ({time.time()-t0:.0f}s)", flush=True)
            continue
        toks, meta = [], None
        dropped = 0
        page_notes = []
        page_toks = []
        for k, p in enumerate(good):
            side = png if k == 0 else f"{png[:-4]}_m{k}.png"
            tk, meta = BT.transcribe_paged(p, txt, side)
            nd = sum(1 for t in tk if t.lstrip("qsdh,").rstrip("'.") and t.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
            page_notes.append(nd)
            page_toks.append(tk)
        # **织体判据(2026-09-30 重做 —— 上一版把真歌截断了, 见下)**:
        #   上一版是"逐页丢 >300 音", 实测**截断了真歌**: 13 份被丢过页, 丢掉的页是 321~508 音,
        #   而这些谱**每页中位只有 285 音**(旋律谱的 p90 才 265!) —— 也就是把正常流行歌最密的那几页
        #   当织体丢了(例:《旅行》1580 -> 357、《圣诞结》416 -> 112)。
        #   所以改成**按整份谱判**, 而不是按单页判:
        #     ① 整份的**每页中位**超过 `JP_AVG_NOTES_PER_PAGE`(默认 400) -> 整份当织体, 不写稿;
        #     ② 单页超过 `JP_MAX_NOTES_PER_PAGE`(默认 600) 才丢那一页(只兜极端的)。
        #   400 这条线也是实测的: 上面那 13 份**真歌**的每页中位最高 397(圣诞结), 而明确的钢琴
        #   织体 `BEYOND_THE_TIME钢琴简谱` 8 页 3,504 音 = 中位 438, 贝斯谱_邓丽君3 中位 620
        #   -> 取 400 正好把 15 个实测样本分成"13 留 / 2 跳", 且**一页都不截断**。
        #   设 0 可分别关掉这两层。
        cap = int(os.environ.get("JP_MAX_NOTES_PER_PAGE", "600"))
        avg_cap = int(os.environ.get("JP_AVG_NOTES_PER_PAGE", "400"))
        if avg_cap and page_notes:
            _srt = sorted(page_notes)
            _med = _srt[len(_srt) // 2]
            if _med > avg_cap:
                if os.path.exists(png):
                    os.remove(png)
                print(f"[{i+1}/{len(dirs)}] {name[:40]}: 整份像织体(每页中位 {_med} 音 > {avg_cap}), 跳过 "
                      f"({time.time()-t0:.0f}s)", flush=True)
                continue
        for nd, tk in zip(page_notes, page_toks):
            if cap and nd > cap:
                dropped += 1
                continue
            toks += tk
        if not toks and dropped:
            if os.path.exists(png):
                os.remove(png)
            print(f"[{i+1}/{len(dirs)}] {name[:40]}: 全是织体页(丢弃 {dropped} 页), 跳过 ({time.time()-t0:.0f}s)",
                  flush=True)
            continue
        with open(txt, "w", encoding="utf-8") as f:
            f.write(" ".join(toks))
        # **confidence 边车**(2026-09-30 加): `JP_CONF=1` 时 `render` 会把"每个数字的 top-1 概率"
        # 汇总进 meta，这里落一个同名 `<name>.json`。为什么不写进 txt: txt 是**纯 token 流**，
        # 下游按 token 逐行解析；置信度是元数据，塞进去会污染口径。转换器读这个边车写成
        # 曲谱头里的 `confidence=`（唯一真源还是 jp_transcribe 的概率）。
        try:
            if meta and isinstance(meta, list) and meta[0].get("confidence") is not None:
                side = {"confidence": meta[0]["confidence"], "conf_p10": meta[0].get("conf_p10"),
                        "conf_n": meta[0].get("conf_n"), "pages": len(good),
                        "page_notes": page_notes, "dropped_pages": dropped}
                with open(os.path.splitext(txt)[0] + ".json", "w", encoding="utf-8") as g:
                    json.dump(side, g, ensure_ascii=False)
        except Exception:
            pass
        d2 = sum(1 for t in toks if t.lstrip("qsdh,").rstrip("'.") and t.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
        tail = f" 页 {len(good)}/{len(pages)}" if MULTIPAGE else ""
        if dropped:
            tail += f" 丢织体页 {dropped}"
        print(f"[{i+1}/{len(dirs)}] {name[:40]}: token {len(toks)} 数字 {d2}{tail} ({time.time()-t0:.0f}s)", flush=True)
    except Exception as ex:
        print(f"[{i+1}/{len(dirs)}] {name[:40]}: 失败 {type(ex).__name__}", flush=True)
    done += 1
print(f"完成 {done}/{len(dirs)}")
