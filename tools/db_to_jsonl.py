# -*- coding: utf-8 -*-
"""【已废弃, 保留作参考】把 jianpu-db/scores/*.txt 转成 JSONL 数据集。

现在这一步已并入 jianpu-db 自己的 parse_scores.py(用 score.Score.to_record()),
所以本脚本不再需要 —— 留着只为对照当年的实现。

当年的字段设计:
  唯一标识就用文件名(file); 不再需要 MBID/id-type。
  每行 = 一首曲子:
    {
      "file":       "th01_01.txt",
      "title":      "A Sacred Lot",
      "tag":        ["th01", "东方灵异传", ...],
      "usertag":    ["th01"],
      "status":     "ok",
      "transcriber":"Francium-223",
      "sections":   [{"subtitle": "intro", "score": ",6s 3 ,6 2 1 ..."}, ...],
      "score":      "全文简谱(各段用 | 连接, 便于直接训练)",
      "n_notes":    123
    }
可直接: datasets.load_dataset("json", data_files="data.jsonl")

用法: py -3.13 tools/db_to_jsonl.py [输出路径]
"""
import glob, json, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")
# 把 <仓库根>/tools 加进 sys.path, 以便读 pipeline.toml
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from jp_root import cfg as _cfg, ROOT as _ROOT

# jianpu-db 仓库位置: pipeline.toml 的 [external] jianpu_db, 环境变量 JP_JIANPU_DB,
# 或默认 <仓库根>/../jianpu-db —— 不再写死绝对路径
DB = (os.environ.get("JP_JIANPU_DB")
      or _cfg("external", "jianpu_db", default=None)
      or os.path.join(os.path.dirname(_ROOT), "jianpu-db"))
SRC = os.path.join(DB, "scores")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(DB, "data.jsonl")

META = {"title", "type", "transcriber", "tag", "usertag", "tagroute", "file",
        "id", "id-type", "mbid", "score", "subtitle", "note"}


def parse_score(path):
    txt = open(path, encoding="utf-8").read()
    lines = txt.splitlines()
    meta, body_start = {}, 0
    for i, l in enumerate(lines):
        s = l.strip()
        if s.replace(" ", "").startswith("%--"):
            body_start = i + 1
            break
        if s.startswith("%") or not s:
            continue
        if "=" in s:
            k, v = s.split("=", 1)
            meta.setdefault(k.strip().lower(), v.strip())
    # 正文: 按 NextScore 分段
    body = lines[body_start:]
    sections, cur, cur_sub = [], [], ""
    for l in body:
        s = l.strip()
        if s.lower().startswith("nextscore"):
            if cur:
                sections.append({"subtitle": cur_sub, "score": " ".join(cur)})
            cur, cur_sub = [], ""
            continue
        if s.replace(" ", "").lower().startswith("%end"):
            break
        if s.lower().startswith("subtitle="):
            cur_sub = s.split("=", 1)[1].strip()
            continue
        # 拍号行(如 4/4)单独一行, 不是音符 —— 不能漏掉: "4/4" 会被下面的 token 正则
        # 当成音符("4")混进 score 字段(实测每条 score 开头都是 "4/4 ,5 - ...")。
        if re.match(r"^\d+\s*/\s*\d+$", s):
            continue
        if s.startswith("%") or not s:
            continue
        # 去掉记谱指令词(KeepLength 等), 只留音符 token
        toks = [t for t in s.split() if re.match(r"^[,']*[qsdh]*[,']*[1-7x0]", t)
                or t in ("-", "|", "~")]
        cur += toks
    if cur:
        sections.append({"subtitle": cur_sub, "score": " ".join(cur)})
    full = " | ".join(x["score"] for x in sections if x["score"])
    n_notes = len([t for t in full.split() if re.match(r"^[,']*[qsdh]*[,']*[1-7x0]", t)])
    # status 可能被写在 %-- 之后(文件末尾) -> 全文兜底再找一次
    if "status" not in meta:
        m = re.search(r"^\s*status\s*=\s*(\S+)", txt, re.M)
        if m:
            meta["status"] = m.group(1)
    tags = [x.strip() for x in re.split(r"[,，、|]", meta.get("tag", "")) if x.strip()]
    usertags = [x.strip() for x in re.split(r"[,，、|]", meta.get("usertag", "")) if x.strip()]
    return {
        # 统一都是多值字段(列表) —— 唯一例外是 title: 它是曲目显示名, 单值, 下游按字符串读。
        "file": [os.path.basename(path)],
        "status": [meta.get("status", "")],      # midi=由 MIDI 硬转(不进数据集) / ok=可用
        "title": meta.get("title", ""),          # ← 例外: 字符串
        "tags": tags,
        "usertags": usertags,
        "transcriber": [meta.get("transcriber", "")],
        "sections": sections,                    # 结构字段(段落数组), 不是标量多值
        "score": full,                           # 全曲 token 串
        "n_notes": n_notes,                      # 计数
    }


def main():
    # 只用 expand 版: 它把 R{} 循环/A{} 变化展开成线性 token 序列, 便于计算机直接读取
    files = sorted(glob.glob(os.path.join(SRC, "*_expand.txt")))
    print(f"expand 版曲谱: {len(files)} 个")
    rows, empty, draft = [], 0, 0
    for f in files:
        try:
            r = parse_score(f)
        except Exception as ex:
            print(f"  跳过 {os.path.basename(f)}: {type(ex).__name__}", flush=True)
            continue
        if r.get("status") != "ok":
            draft += 1
            continue                      # 待整理(🟥)的先不进数据集
        if not r["score"]:
            empty += 1
            continue
        rows.append(r)
    with open(OUT, "w", encoding="utf-8") as g:
        for r in rows:
            g.write(json.dumps(r, ensure_ascii=False) + "\n")
    tot = sum(r["n_notes"] for r in rows)
    print(f"生成 {OUT}")
    print(f"  曲目 {len(rows)} 首 (待整理跳过 {draft}, 空谱跳过 {empty})   总音符 {tot}")
    if rows:
        print("\n=== 样例 ===")
        print(json.dumps(rows[0], ensure_ascii=False, indent=2)[:600])


if __name__ == "__main__":
    main()
