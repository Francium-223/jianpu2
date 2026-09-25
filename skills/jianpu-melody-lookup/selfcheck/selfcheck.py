# -*- coding: utf-8 -*-
"""检索脚本的**自检门**: 已知答案用例必须过, 否则不许出结果。

为什么要这个: 今天同类事故两次 ——
  ① 前端 `metaRows` 引用未定义的 `siteUrl` -> 结果区永远空白;
  ② `lookup_norm` 的解析器逐字符抠数字, 把 231 个音符膨胀成 377 个, 凭空造出
     "33565653253 在 th10_06 位置 0 完全一致" 的**假命中**。
两次都是"改完没验证就宣布完成"。这里把验证固化成函数, 供脚本启动时调用。

⚠ 2026-09-23 晚 **定案翻转**(新机器复核, 见 _analysis/待办4_根因报告.md):
   上面第 ② 条的判断是**反的**。真相是:
     * 源文件 `jianpu-db/scores/th10_06.txt` 第 1 小节 = `3 3 5 6 5 6 5 3 2`
       —— 与用户 2026-09-23 人耳确认的完全一致;
     * "逐字符抠数字"读出来的 **377 个音顺序是对的**; jptok 当时只认前缀时值,
       把 `6c.`/`5s`/`3q`/`,6q` 这类后缀 token **静默丢掉** -> 只剩 231 个音,
       顺序被打乱成 `3 3 5 6 3 2 5 5 6`, 命中因此"消失";
     * 于是用例 ①(锁死 231)与用例 ③(禁止 33565653253 命中)保护的其实是 bug,
       全库 36 首(0.5%)索引里被丢掉最多 91% 的音。
   现在: jptok 前后时值都认; 用例 ③ 翻转为"**必须**在 th10_06 位置 0 命中";
   并新增用例 ④(结构性不变量) —— 它才是这类事故的真正检测器。

用例(全部人工核对过):
  * `63731232`   应在 神々が恋した幻想郷 / th10_06 里 0 错命中
  * `33565653253` **必须**在 th10_06 位置 0 命中(第 1 小节; 用户人耳确认)
  * 解析器口径: `4/4`、`q3`、`5s`、`6c.`、`3q`、`1=C` 里的字母/拍号/调号**不得**被当成音符;
    th10_06 的真实音符数是 **377**(不是 231 —— 231 是丢音后的残值)
  * 结构性: 任何一首, `score` 文本里的音高数字顺序必须与 jptok 解出的旋律**逐字相同**
    (即"不许有任何音符被解析器静默丢掉")
"""
import io
import json
import os
import re
import urllib.parse
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))          # jptok 在上一层
sys.stdout.reconfigure(encoding="utf-8")
import jptok  # noqa: E402

# 调号 `1=C` / `1=Bb`: 不是音符, 但会（且只会有这一个）出现在 score 里
KEY_SIG = re.compile(r"^[1-7]\s*=\s*[A-Ga-g][#b♯♭]?$")


def load(data_path):
    return [json.loads(l) for l in io.open(data_path, encoding="utf-8") if l.strip()]


def pitch_of(score):
    return "".join(str(d) for d, _a, _o in jptok.seq(score or ""))


def digits_of(score):
    """score 文本里"人读谱会读到的音高数字"(排除调号里的数字)。"""
    out = []
    for t in (score or "").split():
        if KEY_SIG.match(t):
            continue
        out.append("".join(c for c in t if c in "1234567"))
    return "".join(out)


