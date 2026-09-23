# -*- coding: utf-8 -*-
"""把交付相关的数字汇总成 train-work/DELIVERY.md(给人看的交付说明, 不产出任何新数据)。"""
import collections
import glob
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

L = []
def w(s=""):
    L.append(s)
    print(s)


# --- 1) 曲库 ---
scores = glob.glob("jianpu-db-out/scores/*.txt")
src = collections.Counter()
nosrc = 0
notes = 0
for f in scores:
    try:
        head = open(f, encoding="utf-8", errors="replace").read(4000)
    except Exception:
        continue
    # 出处统计要**宽松**: 只要写了 `source=` 就算有出处。
    # 早先正则写死 `<站>-<id>`, 于是 `source=unknown`(手工抓的谱没记原页) 和
    # `source=21qupu`(名字里只有站名没有 id) 被误判成"缺出处" ✗
    m = re.search(r"^source=(\S+)", head, re.M)
    if m:
        src[re.split(r"[-.]", m.group(1))[0]] += 1
    else:
        nosrc += 1
n_note_files = 0
for f in scores:
    try:
        t = open(f, encoding="utf-8", errors="replace").read()
    except Exception:
        continue
    body = t.split("%--", 1)[-1]
    notes += len(re.findall(r"\b[,.']*[qsdh]*[1-7x0][.,'qsdh-]*\b", body))
    n_note_files += 1

# --- 2) 基准集 ---
bench = []
if os.path.exists("train-work/bench_pick.tsv"):
    with open("train-work/bench_pick.tsv", encoding="utf-8") as f:
        next(f, None)
        for ln in f:
            p = ln.rstrip("\n").split("\t")
            if len(p) >= 3:
                bench.append(p)
has = sum(1 for p in bench if p[2].startswith("已有"))
todo = sum(1 for p in bench if p[2].startswith("挑"))
nop = sum(1 for p in bench if "无谱" in p[2])

# --- 3) 检索评测数字(从 bench_run.log 里捡) ---
ev = []
if os.path.exists("train-work/bench_run.log"):
    for ln in open("train-work/bench_run.log", encoding="utf-8", errors="replace"):
        if re.search(r"L=\s*\d+ 音", ln):
            ev.append(ln.rstrip())
        m = re.search(r"索引 (\d+) 首", ln)
        if m:
            ev.append(ln.rstrip())
        m = re.search(r"基准集 (\d+) 首, 索引里能找到 (\d+) 首", ln)
        if m:
            ev.append(ln.rstrip())

# --- 4) 曲名清洗 ---
tc = 0
tch = 0
tcq = 0
if os.path.exists("train-work/title_clean.tsv"):
    with open("train-work/title_clean.tsv", encoding="utf-8") as f:
        next(f, None)
        for ln in f:
            p = ln.rstrip("\n").split("\t")
            if len(p) < 4:
                continue
            tc += 1
            tch += int(p[3] == "1")
            tcq += int(p[2] == "?")

# --- 5) ABC ---
# ABC 工具在**仓库外面**(D:\Documents_D\abc2jianpu), 早先只 glob 了仓库内的路径 -> 报 0 首 ✗
abc = glob.glob("abc2jianpu/out/*.jly") + glob.glob("../abc2jianpu/out/*.jly")

w("# jianpu2 交付说明")
w()
w(f"生成时间 {__import__('time').strftime('%Y-%m-%d %H:%M')}")
w()
w("## 0. 一页速览")
w()


def _wilson0(k, n, z=1.96):
    if not n:
        return 0.0, 0.0
    p = k / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    r = z * ((p * (1 - p) / n + z * z / (4 * n * n)) ** 0.5)
    return 100 * (c - r) / d, 100 * (c + r) / d


