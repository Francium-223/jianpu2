# -*- coding: utf-8 -*-
"""守候: 等到**没有任何写库进程** -> 干净重建一次 -> 立刻验证 -> 出报告。

为什么必须"等": 实测有定时任务(finalize / to_jianpu_db / parse_scores)在后台写 scores/,
我这边一边重建一边被覆盖, 导致 data.jsonl 与磁盘文件对不上(同一文件名两次读出不同内容)。
判据: 任何命令行含 finalize / to_jianpu_db / parse_scores / transcribe / absorb 的 python 进程。

用法:
    py -3.13 tools/rebuild_when_idle.py [最多等多少分钟=180]
    py -3.13 tools/rebuild_when_idle.py 600 --site D:\\Documents_D\\jianpu-db.github.io
    py -3.13 tools/rebuild_when_idle.py 900 --import --site D:\\Documents_D\\jianpu-db.github.io
    py -3.13 tools/rebuild_when_idle.py 5400 --convert --import --site D:\\Documents_D\\jianpu-db.github.io

`--convert` 为什么有用(2026-09-28 补): 转录只写 `batch-out/`(裸 token), 成品目录要
`to_jianpu_db.py` 转。而**整份重转会给现成成品改名** —— 实测 165 首新谱抢走旧名、178 首老谱被迫
改名, 配上"只拷不覆盖"的导入 = **76 首白转、从未进语料**(tools/check_convert_damage.py 量出来的)。
所以给 `--convert`: 先跑 `tools/convert_new_batches.py --apply`(只转账本里没有的新谱, 躲开已有名,
落点隔离后再只拷不覆盖地并进成品), **然后**才轮到 `--import`。

`--import` 为什么有用(2026-09-28 补): 流水线是**两段式**的 —— 转录批次只往
`jianpu-db-out/scores/`(成品, 覆盖率报告里叫"待入库")写; 而"成品 -> `jianpu-db/scores/`"这一段
**原先靠人手动跑**(`kugou_pipeline` 只管酷狗那批, `batch_transcribe_queue` 要队列文件)。
于是夜里批次跑一整晚, 新谱就躺在成品目录里没人管 —— 实测成品 8573 / 语料 7816,
**1639 份 `status=ocr` 从未入库**。给了 `--import` 就在重建**之前**先跑
`tools/import_finished_scores.py --apply`(它只拷不覆盖、只拷不删, 并复用流水线自己的两条判据)。

`--site <前端仓库>` 为什么有用: 语料重建完**前端索引并不会自己更新** ——
`data/songs.jsonl.gz` 只有本机能生成(要读 scores/ 与图库), 而站点的 CI 只负责把已入库的
data/ 摊到部署目录。于是新转写的歌会一直躺在 `scores/` 里, 没人跑 build_web_data.py 就上不了站。
给了 --site 就顺带重建前端索引并**自己对账**(stats.songs == data.jsonl 行数、0 首重复小节线)。
**不自动 git commit/push**: 推远端是人的决定, 脚本只把该敲的命令打出来。
"""
import atexit
import io
import json
import os
import random
import re
import subprocess
import sys
import time
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

