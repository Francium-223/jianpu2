# -*- coding: utf-8 -*-
"""转写某个新源目录下的所有谱(不走热度榜), 输出到 batch-out。
用法: py -3.13 tools/transcribe_source.py images-prep/jianpucn-pop [限制数]

环境变量:
  JP_MULTIPAGE=1  **多页拼接**(2026-09-29 加): 一个目录里有多张竖版谱页时逐页转写再拼,
                  每页单独过"纯简谱门"(qupu123 的"双谱"目录里 004/006/008 是五线谱页)。
                  默认关闭 = 老行为(只挑一张页)。
  为什么: `爱错（简和谱）__qupu123-350544` 有两页, 老行为成品只有 `1 7 - 3 6 5 1` 六个音。
"""
import glob, json, os, subprocess, sys, time, traceback
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP
import batch_transcribe as BT

# ══════════════════════════════════════════════════════════════════════════════
# GPU 让路闸（2026-10-01 加，血的教训）
#
# 起因: 我的队列在 07:52:50 检查"外部计划任务没在跑"→ 07:54 开始转 jp114；而用户的计划任务
# **07:53 正好触发**（它每 6 小时一次）。两个进程各加载一份模型：显存用到 **7867/8188 MiB**，
# 我那份**4.5 小时一行输出都没有**（在显存里来回颠簸），外部任务也被拖慢 —— 白白耗掉半天。
#
# 所以把"别抢 GPU"做成**工具自己的纪律**，而不是只靠外面那层 `Wait-WritersClear`：
#   ① 同目录写一个锁文件 `train-work/.transcribe.lock`（里面是 PID）—— 另一个转录进程活着就不开工；
#   ② 顺带查一下用户的计划任务 `jp_mandopop_absorb3` 是不是 Running（`schtasks /query`）；
#   ③ 让路时每 60 秒重查一次，并打印一行说明（别让人以为卡死了）。
# 想强行不等: `JP_NO_WAIT=1`。
# ══════════════════════════════════════════════════════════════════════════════
LOCK = os.path.join("train-work", ".transcribe.lock")


def _pid_alive(pid):
    try:
        out = subprocess.run(["tasklist", "/FI", f"PID eq {pid}", "/NH"],
                             capture_output=True, text=True, encoding="utf-8", errors="replace")
        return str(pid) in (out.stdout or "")
    except Exception:
        return False


def _who_is_using_gpu():
    """谁在占 GPU —— 返回一句人话, 没有就返回空串。"""
    try:
        if os.path.exists(LOCK):
            txt = open(LOCK, encoding="utf-8", errors="replace").read().strip()
            pid = int(txt) if txt.isdigit() else 0
            if pid and pid != os.getpid():
                if _pid_alive(pid):
                    return f"另一个转录进程 (pid={pid})"
                os.remove(LOCK)                     # 上次崩了留下的死锁 -> 清掉
    except Exception:
        pass
    try:
        r = subprocess.run(["schtasks", "/query", "/tn", "jp_mandopop_absorb3", "/fo", "list"],
                           capture_output=True, text=True, encoding="utf-8", errors="replace")
        if "Running" in (r.stdout or ""):
            return "用户的计划任务 jp_mandopop_absorb3"
    except Exception:
        pass
    return ""


# ⚠ **别让计划任务等到自己头上**（2026-10-01 当天就踩了，而且是我自己造成的）:
#   计划任务的脚本里 `py tools/transcribe_source.py …` 是它自己的子进程 —— 加了让路闸之后，
#   它一查 `schtasks` 发现"jp_mandopop_absorb3 正在 Running"（就是它爹），于是**永远等下去**:
#   日志里一行行 `[让路] 用户的计划任务 …`, 而 GPU 占用 0%。用户的整轮任务就这么被卡住。
#   两道保险:
#     ① 计划任务脚本自己会设 `JP_PURITY2=1`（脚本第 9 行）——子进程**继承**它，见到就知道"我在任务里"；
#        同时 `mandopop_absorb3.ps1` 现在也显式设 `JP_NO_WAIT=1`（下一轮起更直白）。
#     ② 就算没这两个变量，"等计划任务"也有**上限**（默认 20 分钟，`JP_WAIT_MAX_MIN` 可调），
#        到点就开工并打一行警告 —— 宁可偶尔抢一下 GPU，也不能把谁锁死。
INSIDE_TASK = os.environ.get("JP_PURITY2") == "1" or os.environ.get("JP_NO_WAIT") == "1"
TASK_WAIT_MAX = int(os.environ.get("JP_WAIT_MAX_MIN", "20")) * 60

if not INSIDE_TASK:
    waited = 0
    while True:
        who = _who_is_using_gpu()
        if not who:
            break
        if "计划任务" in who and waited >= TASK_WAIT_MAX:
            print(f"[让路] 已经等了 {waited // 60} 分钟, 计划任务还没结束 —— 先开工（上限见 JP_WAIT_MAX_MIN）",
                  flush=True)
            break
        print(f"[让路] {who} 正在用 GPU —— 等它跑完再开工"
              f"（第 {waited // 60} 分钟；想强行不等: JP_NO_WAIT=1）", flush=True)
        time.sleep(60)
        waited += 60
try:
    os.makedirs("train-work", exist_ok=True)
    open(LOCK, "w").write(str(os.getpid()))
except Exception:
    pass
import atexit                                          # noqa: E402
atexit.register(lambda: os.path.exists(LOCK) and os.remove(LOCK))

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
        # 逐页的置信度(见下面"谱级 confidence"): 每页一定有一个 (confidence, conf_p10, conf_n)
        page_conf = []
        for k, p in enumerate(good):
            side = png if k == 0 else f"{png[:-4]}_m{k}.png"
            tk, meta = BT.transcribe_paged(p, txt, side)
            nd = sum(1 for t in tk if t.lstrip("qsdh,").rstrip("'.") and t.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
            page_notes.append(nd)
            page_toks.append(tk)
            # ⚠ `meta` 是**这一页**的, 多页时会被下一页覆盖 —— 所以置信度必须在这里逐页收集,
            #   不能等循环结束只读 `meta`(那样只拿到最后一页的, 2026-09-30 自查时发现)。
            if meta and isinstance(meta, list) and meta[0].get("confidence") is not None:
                page_conf.append((meta[0]["confidence"], meta[0].get("conf_p10"), meta[0].get("conf_n") or 0))
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
            if page_conf:
                # **谱级 confidence**: 多页时按每页数字个数**加权平均**(页越密权重越大),
                # `conf_p10` 取**最差那一页**的分位(它才是"有没有个别音很虚"的信号)。
                _w = sum(n for _c, _p, n in page_conf)
                _c = (sum(c * n for c, _p, n in page_conf) / _w) if _w else \
                    (sum(c for c, _p, _n in page_conf) / len(page_conf))
                _p10 = min((p for _c, p, _n in page_conf if p is not None), default=None)
                side = {"confidence": round(_c, 3),
                        "conf_p10": (round(_p10, 3) if _p10 is not None else None),
                        "conf_n": _w, "pages": len(good),
                        "page_notes": page_notes, "dropped_pages": dropped,
                        "page_confidence": [c for c, _p, _n in page_conf]}
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
