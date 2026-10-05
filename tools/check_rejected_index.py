# -*- coding: utf-8 -*-
"""自检 `tools/rejected_index.py` + 它与 `tools/batch_transcribe_queue.py` 的接线。

为什么要有它(2026-10-05): 拒绝名单的**唯一用途**就是"让队列跳过这些目录"。这条接线一旦坏掉
(路径写错、键对不上、缓存读到旧账、名单缺失时抛异常), 症状是**净增又变回 0 而没人报错** ——
跟修之前一模一样, 看不出来。所以拿临时目录 + 临时名单把三种情形钉住:

    名单内 -> 跳过    名单外 -> 不跳    名单缺失 -> 安静返回空(不抛异常、不误跳)

全程只碰临时目录(`JIANPU_REJECTED` / `JIANPU_DB` / `JIANPU_IMAGES` 都指过去),
**不联网、不写语料、不写 images-prep、不碰真名单**。

用法: python3 tools/check_rejected_index.py
"""
import io
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

fails = []


def check(cond, msg):
    print(("  ✓ " if cond else "  !! ") + msg)
    if not cond:
        fails.append(msg)


def write_list(path, rows):
    """rows = [(目录名, 站点, 站内id, 判定, 依据)]"""
    with io.open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("目录名\t站点\t站内id\t判定\t依据\t时间\n")
        for r in rows:
            f.write("\t".join(list(r) + ["2026-01-01 00:00:00"]) + "\n")


