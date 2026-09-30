# -*- coding: utf-8 -*-
"""起隧道 + 把地址写进 Worker 的 API_UPSTREAM —— **只用 Python**，不依赖 PowerShell / bash。

## 为什么是 Python 而不是 .ps1 / .cmd

* `.ps1` 要求 PowerShell 7（**目标机器上没有**，用户 2026-09-30 明确说了）；
* `.cmd` 要做"读日志抠 URL、起进程、管道喂 stdin、判 JSON"这些事，批处理的引号/括号规则会把人逼疯
  （第一版 `tunnel_up.cmd` 就是这么崩的：`if (...)` 里嵌 `for /f ('…')`，内层单引号和 `)` 直接把块劈开）。
* 而这台机器**一定有 Python** —— 服务本体 `app/server.py` 就是它。所以逻辑写在这儿，
  `tunnel_up.cmd` / `tunnel_up.sh` 只做一层"找到 python 再调它"的薄壳。

## 它做什么

1. 看本机服务在不在；不在就起来（带 `JPSUBMIT_TOKEN`，没有就生成一个并记下来）；
2. 服务**必须**要求 `X-Token`，否则拒绝继续（隧道一开等于把写接口挂公网）；
3. 起 cloudflared 快速隧道，从日志里等出 `https://xxx.trycloudflare.com`；
4. 把地址与 token 写进 Worker（`npx wrangler secret put`；**这台机器没有 npx 就跳过并打印手工做法**）；
5. 验 `https://jianpu-db.org/api/health` 的 `api` 是否为 true；地址/token/隧道 PID 记进状态文件。

用法:
  py -3.13 tools/tunnel_up.py                    # 默认 8770 + 站点仓库在 ../jianpu-db.github.io
  py -3.13 tools/tunnel_up.py --port 8790 --no-secret     # 只起服务+隧道并打印地址（不碰 Worker）
  py -3.13 tools/tunnel_up.py --site D:\\my\\jianpu-db.github.io
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
# 两处布局都要认（同一份脚本，既在本机仓库里跑，也在便携包根目录里跑）:
#   仓库布局: <jianpu2>/tools/tunnel_up.py      -> ROOT = <jianpu2>
#   便携包:   <bundle>/tunnel_up.py             -> ROOT = <bundle>（app/server.py 就在旁边）
if os.path.isdir(os.path.join(HERE, "..", "train-work")) or \
        os.path.exists(os.path.join(HERE, "..", "tools", "tunnel_up.py")):
    ROOT = os.path.dirname(HERE)
else:
    ROOT = HERE
_SITE_IN_ROOT = os.path.exists(os.path.join(ROOT, "app", "server.py"))
SITE_DEFAULT = ROOT if _SITE_IN_ROOT else os.path.join(os.path.dirname(ROOT), "jianpu-db.github.io")
PAT = re.compile(r"https://[a-z0-9-]+\.trycloudflare\.com")
WIN = os.name == "nt"
DETACH = 0
if WIN:
    DETACH = getattr(subprocess, "DETACHED_PROCESS", 0) | \
        getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)


def http_json(url, timeout=10):
    import urllib.request
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8", "replace"))
    except Exception:
        return None


def pick_dir(preferred, fallback_name):
    """挑一个落盘目录: 仓库里那个优先, 换台机器就用脚本旁边的 .state/。"""
    for d in (preferred, os.path.join(HERE, ".state")):
        try:
            os.makedirs(d, exist_ok=True)
            return d
        except OSError:
            continue
    return os.path.join(HERE, fallback_name)


def kill_pid(pid):
    try:
        if WIN:
            subprocess.run(["taskkill", "/PID", str(pid), "/F"], capture_output=True)
        else:
            os.kill(pid, 15)
        return True
    except Exception:
        return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8770)
    ap.add_argument("--site", default=SITE_DEFAULT)
    ap.add_argument("--cf", default=r"C:\Program Files (x86)\cloudflared\cloudflared.exe")
    ap.add_argument("--timeout", type=int, default=60, help="等隧道地址的秒数")
    ap.add_argument("--no-secret", action="store_true", help="不写 Worker secret（只起服务+隧道）")
    ap.add_argument("--domain", default="https://jianpu-db.org")
    ap.add_argument("--print-paths", action="store_true", help="只打印它认定的路径就退出（排障用）")
    a = ap.parse_args()

    if a.print_paths:
        for k, v in (("HERE", HERE), ("ROOT", ROOT), ("site", a.site), ("cf", a.cf)):
            print(f"  {k}={v}")
        return 0
    state = pick_dir(os.path.join(ROOT, "train-work"), "train-work")
    logs = pick_dir(os.path.join(os.path.dirname(ROOT), "_analysis"), "_analysis")
    secret_file = os.path.join(state, "tunnel_secret.txt")
    pid_file = os.path.join(state, "tunnel.pid")
    log_file = os.path.join(logs, "tunnel.log")

    # ── token ──────────────────────────────────────────────────────────────
    tok = ""
    if os.path.exists(secret_file):
        m = re.search(r"TOKEN=(\S+)", open(secret_file, encoding="utf-8", errors="replace").read())
        if m:
            tok = m.group(1)

    # ── 1) 本机服务 ────────────────────────────────────────────────────────
    h = http_json(f"http://127.0.0.1:{a.port}/api/health", 6)
    if not h:
        if not tok:
            tok = "jp" + uuid.uuid4().hex[:20]
            print(f"  没找到 token，新生成一个: {tok}")
        server = os.path.join(a.site, "app", "server.py")
        if not os.path.exists(server):
            print(f"  ! 找不到 {server}（用 --site 指站点仓库）")
            return 1
        print(f"  本机服务没在跑，起来（带 JPSUBMIT_TOKEN）: {server}")
        env = dict(os.environ, JPSUBMIT_TOKEN=tok)
        subprocess.Popen([sys.executable, server, str(a.port)], cwd=a.site, env=env,
                         creationflags=DETACH,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(15):
            time.sleep(1)
            h = http_json(f"http://127.0.0.1:{a.port}/api/health", 6)
            if h:
                break
    if not h:
        print(f"  ! 本机服务起不来（http://127.0.0.1:{a.port}/api/health 取不到）")
        return 1
    if not h.get("token_required"):
        print("  ! 本机服务**没有**要求 X-Token —— 隧道一开等于把写接口挂公网，中止。")
        print("    先把 JPSUBMIT_TOKEN 设成一串口令再起 app/server.py，")
        print("    并把同一个值写进 Worker:  npx wrangler secret put API_TOKEN")
        return 1
    print(f"  ✓ 本机服务在跑，且要求 X-Token（repo={h.get('repo')}）")

    # ── 2) 起隧道（先停掉上一次我们自己起的那个） ─────────────────────────────
    if os.path.exists(pid_file):
        try:
            old = int(open(pid_file).read().strip())
            if kill_pid(old):
                print(f"  清掉上一个隧道（我们自己记着的 PID {old}）")
                time.sleep(2)
        except Exception:
            pass
    if not os.path.exists(a.cf):
        print(f"  ! 没装 cloudflared: {a.cf}")
        print(f"    装好后重跑；或自己跑一句: cloudflared tunnel --url http://127.0.0.1:{a.port}")
        return 1
    # ⚠ **不要删日志文件**: 上一个隧道可能还在往里写（Windows 上会 WinError 32 文件占用），
    #   而且"删了再等"还会把上一次的地址当成这一次的。改成**记下当前长度，只看之后新增的部分**。
    try:
        offset = os.path.getsize(log_file)
    except OSError:
        offset = 0
    p = subprocess.Popen([a.cf, "tunnel", "--url", f"http://127.0.0.1:{a.port}",
                          "--no-autoupdate", "--logfile", log_file],
                         creationflags=DETACH,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    open(pid_file, "w").write(str(p.pid))
    print(f"  隧道进程 PID {p.pid}，等地址（最多 {a.timeout} 秒）...")

    # ── 3) 等地址（只看这次追加的那段） ────────────────────────────────────
    url, deadline = "", time.time() + a.timeout
    while time.time() < deadline:
        try:
            with open(log_file, encoding="utf-8", errors="replace") as f:
                f.seek(offset)
                txt = f.read()
        except OSError:
            txt = ""
        m = PAT.search(txt)
        if m:
            url = m.group(0)
            break
        time.sleep(2)
    if not url:
        print(f"  ! {a.timeout} 秒没等到隧道地址，看日志: {log_file}")
        return 1
    print(f"  ✓ 隧道: {url}")

    # ── 4) 写进 Worker ────────────────────────────────────────────────────
    if a.no_secret:
        print("  （--no-secret：跳过写 Worker secret）")
    else:
        npx = "npx.cmd" if WIN else "npx"
        have = subprocess.run(["where", npx] if WIN else ["which", npx],
                              capture_output=True).returncode == 0
        if not have:
            print("  - 这台机器没有 npx，**跳过**。两选一：")
            print(f"      a) 在有 Node 的机器上:  echo {url}|npx wrangler secret put API_UPSTREAM")
            print(f"                              echo {tok}|npx wrangler secret put API_TOKEN")
            print("      b) Cloudflare 面板 → Workers & Pages → jianpu-web → Settings → "
                  "Variables and Secrets，加 API_UPSTREAM / API_TOKEN")
        else:
            for name, val in (("API_UPSTREAM", url), ("API_TOKEN", tok)):
                r = subprocess.run([npx, "wrangler", "secret", "put", name], cwd=a.site,
                                   input=val + "\n", text=True, encoding="utf-8",
                                   errors="replace", capture_output=True, shell=WIN)
                out = (r.stdout or "") + (r.stderr or "")
                ok = ("Success" in out) or (r.returncode == 0 and "ERROR" not in out)
                print(f"  {'✓' if ok else '✗'} {name}" + ("" if ok else f"  <- {out.strip()[:200]}"))

    # ── 5) 验域名 + 记状态 ────────────────────────────────────────────────
    time.sleep(6)
    dh = http_json(a.domain + "/api/health", 20)
    if dh:
        print(f"  域名 health: api={dh.get('api')} upstream={dh.get('upstream')} og={dh.get('og')}")
        if not dh.get("api"):
            print("  ! api 还是 false —— secret 可能没生效或没写，稍等再验一次")
    else:
        print(f"  ! {a.domain}/api/health 取不到")
    with open(secret_file, "w", encoding="utf-8", newline="\n") as f:
        f.write(f"URL={url}\nTOKEN={tok}\nPID={p.pid}\n"
                f"# {time.strftime('%Y-%m-%d %H:%M')} 起：cloudflared 快速隧道 -> 127.0.0.1:{a.port}；"
                "Worker 的 API_UPSTREAM/API_TOKEN 就是上面两个值。\n"
                "# 重启电脑后跑一次: tunnel_up.cmd（macOS/Linux: ./tunnel_up.sh）\n"
                "# 本机服务要用同一个 token 起（否则本脚本会拒绝继续）\n")
    print(f"  记在: {secret_file}")
    print("  想固定地址: cloudflared tunnel login 授权后，用命名隧道绑 api.jianpu-db.org")
    return 0


if __name__ == "__main__":
    sys.exit(main())
