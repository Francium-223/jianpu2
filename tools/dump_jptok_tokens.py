# -*- coding: utf-8 -*-
"""把全语料的**每一个 token** 的 jptok 判定导出成 TSV, 给前端 JS 侧做等价性测试。

为什么要它: `jptok` 这个口径现在有**三份**实现 ——
  ① `jianpu2/skills/jianpu-melody-lookup/jptok.py`(**唯一真源**)
  ② `jianpu-db/score.py` 里的 `_FallbackJptok`(给没有 jianpu2 的环境兜底)
  ③ `jianpu-db.github.io/static/jptok.js`(前端)
②有 `tools/check_jptok_parity.py` 锁着, ③以前**没人管** —— 2026-09-28 实测它就漂了:
`BEAT` 表里 `h: 2.0`(Python 侧早已定案 h = 六十四分音符 = 0.0625), 而且写这个文件的人
自己在文件头写着"改这里时必须同时改 Python 侧"。

这个脚本只负责**产期望值**;比对在 `jianpu-db.github.io/tools/check_jptok_js.mjs`。
用法:
    py -3.13 tools/dump_jptok_tokens.py [输出.tsv]
默认输出 `<jianpu2>/train-work/jptok_tokens.tsv`。

⚠ 2026-10-05: 表尾加了第 6 列 `notes`(逐音), 因为和弦 token 光比"认不认得出"是不够的
  —— 八度/变音写错位也照样绿。前端必须用 `parseTokenAll()` 逐音对上(见 check_jptok_js.mjs)。
"""
import io
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                               "skills", "jianpu-melody-lookup"))
import jptok  # noqa: E402

from guard import guard_help        # noqa: E402
guard_help(__doc__)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.environ.get("JIANPU_DB") or r"D:\Documents_D\jianpu-db"
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "train-work", "jptok_tokens.tsv")


def notes_of(t):
    """一个 token -> 逐音串(第 6 列), 给前端做"逐音"对拍用。

    为什么加这一列(2026-10-05): 以前只比 is_note/is_pitch/beat —— 那三样对和弦 token 而言
    是"有没有"的粗判, 前端就算把 `,4,,b5,,3,,1` 的四个音解析错(八度/变音错位)也照样绿。
    和弦是**逐音**写八度与变音的, 所以必须逐音比:
        有音高 -> `音级` + 变音记号(`#`/`b`) + 八度记号(`^` = 代码口径 oct=+1, `v` = oct=-1)
        休止/念白 -> `_` + 同上
    实测: `,4,,b5,,3,,1` -> `4^,5b^^,3^^,1^^` ; `64x0` -> `6,4,_,_`
    ⚠ 八度必须一起比: 只比音级+变音的话, 把八度方向写反也查不出来(反向验证时真的漏过)。
    """
    def octs(o):
        return "^" * o if o > 0 else ("v" * (-o) if o < 0 else "")

    out = []
    for d, a, o in jptok.parse_token_all(t):
        if d is None:
            out.append("_" + octs(o))
        else:
            out.append("%d%s%s" % (d, "#" if a == 1 else "b" if a == -1 else "", octs(o)))
    return ",".join(out)


def main():
    scores = os.path.join(DB, "scores")
    toks = set()
    n_file = 0
    for fn in sorted(os.listdir(scores)):
        if not fn.endswith(".txt") or fn.endswith(("_expand.txt", "_buf.txt")):
            continue
        n_file += 1
        raw = io.open(os.path.join(scores, fn), encoding="utf-8", errors="replace").read()
        _head, _sep, body = raw.partition("%--")
        toks.update(body.split())
    lines = ["token\tis_note\tis_pitch\tduration_letter\tbeat\tnotes"]
    for t in sorted(toks):
        if "\t" in t or "\n" in t:
            continue
        lines.append("%s\t%d\t%d\t%s\t%s\t%s" % (
            t,
            1 if jptok.is_note(t) else 0,
            1 if jptok.is_pitch(t) else 0,
            jptok.duration_letter(t),
            repr(jptok.beat(t)),
            notes_of(t),
        ))
    io.open(OUT, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("%d 份谱, %d 个**不同** token -> %s" % (n_file, len(lines) - 1, OUT))


if __name__ == "__main__":
    main()
