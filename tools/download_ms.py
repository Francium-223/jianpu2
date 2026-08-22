# -*- coding: utf-8 -*-
"""ModelScope 并行分块下载器 (慢 CDN 对策): 把文件切成 N 段并行拉, 完成后拼接。"""
import os
import ssl
import sys
import threading
import time
import urllib.error
import urllib.request

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}


def get_size(url):
    req = urllib.request.Request(url, headers={**UA, "Range": "bytes=0-0"})
    with urllib.request.urlopen(req, timeout=30, context=ctx) as r:
        cr = r.headers.get("Content-Range", "")
        return int(cr.split("/")[-1]) if "/" in cr else None


def download_range(url, dest, start, end, idx, status, timeout=90):
    """下载 [start, end) 到 dest 的对应偏移, 支持续传。"""
    part = f"{dest}.part{idx}"
    have = os.path.getsize(part) if os.path.exists(part) else 0
    cur = start + have
    if cur >= end:
        status[idx] = end - start
        return
    retries = 40
    for attempt in range(retries):
        try:
            headers = {**UA, "Range": f"bytes={cur}-{end - 1}"}
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
                with open(part, "ab") as f:
                    while True:
                        chunk = r.read(2 * 1024 * 1024)
                        if not chunk:
                            break
                        f.write(chunk)
                        cur += len(chunk)
                        status[idx] = cur - start
            if cur >= end:
                return
        except Exception:
            pass
        time.sleep(min(2 ** attempt, 30))
    raise RuntimeError(f"segment {idx} failed")


def parallel_download(url, dest, segments=8):
    size = get_size(url)
    print(f"总大小: {size/1e6:.0f} MB, {segments} 段")
    if os.path.exists(dest) and os.path.getsize(dest) >= size:
        print("已存在, 跳过")
        return True
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    step = size // segments
    status = [0] * segments
    threads = []
    for i in range(segments):
        start = i * step
        end = size if i == segments - 1 else (i + 1) * step
        t = threading.Thread(target=download_range,
                             args=(url, dest, start, end, i, status))
        t.start()
        threads.append(t)
    last = [0] * segments
    while any(t.is_alive() for t in threads):
        tot = sum(status)
        speed = sum(status[i] - last[i] for i in range(segments))
        print(f"\r  {tot/1e6:.0f}/{size/1e6:.0f} MB  {speed/1e6:.1f} MB/s  ", end="", flush=True)
        last = status[:]
        time.sleep(10)
    for t in threads:
        t.join()
    # 拼接
    with open(dest, "wb") as out:
        for i in range(segments):
            with open(f"{dest}.part{i}", "rb") as p:
                while True:
                    c = p.read(8 * 1024 * 1024)
                    if not c:
                        break
                    out.write(c)
            os.unlink(f"{dest}.part{i}")
    ok = os.path.getsize(dest) >= size
    print(f"\n{'完成' if ok else '不完整'}: {os.path.getsize(dest)/1e6:.0f} MB")
    return ok


if __name__ == "__main__":
    BASE = "https://modelscope.cn/api/v1/models/lmstudio-community/Qwen2.5-VL-7B-Instruct-GGUF/repo?Revision=master&FilePath="
    OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "models", "qwen2.5vl7b")
    for name, segs in [("Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf", 8),
                       ("mmproj-model-f16.gguf", 4)]:
        dest = os.path.join(OUT, name)
        print(f"== {name} ==")
        parallel_download(BASE + name, dest, segs)