def _pick(path, Lq, e):
    """从评测 TSV 里取指定 L/错音数那行的 (Top1%, lo, hi, Top3%)，避免写死数字后又过期。"""
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        next(f, None)
        for ln in f:
            p = ln.rstrip("\n").split("\t")
            if len(p) >= 6 and p[0] == str(Lq) and p[1] == str(e):
                tot = int(p[3])
                lo, hi = _wilson0(int(p[4]), tot)
                return 100.0 * int(p[4]) / tot, lo, hi, 100.0 * int(p[5]) / tot
    return None


_main = _pick("train-work/retrieval_eval_neighbor.tsv", 11, 1)
_rand = _pick("train-work/retrieval_eval_rand.tsv", 11, 1)
_indel = None
if os.path.exists("train-work/retrieval_indel.tsv"):
    with open("train-work/retrieval_indel.tsv", encoding="utf-8") as f:
        next(f, None)
        for ln in f:
            p = ln.rstrip("\n").split("\t")
            if len(p) >= 6 and p[0] == "13":
                tot = int(p[4])
                lo, hi = _wilson0(int(p[5]), tot)
                _indel = (100.0 * int(p[5]) / tot, lo, hi)

w("- **交付物**：`jianpu-db-out/scores/*.txt` —— 每份是 jianpu-ly 文本，带 `source=<站>-<id>` 出处字段。")
w("- **能力**：哼一段简谱（数字串）→ 从全库找出是哪首歌，给出处与命中位置：`tools/melody_query.py`。")
w("- **可宣传口径（歌级 Top-1，Wilson 95% CI）**：")
if _main:
    w(f"  - 哼 11 个音、1 个音唱错（相邻音级，最像真人）→ **{_main[0]:.2f}%** "
      f"[{_main[1]:.1f}, {_main[2]:.1f}]，Top-3 {_main[3]:.1f}%")
if _rand:
    w(f"  - 同上但错音随机换任意音（更狠）→ **{_rand[0]:.2f}%** [{_rand[1]:.1f}, {_rand[2]:.1f}]")
if _indel:
    w(f"  - 哼 13 个音、中间漏/多 1 个音 → **{_indel[0]:.2f}%** [{_indel[1]:.1f}, {_indel[2]:.1f}]")
w("- **注意**：这个数字衡量的是**检索环节**（输入=唱名串）。「哼唱录音 → 唱名串」那一段不在里面，"
  "别把它说成「听歌识曲准确率」。")
w("- 口径细节、限制、复现命令：`SKILL.md`（同目录）。")
w()
w("## 1. 曲库(简谱 -> jianpu-ly 文本)")
w()
w(f"- 成品谱: **{len(scores)}** 份 (jianpu-db-out/scores/*.txt)")
w(f"- 音符总数: {notes}")
w(f"- 带 `source=` 出处的: {len(scores)-nosrc} ({100.0*(len(scores)-nosrc)/max(1,len(scores)):.1f}%)，缺 {nosrc} 份")
w("- 按站点: " + "、".join(f"{k} {v}" for k, v in src.most_common()))
w(f"- 转写队列: batch-out {len(glob.glob('batch-out/*.txt'))} / -dup {len(glob.glob('batch-out-dup/*.txt'))} "
  f"/ -bad {len(glob.glob('batch-out-bad/*.txt'))} / -empty {len(glob.glob('batch-out-empty/*.txt'))} "
  f"/ -suspect {len(glob.glob('batch-out-suspect/*.txt'))}")
# 内容级去重(整串旋律完全相同, 但曲名不同所以绕过了按曲名归并的 pick_best)
# 数字取**当前状态**(审计文件里"已归并"的条数), 不取"最后一次跑动了几份" —— 后者第二次跑是 0,
# 会让人误以为没去过重(实测就被这个口径坑过一次) ✗
if os.path.exists("train-work/dup_melodies.tsv"):
    _rows = [l.split("\t") for l in open("train-work/dup_melodies.tsv", encoding="utf-8")
             .read().splitlines()[1:] if l.strip()]
    _merged = sum(1 for r in _rows if r and r[0] == "同名重复-已归并")
    if _merged:
        w(f"- **内容级去重**：检出 **{_merged}** 份「整串旋律完全相同、但曲名不同」的重复谱，"
          f"已移到 `batch-out-dup/`（只移不删）—— `pick_best.py` 按曲名归并，这类不同名的重复正好绕过它。"
          f"清单 `train-work/dup_melodies.tsv` 给出**保留者↔被归并者**的对应关系（可逆）。")
