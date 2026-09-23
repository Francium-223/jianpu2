# -*- coding: utf-8 -*-
"""把 source_map.tsv 导成一页**可点击**的 HTML（自带筛选框，无外部依赖，离线可用）。

用法: py -3.13 tools/source_map_html.py
产物: train-work/source_map.html
说明:
  * 图片链接用**相对路径**（HTML 在 train-work/ 下, 所以是 ../images-prep/...）,
    双击打开就能直接跳去看原始扫描件 —— 这是"被问出处"时最硬的证据。
  * 转写列链到 batch-out 等结果目录里的 txt。
  * 16k 行全量塞进一页, 靠顶部输入框做客户端筛选（不联网、不装库）。
"""
import glob
import html
import os
import re
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

sys.path.insert(0, "tools")
try:
    from to_jianpu_db import fix_mojibake, title_of   # 与谱子本体同一份修复/取名逻辑
except Exception:
    def fix_mojibake(s):
        return s

    def title_of(s):
        return s

TSV = "train-work/source_map.tsv"
OUT = "train-work/source_map.html"

IMG_EXT = (".jpg", ".jpeg", ".png", ".gif", ".webp")
rows = []
with open(TSV, encoding="utf-8") as f:
    head = f.readline()
    for line in f:
        p = line.rstrip("\n").split("\t")
        if len(p) < 7:
            continue
        title = p[0]
        for _ in range(5):        # 双重转义(&amp;nbsp;)要解到不动为止
            t2 = html.unescape(title)
            if t2 == title:
                break
            title = t2
        title = title.replace("\u00a0", " ").strip()
        title = fix_mojibake(title)          # 兜底: TSV 若还是旧的脏数据也能救回来
        site, sid, d, nimg, done, url = p[1:7]
        note = p[7] if len(p) > 7 else ""
        # 曲名显示用**干净标题**（title_of 会去掉 `简谱(歌词)_儿歌_陈洲宏记谱` 这类爬虫后缀），
        # 但链接仍指向磁盘真实目录名 —— 显示和路径要分开，不然链接会点不开 ✗
        shown = title_of(os.path.basename(d)) or title
        first = ""
        try:
            fs = [x for x in os.listdir(d) if x.lower().endswith(IMG_EXT)]
            if fs:
                first = sorted(fs)[0]
        except Exception:
            pass
        rows.append((title, site, sid, d, nimg, done, url, first, note))

# 名字可疑的目录（由 tools/flag_odd_names.py 产出），在页面上直接标出来
flagged = set()
try:
    with open("train-work/odd_names.tsv", encoding="utf-8") as f:
        next(f, None)
        for line in f:
            p = line.rstrip("\n").split("\t")
            if p and p[0]:
                flagged.add(p[0])
except Exception:
    pass

site_count = {}

for r in rows:
    site_count[r[1] or "(无标记)"] = site_count.get(r[1] or "(无标记)", 0) + 1
n_done = sum(1 for r in rows if r[5])

opts = "".join(f'<option value="{s}">{s}（{c}）</option>'
               for s, c in sorted(site_count.items(), key=lambda x: -x[1]))