def main():
    tmp = tempfile.mkdtemp(prefix="check_rejected_")
    os.environ["JIANPU_REJECTED"] = os.path.join(tmp, "rejected.tsv")
    # 图库指到一个**不存在**的目录: 本自检不该去走 2.9 万个真图目录
    os.environ["JIANPU_IMAGES"] = os.path.join(tmp, "没有这个图库")

    try:
        import rejected_index as R

        print("=== 1) 名单不存在 -> 安静返回空(不抛异常、不误跳) ===")
        check(not os.path.exists(R.rejected_path()), "名单确实不存在: %s" % R.rejected_path())
        R._cache.clear()
        try:
            got = R.is_rejected("任意曲名__qupu123-1")
            ok = got is False
        except Exception as e:                                  # noqa: BLE001
            got, ok = repr(e), False
        check(ok, "is_rejected() 返回 False -> %r" % (got,))
        check(R.reason_of("任意曲名__qupu123-1") == "", "reason_of() 返回空串")
        check(R.read_rows() == [], "--census 的数据源是空表(不是崩溃)")

        print("\n=== 2) 名单内 -> 跳过；名单外 -> 不跳 ===")
        write_list(R.rejected_path(), [
            ("不让转的歌__qupu123-111", "qupu123", "111", "非纯简谱", "自检夹具"),
            ("没图的歌__jianpucn-222", "jianpucn", "222", "无可用图片", "自检夹具"),
        ])
        R._cache.clear()
        check(R.is_rejected("不让转的歌__qupu123-111") is True, "目录名精确命中 -> 跳过")
        check(R.is_rejected("没图的歌__jianpucn-222") is True, "目录名精确命中(第二类) -> 跳过")
        check(R.is_rejected("能转的歌__qupu123-333") is False, "没在名单里 -> 不跳")
        check(R.reason_of("不让转的歌__qupu123-111") == "非纯简谱", "reason_of() 取得回判定名")
        check(R.reason_of("能转的歌__qupu123-333") == "", "名单外的 reason_of() 是空串")

        print("\n=== 3) 目录名留空时靠 `站-id` 后缀兜底(隔离区文件名被洗过, 只剩后缀可靠) ===")
        write_list(R.rejected_path(), [("", "qupu123", "444", "解析失败", "自检夹具: 只有站-id")])
        R._cache.clear()
        check(R.is_rejected("随便什么名字__qupu123-444") is True,
              "目录名对不上、但 `__qupu123-444` 后缀对上 -> 跳过")
        check(R.is_rejected("随便什么名字__qupu123-445") is False, "后缀对不上 -> 不跳")
        # 目录名被 safe_name 洗过(空格->下划线)也要能认出来
        check(R.is_rejected("随便 什么 名字__qupu123-444") is True, "路径里有空格照样认得后缀")

        print("\n=== 3b) 曲名里带点号也要认得后缀(实测漏过 3 条) ===")
        # `os.path.splitext` 会拿**曲名里的点**当扩展名分隔符: `想你0.01秒__jianpucn-10204`
        # 被切成 `想你0` + `.01秒__jianpucn-10204`, 后缀就这么没了。图目录没有扩展名, 不该走 splitext。
        write_list(R.rejected_path(), [("", "jianpucn", "10204", "非纯简谱", "自检夹具: 曲名带点")])
        R._cache.clear()
        for nm, why in (("想你0.01秒__jianpucn-10204", "曲名里的点"),
                        ("原點(孫燕姿 蔡健雅).__jianpucn-10204", "曲名以点结尾"),
                        ("想你0.01秒__jianpucn-10204.txt", "带 .txt 扩展名"),
                        ("原點(孫燕姿 蔡健雅).__jianpucn-10204.txt", "以点结尾 + .txt")):
            check(R.is_rejected(nm) is True, "%s -> 跳过" % why)
            check(R.reason_of(nm) == "非纯简谱", "%s -> 判定名取得回" % why)
        check(R.is_rejected("想你0.01秒__jianpucn-10205") is False, "只差一个 id 就不跳")

        print("\n=== 4) 缓存: 名单被重写后要读到新账(不能一直吃旧缓存) ===")
        write_list(R.rejected_path(), [("新加的歌__jianpucn-555", "jianpucn", "555", "重复内容", "自检夹具")])
        import time
        time.sleep(0.01)
        R._cache.clear()
        check(R.is_rejected("新加的歌__jianpucn-555") is True, "重写名单后新条目生效")
        check(R.is_rejected("不让转的歌__qupu123-111") is False, "旧条目已随重写消失(重写=新账)")

        print("\n=== 5) 队列真的会跳过: batch_transcribe_queue.py 接线 ===")
        # 临时"语料": 空 scores/ -> existing_sources() 为空, 排除"已在语料"这条线的干扰
        db = os.path.join(tmp, "db")
        os.makedirs(os.path.join(db, "scores"))
        # 临时图库: 两个目录各一张图, 保证"找不到图"不是跳过原因
        imgs = os.path.join(tmp, "imgs")
        for d in ("不进队列的歌__qupu123-111", "要转的歌__qupu123-333"):
            os.makedirs(os.path.join(imgs, "kw", d))
            io.open(os.path.join(imgs, "kw", d, "001.jpg"), "w").write("x")
        q = os.path.join(tmp, "q.tsv")
        with io.open(q, "w", encoding="utf-8", newline="\n") as f:
            f.write("曲名\t站\t页面id\t页数\t类型\t目录\t首图\n")
            f.write("不进队列的歌\tqupu123\t111\t1\t简谱\t不进队列的歌__qupu123-111\t\n")
            f.write("要转的歌\tqupu123\t333\t1\t简谱\t要转的歌__qupu123-333\t\n")
        work = os.path.join(tmp, "work")
        env = dict(os.environ)
        env["JIANPU_DB"] = db
        env["JIANPU_IMAGES"] = imgs
        env["JIANPU_REJECTED"] = R.rejected_path()
        env["PYTHONIOENCODING"] = "utf-8"
        # 名单里放 333(要转的那首) 之外的 111 -> 期望 111 被跳、333 留下
        write_list(R.rejected_path(), [("不进队列的歌__qupu123-111", "qupu123", "111", "非纯简谱", "自检夹具")])
        r = subprocess.run([sys.executable, os.path.join(HERE, "batch_transcribe_queue.py"),
                            "--stage", "import", "--queue", q, "--work", work,
                            "--dry-run"],
                           capture_output=True, text=True, encoding="utf-8", errors="replace",
                           env=env, cwd=ROOT)
        out = (r.stdout or "") + (r.stderr or "")
        check(r.returncode == 0, "队列工具跑通(returncode=%s)" % r.returncode)
        check("跳过 1 条（拒绝名单）" in out, "打出 `跳过 1 条（拒绝名单）` -> %s"
              % [l for l in out.splitlines() if "拒绝名单" in l][:1])
        check("待处理 1 首" in out, "队列 2 条 -> 待处理 1 首 -> %s"
              % [l for l in out.splitlines() if "待处理" in l][:1])

        print("\n=== 6) 名单缺失时队列照跑(不误跳、不崩) ===")
        os.remove(R.rejected_path())
        r = subprocess.run([sys.executable, os.path.join(HERE, "batch_transcribe_queue.py"),
                            "--stage", "import", "--queue", q, "--work", work,
                            "--dry-run"],
                           capture_output=True, text=True, encoding="utf-8", errors="replace",
                           env=env, cwd=ROOT)
        out = (r.stdout or "") + (r.stderr or "")
        check(r.returncode == 0, "没有名单时也跑通(returncode=%s)" % r.returncode)
        check("拒绝名单" not in out, "没有名单就不打跳过行")
        check("待处理 2 首" in out, "队列 2 条 -> 待处理 2 首(一条都不误跳) -> %s"
              % [l for l in out.splitlines() if "待处理" in l][:1])

        print("\n=== 7) 队列工具自己的 --help 不能被 rejected_index 的守卫抢走 ===")
        r = subprocess.run([sys.executable, os.path.join(HERE, "batch_transcribe_queue.py"), "--help"],
                           capture_output=True, text=True, encoding="utf-8", errors="replace",
                           env=env, cwd=ROOT)
        out = (r.stdout or "") + (r.stderr or "")
        check(r.returncode == 0 and "拒绝名单" not in out.split("\n")[0]
              and ("转写队列" in out or "queue_from_crawl" in out),
              "打印的是**队列工具**的用法(不是 rejected_index 的)")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print()
    if fails:
        print("!! 自检失败 %d 项:" % len(fails))
        for f in fails:
            print("   - " + f)
        return 1
    print("✓ rejected_index 自检通过(名单内跳过 / 名单外不跳 / 缺失安静返回空 / 队列接线生效)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