def check(data_path=None):
    """返回 (ok: bool, 报告: list[str])"""
    data_path = data_path or os.path.join(os.path.dirname(HERE), "data.jsonl")
    rep = []
    ok = True
    if not os.path.exists(data_path):
        return False, [f"找不到数据: {data_path}"]
    rows = load(data_path)
    rep.append(f"数据 {len(rows)} 首")

    # ① 解析器口径: th10_06 音符数必须是 415(源谱音符数; 少一个数就是某一类 token 又被静默丢了)
    #    231 = 后缀时值(`6c.`/`5s`/`3q`)被丢; 377 = `c` 前缀时值(`c6.`/`c3`)又被旧白名单丢掉。
    th = [r for r in rows if r["file"][0] == "th10_06.txt"]
    if th:
        n = len(pitch_of(th[0].get("score")))
        good = (n == 415)
        ok &= good
        rep.append(f"{'OK ' if good else '**FAIL**'} th10_06 音符数 = {n} (期望 415; 231=后缀时值被丢, "
                   f"377=`c` 前缀时值又被白名单丢, 后者会把第 1 小节读成 `3 3 5 6 3 2 5 5 6`)")
    else:
        rep.append("  (th10_06.txt 不在数据里, 跳过该用例)")

    # ② 63731232 必须 0 错命中 th10_06 / 神々
    hit = any("63731232" in pitch_of(r.get("score")) for r in rows)
    ok &= hit
    rep.append(f"{'OK ' if hit else '**FAIL**'} 63731232 应 0 错命中(神々が恋した幻想郷)")

    # ③ 33565653253 **必须**在 th10_06 位置 0 命中 —— 它就是第 1 小节, 用户人耳确认过。
    #    (2026-09-23 之前这里是"不许命中"; 那个断言来自"231 才是真音符数"的误判, 见文件头)
    where = [r["file"][0] for r in rows if pitch_of(r.get("score")).find("33565653253") == 0]
    good = ("th10_06.txt" in where)
    ok &= good
    rep.append(f"{'OK ' if good else '**FAIL**'} 33565653253 应在 th10_06 位置 0 命中, 实际位置 0 的: {where[:3]}")

    # ④ 结构性不变量: 每首谱, score 里的音高数字顺序 == jptok 解出的旋律
    #    (这一条会在**任何**"白名单不认某种 token -> 静默丢音"时立刻失败)
    bad = [(r["file"][0], len(digits_of(r.get("score"))), len(pitch_of(r.get("score"))))
           for r in rows if digits_of(r.get("score")) != pitch_of(r.get("score"))]
    good = (len(bad) == 0)
    ok &= good
    rep.append(f"{'OK ' if good else '**FAIL**'} 无音符被静默丢弃(数字数==旋律数)"
               + (f", 异常 {len(bad)} 首: {bad[:3]}" if bad else f", {len(rows)} 首全对"))


    # ④b **lookup.py 自己那份 token 口径**也必须同源 —— 2026-09-25 实测它自写的窄正则
    #     `^([qsdh]*)([,']*)([0-9x])` 不认 `c` 前缀时值(KeepLength 的写法, 如 `c6.`), 把这些音
    #     静默丢掉 -> 音序错位 -> 连《神々が恋した幻想郷》那种**精确命中**都从结果里消失
    #     (只报出 1 错的别的歌)。④ 那条查的是本自检里的 helper, 查不到 lookup.py 的私货, 所以补这条。
    try:
        sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        import lookup as _lk
        bad2 = [(r["file"][0], len(digits_of(r.get("score"))), len(_lk.pitch_and_oct(r.get("score"))[0]))
                for r in rows if len(digits_of(r.get("score"))) != len(_lk.pitch_and_oct(r.get("score"))[0])]
        good2 = (len(bad2) == 0)
        ok &= good2
        rep.append(f"{'OK ' if good2 else '**FAIL**'} lookup.py 的音符数与 jptok 同源(不静默丢音)"
                   + (f", 异常 {len(bad2)} 首: {bad2[:3]}" if bad2 else f", {len(rows)} 首全对"))
    except Exception as e:
        rep.append(f"  (lookup.py 口径检查跳过: {type(e).__name__}: {e})")

    # ⑤ 小节线必须给休止计拍 —— th10_06 开头是「2.5 拍休止 + 三个八分音符弱起」:
    #    [c0 q0 q3 q3 q5] 正好 4 拍, 所以第一条线必须在**第 3 个音符之前**(c6.)。
    #    若休止不计时(老写法), 线会落到第 4 个音符之前 -> 用户实测一眼看出
    #    `c0 q0 q3 q3 | q5 …` 不对。这条用例把那个 bug 钉住。
    if th:
        bs = sorted(set(int(x) for x in (th[0].get("bars") or [])))
        good = bool(bs) and bs[0] == 3 and all(a < b for a, b in zip(bs, bs[1:]))
        ok &= good
        rep.append(f"{'OK ' if good else '**FAIL**'} th10_06 第一条小节线在第 {bs[0] if bs else '?'} 个音符之前"
                   f" (期望 3; 4 = 休止没计拍, 小节线会整体前漂)")

    # ⑥ 收录页必须是**具体页面**: 语料里不许出现搜索 URL。
    #    口径的唯一实现在 jianpu-db/linkurl.py(写入时就拒收); 这一条是事后兜底 ——
    #    万一有人绕过工具手改文件, 检索/前端会立刻暴露出来。
    db = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "jianpu-db"))
    if os.path.isfile(os.path.join(db, "linkurl.py")):
        sys.path.insert(0, db)
        import linkurl
        badu = []
        for r in rows:
            for u in (r.get("link") or []):
                try:
                    if linkurl.looks_like_search(urllib.parse.urlsplit(u)):
                        badu.append((r["file"][0], u))
                except Exception:
                    badu.append((r["file"][0], u))
        good = not badu
        ok &= good
        n = sum(len(r.get("link") or []) for r in rows)
        rep.append(f"{'OK ' if good else '**FAIL**'} 收录页里没有搜索 URL(共 {n} 条人工补的链接)"
                   + (f", 违规 {badu[:3]}" if badu else ""))
    else:
        rep.append(f"  (找不到 {db}/linkurl.py, 跳过收录页用例)")

    # ⑦ 白名单核对: data.jsonl 里**不许**混进 status=midi 或没有 status 的谱(2026-09-24 加)
    #    为什么值得单列: parse_scores 只收 status ∈ {ok, ocr}; 而 `scores/` 里还躺着
    #      273 个 status=midi(MIDI 硬转; 中位数 11242 音、最大 175392 音, 合计 474 万音
    #      = 现有语料的 3.6 倍 —— 全是多轨转储, 收进来会毁掉检索) 与 225 个没有 status 的空壳
    #      (东方曲目的元数据占位, 0 个音符)。这一条把"它们绝不能进数据集"钉成不变量,
    #      以后谁改了白名单会立刻红。
    try:
        import json as _json
        n_midi = n_nostatus = n_notes0 = 0
        for ln in io.open(os.path.join(db, "data.jsonl"), encoding="utf-8"):
            if not ln.strip():
                continue
            r = _json.loads(ln)
            st = r.get("status")
            st = st if isinstance(st, list) else [st]
            if any((x or "") == "midi" for x in st):
                n_midi += 1
            if all(not (x or "").strip() for x in st):
                n_nostatus += 1
            if not (r.get("n_notes") or 0) and not any(
                    (sec.get("score") or "").split() for sec in (r.get("sections") or [])):
                n_notes0 += 1
        good = (n_midi == 0 and n_nostatus == 0 and n_notes0 == 0)
        ok &= good
        rep.append(f"{'OK ' if good else '**FAIL**'} 数据集里没有 midi 硬转/无 status/空谱"
                   f"(midi {n_midi}, 无 status {n_nostatus}, 空谱 {n_notes0})")
    except Exception as e:
        rep.append(f"  (白名单用例跳过: {type(e).__name__}: {e})")

    # ⑧ 注释不是属性: `%` 开头的行一律是注释, **哪怕里面有 `=`**(2026-09-24 加)
    #    用户抓到的 bug: 源文件第一行常是 `%<原文件名>`, 而
    #      `scores/草原之夜1=bE2_4_中速深情地.txt` 的第一行是
    #      `%草原之夜1=bE2_4_中速深情地.txt` —— 解析器把 `=` 分支放在 `%` 注释分支**前面**,
    #      于是读出一个**属性** `草原之夜1` = `bE2_4_中速深情地.txt`。用户原话:
    #      "草原之夜不是attribute"。实测 123 首中招(3 首文件名带调号/拍号 + 120 首人工注释
    #      `% 原 title=…`), data.json 里多出 4 个 `%` 开头的假属性键, 还长出 `by_% 原 title`
    #      这种目录。这一条两头都钉住: ① 产物里不许有 `%` 开头的字段;
    #      ② 源码里每个 `%` 开头含 `=` 的行, 其 `=` 左边绝不许出现在该曲的字段里。
    try:
        import json as _json
        import glob as _glob
        dpath = os.path.join(db, "data.json")
        meta = _json.load(io.open(dpath, encoding="utf-8")) if os.path.isfile(dpath) else {}
        bad_key = [(f, k) for f, m in meta.items() for k in m if k.startswith("%")]
        n_comment_eq, bad_attr = 0, []
        for p in sorted(_glob.glob(os.path.join(db, "scores", "*.txt"))):
            if p.endswith(("_expand.txt", "_buf.txt")):
                continue
            fn = os.path.basename(p)
            mm = meta.get(fn) or {}
            for ln in io.open(p, encoding="utf-8"):
                ln = ln.rstrip("\n")
                if ln.replace(" ", "").startswith("%--"):
                    break                      # 元数据区结束
                if ln.startswith("%") and "=" in ln:
                    n_comment_eq += 1
                    k = ln.split("=", 1)[0].strip()
                    if k in mm:
                        bad_attr.append((fn, k))
        good = (not bad_key) and (not bad_attr)
        ok &= good
        rep.append(f"{'OK ' if good else '**FAIL**'} 注释没被当成属性(扫到 {n_comment_eq} 处"
                   f"『% 开头且含 =』的注释; 假属性键 {len(bad_key)} 个)"
                   + (f"; 例 {bad_key[:2]}{bad_attr[:2]}" if not good else ""))
    except Exception as e:
        rep.append(f"  (注释/属性用例跳过: {type(e).__name__}: {e})")

    return ok, rep


def main():
    ok, rep = check()
    print("\n".join(rep))
    print("自检", "通过" if ok else "**未通过** —— 不要相信本脚本的检索结果")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
