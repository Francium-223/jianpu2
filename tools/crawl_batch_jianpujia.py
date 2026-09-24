# -*- coding: utf-8 -*-
"""按分类批量爬 jianpujia(简谱之家) —— **断点续爬** + 礼貌限速 + 落日志。

为什么要有它: 单个 `crawl_jianpujia.py <cat> <name> <n>` 一次只爬一个分类, 一晚上要爬几十个;
手工一串命令既不好断点续跑, 也不好回头看"爬到哪了"。这个驱动就是那张清单:

    python3 tools/crawl_batch_jianpujia.py                 # 按清单顺序爬没爬过的
    python3 tools/crawl_batch_jianpujia.py --per 30        # 每个分类最多下 30 首
    python3 tools/crawl_batch_jianpujia.py --only 583,1252 # 只爬指定分类
    python3 tools/crawl_batch_jianpujia.py --list          # 只打印清单与状态

口径:
  * 这份清单是 2026-09-25 从站点 sitemap 抓出来的真实分类号(不是拍脑袋写的数字),
    生成时用 `by name` 对上, 对不上的名字直接跳过并打出来。
  * 分类号来自站点 sitemap(`https://www.jianpujia.com/sitemap.html`)里的 `/list/<cat>-0.html`,
    **不写死**在代码里拍脑袋的数字; 名字是 sitemap 上的锚文本。
  * 断点续爬: 每个分类跑完写进状态文件(默认 `_analysis/crawl_state_jianpujia.json`);
    爬虫自己对"已存在的目录"也会跳过, 双保险。
  * 礼貌: 分类之间 sleep(默认 2s); 爬虫内部每首歌/每页也有 sleep。
  * **不动语料**: 只往 `images-prep/jianpujia-<cat>/` 落图。要不要进库、怎么转写, 是后面的事
    (见 `_analysis/金曲缺口与转写队列_2026-09-24.md`)。
"""
import argparse
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                       # jianpu2
WS = os.path.dirname(ROOT)
STATE_DEFAULT = os.path.join(WS, "_analysis", "crawl_state_jianpujia.json")

# 清单顺序 = 优先级。名字只用来打日志/目录名; 真正的抓取靠分类号。
# ① 库里已有的"大户"(军旅/民族/经典) —— 补齐同一位歌手的其它名曲;
# ② 华语流行里库里明显缺的(周杰伦一整批、林俊杰、陈奕迅…);
# ③ 千禧年前后的经典与独立/民谣。
TARGETS = [
    ("1252", "邓丽君"),
    ("14062", "阎维文"),
    ("6982", "宋祖英"),
    ("6369", "雷佳"),
    ("7224", "谭晶"),
    ("12500", "王丽达"),
    ("315", "陈奕迅"),
    ("499", "林俊杰"),
    ("583", "周杰伦"),
    ("3395", "王菲"),
    ("414", "张学友"),
    ("855", "刘德华"),
    ("377", "邓紫棋"),
    ("380", "周深"),
    ("351", "薛之谦"),
    ("362", "毛不易"),
    ("693", "许嵩"),
    ("3246", "Beyond"),
    ("1192", "五月天"),
    ("859", "朴树"),
    ("1106", "李健"),
    ("1173", "罗大佑"),
    ("3292", "齐秦"),
    ("24064", "张信哲"),
    ("2190", "周华健"),
    ("836", "任贤齐"),
    ("468", "孙燕姿"),
    ("568", "梁静茹"),
    ("725", "蔡依林"),
    ("633", "莫文蔚"),
    ("703", "田馥甄"),
    ("409", "林宥嘉"),
    ("1498", "杨宗纬"),
    ("915", "苏打绿"),
    ("547", "张韶涵"),
    ("530", "张碧晨"),
    ("529", "张杰"),
    ("372", "华晨宇"),
    ("478", "李荣浩"),
    ("736", "汪苏泷"),
    ("869", "汪峰"),
    ("1380", "许巍"),
    ("3407", "老狼"),
    ("3418", "赵雷"),
    ("3509", "宋冬野"),
    ("3127", "陈粒"),
    ("2873", "陈绮贞"),
    ("3173", "徐佳莹"),
    ("1165", "郁可唯"),
    ("770", "胡夏"),
    ("2757", "张靓颖"),
    ("12739", "海来阿木"),
    ("3109", "隔壁老樊"),
    ("406", "水木年华"),
    ("3309", "伍佰"),
    ("980", "周传雄"),
    ("752", "张震岳"),
    ("3777", "陶喆"),
    ("600", "王力宏"),
    ("3403", "刘若英"),
    ("1572", "陈瑞"),
    ("3593", "陈鸿宇"),
    ("3167", "张惠妹"),
    ("4217", "徐秉龙"),
    ("3188", "房东的猫"),
    ("5916", "沈以诚"),
    ("5944", "任然"),
    ("2719", "洛天依"),
    ("21523", "初音未来"),
]

# 去重(同一个分类号只爬一次), 保序
_seen, ORDERED = set(), []
for cat, name in TARGETS:
    if cat not in _seen:
        _seen.add(cat)
        ORDERED.append((cat, name))


def load_state(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def save_state(path, st):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(st, f, ensure_ascii=False, indent=1)
    os.replace(tmp, path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--per", type=int, default=40, help="每个分类最多下多少首(默认 40)")
    ap.add_argument("--only", default="", help="只爬这些分类号(逗号分隔)")
    ap.add_argument("--sleep", type=float, default=2.0, help="分类之间歇多久(默认 2s)")
    ap.add_argument("--state", default=STATE_DEFAULT)
    ap.add_argument("--list", action="store_true", help="只打印清单与状态")
    ap.add_argument("--redo", action="store_true", help="连跑过的分类也重跑")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

    st = load_state(a.state)
    only = {x.strip() for x in a.only.split(",") if x.strip()}
    todo = [(c, n) for c, n in ORDERED if (not only or c in only) and (a.redo or not st.get(c, {}).get("done"))]

    if a.list:
        for c, n in ORDERED:
            s = st.get(c, {})
            print(f"  {c:>7}  {n:<8} {'✓' if s.get('done') else '·'}  {s.get('note', '')}")
        print(f"清单 {len(ORDERED)} 个分类, 待爬 {len(todo)} 个")
        return 0

    print(f"待爬 {len(todo)} 个分类(每个最多 {a.per} 首), 状态文件 {a.state}", flush=True)
    for i, (cat, name) in enumerate(todo, 1):
        t0 = time.time()
        print(f"\n=== [{i}/{len(todo)}] {name}（分类 {cat}）===", flush=True)
        try:
            r = subprocess.run([sys.executable, os.path.join(HERE, "crawl_jianpujia.py"),
                                cat, name, str(a.per)],
                               cwd=ROOT, capture_output=True, text=True, timeout=3600)
            tail = (r.stdout or "").strip().splitlines()[-2:]
            note = " / ".join(x.strip() for x in tail)[-160:]
            ok = r.returncode == 0
        except subprocess.TimeoutExpired:
            ok, note = False, "超时(>1h)"
        st.setdefault(cat, {})
        st[cat].update({"name": name, "done": ok, "note": note,
                        "at": time.strftime("%Y-%m-%d %H:%M:%S"),
                        "per": a.per})
        save_state(a.state, st)
        print(f"  {'✓' if ok else '✗'} {note}  ({time.time() - t0:.0f}s)", flush=True)
        if i < len(todo):
            time.sleep(a.sleep)
    print("\n批量爬结束。", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
