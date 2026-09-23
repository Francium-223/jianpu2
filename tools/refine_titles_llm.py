# -*- coding: utf-8 -*-
"""用本地**纯文本**小模型(Qwen3-1.7B)把 16219 条乱名字洗成"只有曲名"。

用户口径(2026-09-22): 正常名字 = **除了必要的曲名没有多余的**; 而且**全量都喂**, 不挑可疑的
(模型小、批量跑, 反正不贵)。样例:
  `燕子归来草原丁喜萨克斯原创曲简谱_草原丁喜演唱_草原大哈_草原丁喜词曲` -> `燕子归来`
  `云朵上的草原草原丁喜萨斯原创曲简谱_草原大哈演唱_…`              -> `云朵上的草原`
  `夜曲-弹唱版-巴特尔`                                              -> `夜曲`

实测过的坑(2026-09-22 01:50, 都在本文件里留着):
  * v1 单序列逐字生成 -> 1.02 s/条 = 4.5 小时, 太慢
  * "一次 16 条塞进一条序列、要求输出同样行数" -> 模型**照抄输入**(19/20 条原样吐出), 完全废
  * 改成 **一条序列一个曲名** + 真并行 batch -> 洗得干净(16/20 真改动), 速度也够
  * 生成部分凑够 1 个换行就停(StoppingCriteria 只数生成段), 不浪费解码步

输出: 边跑边写 train-work/title_clean.part.tsv(可 --resume 续跑), 跑完写 title_clean.tsv
      (目录名/原始名/模型曲名/有变化/原文输出) —— 只出建议, **不直接改谱子**
用法: py -3.13 tools/refine_titles_llm.py [--par 48] [--limit N] [--resume] [--shard i/n]
"""
import argparse
import glob
import os
import re
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, "tools")
from to_jianpu_db import fix_mojibake

MODEL = os.environ.get("TITLE_LM", "models/Qwen3-1.7B")
PART = "train-work/title_clean.part.tsv"
FINAL = "train-work/title_clean.tsv"
SYS = ("你是简谱曲名清洗器。输入是一条被站点拼接坏了的曲名，里面混着歌手/乐队名、副标题、"
       "词曲/演唱/制谱署名、乐器名(如 钢琴/吉他/萨克斯)、调号、版本说明(如 简单版/初级/弹唱教学/"
       "指弹)、站点词(简谱/歌曲类/钢琴伴奏谱)、重复片段。"
       "只输出**歌名本身**：以上这些一律删掉，**包括残留在括号里的**；保留 [英]/[日] 这类"
       "语言标记，**但歌名不要带书名号《》**。禁止解释、禁止编号、禁止空行；**只输出一行**。")
FEWSHOT = [
    ("燕子归来草原丁喜萨克斯原创曲简谱_草原丁喜演唱_草原大哈_草原丁喜词曲", "燕子归来"),
    ("云朵上的草原草原丁喜萨斯原创曲简谱_草原大哈演唱_草原大哈、逍遥_草原丁喜词曲", "云朵上的草原"),
    ("夜曲-弹唱版-巴特尔", "夜曲"),
    ("一分钱简谱(歌词)_儿歌_陈洲宏记谱-简谱", "一分钱"),
    ("[英]GOODMORNINGTOYOU您早儿歌[英]GOOD_MORNING_TO_YOU您早儿歌简谱-简谱", "[英]GOOD MORNING TO YOU 您早儿歌"),
    ("I_will_carry_you钢琴谱当王者荣耀遇到五月天骨灰级玩家在哪里", "I Will Carry You"),
    ("光辉岁月(女生吉他弹唱)", "光辉岁月"),
    ("不再犹豫（G调蓝莓吉他弹唱教学版）", "不再犹豫"),
    ("Beyond《Amani》 简单版 吉他弹唱教学", "Amani"),
]


def pick_names():
    out = []
    for d in sorted(glob.glob("images-prep/*/*")):
        if not os.path.isdir(d):
            continue
        full = os.path.basename(d)
        part = full.split("__")[0]
        out.append((full, fix_mojibake(part).strip()))
    return out


# 零宽/不可见字符: 源站标题里混着 U+200B 这类(实测 63 个 batch-out 名、104 行清洗表里有),
# 肉眼看不见但会让**匹配失败**(`算什么男人` 匹配不上基准集)并且污染交付文件名 ✗
INVIS = re.compile(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]")


def clean_one(s):
    s = INVIS.sub("", s or "")
    s = re.sub(r"\s+", " ", s.strip())
    s = re.sub(r"^(曲名[:：]|输出[:：]|\d+[.、)])\s*", "", s)
    s = s.strip().strip('"').strip()
    # 用户口径(2026-09-22): **书名号也不要有** —— 《情人》-> 情人, Beyond《不再犹豫》-> 不再犹豫
    s = s.replace("《", "").replace("》", "").replace("〈", "").replace("〉", "")
    # 去书名号后常留下两头的残留标点(实测 `《_郴_州_行_》` -> `_郴_州_行_`), 一并剪掉
    s = re.sub(r"\s+", " ", s).strip()
    # 汉字之间的下划线是站点排版残留(`郴_州_行` 其实是 `郴州行`), 去掉;
    # 英文/数字之间的下划线保留(可能是 `I_will_carry_you` 这种, 由模型自己改成空格)
    s = re.sub(r"(?<=[\u4e00-\u9fff])_(?=[\u4e00-\u9fff])", "", s)
    return s.strip("_-—–·.、,，。;；:：!！?？\"' ")


