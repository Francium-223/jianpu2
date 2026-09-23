# -*- coding: utf-8 -*-
"""诊断: 并行批生成到底卡在哪 —— 打印每条序列生成了多少 token、耗时、原文。"""
import os
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, "tools")
from refine_titles_llm import MODEL, SYS, FEWSHOT, pick_names

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, StoppingCriteria, StoppingCriteriaList

PAR = int(os.environ.get("DBG_PAR", "4"))
LINE = int(os.environ.get("DBG_LINE", "8"))
tok = AutoTokenizer.from_pretrained(MODEL)
tok.padding_side = "left"
if tok.pad_token_id is None:
    tok.pad_token = tok.eos_token
print("newline ids:", tok.encode("\n", add_special_tokens=False), repr(tok.decode([198])), flush=True)
t0 = time.time()
model = AutoModelForCausalLM.from_pretrained(MODEL, dtype=torch.bfloat16, device_map="cuda:0")
model.eval()
print(f"load {time.time()-t0:.1f}s  attn={model.config._attn_implementation}", flush=True)


def build(lines):
    msgs = [{"role": "system", "content": SYS}]
    for i, o in FEWSHOT:
        msgs += [{"role": "user", "content": i}, {"role": "assistant", "content": o}]
    msgs.append({"role": "user", "content": "\n".join(lines) + "\n(每行输出一个歌名，共 %d 行)" % len(lines)})
    return tok.apply_chat_template(msgs, tokenize=False, add_generation_prompt=True, enable_thinking=False)


names = [t for _f, t in pick_names()][:PAR * LINE]
groups = [names[i:i + LINE] for i in range(0, len(names), LINE)]
prompts = [build(g) for g in groups]
enc = tok(prompts, return_tensors="pt", padding=True).to(model.device)
start = enc["input_ids"].shape[1]
print(f"prompt tokens(padded) {start}  groups {len(groups)}", flush=True)

nl_ids = sorted(set(tok.encode("\n", add_special_tokens=False)))


class Enough(StoppingCriteria):
    def __init__(self, counts):
        self.counts = torch.tensor(counts, device=model.device).unsqueeze(1)
        self.nl = torch.tensor(nl_ids, device=model.device)

    def __call__(self, input_ids, scores, **kw):
        gen = input_ids[:, start:]
        if gen.shape[1] == 0:
            return False
        return bool((torch.isin(gen, self.nl).sum(1, keepdim=True) >= self.counts).all())


for tag, crit, mx in (("baseline max_new=200 无停条件", None, 200),
                      ("按行数提前停 max_new=544", StoppingCriteriaList([Enough([len(g) for g in groups])]), 32 * LINE + 32)):
    t = time.time()
    with torch.no_grad():
        out = model.generate(**enc, max_new_tokens=mx, do_sample=False, pad_token_id=tok.pad_token_id,
                             stopping_criteria=crit)
    el = time.time() - t
    gen = out[:, start:]
    lens = [int((gen[i] != tok.pad_token_id).sum()) for i in range(gen.shape[0])]
    toks = sum(lens)
    print(f"\n== {tag}: {el:.1f}s  生成 {toks} tok  {toks/el:.1f} tok/s  {el/len(names):.3f}s/条  每条序列 {lens}", flush=True)
    for i in (0, 1):
        print(f"--- seq{i} ---\n{tok.decode(gen[i], skip_special_tokens=True)[:400]}", flush=True)
