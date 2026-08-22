# jianpu2 —— 简谱图片批量转 jianpu-db 格式

从简谱网站批量下载简谱图片，用本地大模型（Ollama + Qwen2.5-VL）识别，
批量生成 **jianpu-db 格式**的规范化简谱曲谱文件（基于 [jianpu-ly](https://github.com/ssb22/jianpu-ly) 语法），
可直接并入 [jianpu-db](https://github.com/) 数据集流水线。

```
简谱网站 ──crawler.py──> 图片目录(每首歌一个子目录) ──convert.py──> jianpu-db 格式 .txt
                              │                                        │
                          (本地模型识别)                          (jianpu-ly 校验+渲染预览)
```

## 项目结构

| 文件 | 说明 |
|---|---|
| `crawler.py` | 爬虫：下载简谱图片（jianpu.cn / jianpujia.com），断点续爬 |
| `convert.py` | 转换：Ollama 识别 → jianpu-db 格式曲谱文件 |
| `vendor/` | 内置的 `jianpu_ly` + `python-ly` 库（也可用 pip 安装替代） |
| `images/` | 爬虫输出目录（含测试下载的 130 首歌） |
| `scores-out/` | 转换输出目录（默认） |

## 环境准备

1. **安装 Ollama**：https://ollama.com 下载安装，然后拉取视觉模型：

   ```
   ollama pull qwen2.5vl:3b      # 推荐: 3b 识别质量可用, 下载体积小
   ollama pull qwen2.5vl:7b      # 质量更好; 若你的网络慢/被限速, 见下方"网络疑难"
   ```

2. **Python 依赖**（可选，`vendor/` 已内置 jianpu-ly）：
   `pip install jianpu-ly`

3. 可选：LilyPond（https://lilypond.org）渲染 `.ly` 预览。

### 网络疑难 (ollama 模型下载卡在 ~95%)

现象: `ollama pull` 进度到 95% 左右就停住, 磁盘上的 `-partial` 文件不再增长。
这是网络对长连接的限制 (国内访问 ollama 注册表常见)。处理办法:

1. **重启 Ollama**: 任务栏退出 Ollama → 重新打开 (或杀进程后重新启动), 再 `ollama pull` —
   每次重启后重试都有机会把剩余部分拉完 (本仓库实测: 3b 用此法从 95% 拉到了 100%)。
2. 换网络/代理后再试 (代理软件开系统代理即可, ollama 会走 HTTP(S)_PROXY)。
3. 换小模型: `qwen2.5vl:3b` 比 7b 容易拉完; `granite3.2-vision:2b` 最小但识别质量差, 仅应急。
4. 已下载的 95% 不会浪费: 修好网络后重跑 `ollama pull` 会断点续传。

### 图片预处理 (视觉模型用)

```bash
powershell -ExecutionPolicy Bypass -File tools/preprocess.ps1 -Source images/ready -Dest images-prep/ready -Strips 240
```

把图片缩放到最长边 2000px 并切成 240px 高的横条 (重叠 32px), 输出 JPEG。
`convert.py` 检测到 `*_strip_*.jpg` 时会逐条转写 (小模型必需, 长图一次转写会循环/漏读);
没有切片文件时走整图单次转写 (适合 qwen2.5vl:7b 等强模型)。

## 1. 爬虫下载图片

```bash
# 歌谱简谱网 http://www.jianpu.cn —— 按分类爬
python crawler.py jianpucn --cat sanzigepu --pages 3 --out images/jianpucn

# 歌谱简谱网 —— 按关键词搜索（最多前100条）
python crawler.py jianpucn-search --query 青花瓷 --out images/qinghuaci

# 简谱之家 https://www.jianpujia.com —— 按分类列表 id 爬
python crawler.py jianpujia --list 21436 --pages 2 --out images/jianpujia

# 简谱之家 —— 按关键词搜索
python crawler.py jianpujia-search --query 青花瓷 --out images/qinghuaci
```

**jianpu.cn 常用分类**：`yizigepu`(一字) `erzigepu` `sanzigepu` `hechangpu`(合唱)
`yingwengepu`(英文) `jitapu`(吉他) `gangqinpu`(钢琴) `erhupu`(二胡) 等。

**jianpujia.com 常用列表 id**：`21436`(影视) `3462`(儿歌) `22807`(民歌) `388`(主题曲)
`583`(周杰伦) `499`(林俊杰) `315`(陈奕迅)；其它分类从首页导航复制 `/list/<id>-0.html`。

每首歌保存为子目录：`<歌名>__<站点>-<id>/001.jpg ...`，内含 `song.json`（标题、来源、
图片列表）。已存在自动跳过，中断重跑即续爬。`--delay` 调请求间隔（默认 0.3s）。

> `www.jianpujia.com.cn` 域名已失效，「简谱之家」现在在 `https://www.jianpujia.com`。

## 2. 本地模型识别 → jianpu-db 格式

先确认 Ollama 已启动，然后：

```bash
# 推荐流程: 预处理 → 转换
powershell -ExecutionPolicy Bypass -File tools/preprocess.ps1 -Source images/ready -Dest images-prep/ready -Strips 240
python convert.py --input images-prep/ready --out scores-out --model qwen2.5vl:3b

# 不预处理直接转 (适合 7b 等强模型整图识别)
python convert.py --input images/ready --out scores-out --model qwen2.5vl:7b

# 推荐: 填上转写者 ID 和 usertag (不填 --transcriber 则不写该行, 避免空值)
python convert.py --input images/jianpucn --transcriber 你的ID --tags 儿歌,华语

# 补 MBID: 手动指定 / 自动查 MusicBrainz (分级置信度) / 映射文件批量补
python convert.py --input images/qinghuaci --mbid 310b3b07-ec9f-3e88-9fd8-529c17478179
python convert.py --input images/qinghuaci --lookup-mbid
python convert.py --input images/qinghuaci --lookup-mbid --mbid-file mbid_map.json

# 单张图片 / 只看不跑 / 关闭标题清洗
python convert.py --input images/xxx.jpg --out scores-out
python convert.py --input images/jianpucn --dry-run
python convert.py --input images/jianpucn --no-clean-title
```

### 输出格式（jianpu-db 规范）

```jianpu-ly
title=小红帽                      # 清洗后的通用曲名
type=work
usertag=儿歌                     # --tags
alias=小红帽简谱_儿歌_小红帽的故事 # 爬虫原始标题 (与 title 不同时)
transcriber=你的ID                # --transcriber
%--
4/4                              # 拍号
4=90                             # 速度 (谱面有才写)
subtitle=verse                   # 段落: intro/verse/pre-chorus/chorus/...
,6 3 ,6 5 1 2 3 - 6 6 6 5 3 2 1 2
NextScore                        # 分段标记 (模型漏写时自动补)
subtitle=chorus
R2{ 3 4 5 ,6 ,6 5 ,6 1' } A{ 2' 1' ,6 5 | 3 - 2 - }
%END
```

自动处理的转写规范（与 jianpu-db README 一致）：

- **听感记谱**：模型报告谱面调号（`#KEY 1=X` 或 `#KEY 6=Xm`）；小调谱（`6=Xm`）
  的主音自动降八度（`6→,6`、`6'→6`），大调谱照抄，不引入绝对调号
- **只记特征性线性旋律**：提示词要求忽略伴奏、和弦、歌词
- **分段**：`subtitle=` + `NextScore`（自动补漏）；完全相同的重复可省略或用 `R{}/A{}`
- **时值全标注**（`q`八分 `s`十六分 `-`二分 `1 - -`附点二分等），不用 `KeepLength`

### 输出文件

| 文件 | 内容 |
|---|---|
| `*.txt` | jianpu-db 格式曲谱（放入 jianpu-db/scores/ 即可跑 parse_scores.py） |
| `*.ly` | jianpu-ly 渲染预览（校验通过才生成） |
| `*.trans` | 模型原始转写文本（人工校对用） |
| `*.err` | 失败原因 + 对应曲谱（修好 `.trans` 后重跑） |
| `summary.csv` | 批量结果汇总 |
| `mbid_review.csv` | MBID 复核清单（缺失/低置信度歌曲 + 候选） |

## MBID 自动查找（分级置信度）

MBID 是 jianpu-db 的主键，但 MusicBrainz 对华语/儿歌覆盖参差，
**错配比没有更糟**（空 MBID 只是进不了流水线，错 MBID 是污染数据）。因此按置信度分级：

| 置信度 | 判定 | 行为 |
|---|---|---|
| **high** | 标题精确 + 歌手匹配 + score≥90 | 自动填 |
| **medium** | 标题精确但无歌手佐证 / 歌手对不上；或繁简等近似标题 | 自动填 **但进复核清单** |
| **low / 无** | 标题只是近似或没有候选 | **不填** |

查找顺序：`work+歌手` → `recording+歌手` → （歌手过滤一无所获时回退）`work` → `recording`；
查到 recording 时 `type` 自动同步为 `recording`。遵守 MusicBrainz 限速（1 req/s，带 UA）。

**歌手从哪来**：爬虫自动提取——jianpu.cn 的 `[歌手]` 前缀和详情页
`艺术家/歌手/词曲:` 链接（可靠）；jianpujia 从"xx演唱"启发式提取，存进 `song.json`。
提取不到/猜错只会降置信度，不会出错配。

**人工复核闭环**（批量场景推荐）：

```bash
# 1. 首次批量转换
python convert.py --input images/jianpucn --lookup-mbid

# 2. 打开 mbid_review.csv: 看 matched 列里的候选, 挑对的写成映射文件
#    (映射文件格式: {"小红帽": "uuid"} 或 {"小红帽": {"mbid": "uuid", "type": "recording"}})
# 3. 重跑, 映射表优先于网络查询
python convert.py --input images/jianpucn --lookup-mbid --mbid-file mbid_map.json
```

一次人工修正 → 同名歌曲全部复用（重跑时已生成的 .txt 会跳过，删掉或移到别处再跑）。

### 接入 jianpu-db

1. 把 `scores-out/*.txt` 拷入 jianpu-db 的 `scores/` 目录
2. **补 MBID**：没有 MBID 的文件不能进流水线（`data.json` 以 MBID 为主键，空键会互相覆盖）——
   转换时用 `--lookup-mbid` 或 `--mbid`，或事后手工加 `MBID=` 行
3. 在 jianpu-db 目录跑 `python parse_scores.py`，自动生成 `data.json`、`by_*` 索引、
   展开 `R{}/A{}` 的 `_expand.txt`，并按规范重排元数据

## 3. 常见问题

- **识别不准**：换更大模型（`qwen2.5vl:14b`）或调 `convert.py` 里的 `PROMPT`；
  老网站扫描图质量参差，建议抽查 `.trans`
- **barcheck fail / Unrecognised command**：看 `.err` 定位信息，改 `.trans` 后重跑
- **Ollama 连不上**：确认 `curl http://127.0.0.1:11434` 通
- **jianpu.cn 搜索中文**：脚本内部按 GBK 编码，无需手动处理
- `tools/pip-tmp/` 是本机沙箱遗留的锁死目录，可手动删除

## 免责声明

爬虫仅用于个人学习研究，请遵守目标网站服务条款与版权规定；简谱图片版权归原站及原作者所有。
