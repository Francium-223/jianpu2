# -*- coding: utf-8 -*-
"""守候: 等到**没有任何写库进程** -> 干净重建一次 -> 立刻验证 -> 出报告。

为什么必须"等": 实测有定时任务(finalize / to_jianpu_db / parse_scores)在后台写 scores/,
我这边一边重建一边被覆盖, 导致 data.jsonl 与磁盘文件对不上(同一文件名两次读出不同内容)。
判据: 任何命令行含 finalize / to_jianpu_db / parse_scores / transcribe / absorb 的 python 进程。

用法:
    py -3.13 tools/rebuild_when_idle.py [最多等多少分钟=180]
    py -3.13 tools/rebuild_when_idle.py 600 --site D:\\Documents_D\\jianpu-db.github.io

`--site <前端仓库>` 为什么有用(2026-09-28 补): 语料重建完**前端索引并不会自己更新** ——
`data/songs.jsonl.gz` 只有本机能生成(要读 scores/ 与图库), 而站点的 CI 只负责把已入库的
data/ 摊到部署目录。于是新转写的歌会一直躺在 `scores/` 里, 没人跑 build_web_data.py 就上不了站。
给了 --site 就顺带重建前端索引并**自己对账**(stats.songs == data.jsonl 行数、0 首重复小节线)。
**不自动 git commit/push**: 推远端是人的决定, 脚本只把该敲的命令打出来。
"""
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
PAT = re.compile(r"finalize|to_jianpu_db|parse_scores|transcribe|absorb|kugou_pipeline")
_argv = [a for a in sys.argv[1:] if not a.startswith("-")]
WAIT_MIN = int(_argv[0]) if _argv and _argv[0].isdigit() else 180
SITE = None
if "--site" in sys.argv:
    _i = sys.argv.index("--site")
    SITE = os.path.abspath(sys.argv[_i + 1]) if _i + 1 < len(sys.argv) else None


def say(m):
    line = f"{time.strftime('%H:%M:%S')}  {m}"
    print(line, flush=True)
    with io.open(r"D:\Documents_D\jianpu2\train-work\rebuild_when_idle.log", "a", encoding="utf-8") as g:
        g.write(line + "\n")


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
        say(f"前端索引已就绪(我没有自动推远端, 免得替人做决定)。要发布就敲:")
        say(f"    cd {SITE} && git add data && git commit -m \"chore(data): 重建前端索引(新转写的 N 首)\" && git push")
        say("    推送后 pages.yml 会自己把产物同步到仓库根并核对线上首页")
say("完成")