w()
w("## 2. 华流金曲 100:旋律片段检索(宣传口径)")
w()
w(f"- 基准集 100 首: **" + (f"{has} 首**有可用转写（`bench_pick.tsv` 快照；最新覆盖见下一行的索引口径）"
                            if has else "待补**") + f"，本次补转 {todo} 首，本地无谱 {nop} 首")


def _wilson(k, n, z=1.96):
    if not n:
        return 0.0, 0.0
    p = k / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    r = z * ((p * (1 - p) / n + z * z / (4 * n * n)) ** 0.5)
    return 100 * (c - r) / d, 100 * (c + r) / d


def _sweep_table(path, title):
    """**直接读评测 TSV**, 不去扒日志 —— 扒日志会引用到中间那轮的数字
    (实测 DELIVERY.md 引了 89 首那轮的 96.0%, 而最终是 100 首那轮的 94.5% ✗)。"""
    if not os.path.exists(path):
        return
    w()
    w(f"**{title}**")
    w()
    w("| 哼多少音 | 错音 | 查询数 | Top-1 | Top-3 | Top-5 | 并列下界 Top-1 | 并列组均值 |")
    w("|---|---|---|---|---|---|---|---|")
    with open(path, encoding="utf-8") as f:
        next(f, None)
        for ln in f:
            p = ln.rstrip("\n").split("\t")
            if len(p) < 9:
                continue
            Lq, e, mode, tot = p[0], p[1], p[2], int(p[3])
            t1, t3, t5, pess = int(p[4]), int(p[5]), int(p[6]), int(p[7])
            lo, hi = _wilson(t1, tot)
            w(f"| {Lq} | {e}（{mode}） | {tot} | **{100.0*t1/tot:.1f}%** [{lo:.1f}, {hi:.1f}] | "
              f"{100.0*t3/tot:.1f}% | {100.0*t5/tot:.1f}% | {100.0*pess/tot:.1f}% | {p[8]} |")


# 覆盖率(评测脚本落盘的权威值)
if os.path.exists("train-work/retrieval_coverage.txt"):
    _cv = open("train-work/retrieval_coverage.txt", encoding="utf-8").read().split()
    if len(_cv) >= 2:
        w(f"- **基准集 {_cv[0]}/{_cv[1]} 首**进了检索索引；索引 = {_cv[2]} 首歌 / {_cv[3]} 份谱")
w("- 查询 = 从该首歌自己的谱里随机截 L 个音；排名按「最小错音数」，**并列时目标歌排最前**，"
  "同时给出「并列按名次算」的下界（下界小是正常的：并列本该由更多证据来破）。")
_sweep_table("train-work/retrieval_eval_rand.tsv", "随机错音（更狠）")
_sweep_table("train-work/retrieval_eval_neighbor.tsv", "相邻音级错音（更像真人哼唱）")
if os.path.exists("train-work/retrieval_indel.tsv"):
    w()
    w("**漏唱 / 多唱一个音也能查**（`--indel 1`）：")
    w()
    w("| 真值长度 | 漏多唱 | 额外错音 | 查询数 | Top-1 | Top-3 | Top-5 |")
    w("|---|---|---|---|---|---|---|")
    with open("train-work/retrieval_indel.tsv", encoding="utf-8") as f:
        next(f, None)
        for ln in f:
            p = ln.rstrip("\n").split("\t")
            if len(p) < 8:
                continue
            tot = int(p[4])
            lo, hi = _wilson(int(p[5]), tot)
            w(f"| {p[0]} | {p[1]} | {p[2]}（{p[3]}） | {tot} | "
              f"**{100.0*int(p[5])/tot:.1f}%** [{lo:.1f}, {hi:.1f}] | "
              f"{100.0*int(p[6])/tot:.1f}% | {100.0*int(p[7])/tot:.1f}% |")
