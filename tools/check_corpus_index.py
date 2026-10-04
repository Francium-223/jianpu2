# -*- coding: utf-8 -*-
"""自检 `tools/corpus_index.py` —— 爬虫"避抓"的判据是否真的按**语料里的曲谱文件**算。

为什么要有它(2026-10-04): 之前爬虫判"抓过没有"只看 `images/` 目录在不在, 结果一轮 1764 条
转写队列里几乎全是语料里早有的曲子(净增 1 首)。这次把判据换成 `scores/*.txt`, 而"判据"这种东西
最容易在改动里悄悄漂掉(改名、换个归一化、缓存写错), 所以拿**临时语料**把它钉住: 已存在 -> 跳过,
不存在 -> 抓。

全程只碰临时目录(`JIANPU_DB` 指过去), **不联网、不写语料、不写 images-prep**。

用法: python3 tools/check_corpus_index.py
"""
import io
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

fails = []


def check(cond, msg):
    print(("  ✓ " if cond else "  !! ") + msg)
    if not cond:
        fails.append(msg)


SCORE = """%%{stem}.txt
title={title}
tag=
usertag=
tagroute=
transcriber=check
status=ocr
source={source}
%--
4/4
subtitle=score
1 2 3 4 5 6 7 1'
%END
"""


def write_score(scores, stem, title, source):
    p = os.path.join(scores, stem + ".txt")
    io.open(p, "w", encoding="utf-8", newline="\n").write(
        SCORE.format(stem=stem, title=title, source=source))


def main():
    tmp = tempfile.mkdtemp(prefix="check_corpus_index_")
    db = os.path.join(tmp, "jianpu-db")
    scores = os.path.join(db, "scores")
    os.makedirs(scores)
    os.environ["JIANPU_DB"] = db
    os.environ.pop("JP_JIANPU_DB", None)
    empty = tempfile.mkdtemp(prefix="check_corpus_index_empty_")

    try:
        import corpus_index as ci

        print("=== 1) 语料索引(假语料: 3 首) ===")
        check(ci.scores_dir() == scores, "scores_dir() 认 JIANPU_DB -> %s" % scores)
        # 语料里两个文件: 一个标题与文件名一致, 一个文件名带 `__站-id` 后缀(真实语料就这两种)
        write_score(scores, "路灯下的小姑娘", "路灯下的小姑娘", "qupu123-377993")
        write_score(scores, "爱错__jianpujia-9998", "爱错", "jianpujia-9998")
        # 语料里放一首**长一点的**歌, 专门验包含关系(短曲名按 `same()` 规则本来就匹配不上带歌手后缀的标题)
        write_score(scores, "蜗牛与黄鹂鸟", "蜗牛与黄鹂鸟", "jianpujia-15619")
        srcs = ci.existing_sources()
        names = ci.existing_score_names()
        check(srcs == {"qupu123-377993", "jianpujia-9998", "jianpujia-15619"},
              "existing_sources() -> %s" % sorted(srcs))
        check(ci.norm_title("路灯下的小姑娘") in names, "曲名进了名字集(标题)")
        check(ci.norm_title("爱错") in names, "曲名进了名字集(文件名主干去掉 __站-id)")
        check("jianpujia-9998" in ci.source_of_name("爱错__jianpujia-9998.txt"),
              "source_of_name() 能从文件名取回站-id")

        print("\n=== 2) 已存在 -> 跳过 / 不存在 -> 抓 ===")
        rows = [
            ("qupu123", "377993", "路灯下的小姑娘", "source", "站内 id 已在语料"),
            ("qupu123", "88888888", "路灯下的小姑娘", "title", "换个 id, 但曲名已在语料"),
            ("jianpujia", "9998", "爱错", "source", "站内 id 已在语料"),
            ("jianpujia", "7777777", "蜗牛与黄鹂鸟简谱_儿歌", "title", "站点标题那种长尾巴, 归一化后前缀同名"),
            ("jianpujia", "6666666", "蜗牛与黄鹂鸟(粤语)", "title", "带括号说明, 归一化后同名"),
            ("qupu123", "12345678", "一首语料里没有的歌", "", "真新歌, 要抓"),
            ("jianpucn", "475747", "苍穹唤", "", "真新歌, 要抓"),
        ]
        for site, sid, title, want, why in rows:
            got = ci.skip_reason(site, sid, title)
            check(got == want, "skip_reason(%s, %s, %s) = %r <- %s" % (site, sid, title, got or "抓", why))

        print("\n=== 3) 跳过计数 ===")
        c = ci.SkipCounter()
        for _ in range(3):
            c.count("source")
        for _ in range(2):
            c.count("title")
        check((c.source, c.title, c.total) == (3, 2, 5), "计数 -> %s" % c.summary())

        print("\n=== 4) 缓存: 一次进程只扫一遍 ===")
        write_score(scores, "新加的歌", "新加的歌", "jianpucn-1")
        check(ci.title_in_corpus("新加的歌") is False, "改语料后**不重扫**(缓存生效, 仍是旧结果)")
        check(len(ci.existing_sources()) == 3, "existing_sources() 同样命中缓存")

        print("\n=== 5) 语料目录不存在时安静返回空集(不能抛异常) ===")
        os.environ["JIANPU_DB"] = os.path.join(empty, "没有这个仓库")
        check(ci.existing_sources() == set(), "existing_sources() 返回空集")
        check(ci.existing_score_names() == set(), "existing_score_names() 返回空集")
        check(ci.skip_reason("qupu123", "1", "任何歌") == "", "没有语料时一切照抓(不误跳)")
        check(ci.title_in_corpus("任何歌") is False, "title_in_corpus() 为假")

        print("\n=== 6) 爬虫能在没有语料时 import(否则 --help 冒烟自检会红) ===")
        import subprocess
        code = ("import sys; sys.path.insert(0, %r); import corpus_index as ci; "
                "print('OK', len(ci.existing_sources()))" % HERE)
        env = dict(os.environ)
        env["JIANPU_DB"] = os.path.join(empty, "没有这个仓库")
        r = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True,
                           encoding="utf-8", errors="replace", env=env, cwd=os.path.dirname(HERE))
        check(r.returncode == 0 and r.stdout.strip() == "OK 0",
              "子进程里 import 正常 -> %r" % (r.stdout.strip() or r.stderr.strip()[:60]))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        shutil.rmtree(empty, ignore_errors=True)

    print()
    if fails:
        print("!! 自检失败 %d 项:" % len(fails))
        for f in fails:
            print("   - " + f)
        return 1
    print("✓ corpus_index 自检通过(判据按语料: 已存在则跳过)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
