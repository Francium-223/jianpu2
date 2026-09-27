# -*- coding: utf-8 -*-
"""核对 `propose_mbid` 给出的 high 档 MBID 是不是真对得上（只读，问 MusicBrainz）。

为什么要单独验: 口径说 high = "标题精确 + 歌手匹配 + score>=90 -> 直接填", 但那是**搜索接口的自评**;
落盘前应该拿 MBID 反查一次实体, 确认 (a) 实体存在 (b) 标题确实一致 (c) 署名里有我们那个歌手。
只读, 不写语料。
"""
import io
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

WS = r"D:\Documents_D"
OUT = os.path.join(WS, "_analysis", "mbid_proposal.tsv")
CACHE = os.path.join(WS, "jianpu2", "train-work", "mbid_cache.json")
UA = {"User-Agent": "jianpu-corpus-mbid-verify/1.0 ( https://github.com/Francium-223/jianpu-db )"}


def _cache_path():
    """`--cache <路径>` 可换一份**快照**。

    为什么要这个开关: `propose_mbid.py` 全量跑的时候会每 25 条重写一次缓存,
    核对脚本直接读同一个文件会读到**半截 JSON**(实测), 所以跑核对的正确姿势是
    先 `Copy-Item` 一份快照, 再 `--cache 快照`。
    """
    if "--cache" in sys.argv:
        return sys.argv[sys.argv.index("--cache") + 1]
    return CACHE


def norm(s):
    return re.sub(r"[\s\-_·、,，。.（）()【】\[\]《》!！?？:：;；'\"“”‘’~～|/\\+&]", "", (s or "")).casefold()


def fetch(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=20) as f:
        return json.loads(f.read().decode("utf-8"))


def main():
    cache = json.load(io.open(_cache_path(), encoding="utf-8"))
    highs = [(k, v) for k, v in cache.items() if v.get("conf") == "high" and v.get("mbid")]
    if not highs:
        sys.exit("缓存里还没有 high 档（先跑 propose_mbid.py）")
    print("核对 %d 条 high 档(每条 2 次请求, 间隔 1.1s)\n" % len(highs))
    good = bad = n_variant = 0
    for k, v in highs:
        kind = v.get("kind") or "work"
        mbid = v["mbid"]
        try:
            ent = fetch("https://musicbrainz.org/ws/2/%s/%s?fmt=json&inc=artist-rels"
                        % (kind, urllib.parse.quote(mbid)))
        except Exception as e:                                    # noqa: BLE001
            print("  ! %-30s 查不到实体(%s)" % (v["title"][:30], type(e).__name__))
            bad += 1
            time.sleep(1.1)
            continue
        mt = ent.get("title", "")
        # ⚠ 2026-09-28: 不能只比"完全相等"。语料里大量标题是**简体**, 而 MusicBrainz 那条是**繁体**
        #   (`再見理想` vs `再见理想`、`單行的軌道` vs `单行的轨道`、`一個都不能少` vs `一个都不能少`),
        #   只比相等会把 95/150 判成"标题对不上", 其实全是同一首 —— 我差点被自己这个数字带偏。
        #   改用 `musicbrainz_lookup.title_ok()` 的**同一个口径**: 完全相等算一致; 否则字符重合度
        #   >= 0.5 算"繁简/异体"。(仓库里没有简繁转换表, 检索那边一直就是这么兜的 —— 口径必须一致。)
        _a, _b = norm(mt), norm(v["title"])
        if _a == _b:
            ok_title, variant = True, ""
        else:
            _ov = len(set(_a) & set(_b)) / max(len(_a), len(_b), 1)
            ok_title, variant = (_ov >= 0.5), ("繁简/异体" if _ov >= 0.5 else "")
        arts = []
        for r in (ent.get("relations") or []):
            a = (r.get("artist") or {}).get("name")
            if a:
                arts.append(a)
        for ac in (ent.get("artist-credit") or []):
            if isinstance(ac, dict) and isinstance(ac.get("artist"), dict):
                arts.append(ac["artist"].get("name", ""))
        # work 实体**本来就不带演唱者**(只有词曲作者, 而且常常没登记 rel) —— 所以要**独立佐证**
        # 就得下探一层: 查这个 work 的 recording, 看有没有一条的 artist-credit 是我们的歌手。
        # (第一版只在 work 上看 artist-rels, 于是大部分显示"署名里没我们的歌手",
        #  那是我的核查查错了层面, 不是匹配错了。)
        if not arts and kind == "work":
            try:
                rl = fetch("https://musicbrainz.org/ws/2/recording?work=%s&fmt=json&inc=artist-credits&limit=8"
                           % urllib.parse.quote(mbid))
                for rec in (rl.get("recordings") or []):
                    for ac in (rec.get("artist-credit") or []):
                        if isinstance(ac, dict) and isinstance(ac.get("artist"), dict):
                            n = ac["artist"].get("name", "")
                            if n and n not in arts:
                                arts.append(n)
                time.sleep(1.1)
            except Exception:
                pass
        verified = ok_title and (v.get("artist") and any(norm(v["artist"]) in norm(a) or norm(a) in norm(v["artist"]) for a in arts if a))
        if ok_title and variant:
            n_variant += 1
        _tok = "完全一致" if not variant else variant
        # 保留"标题对得上、但署名里没有我们那个歌手"这一档: 对 **work** 来说这**不是错**
        # (work 认的是作品, 本库那首常常是翻唱; 例 `西海情歌` 的 work 署名是刀郎, 我们这首是降央卓玛)。
        tag = ("✓ " + _tok if verified else
               ("? 标题一致(%s)但署名里没我们的歌手" % _tok if ok_title else "✗ 标题对不上"))
        if ok_title:
            good += 1
        else:
            bad += 1
        print("  %-34s %-10s MB: %s | 署名: %s"
              % ("%s（%s）" % (v["title"][:24], v["artist"][:8]), tag, mt[:28], " / ".join(arts[:3])[:40]))
        time.sleep(1.1)
    print("\n标题一致 %d / %d(其中简繁/异体 %d); 不一致 %d"
          % (good, len(highs), n_variant, bad))
    return 0


if __name__ == "__main__":
    sys.exit(main())