def ok(inp, outp):
    if not outp or len(outp) > 40 or "\n" in outp:
        return False
    if len(outp) > len(inp) + 10:
        return False
    return bool(re.search(r"[0-9A-Za-z\u4e00-\u9fff]", outp))


def load_done():
    done = set()
    if os.path.exists(PART):
        with open(PART, encoding="utf-8") as f:
            next(f, None)
            for ln in f:
                p = ln.rstrip("\n").split("\t")
                if p and p[0]:
                    done.add(p[0])
    return done


def write_rows(path, rows):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("目录名\t原始名\t模型曲名\t有变化\t原文输出\n")
        for r in rows:
            f.write("\t".join(str(x).replace("\t", " ") for x in r) + "\n")
    os.replace(tmp, path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--par", type=int, default=48, help="每次 generate 并行多少条序列")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--shard", default="")
    ap.add_argument("--resume", action="store_true", help="跳过 part.tsv 里已有结果的目录")
    # 第二轮: 只处理"被规则标成 todo= 的那批"(机器规则不敢乱砍后缀, 交给模型判断)
    ap.add_argument("--only", default="", help="只处理这个名单文件里的目录名(每行一个)")
    ap.add_argument("--out", default="", help="结果写到这个路径(默认仍写 title_clean.tsv)")
    a = ap.parse_args()

    names = pick_names()
    if a.shard:
        i, n = (int(x) for x in a.shard.split("/"))
        names = [t for k, t in enumerate(names) if k % n == i]
    done = load_done() if a.resume else set()
    if done:
        names = [t for t in names if t[0] not in done]
    if a.only:
        want = {l.strip() for l in open(a.only, encoding="utf-8") if l.strip()}
        names = [t for t in names if t[0] in want]
        print(f"名单 {a.only}: {len(want)} 条 -> 命中 {len(names)} 条", flush=True)
    if a.limit:
        names = names[:a.limit]

    print(f"待清洗 {len(names)} 条   模型 {MODEL}   par={a.par}"
          + (f"   续跑跳过 {len(done)}" if done else ""), flush=True)
    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer, StoppingCriteria, StoppingCriteriaList
    tok = AutoTokenizer.from_pretrained(MODEL)
    tok.padding_side = "left"
    if tok.pad_token_id is None:
        tok.pad_token = tok.eos_token
    model = AutoModelForCausalLM.from_pretrained(MODEL, dtype=torch.bfloat16, device_map="cuda:0")
    model.eval()
    nl_ids = sorted(set(tok.encode("\n", add_special_tokens=False)))
    print(f"模型已加载 (换行 token id {nl_ids})", flush=True)

    def build(name):
        msgs = [{"role": "system", "content": SYS}]
        for i, o in FEWSHOT:
            msgs += [{"role": "user", "content": i}, {"role": "assistant", "content": o}]
        msgs.append({"role": "user", "content": name + "\n(只输出这一条的歌名，一行)"})
        return tok.apply_chat_template(msgs, tokenize=False, add_generation_prompt=True,
                                       enable_thinking=False)

    class OneLine(StoppingCriteria):
        """每条序列在**生成段**凑够 1 个换行就整体收工(单条模式只要一行)。"""

        def __init__(self, start):
            self.start = start
            self.nl = torch.tensor(nl_ids, dtype=torch.long, device=model.device)

        def __call__(self, input_ids, scores, **kw):
            gen = input_ids[:, self.start:]
            if gen.shape[1] == 0:
                return False
            return bool(torch.isin(gen, self.nl).any(dim=1).all())

    def ask_batch(batch):
        enc = tok([build(n) for n in batch], return_tensors="pt", padding=True).to(model.device)
        start = enc["input_ids"].shape[1]
        with torch.no_grad():
            out = model.generate(**enc, max_new_tokens=48, do_sample=False,
                                 pad_token_id=tok.pad_token_id,
                                 stopping_criteria=StoppingCriteriaList([OneLine(start)]))
        gen = out[:, start:]
        res = []
        for i in range(gen.shape[0]):
            s = [x for x in tok.decode(gen[i], skip_special_tokens=True).splitlines() if x.strip()]
            res.append(clean_one(s[0]) if s else "")
        return res

    rows, t0, calls = [], time.time(), 0
    for k in range(0, len(names), a.par):
        block = names[k:k + a.par]
        got = ask_batch([t for _f, t in block])
        for (full, orig), g in zip(block, got):
            g = g if ok(orig, g) else "?"
            rows.append((full, orig, g, "1" if g not in ("?", orig) else "0", ""))
        calls += 1
        n = k + len(block)
        el = time.time() - t0
        if calls % 5 == 0 or n >= len(names):
            print(f"  {n}/{len(names)}  {el/len(rows):.3f}s/条  预计还要 "
                  f"{(len(names)-n)*el/len(rows)/60:.1f} 分钟", flush=True)
            if not a.out:            # --out 模式下不覆盖正式中间结果
                write_rows(PART, rows)

    if a.out:
        # 第二轮(只跑被标 todo= 的那批): **只写指定文件**, 绝不碰 title_clean.tsv
        write_rows(a.out, rows)
    else:
        write_rows(PART, rows)
        write_rows(FINAL, rows)
    ch = sum(1 for r in rows if r[3] == "1")
    bad = sum(1 for r in rows if r[2] == "?")
    print(f"\n完成 {len(rows)} 条: 有改动 {ch}, 未通过校验 {bad} -> {a.out or FINAL}", flush=True)


if __name__ == "__main__":
    main()
