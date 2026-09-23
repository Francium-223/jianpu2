# -*- coding: utf-8 -*-
"""对比揭示格式: 多行批 vs 单条(带 few-shot) vs 单条(加"禁止照抄")。看谁真的在洗名字。"""
import os
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, "tools")
from refine_titles_llm import MODEL, SYS, FEWSHOT, pick_names, clean_one

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

tok = AutoTokenizer.from_pretrained(MODEL)
tok.padding_side = "left"
if tok.pad_token_id is None:
    tok.pad_token = tok.eos_token
model = AutoModelForCausalLM.from_pretrained(MODEL, dtype=torch.bfloat16, device_map="cuda:0")
model.eval()

POOL = pick_names()
dirty = [t for _f, t in POOL if any(k in t for k in ("简谱", "原创曲", "萨克斯", "弹唱", "钢琴谱", "记谱"))
         and len(t) > 8][:20]
print(f"取 {len(dirty)} 条脏名字\n", flush=True)


def run(prompts, mx=64):
    enc = tok(prompts, return_tensors="pt", padding=True).to(model.device)
    with torch.no_grad():
        out = model.generate(**enc, max_new_tokens=mx, do_sample=False, pad_token_id=tok.pad_token_id)
    gen = out[:, enc["input_ids"].shape[1]:]
    return [clean_one(tok.decode(gen[i], skip_special_tokens=True).splitlines()[0])
            if tok.decode(gen[i], skip_special_tokens=True).strip() else "?" for i in range(gen.shape[0])]


def tpl_single(name, extra=""):
    msgs = [{"role": "system", "content": SYS + extra}]
    for i, o in FEWSHOT:
        msgs += [{"role": "user", "content": i}, {"role": "assistant", "content": o}]
    msgs.append({"role": "user", "content": name + "\n(只输出这一条的歌名，一行)"})
    return tok.apply_chat_template(msgs, tokenize=False, add_generation_prompt=True, enable_thinking=False)


def tpl_multi(names):
    msgs = [{"role": "system", "content": SYS}]
    for i, o in FEWSHOT:
        msgs += [{"role": "user", "content": i}, {"role": "assistant", "content": o}]
    msgs.append({"role": "user", "content": "\n".join(names) + "\n(每行输出一个歌名，共 %d 行)" % len(names)})
    return tok.apply_chat_template(msgs, tokenize=False, add_generation_prompt=True, enable_thinking=False)


variants = {}

t = time.time()
out = run([tpl_single(n) for n in dirty])
variants["单条+fewshot"] = (out, time.time() - t)

t = time.time()
out = run([tpl_single(n, "**绝对不要照抄输入**：输入的署名/乐器/站点词/版本必须删掉。") for n in dirty])
variants["单条+禁照抄"] = (out, time.time() - t)

t = time.time()
enc = tok([tpl_multi(dirty)], return_tensors="pt").to(model.device)
with torch.no_grad():
    o = model.generate(**enc, max_new_tokens=64 * len(dirty) + 64, do_sample=False,
                       pad_token_id=tok.pad_token_id)
m = [clean_one(x) for x in tok.decode(o[0][enc["input_ids"].shape[1]:], skip_special_tokens=True).splitlines()
     if x.strip()]
variants["多行批"] = (m + ["?"] * (len(dirty) - len(m)), time.time() - t)

print(f"{'输入':<58} | {'单条+fewshot':<16} | {'单条+禁照抄':<16} | 多行批")
for i, n in enumerate(dirty):
    print(f"{n[:56]:<58} | {variants['单条+fewshot'][0][i][:16]:<16} | "
          f"{variants['单条+禁照抄'][0][i][:16]:<16} | {variants['多行批'][0][i][:16]}")
for k, (o, el) in variants.items():
    same = sum(1 for i, n in enumerate(dirty) if o[i] == n)
    print(f"\n{k}: 耗时 {el:.1f}s ({el/len(dirty):.3f}s/条)  照抄原样 {same}/{len(dirty)}")