html = ["""<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">
<title>简谱语料来源档案</title>
<style>
 body{font:13px/1.6 -apple-system,"Segoe UI","Microsoft YaHei",sans-serif;margin:0;padding:16px;background:#fafafa;color:#222}
 h1{font-size:18px;margin:0 0 6px}
 .bar{position:sticky;top:0;background:#fafafa;padding:8px 0;border-bottom:1px solid #ddd;z-index:5}
 input,select{font:13px inherit;padding:5px 8px;border:1px solid #bbb;border-radius:5px}
 input{width:260px}
 .stat{color:#666;margin:6px 0}
 table{border-collapse:collapse;width:100%;background:#fff}
 th,td{border-bottom:1px solid #eee;padding:4px 8px;text-align:left;vertical-align:top}
 th{position:sticky;top:52px;background:#f0f0f0;z-index:4}
 tr:hover{background:#f6faff}
 a{color:#0a58ca;text-decoration:none} a:hover{text-decoration:underline}
 .no{color:#bbb}
 code{background:#f3f3f3;padding:0 3px;border-radius:3px}
</style></head><body>
<h1>简谱语料来源档案</h1>
<div class="stat">""" + f"共 <b>{len(rows)}</b> 个谱目录 · 其中 <b>{n_done}</b> 份已有转写 · 站点分布：" + \
    " ".join(f"{s} <b>{c}</b>" for s, c in sorted(site_count.items(), key=lambda x: -x[1])) + \
    f" · 生成于 {time.strftime('%Y-%m-%d %H:%M')}" + """</div>
<div class="bar">
 <input id="q" placeholder="按曲名筛选…" oninput="flt()">
 <select id="s" onchange="flt()"><option value="">全部站点</option>""" + opts + """</select>
 <label style="margin-left:10px"><input type="checkbox" id="d" onchange="flt()" style="width:auto"> 只看已转写</label>
 <span class="stat" id="c" style="margin-left:10px"></span>
</div>
<table id="t"><thead><tr>
 <th>曲名</th><th>站点</th><th>站点ID</th><th>原始扫描件</th><th>转写</th><th>站点检索</th>
</tr></thead><tbody>
"""]

for title, site, sid, d, nimg, done, url, first, note in rows:
    img = f'<a href="../{d}/{first}" target="_blank">{first}</a>' if first else '<span class="no">—</span>'
    tr = (f'<a href="../{done}/{os.path.basename(d)}.txt" target="_blank">打开</a>'
          if done else '<span class="no">未转写</span>')
    u = f'<a href="{url}" target="_blank">站点检索</a>' if url else '<span class="no">—</span>'
    # 曲名直接取 TSV 里那列 —— **不要在 HTML 里重算** ✗: source_map 已经把
    # `title_of`(去爬虫后缀) + "坏副本借用干净孪生名" 都做完了, 重算会把借来的名字覆盖掉。
    shown = title or fix_mojibake(os.path.basename(d))
    if note.startswith("duplicate-of="):
        # 名字坏掉(丢过字节)但有干净孪生 -> 已经借用孪生的名字, 不再挂 todo
        shown += (' <span style="color:#888;font-size:11px">' + note + '</span>')
    elif os.path.basename(d) in flagged:
        shown += ' <span style="color:#c00;font-size:11px">todo=refine the filename</span>'
    html.append(f'<tr data-s="{site}" data-d="{1 if done else 0}">'
                f'<td>{shown}</td><td>{site or "—"}</td><td>{sid or "—"}</td>'
                f'<td>{img} <span class="no">({nimg})</span></td><td>{tr}</td><td>{u}</td></tr>\n')

html.append("""</tbody></table>
<script>
function flt(){
  var q=document.getElementById('q').value.trim().toLowerCase();
  var s=document.getElementById('s').value;
  var onlyD=document.getElementById('d').checked;
  var rows=document.querySelectorAll('#t tbody tr'), n=0;
  for(var i=0;i<rows.length;i++){
    var r=rows[i], ok=true;
    if(q && r.cells[0].textContent.toLowerCase().indexOf(q)<0) ok=false;
    if(s && r.getAttribute('data-s')!==s) ok=false;
    if(onlyD && r.getAttribute('data-d')!=='1') ok=false;
    r.style.display = ok ? '' : 'none';
    if(ok) n++;
  }
  document.getElementById('c').textContent='显示 '+n+' / '+rows.length;
}
flt();
</script></body></html>""")

open(OUT, "w", encoding="utf-8").write("".join(html))
print(f"已写 {OUT}  ({os.path.getsize(OUT)/1024/1024:.1f} MB, {len(rows)} 行)")
