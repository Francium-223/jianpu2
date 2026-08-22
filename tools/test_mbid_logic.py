# -*- coding: utf-8 -*-
"""Test MBID confidence tiering with mocked MusicBrainz responses."""
import sys
sys.path.insert(0, ".")
import convert

calls = []


def fake_search(kind, title, artist):
    calls.append((kind, title, artist))
    if title == "永远の巫女":                      # 真实 API: work 无歌手数组, 繁体标题
        return [{"id": "w1", "title": "永遠の巫女", "artists": [], "score": 100}]
    if title == "青花瓷" and artist == "周杰伦":     # 繁简歌手
        return [{"id": "w2", "title": "青花瓷", "artists": ["周杰倫"], "score": 100}]
    if title == "小红帽" and artist is None:       # 裸标题: 命中流行歌(错的)
        return [{"id": "r1", "title": "小红帽", "artists": ["鄧麗欣"], "score": 100}]
    if title == "小红帽" and artist:               # 歌手过滤: 儿歌查不到
        return []
    if title == "故乡的云" and artist == "费翔":
        return [{"id": "w3", "title": "故鄉的雲", "artists": ["費翔"], "score": 92}]
    return []


convert.musicbrainz_search = fake_search
convert.musicbrainz_search.__name__ = "fake_search"

cases = [
    ("永远の巫女", "ZUN"),     # 期望: work, medium (繁简标题近匹配, 无歌手佐证)
    ("青花瓷", "周杰伦"),       # 期望: work, high (歌手字符重合>=2)
    ("小红帽", ""),            # 期望: medium (无歌手佐证, 邓丽欣)
    ("小红帽", "银河少年艺术团"),  # 期望: None (歌手过滤无结果→回退裸标题→medium候选) — 注意: 有回退
    ("故乡的云", "费翔"),       # 期望: medium (近似标题+歌手)
]
for title, artist in cases:
    calls.clear()
    r = convert.musicbrainz_lookup(title, artist)
    print(f"{title} + {artist or '(无)'}")
    print(f"  -> {r[0]} kind={r[1]} conf={r[2]} matched={r[3]}")
    print(f"     queries: {calls}")
