# -*- coding: utf-8 -*-
"""把原子数据(token标注) 转换为 JSON 结构化训练数据。
每个原子图 → {"image": 图路径, "json": {digit, accidental, voice, low, beam, dotted}}
杠(-) → {"type": "dash"}
输出 train-data-atoms-v4-json/manifest.jsonl
"""
import json, os, sys, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from token_json import token_to_json
sys.stdout.reconfigure(encoding="utf-8")

SRC = "train-data-atoms-v4/manifest.jsonl"
OUT = "train-data-atoms-v4-json"
os.makedirs(OUT + "/png", exist_ok=True)

DASH_JSON = {"type": "dash"}


def convert_all():
    rows = [json.loads(l) for l in open(SRC, encoding="utf-8")]
    out = []
    err = 0
    for r in rows:
        tok = r["text"]
        img_src = "train-data-atoms-v4/png/" + r["pages"][0]
        img_dst = OUT + "/png/" + r["pages"][0]
        if not os.path.exists(img_src):
            err += 1
            if err <= 5: print(f"[缺图] {tok}")
            continue
        import shutil
        shutil.copy(img_src, img_dst) if not os.path.exists(img_dst) else None
        if tok == "-":
            js = DASH_JSON
        else:
            try:
                js = token_to_json(tok)
                # 白名单应为纯单音符: 校验 digit 是单个数字
                if not re.match(r"^[1-7]$", js["digit"]):
                    if err <= 10: print(f"[非常规] {tok} -> {json.dumps(js, ensure_ascii=False)}")
            except Exception as e:
                err += 1
                if err <= 5: print(f"[ERR] {tok}: {e}")
                continue
        out.append({"image": img_dst, "json": js})
    with open(OUT + "/manifest.jsonl", "w", encoding="utf-8") as f:
        for r in out:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"转换 {len(out)} 条, 累计异常 {err} -> {OUT}/manifest.jsonl")


if __name__ == "__main__":
    convert_all()
