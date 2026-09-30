# -*- coding: utf-8 -*-
"""从 cloudflared 的日志里**等出**快速隧道的地址，打印到 stdout（给 .cmd / .sh 脚本用）。

为什么单独做成一个 py: `tunnel_up.cmd`（纯 cmd，不依赖 PowerShell）要从日志里抠出
`https://xxx.trycloudflare.com` —— 在批处理里做正则提取又丑又容易错，而**这台机器一定有 Python**
（服务本体就是 Python）。所以让 Python 干这件事，批处理只负责调用。

用法:
  py -3.13 tools/tunnel_url.py <日志文件> [秒数=60]
退出码: 0 = 拿到并打印了地址; 2 = 超时没等到; 1 = 用法/读文件出错。
"""
import io
import os
import re
import sys
import time

PAT = re.compile(r"https://[a-z0-9-]+\.trycloudflare\.com")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    log = sys.argv[1]
    timeout = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 60
    deadline = time.time() + timeout
    while True:
        try:
            txt = io.open(log, encoding="utf-8", errors="replace").read()
        except OSError:
            txt = ""
        m = PAT.search(txt)
        if m:
            print(m.group(0))
            return 0
        if time.time() >= deadline:
            sys.stderr.write(f"等了 {timeout} 秒没在 {os.path.abspath(log)} 里看到隧道地址\n")
            return 2
        time.sleep(2)


if __name__ == "__main__":
    sys.exit(main())
