# -*- coding: utf-8 -*-
"""取 jianpujia 的"列表页 id -> 名字"(缓存 train-work/jianpujia_list_titles.tsv)。

为什么需要: `images-prep/jianpujia-<id>/` 这批下载目录**只留了 id**, 歌手/分类名没随页存下来。
上游 `train-work/jianpujia_artists.tsv` 只有 76 条(它当时是"要爬谁"的清单, 不是全集),
实测 19 个批次里 10 个查得到、9 个查不到。列表页自己的 <title> 就是名字:
    `https://www.jianpujia.com/list/<id>-1.html` -> `张学友的曲谱列表-简谱之家`
  站点证书过期 -> 必须关校验(ctx.check_hostname=False)。结果落盘缓存, 之后不再联网。
"""
import io, os, re, ssl, sys, time, urllib.request

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
CACHE = "train-work/jianpujia_list_titles.tsv"
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE


def load():
    m = {}
    if os.path.exists(CACHE):
        for ln in io.open(CACHE, encoding="utf-8"):
            c = ln.rstrip("\n").split("\t")
            if len(c) == 2:
                m[c[0]] = c[1]
    return m


def fetch(i):
    try:
        r = urllib.request.urlopen(f"https://www.jianpujia.com/list/{i}-1.html", timeout=20, context=CTX)
        h = r.read().decode("utf-8", "replace")
        t = re.search(r"<title>(.*?)</title>", h, re.S)
        s = t.group(1).strip() if t else ""
        s = re.sub(r"的曲谱列表.*$", "", s).strip()
        return s
    except Exception as ex:
        return "ERR:" + type(ex).__name__


def main():
    ids = sys.argv[1:]
    m = load()
    for i in ids:
        if i in m and not m[i].startswith("ERR:"):
            continue
        m[i] = fetch(i)
        print(f"{i}\t{m[i]}", flush=True)
        time.sleep(0.6)
    with io.open(CACHE, "w", encoding="utf-8", newline="\n") as g:
        g.write("id\t名字\n")
        for k in sorted(m, key=lambda x: int(x) if x.isdigit() else 0):
            g.write(f"{k}\t{m[k]}\n")
    print(f"缓存 {len(m)} 条 -> {CACHE}")


if __name__ == "__main__":
    main()