sys.stdout.reconfigure(encoding="utf-8")
DB = r"D:\Documents_D\jianpu-db"
# 写者判据分两档:
#   * DB_WRITERS —— **真的会写 scores/ 与 data.jsonl** 的那些工具。等它们是对的: 一边重建一边被覆盖,
#     data.jsonl 就会与磁盘对不上(本文件 docstring 里的那个事故)。
#   * PAT(默认, = DB_WRITERS + transcribe/absorb) —— 更保守: 连**转录**也等。理由是"转录之后紧接着
#     就是驱动脚本的 finalize/导入", 早做一次重建多半马上被覆盖, 白忙。
#     ⚠ 2026-09-28 实测这个保守档会把自己饿死: 外部 `mandopop_absorb3` 从 07:53 一直逐个源转录到 20:28
#       (12.5 小时里**没有一刻**没有转录进程), 于是守候从 10:43 一直等到被关机, 一次都没重建 ——
#       而转录只写 `batch-out/`, 跟 `scores/`、`data.jsonl` **毫无关系**。
#       所以给了 `--ignore-transcribers`: 只等真正的 DB 写者。实测那次手工执行(确认无 DB 写者后
#       直接 import+parse)完全安全, 语料 8926 -> 9340。
DB_WRITERS = re.compile(r"finalize|to_jianpu_db|parse_scores|import_finished|db_to_jsonl|kugou_pipeline")
PAT_STRICT = re.compile(r"finalize|to_jianpu_db|parse_scores|transcribe|absorb|kugou_pipeline")
PAT = DB_WRITERS if "--ignore-transcribers" in sys.argv else PAT_STRICT
_argv = [a for a in sys.argv[1:] if not a.startswith("-")]
WAIT_MIN = int(_argv[0]) if _argv and _argv[0].isdigit() else 180
SITE = None
if "--site" in sys.argv:
    _i = sys.argv.index("--site")
    SITE = os.path.abspath(sys.argv[_i + 1]) if _i + 1 < len(sys.argv) else None
# `--push`: 重建完**直接把语料仓库与站点仓库提交并推远端**(2026-09-29 用户授权: "仓库你动就行了。我让你动。")
PUSH = "--push" in sys.argv


def _commit_push(repo, paths, msg):
    """在 repo 里 add 指定路径 -> **有变化才** commit -> push; 被 CI 抢先推了就 fetch+merge 再来一次。"""
    try:
        st = subprocess.run(["git", "status", "--porcelain", "--"] + paths, cwd=repo,
                            capture_output=True, text=True)
        if not (st.stdout or "").strip():
            say(f"  {os.path.basename(repo)}: 没有变化, 不提交")
            return
        subprocess.run(["git", "add"] + paths, cwd=repo, check=True)
        r = subprocess.run(["git", "commit", "-q", "-m",
                            msg + "\n\nCo-authored-by: deepseek-ai <service@deepseek.com>"],
                           cwd=repo, capture_output=True, text=True)
        if r.returncode != 0:
            say(f"  !! {os.path.basename(repo)} 提交失败: {(r.stderr or r.stdout or '').strip()[:200]}")
            return
        p = subprocess.run(["git", "push"], cwd=repo, capture_output=True, text=True)
        if p.returncode != 0:
            subprocess.run(["git", "fetch", "-q"], cwd=repo)
            subprocess.run(["git", "merge", "--no-edit", "-X", "ours", "FETCH_HEAD"], cwd=repo,
                           capture_output=True, text=True)
            p = subprocess.run(["git", "push"], cwd=repo, capture_output=True, text=True)
        say(f"  {os.path.basename(repo)}: push 退出码 {p.returncode}"
            + ("" if p.returncode == 0 else f" :: {(p.stderr or '')[:180]}"))
    except Exception as e:                                       # noqa: BLE001
        say(f"  !! {os.path.basename(repo)} 提交/推送异常: {type(e).__name__}: {e}")


def say(m):
    line = f"{time.strftime('%H:%M:%S')}  {m}"
    print(line, flush=True)
    with io.open(r"D:\Documents_D\jianpu2\train-work\rebuild_when_idle.log", "a", encoding="utf-8") as g:
        g.write(line + "\n")


# ---------------- 单实例锁(照 refresh.sh 的 .refresh.lock 先例) ----------------
# 为什么必须有: 2026-09-28 实测自己踩到 —— 重启"带新检查的守候作业"时**忘了停旧的**, 两个实例同时
# 等在写者清空; 一旦清空, 两个 `parse_scores.py` 会**并发重建同一个 data.jsonl**,
# 正是本文件 docstring 里写的那个事故("一边重建一边被覆盖 -> data.jsonl 与磁盘文件对不上")。
LOCK = r"D:\Documents_D\jianpu2\train-work\rebuild_when_idle.lock"


def _pid_alive(pid):
    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        f"(Get-Process -Id {pid} -ErrorAction SilentlyContinue | Measure-Object).Count"],
                       capture_output=True, text=True)
    return (r.stdout or "").strip() not in ("", "0")


