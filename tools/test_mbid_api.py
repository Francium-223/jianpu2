# -*- coding: utf-8 -*-
"""Test MusicBrainz search API variants for MBID auto-lookup."""
import json
import urllib.parse
import urllib.request

UA = {"User-Agent": "jianpu2-converter/1.0 (test)"}


def q(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read().decode("utf-8"))


def show(kind, items):
    for it in items:
        if kind == "work":
            artists = [a.get("name") for a in it.get("artists", [])]
        else:
            artists = [a.get("name") for a in it.get("artist-credit", [])]
        print(f"  {kind:3} {it['id']} | {it.get('title')} | {artists} | score={it.get('score')}")


# 1) work + artist 过滤 (Touhou, 应精确命中)
u = ("https://musicbrainz.org/ws/2/work/?query="
     + urllib.parse.quote('work:"永遠の巫女" AND artist:"ZUN"') + "&fmt=json&limit=3")
show("work", q(u).get("works", []))
print("---")

# 2) work 只按标题 (不限定艺术家)
u = ("https://musicbrainz.org/ws/2/work/?query="
     + urllib.parse.quote('work:"永遠の巫女"') + "&fmt=json&limit=3")
show("work", q(u).get("works", []))
print("---")

# 3) recording + artist 过滤 (华语流行)
u = ("https://musicbrainz.org/ws/2/recording/?query="
     + urllib.parse.quote('recording:"青花瓷" AND artist:"周杰伦"') + "&fmt=json&limit=3")
show("rec", q(u).get("recordings", []))
print("---")

# 4) recording 只按标题 (儿歌, 无艺术家)
u = ("https://musicbrainz.org/ws/2/recording/?query="
     + urllib.parse.quote('recording:"小红帽"') + "&fmt=json&limit=3")
show("rec", q(u).get("recordings", []))