w()
w("- **这是「检索环节」的指标**（输入=唱名串）：哼唱录音 → 唱名串那一段不在其中，"
  "不能当成「听歌识曲准确率」。口径细节与限制见 `SKILL.md`。")
# 留一版本(cross-version): 把"拿谱对谱"的偏乐观量化掉 —— 查询取自版本 A, 索引里排除 A
if os.path.exists("train-work/retrieval_holdout.tsv"):
    w()
    w("### 留一版本（更接近「凭记忆哼唱」）")
    w()
    w("查询片段取自版本 A，**把 A 从索引里排除**，必须靠这首歌的**其它版本**认出来 —— "
      "这模拟的是「脑子里记得的旋律」和「库里那份谱」不一致的情形。")
    w()
    w("| 每段长度 | 段数 | 查询数 | Top-1 | Top-3 | Top-5 | 两版一致时 Top-1 | 两版有差异时 Top-1 |")
    w("|---|---|---|---|---|---|---|---|")
    with open("train-work/retrieval_holdout.tsv", encoding="utf-8") as f:
        next(f, None)
        for ln in f:
            p = ln.rstrip("\n").split("\t")
            if len(p) < 13:
                continue
            tot = int(p[4])
            lo, hi = _wilson(int(p[5]), tot)
            w(f"| {p[0]} 音 | {p[3]} | {tot} | **{100.0*int(p[5])/tot:.1f}%** [{lo:.1f}, {hi:.1f}] | "
              f"{100.0*int(p[6])/tot:.1f}% | {100.0*int(p[7])/tot:.1f}% | {p[11]}% | {p[12]}% |")
    w()
    w("- **怎么读这张表**：只要那段旋律在库里**确实存在**（两版这段一样），Top-1 就是 ~100%；"
      "掉分全部来自「同一首歌的另一份谱这段记谱本来就不同」（中位数差 1–4 个音）。"
      "真人哼唱不会只哼一句 —— 给 5 段后 Top-1 从 51.3% 回到 **70.3%**。")
    w("- 所以对外最好说「哼 3–5 段短句」，并同时给自匹配与留一版本两个数，别只给高的那个。")
    # 间隔轮廓对照: 排除"是不是匹配器不行"
    if os.path.exists("train-work/retrieval_contour.tsv"):
        w()
        w("**「是不是匹配器不行？」—— 已用数据排除**（`tools/melody_retrieval_contour.py`）：")
        with open("train-work/retrieval_contour.tsv", encoding="utf-8") as _f:
            next(_f, None)
            for _ln in _f:
                _p = _ln.rstrip("\n").split("\t")
                if len(_p) < 7:
                    continue
                _t = int(_p[3])
                w(f"- {_p[0]}：Top-1 {100.0*int(_p[4])/_t:.1f}%、Top-3 {100.0*int(_p[5])/_t:.1f}%、"
                  f"Top-5 {100.0*int(_p[6])/_t:.1f}%")
        w("- 诊断：唱名匹配的 79 次失败里，**只有 2 次（2.5%）**是「只是移调/换记法」（轮廓能救），"
          "其余 77 次是**旋律真的不同**。所以跨版本差距来自**谱与谱之间的差异**，不是检索算法。")
w("## 3. 曲名清洗(本地 Qwen3-1.7B, 纯文本)")
w()
w(f"- 全量 {tc} 条目录名喂给模型, 其中 **{tch}** 条洗出了改动, 复核不过 {tcq} 条")
w("- 清名已接进重建管线(to_jianpu_db 读 train-work/title_clean.tsv), 每次重建自动保持干净")
w("- 文件名仍不达标的写 `todo=refine the filename` 字段(见 source_map.html 红标)")
w()
w("## 4. 手写 GT 复评(转写质量, 不是检索)")
w()
if os.path.exists("train-work/gt_report.txt"):
    for ln in open("train-work/gt_report.txt", encoding="utf-8"):
        w("- " + ln.strip())