def take_lock():
    if os.path.isfile(LOCK):
        try:
            old = io.open(LOCK, encoding="utf-8").read().strip()
            if old.isdigit() and _pid_alive(int(old)):
                print(f"!! 已有一个守候作业在跑(PID {old})—— 两个同时等清空会并发重建语料, 拒绝启动。")
                print(f"   要换新的: 先停掉 {old}, 或删掉 {LOCK}")
                sys.exit(2)
        except Exception:                                        # noqa: BLE001
            pass
    io.open(LOCK, "w", encoding="utf-8").write(str(os.getpid()))


def drop_lock():
    try:
        if os.path.isfile(LOCK) and io.open(LOCK, encoding="utf-8").read().strip() == str(os.getpid()):
            os.remove(LOCK)
    except Exception:                                            # noqa: BLE001
        pass


take_lock()
atexit.register(drop_lock)      # 正常退出/异常退出都清; 被强杀时留下的锁靠 "PID 还活着吗" 判为陈旧


def writers():
    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | "
                        "ForEach-Object { $_.ProcessId.ToString() + ' ' + $_.CommandLine }"],
                       capture_output=True, text=True)
    out = []
    for ln in (r.stdout or "").splitlines():
        if PAT.search(ln) and "http.server" not in ln:
            out.append(ln.strip()[:110])
    return out


say("=== 守候: 等写者清空 ===")
t0 = time.time()
while time.time() - t0 < WAIT_MIN * 60:
    w = writers()
    if not w:
        break
    say(f"  还有 {len(w)} 个写者, 等 60s: {w[0]}")
    time.sleep(60)
else:
    say("超时, 放弃"); sys.exit(1)

say("写者已清空, 开始重建")

# ---- 先把裸 token 转成成品(--convert) -------------------------------------------
# 为什么需要这一段(**2026-09-28 实测的教训**): 转录批次只往 `batch-out/` 写裸 token, 而成品目录
# 是靠 `to_jianpu_db.py` 整份重转出来的。整份重转**不是**无害操作: 新谱会**抢走**旧名
# (实测 9053 个 batch 里 165 首新谱抢名 / 178 首老谱被迫改名), 导入又是"只拷不覆盖"
# -> 抢名的新谱被丢掉(实测 **76 首**转出来却从未进语料), 老谱则可能被再拷一份。
# `tools/convert_new_batches.py` 就是为此写的: 只转"账本里没有的"新谱, `--avoid` 躲开已有名,
# 落点隔离在 `train-work/conv-new/`, 再只拷不覆盖地并进成品。
CONVERT = "--convert" in sys.argv
if CONVERT:
    _cv = os.path.join(os.path.dirname(os.path.abspath(__file__)), "convert_new_batches.py")
    _lost = r"D:\Documents_D\_analysis\lost_batches.txt"
    if not os.path.isfile(_cv):
        say(f"!! --convert 要的工具不在: {_cv}")
    else:
        _cmd = [sys.executable, "-u", _cv, "--apply"]
        if os.path.isfile(_lost):
            _cmd += ["--also", _lost]      # 补转"转过但被跳过"的谱(播种时会剔除它们)
        with open(r"D:\Documents_D\jianpu2\train-work\convert_idle.log", "w", encoding="utf-8") as lg:
            rc = subprocess.run(_cmd, cwd=os.path.dirname(_cv), stdout=lg, stderr=subprocess.STDOUT, text=True)
        tail = ""
        try:
            with io.open(r"D:\Documents_D\jianpu2\train-work\convert_idle.log", encoding="utf-8") as f:
                for ln in f:
                    if ln.startswith("新谱(") or ln.startswith("合并:") or ln.startswith("转换完成"):
                        tail += " " + ln.strip()
        except Exception:                                        # noqa: BLE001
            pass
        say(f"转换新谱(convert_new_batches --apply) 退出码 {rc.returncode} ->{tail}")

