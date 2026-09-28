# -*- coding: utf-8 -*-
"""把 `batch-out/` 里**还没转过的**新谱, 安全地转成成品并合并进 `jianpu-db-out/scores/`。

为什么不能直接 `to_jianpu_db.py` 整份重转(实测, tools/check_convert_rename_drift.py):
    9043 个 batch 里, 单单"今天新写的 428 个"就会让 **176 首老谱改名**、**162 首新谱抢走旧名**;
    而 `import_finished_scores.py` 是"只拷不覆盖" —— 抢名的新歌被丢掉, 改名后的老歌被再拷一份。
    => 增量入库必须"只转新谱 + 躲开已用名 + 落点隔离"。

做法:
    1. 记账(`train-work/converted_batches.txt`)记住"哪些 batch 名已经转过了";
       账本不存在时用 mtime 播种: 早于"现成成品最新 mtime"的都算已转过(那批就是上次整份转的)。
    2. 只把新谱名单喂给 `to_jianpu_db.py --only <名单> --avoid <成品目录> --outdir <暂存>`;
       `--avoid` 让它自动退到 `_2`/`_3`, 不会跟任何现成成品撞名。
    3. 按 `_converted.tsv` 清单把暂存里的成品**只拷不覆盖**地合进 `jianpu-db-out/scores/`。
    4. 把"真的转出文件了"的 batch 名记进账本(太短被跳过的**不记账**, 以后再转还能补上)。

用法:
    py -3.13 tools/convert_new_batches.py                 # 只看要转哪些(默认 dry)
    py -3.13 tools/convert_new_batches.py --apply         # 真转 + 合并
    py -3.13 tools/convert_new_batches.py --apply --meter # 新谱拍号走模型(默认 4/4)
"""
import argparse
import glob
import io
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from guard import guard_help        # noqa: E402
guard_help(__doc__)

FIN = os.path.join(ROOT, "jianpu-db-out", "scores")


def batch_names():
    out = {}
    for p in glob.glob(os.path.join(ROOT, "batch-out", "*.txt")):
        n = os.path.splitext(os.path.basename(p))[0]
        if n != "progress":
            out[n] = p
    return out


def read_ledger(p):
    if not os.path.isfile(p):
        return None
    return {l.strip() for l in io.open(p, encoding="utf-8") if l.strip()}


