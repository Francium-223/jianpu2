# -*- coding: utf-8 -*-
"""把 MBID 缓存里的 **recording 命中换成 work** —— 库里 MBID 的约定是 work。

背景(2026-09-28 实测, 不是推理):
  * 语料里 36 条 MBID 逐个问 `/ws/2/work/<id>`: **36/36 都是 200 且标题对得上**
    (例 `th10_06` -> 神々が恋した幻想郷), 当作 recording 问一律 404;前端的 MusicBrainz 链接
    也写死 `/work/<mbid>` -> **约定就是 work**。
  * 而 MusicBrainz 的 **work 实体通常不带 artist**, 于是 `musicbrainz_lookup` 里的 `artist_ok()`
    对 work 永远不成立 -> work 最高只能评到 medium;反倒 recording 有 artist-credit, 能评到 high。
    结果就是"高置信度清一色是 recording"——照那个写库会生成 `/work/<recording-id>` 的死链。
  * 抽样 12 条 high recording: **只有 2 条**挂了 work 关系(≈17%)。所以这一步只能救回一部分;
    剩下的是"确实没有 work 实体", 按"错配比没有更糟"**不该写 MBID**。

做什么:
  * 先备份缓存到 `_analysis/`(只移不删);
  * 对 `kind=recording` 且 `conf ∈ {high, medium}` 的条目, 用 `convert.musicbrainz_recording_work`
    换 id: 换成 -> `kind=work` + 记下 `via`(那条 recording)与 `work_title`;
    换不到 -> 打上 `no_work=true`(重跑时跳过, 幂等);
  * 1.3s/次(礼貌), HTTP 503 退避重试;
  * 结尾抽查新的 work id: `GET /work/<id>` 必须 200 —— 这是验收判据。
用法:
    py -3.13 tools/upgrade_mbid_cache_to_work.py [--limit N]
"""
import argparse
import io
import json
import os
import shutil
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from guard import guard_help        # noqa: E402
guard_help(__doc__)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WS = os.path.dirname(ROOT)
CACHE = os.path.join(ROOT, "train-work", "mbid_cache.json")
sys.path.insert(0, ROOT)
import convert                                              # noqa: E402  唯一口径

UA = {"User-Agent": "jianpu2-mbid-upgrade/0.1 (local audit)"}


def work_ok(wid):
    """验收: 这个 id 真能以 work 取回来吗(标题一并返回)。"""
    url = "https://musicbrainz.org/ws/2/work/%s?fmt=json" % wid
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=25) as r:
        return json.loads(r.read().decode("utf-8")).get("title", "")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--interval", type=float, default=1.3)
    a = ap.parse_args()

    cache = json.load(io.open(CACHE, encoding="utf-8"))
    bak = os.path.join(WS, "_analysis", "mbid_cache_before_work_%s.json"
                       % time.strftime("%Y%m%d-%H%M%S"))
    shutil.copy2(CACHE, bak)
    print("缓存 %d 条, 已备份 -> %s" % (len(cache), bak))

    todo = [(k, v) for k, v in cache.items()
            if v.get("kind") == "recording" and v.get("conf") in ("high", "medium")
            and v.get("mbid") and not v.get("no_work")]
    if a.limit:
        todo = todo[:a.limit]
    print("待换 recording -> work: %d 条" % len(todo))

    conv = none = err = 0
    for i, (k, v) in enumerate(todo, 1):
        wid = wt = None
        failed = False
        for attempt in (1, 2, 3):
            try:
                wid, wt = convert.musicbrainz_recording_work(v["mbid"], v.get("title", ""))
                break
            except Exception as e:                              # noqa: BLE001
                code = getattr(e, "code", 0)
                if code == 503 and attempt < 3:
                    time.sleep(5 * attempt)
                    continue
                failed = True
                err += 1
                print("  !! %-24s 查询出错 HTTP %s" % (k, code), flush=True)
                break
        time.sleep(a.interval)
        if wid:
            v["mbid_before"] = v["mbid"]
            v["mbid"] = wid
            v["kind"] = "work"
            v["via"] = "recording " + v["mbid_before"]
            v["work_title"] = wt
            conv += 1
        elif not failed:
            # 查通了、确实没有 work 关系 -> 打标记, 重跑时不再查(幂等)。
            # 出错的那条**不打标记** —— 下次还要再试。
            v["no_work"] = True
            none += 1
        if i % 25 == 0:
            json.dump(cache, io.open(CACHE, "w", encoding="utf-8"), ensure_ascii=False)
            print("  ...%d/%d  换成 work %d / 没有 work %d / 出错 %d"
                  % (i, len(todo), conv, none, err), flush=True)
    json.dump(cache, io.open(CACHE, "w", encoding="utf-8"), ensure_ascii=False)

    import collections
    cc = collections.Counter((v.get("conf") or "(空)", v.get("kind") or "(空)") for v in cache.values())
    print("\n换完之后的 (置信度, 实体类型) 分布:")
    for kk, n in sorted(cc.items(), key=lambda x: -x[1]):
        print("   %-24s %d" % (str(kk), n))
    print("本轮: 换成 work %d / 没有 work %d / 出错 %d" % (conv, none, err))

    # 验收: 抽查新的 work id 是否能以 work 取回
    sample = [(k, v) for k, v in cache.items() if v.get("kind") == "work" and v.get("via")][:5]
    print("\n抽查新的 work id(必须是 work 且标题对得上):")
    for k, v in sample:
        try:
            t = work_ok(v["mbid"])
            print("   %-26s work %s 标题「%s」%s" % (k, v["mbid"][:8], t,
                  "==缓存标题" if t.strip() == (v.get("work_title") or "").strip() else "(缓存写了 %s)" % v.get("work_title")))
        except Exception as e:                                  # noqa: BLE001
            print("   !! %-26s 取不回: HTTP %s" % (k, getattr(e, "code", e)))
        time.sleep(1.3)
    return 0


if __name__ == "__main__":
    sys.exit(main())