# ---- 先导入成品(--import) --------------------------------------------------------
# 为什么要有这一步: 流水线是两段式的, 转录批次只往 `jianpu-db-out/scores/`(成品, 覆盖率报告里叫"待入库")
# 写; 而 `jianpu-db/scores/` -> data.jsonl 那一段**原先靠人手动跑**。夜里批次跑了一整晚, 新谱就
# 一直躺在成品目录里 —— 2026-09-28 实测: 成品 8573 / 语料 7816, **1639 份 status=ocr 从未入库**。
# 顺序**必须先导入再重建**(导入写 scores/, parse_scores 才读得到)。
IMPORT = "--import" in sys.argv
if IMPORT:
    _imp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "import_finished_scores.py")
    if not os.path.isfile(_imp):
        say(f"!! --import 要的工具不在: {_imp}")
    else:
        with open(r"D:\Documents_D\jianpu2\train-work\import_idle.log", "w", encoding="utf-8") as lg:
            ri = subprocess.run([sys.executable, "-u", _imp, "--apply"], cwd=os.path.dirname(_imp),
                                stdout=lg, stderr=subprocess.STDOUT, text=True)
        tail = ""
        try:
            with io.open(r"D:\Documents_D\jianpu2\train-work\import_idle.log", encoding="utf-8") as f:
                for ln in f:
                    if ln.startswith("  -> **可导入") or ln.startswith("已拷入"):
                        tail += " " + ln.strip()
        except Exception:                                        # noqa: BLE001
            pass
        say(f"导入成品(import_finished_scores --apply) 退出码 {ri.returncode} ->{tail}")

r = subprocess.run([sys.executable, "-u", "parse_scores.py"], cwd=DB,
                   stdout=open(r"D:\Documents_D\jianpu2\train-work\parse_idle.log", "w", encoding="utf-8"),
                   stderr=subprocess.STDOUT, text=True)
say(f"重建退出码 {r.returncode}")
time.sleep(10)
if writers():
    say(f"!! 重建后又出现写者: {writers()}  —— 结果可能仍不同步")

# 验证: data.jsonl 的 note 数与 scores/<file> 原文一致
TOK = re.compile(r"^[,']*[qsdh]*[,']*[0-9x]")
# ⚠ 拍号那一行(独立成行的 `4/4`)**必须排掉**: `TOK` 会把它的 "4" 当成音符 -> 文件比 jsonl 永远多 1。
#   实测 2026-09-28: 抽查 10 首**全部**报 `文件 N vs jsonl N-1`, 整齐的差 1 就是这个原因
#   (jsonl 里拍号是**独立字段** `beats_per_bar`, 不在 `score` 里)。
#   验证: `就这样.txt` 是 178, 排掉 `4/4` 后 177 == jsonl 的 177 ✓。
TS_LINE = re.compile(r"^\d+/\d+$")
rows = [json.loads(l) for l in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8") if l.strip()]
bad = 0
for row in random.Random(7).sample(rows, 10):
    f = os.path.join(DB, "scores", row["file"][0])
    if not os.path.exists(f):
        bad += 1; continue
    raw = io.open(f, encoding="utf-8", errors="replace").read()
    n1 = len([t for t in raw.split() if TOK.match(t) and not TS_LINE.match(t)])
    n2 = len([t for t in (row.get("score") or "").replace(" | ", " ").split() if TOK.match(t)])
    if n1 != n2:
        bad += 1
        say(f"  不一致 {row['file'][0]}: 文件 {n1} vs jsonl {n2}")
say(f"验证: {len(rows)} 行, 抽查 10 首, 不一致 {bad}")

# 重建后跑一次"静默丢数据"检查(qa_parse_loss): 抓"正文有音、解析出来却是空"。
# 为什么放这儿: 2026-09-28 的 `%END` 前缀 bug 就是这样丢了一首歌, 而**三道自检都看不见**
# (不变量查进库的数据、自检门查库内一致性、CI 查产物)。代价是几分钟 CPU, 而这时机器本来就空着。
_qp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "qa_parse_loss.py")
if os.path.isfile(_qp):
    with open(r"D:\Documents_D\jianpu2\train-work\qa_parse_loss_idle.log", "w", encoding="utf-8") as lg:
        r = subprocess.run([sys.executable, "-u", _qp], cwd=os.path.dirname(_qp),
                           stdout=lg, stderr=subprocess.STDOUT, text=True)
    tail = ""
    try:
        with io.open(r"D:\Documents_D\jianpu2\train-work\qa_parse_loss_idle.log", encoding="utf-8") as f:
            for ln in f:
                if ln.startswith("①") or ln.startswith("②") or ln.startswith("③"):
                    tail += " " + ln.strip()
    except Exception:                                            # noqa: BLE001
        pass
    say(f"静默丢数据检查(qa_parse_loss) 退出码 {r.returncode} ->{tail}")
    if r.returncode != 0:
        say("!! 有全丢或准入缺口 —— 看 train-work/qa_parse_loss_idle.log")