def seed_ledger(fin_mtime):
    """账本不存在时的播种: 早于"成品最新 mtime"的 batch 算已转过。"""
    return [n for n, p in batch_names().items() if os.path.getmtime(p) <= fin_mtime]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="默认 dry: 只列要转的")
    ap.add_argument("--stage", default=os.path.join(ROOT, "train-work", "conv-new"))
    ap.add_argument("--ledger", default=os.path.join(ROOT, "train-work", "converted_batches.txt"))
    ap.add_argument("--fin", default=FIN)
    ap.add_argument("--meter", action="store_true", help="新谱拍号调模型认(默认 4/4, 慢)")
    ap.add_argument("--limit", type=int, default=0, help="最多转几首(0=全部)")
    ap.add_argument("--also", default="", help="额外强制要转的 batch 名单文件(每行一个) —— 补转"
                                              "'转过但导入时被跳过'的谱, 见 tools/check_convert_damage.py")
    a = ap.parse_args()

    forced = set()
    if a.also and os.path.isfile(a.also):
        forced = {l.strip() for l in io.open(a.also, encoding="utf-8") if l.strip()}
    bn = batch_names()
    fins = glob.glob(os.path.join(a.fin, "*.txt"))
    fin_mtime = max((os.path.getmtime(p) for p in fins), default=0)
    when = time.strftime("%Y-%m-%d %H:%M", time.localtime(fin_mtime)) if fin_mtime else "(无成品)"
    led = read_ledger(a.ledger)
    print(f"batch-out {len(bn)} 个 · 成品 {len(fins)} 份(最新 {when})")

    if led is None:
        seeded = seed_ledger(fin_mtime)
        # 播种是"按 mtime 猜"的 —— 里面会混进"转过但导入时被跳过"的谱(抢名那批)。
        # 这些必须**剔除**, 否则账本一播就把它们永久锁死, 白转的谱再也补不回来。
        seeded = [n for n in seeded if n not in forced]
        print(f"账本不存在 -> 用 mtime 播种 {len(seeded)} 个(早于成品最新 mtime 的都算已转过)")
        if a.apply:
            os.makedirs(os.path.dirname(a.ledger), exist_ok=True)
            with io.open(a.ledger, "w", encoding="utf-8") as g:
                g.write("\n".join(sorted(seeded)) + "\n")
            print(f"   账本已写 -> {a.ledger}")
        led = set(seeded)

    # 账本里有的一律跳过(有账本=转过且并进去了, 再转会撞出新的一份 -> 重复)。
    # `--also` 只是"额外候选", 仍然受账本约束 —— 它的作用是**在播种时不被锁死**。
    new = sorted(n for n in (set(bn) | forced) if n in bn and n not in led)
    if forced & led:
        print(f"(--also 里有 {len(forced & led)} 个已在账本里, 跳过 —— 那些已经转进去了)")
    if a.limit:
        new = new[:a.limit]
    print(f"新谱(账本里没有的): {len(new)} 个")
    for n in new[:10]:
        print(f"   {n}")
    if len(new) > 10:
        print(f"   ... 还有 {len(new) - 10} 个")
    if not new:
        print("没有新谱, 不用转。")
        return
    if not a.apply:
        print("\n(dry) 加 --apply 才会真转。")
        return

    # 暂存目录: 老内容**移走不删**(与项目一贯口径一致)
    if os.path.isdir(a.stage) and os.listdir(a.stage):
        prev = a.stage + "-prev"
        shutil.rmtree(prev, ignore_errors=True)
        shutil.move(a.stage, prev)
        print(f"暂存老内容移到 {prev}")
    os.makedirs(a.stage, exist_ok=True)
    lst = os.path.join(a.stage, "_names.txt")
    with io.open(lst, "w", encoding="utf-8") as g:
        g.write("\n".join(new) + "\n")

    cmd = [sys.executable, "-u", os.path.join(ROOT, "tools", "to_jianpu_db.py"),
           "--outdir", a.stage, "--only", lst, "--avoid", a.fin]
    if a.meter:
        cmd.append("--meter")
    print("跑: " + " ".join(cmd[1:]))
    r = subprocess.run(cmd, cwd=ROOT)
    if r.returncode != 0:
        sys.exit(f"!! to_jianpu_db 退出码 {r.returncode}")

    man = os.path.join(a.stage, "_converted.tsv")
    if not os.path.isfile(man):
        sys.exit(f"!! 没有清单文件 {man}")
    pairs = []
    for i, l in enumerate(io.open(man, encoding="utf-8")):
        if i == 0 or not l.strip():
            continue
        b, o = l.rstrip("\n").split("\t")
        pairs.append((b, o))
    copied = skipped = 0
    for b, o in pairs:
        src = os.path.join(a.stage, o + ".txt")
        dst = os.path.join(a.fin, o + ".txt")
        if not os.path.isfile(src):
            print(f"   !! 清单里的 {o}.txt 不在暂存里")
            continue
        if os.path.exists(dst):
            skipped += 1            # 只拷不覆盖
            continue
        shutil.copy2(src, dst)
        copied += 1
    with io.open(a.ledger, "a", encoding="utf-8") as g:
        g.write("\n".join(sorted(b for b, _o in pairs)) + "\n")
    print(f"合并: 拷入 {copied} 份, 因已存在跳过 {skipped} 份 · 记账 {len(pairs)} 个 -> {a.ledger}")
    print("下一步: py -3.13 tools/import_finished_scores.py --apply   (再 cd jianpu-db && py parse_scores.py)")


if __name__ == "__main__":
    main()
