# -*- coding: utf-8 -*-
"""存量算账: 从 images-prep/ 抽样算 每首图数 / 每图字节 / 两站分布。

只读。输出摘要给"抓完剩余存量要多少请求、多少 GB、多少小时"用。
"""
import collections
import io
import os
import re
import sys
import statistics

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
IMG = r"D:\Documents_D\jianpu2\images-prep"
IMGEXT = re.compile(r"\.(jpg|jpeg|png|gif|webp)$", re.I)
DIRSID = re.compile(r"__(?P<site>[a-z0-9]+)-(?P<sid>[0-9a-z_]+)$")

SITE_PREFIX = {
    "qupu123": re.compile(r"^qupu123"),
    "jianpucn": re.compile(r"^jianpucn"),
}


def site_of(dirname):
    m = DIRSID.search(dirname)
    if not m:
        return None
    return m.group("site")


def main():
    per_site = collections.defaultdict(lambda: {
        "songs": 0, "imgs": 0, "bytes": 0, "hist": collections.Counter(),
        "zero_img_dirs": 0, "bytes_list": [],
    })
    roots = [d for d in os.listdir(IMG) if os.path.isdir(os.path.join(IMG, d))]
    for root in roots:
        m_site = None
        for s, rx in SITE_PREFIX.items():
            if rx.match(root):
                m_site = s
        if not m_site:
            continue
        base = os.path.join(IMG, root)
        for dirpath, dirnames, filenames in os.walk(base):
            for d in list(dirnames):
                s = site_of(d)
                if s != m_site:
                    # 也统计"目录自身就是曲名__站-id"的情形
                    continue
                p = os.path.join(dirpath, d)
                try:
                    names = os.listdir(p)
                except OSError:
                    continue
                szs = []
                for n in names:
                    if not IMGEXT.search(n):
                        continue
                    fp = os.path.join(p, n)
                    try:
                        if os.path.isfile(fp):
                            z = os.path.getsize(fp)
                            if z > 0:
                                szs.append(z)
                    except OSError:
                        pass
                st = per_site[m_site]
                st["songs"] += 1
                st["imgs"] += len(szs)
                st["bytes"] += sum(szs)
                st["hist"][len(szs)] += 1
                if not szs:
                    st["zero_img_dirs"] += 1
                st["bytes_list"].extend(szs)
            # 处理"根下一层直接就是曲名__站-id"的目录已在上面 walk 中算过

    for s in ("qupu123", "jianpucn"):
        st = per_site[s]
        if not st["songs"]:
            print("%s: 无目录" % s)
            continue
        hn = st["imgs"] / st["songs"]
        bl = sorted(st["bytes_list"])
        print("== %s ==" % s)
        print("  曲名目录 %d 个 · 图 %d 张 · 总字节 %.2f GB" % (
            st["songs"], st["imgs"], st["bytes"] / 1024 ** 3))
        print("  平均每首 %.3f 张(含 0 图目录 %d 个; 去掉 0 图后 %.3f 张)" % (
            hn, st["zero_img_dirs"],
            st["imgs"] / max(1, st["songs"] - st["zero_img_dirs"])))
        if bl:
            print("  单图字节: 均值 %.0f KB · 中位 %.0f KB · p90 %.0f KB · p99 %.0f KB · 最大 %.0f KB" % (
                sum(bl) / len(bl) / 1024, bl[len(bl) // 2] / 1024,
                bl[int(len(bl) * .9)] / 1024, bl[int(len(bl) * .99)] / 1024, bl[-1] / 1024))
        print("  图数分布(张:目录数): %s" % ", ".join(
            "%d:%d" % (k, st["hist"][k]) for k in sorted(st["hist"])[:12]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