# 顺带重建前端索引(--site): 语料重建完前端**不会自己更新**, 没人跑 build_web_data.py 就上不了站
if SITE:
    bw = os.path.join(SITE, "tools", "build_web_data.py")
    if not os.path.isfile(bw):
        say(f"!! --site 给的目录里没有 tools/build_web_data.py: {SITE} —— 跳过前端重建")
    else:
        say(f"重建前端索引 -> {os.path.join(SITE, 'data')}")
        with open(r"D:\Documents_D\jianpu2\train-work\build_web_data_idle.log", "w", encoding="utf-8") as lg:
            r = subprocess.run([sys.executable, "-u", bw,
                                "--data", os.path.join(DB, "data.jsonl"),
                                "--out", os.path.join(SITE, "data")],
                               cwd=SITE, stdout=lg, stderr=subprocess.STDOUT, text=True)
        say(f"build_web_data 退出码 {r.returncode}")
        # 对账: 站点 stats 的曲数 == 语料行数; 且前端索引里 0 首重复小节线
        try:
            import gzip
            st = json.load(io.open(os.path.join(SITE, "data", "stats.json"), encoding="utf-8"))
            dup = 0
            n_idx = 0
            with gzip.open(os.path.join(SITE, "data", "songs.jsonl.gz"), "rt", encoding="utf-8") as g:
                for ln in g:
                    if not ln.strip():
                        continue
                    n_idx += 1
                    b = json.loads(ln).get("bars") or []
                    for i in range(1, len(b)):
                        if b[i] <= b[i - 1]:
                            dup += 1
                            break
            okc = (st.get("songs") == len(rows) == n_idx) and dup == 0
            say(f"前端对账: stats.songs={st.get('songs')} 索引={n_idx} 语料={len(rows)} 重复小节线={dup}  {'OK' if okc else '!! 不一致'}")
        except Exception as e:                                   # noqa: BLE001
            say(f"!! 前端对账失败: {type(e).__name__}: {e}")
        # `--push`: 重建完直接提交并推远端(语料仓库 + 站点仓库)。
        # 为什么现在默认不做、要显式开关: 推远端=替人做发布决定。**2026-09-29 用户明确授权**
        # ("仓库你动就行了。我让你动。"), 所以给了这个开关, 我自己的守候都带上它。
        # 对账不通过(okc=False)时**不推** —— 宁可停在本地让人看。
        if PUSH:
            if not okc:
                say("!! 对账没通过, --push 跳过(不推远端)")
            else:
                _commit_push(DB, ["scores", "data.jsonl", "data.json", "by_alias", "by_artist",
                                  "by_copyright", "by_MBID", "by_source", "by_status", "by_tag",
                                  "by_tagroute", "by_title", "by_todo", "by_transcriber"],
                             f"chore(data): 语料 {len(rows)} 首(自动入库)")
                _commit_push(SITE, ["data"], f"chore(data): 重建前端索引({len(rows)} 首)")
        else:
            say("前端索引已就绪(没开 --push, 没自动推远端)。要发布就敲:")
            say(f"    cd {SITE} && git add data && git commit -m \"chore(data): 重建前端索引(新转写的 N 首)\" && git push")
            say("    推送后 pages.yml 会自己把产物同步到仓库根并核对线上首页")
say("完成")
drop_lock()
