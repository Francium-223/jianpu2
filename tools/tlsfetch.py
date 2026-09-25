# -*- coding: utf-8 -*-
"""取页时对**过期证书**的兜底 —— qupu123 的证书 2026-09-23 到期, 之后所有严格校验的
客户端都取不到它, 而工具把失败一律记成"站点打不开/反爬", 白白停摆了两天。

教训: 证书过期**不是**网络不通, 也不该整站禁用校验。这里的口径是:

  1. **先用正常校验取**;
  2. 只有真的抛"证书过期/校验失败"时, 才针对**这一个 host** 改成不校验再试一次,
     并在 stderr 打一行带 host 的警告(每个 host 只打一次);
  3. 别的原因(超时/拒绝/404)照旧抛出/返回 —— 免得把"站真挂了"误判成"证书问题"。

用法:
    from tlsfetch import urlopen          # 与 urllib.request.urlopen 同签名(多两个开关)
    with urlopen(req, timeout=25) as r: ...

也可以直接跑本文件做离线自检:
    python3 tools/tlsfetch.py
"""
import ssl
import sys
import threading
import urllib.error
import urllib.parse
import urllib.request

_LOCK = threading.Lock()
_SKIP_VERIFY = {}                     # host -> True: 该 host 已确认要跳过证书校验


def host_of(req):
    url = getattr(req, "full_url", None) or (req if isinstance(req, str) else "")
    return urllib.parse.urlsplit(url).netloc


def is_cert_error(exc):
    """只在真的"证书问题"上返回 True。

    urllib 会把 ssl 的异常包在 URLError.reason 里, 所以两个位置都要看;
    另外不同 Python 版本的措辞不一样(证书过期 / 校验失败 / hostname 不匹配), 所以兜一层字符串。
    """
    reason = getattr(exc, "reason", None)
    if isinstance(reason, ssl.SSLCertVerificationError) or isinstance(exc, ssl.SSLCertVerificationError):
        return True
    if isinstance(reason, ssl.SSLError) and "certificate" in str(reason).lower():
        return True
    s = str(exc).lower()
    return ("certificate verify failed" in s or "certificate has expired" in s
            or "certificate is not yet valid" in s or "hostname mismatch" in s
            or "self-signed certificate" in s)


def _ctx(verify):
    return ssl.create_default_context() if verify else ssl._create_unverified_context()


def urlopen(req, timeout=20, context=None, allow_bad_cert=True, warn=True):
    """urllib.request.urlopen 的包装: 见模块文档的 1/2/3 步。

    context 显式给了就不再兜底(调用方自己负责)。
    """
    host = host_of(req)
    skip = False
    if context is None:
        with _LOCK:
            skip = bool(_SKIP_VERIFY.get(host))
        context = _ctx(not skip)
    try:
        return urllib.request.urlopen(req, timeout=timeout, context=context)
    except Exception as e:                                     # noqa: BLE001 —— 要按类型分流
        if not (allow_bad_cert and context is not None and not skip and is_cert_error(e)):
            raise
        with _LOCK:
            _SKIP_VERIFY[host] = True
        if warn:
            print("  ! %s 的证书校验失败, 改用不校验证书重试: %s" % (host, e), file=sys.stderr)
        return urllib.request.urlopen(req, timeout=timeout, context=_ctx(False))


def cert_error_of(host, timeout=15):
    """体检用: 取该 host 的证书, 返回 (notBefore, notAfter) 或 None。"""
    import socket
    ctx = ssl.create_default_context()
    with socket.create_connection((host, 443), timeout=timeout) as sock:
        with ctx.wrap_socket(sock, server_hostname=host) as ss:
            return ss.getpeercert().get("notAfter"), ss.getpeercert().get("notBefore")


def _selftest():
    """离线自检: 只验 is_cert_error 的分流, 不联网。"""
    import ssl as _s
    ok = True

    def chk(cond, what):
        nonlocal ok
        print(("  ✓ " if cond else "  ✗ ") + what)
        ok = ok and cond

    cert = _s.SSLCertVerificationError(1, "certificate verify failed: certificate has expired")
    chk(is_cert_error(urllib.error.URLError(cert)), "URLError 包着的证书错误 -> True")
    chk(is_cert_error(cert), "裸 SSLCertVerificationError -> True")
    chk(is_cert_error(urllib.error.URLError("certificate has expired")), "只有文本也认得 -> True")
    chk(not is_cert_error(urllib.error.URLError(TimeoutError("timed out"))), "超时 -> False")
    chk(not is_cert_error(urllib.error.URLError(ConnectionRefusedError(111, "refused"))), "拒绝连接 -> False")
    chk(not is_cert_error(urllib.error.HTTPError("u", 404, "nf", {}, None)), "HTTP 404 -> False")
    chk(host_of(urllib.request.Request("https://a.b.c/x")) == "a.b.c", "host_of 取 netloc")
    chk(host_of("https://q.w.e/y") == "q.w.e", "host_of 也认字符串 URL")
    print("自检" + ("通过" if ok else "失败"))
    return 0 if ok else 1


if __name__ == "__main__":
    # 冒烟测试会拿 `--help` 探所有 tools/*.py —— 这里必须先打文档再退, 别让它去联网。
    if any(a in ("-h", "--help") for a in sys.argv[1:]):
        print(__doc__)
        raise SystemExit(0)
    raise SystemExit(_selftest())
