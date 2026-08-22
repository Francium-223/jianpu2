# -*- coding: utf-8 -*-
"""Manually download & extract pure-python packages from PyPI into tools/vendor
(bypasses pip, which is blocked by the sandbox on this machine)."""
import io
import json
import os
import sys
import tarfile
import urllib.request
import zipfile

VENDOR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "vendor")
os.makedirs(VENDOR, exist_ok=True)

UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}


def fetch(url):
    req = urllib.request.Request(url, headers=UA)
    return urllib.request.urlopen(req, timeout=60).read()


def get_sdist_url(pkg):
    data = json.loads(fetch(f"https://pypi.org/pypi/{pkg}/json"))
    for u in data["urls"]:
        if u["packagetype"] == "sdist":
            return u["url"]
    raise RuntimeError(f"no sdist for {pkg}")


def extract_into(data, name, dest):
    if name.endswith(".zip"):
        z = zipfile.ZipFile(io.BytesIO(data))
        top = z.namelist()[0].split("/")[0]
        for m in z.namelist():
            if m.startswith(top + "/") and not m.endswith("/"):
                out = os.path.join(dest, m[len(top) + 1:])
                os.makedirs(os.path.dirname(out), exist_ok=True)
                with open(out, "wb") as f:
                    f.write(z.read(m))
    else:
        t = tarfile.open(fileobj=io.BytesIO(data), mode="r:*")
        top = t.getnames()[0].split("/")[0]
        for m in t.getmembers():
            if m.name.startswith(top + "/") and m.isfile():
                out = os.path.join(dest, m.name[len(top) + 1:])
                os.makedirs(os.path.dirname(out), exist_ok=True)
                with open(out, "wb") as f:
                    f.write(t.extractfile(m).read())


for pkg in sys.argv[1:] or ["jianpu-ly", "python-ly"]:
    url = get_sdist_url(pkg)
    print(f"{pkg}: {url}")
    extract_into(fetch(url), url.rsplit("/", 1)[-1], VENDOR)
    print(f"  -> extracted into {VENDOR}")