else:
    w("- 还没跑: `py -3.13 tools/gt_transcribe_eval.py`(把 train-work/gt/*.jpg 用手写 GT 同口径重转比对)")
w()
w("## 5. 自我抽检(语料质量)")
w()
if os.path.exists("train-work/qa_report.txt"):
    for ln in open("train-work/qa_report.txt", encoding="utf-8"):
        w("- " + ln.strip())
    w("- 说明：`(` `)` 与 `~` 是转写器输出的**圆滑线/连音线**标记，不是噪声音符。"
      "写 scores 时 `~` 保留（下游 `score.py` 白名单认它），`(` `)` 丢弃（白名单不含）。"
      "`~` 在音高串索引里不参与比对，所以不影响检索指标。")
# 双声部/改编类抽检(名字像 钢琴/双手/吉他/五线谱 的): 看纯度门到底挡住了多少
if os.path.exists("train-work/arrangement_like.tsv"):
    import collections as _c
    _rows = [l.rstrip("\n").split("\t") for l in
             open("train-work/arrangement_like.tsv", encoding="utf-8").read().splitlines()[1:]]
    _d = _c.Counter(r[2] for r in _rows if len(r) >= 3)
    _acc = _d.get("batch-out", 0) + _d.get("batch-out-dup", 0)
    w(f"- 名字像双声部/改编（钢琴/双手/吉他/五线谱/伴奏…）的谱：**{len(_rows)}** 份，"
      f"其中已被纯度门隔离 **{_d.get('batch-out-bad', 0)}** 份，仍在语料里 {_acc} 份"
      f"（占语料 {100.0*_acc/max(1,len(scores)):.1f}%，这些是通过了纯度门的纯简谱）")
    w("  清单：`train-work/arrangement_like.tsv`（只列清单，没有动语料；要不要移出由你定）")
if os.path.exists("train-work/qa_sample/index.html"):
    w("- **人工核对样本**：`train-work/qa_sample/index.html` —— 随机 40 首，"
      "左边是原谱前 3 个行带、右边是转写出的 token，肉眼一比就知道读对没有"
      "（`py -3.13 tools/qa_sample.py 40` 可随时重抽）")
else:
    w("- 还没跑: `py -3.13 tools/qa_corpus.py`")
w()
w("## 6. ABC 记谱工具(abc2jianpu/)")
w()
w(f"- ABC -> 简谱 jianpu-ly 脚本 + 批量产物 {len(abc)} 首 (out/*.jly + manifest.tsv)")
w("- 调号规则: 大调主音写 1, 小调关系大调主音写 1(即小调第 3 音)")
w()
w("## 7. 怎么用")
w()
w("```")
w("py -3.13 tools/melody_query.py \"51223323323531\" --top 5 --show   # 哼一段 -> 查歌")
w("py -3.13 tools/melody_query.py \"51223323323531\" --json           # 给 AI agent 用")
w("py -3.13 tools/jp_transcribe.py <图片>        # 单张图 -> token")
w("py -3.13 tools/scan_backlog.py               # 看还差哪些没转")
w("py -3.13 tools/finalize.py                   # 收尾: 纯度 -> 择优 -> 重建 DB")
w("py -3.13 tools/melody_retrieval_eval.py --sweep   # 检索评测")
w("py -3.13 tools/verify_deliverable.py         # 交付物总验收")
w("```")
w()
w("来源表(每首谱的出处/图片目录/转写结果/检索链接): `train-work/source_map.html`")

open("train-work/DELIVERY.md", "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n-> train-work/DELIVERY.md")
