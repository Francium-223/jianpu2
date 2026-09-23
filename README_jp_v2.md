# 简谱转写管线 v2（组合方案）

## 最终交付（2026 实测）

| 项 | 数量 |
|---|---|
| 批量转写 | **367 套**（296 有效 / 71 空）|
| 转写总音符 | **54,507** |
| **jianpu-db 曲谱** | **281 个 / 44,906 音符**（`jianpu-db-out/scores/`）|
| 拍号识别分布 | `4/4` 174 · `2/4` 84 · `3/4` 19 · `6/8` 4 |
| MBID | 42 命中 / 239 占位（`%TODO`）|
| 双高八度残留 | **0** |
| 超长图跳过 | 29（`batch-out/skipped.txt`）|
| 失败 | 12（`batch-out/errors.log`）|

## 架构

```
谱图
 ├─ 1) 切分   transcribe.fine_rows / count_bars / crop_note_regions / bound_to_note_row
 │            （行切割 → 原子框；crop 到行底，包含数字下方的时值下划线/低八点）
 ├─ 2) 数字   Qwen3-VL-2B 直接看每个原子块输出数字（零样本）
 ├─ 3) 符号   geo_detect：时值下划线（按 y 行聚类，抗扫描碎片）/ 低八度点 / 高八度点 / 附点
 └─ 4) 组装   jianpu-ly token（如 q3 / ,s5 / 5. / - / 0）
```

**同一次运行同时输出**：转写序列 + 标注框图（保证图上标注 == 转写结果）。

## 用法

```powershell
py -3.13 tools/jp_transcribe.py <谱图路径> [输出图.png]
```

示例：
```powershell
py -3.13 tools/jp_transcribe.py "images-prep/.../001.jpg" "train-work/out.png"
```

输出：`音 N -> out.png` + 一行 token 序列。

## 依赖

- `models/Qwen3-VL-2B-Instruct`（数字识别，可用环境变量 `QWEN_VL_MODEL` 覆盖路径）
- Python: torch / transformers / peft / Pillow / numpy
- 环境：**页面文件（虚拟内存）需 ≥ 20GB**（加载 2B 模型）

## 关键修复（相对旧管线）

| 修复 | 说明 |
|---|---|
| crop 到行底 | `bound_to_note_row`: `y1 = min(max(ny1,bbot), bbot+6)` —— 原子框必须含数字下方的下划线；否则两道杠被截 → `s` 误判 `q` |
| 附点收纳不连锁 | `crop_note_regions`: 附点收纳相对**数字原始右缘**判断（≤14px），避免 x1 动态扩大跨到隔壁音符 |
| 下划线按 y 行聚类 | `geo_detect`: 扫描图一道杠常断成多个碎片 → 收集细碎片后按 y 分组，**该行碎片总宽 ≥4** 才算一条时值线 |
| 弧线/连音线排除 | `crop_note_regions`: `dashes` 收紧为 `h<=4`（纯横线）—— 音符**上方的曲线（延音线/连音线）** h 更大，不再被当延音杠生成音符块 |
| 附点 y 约束 | `geo_detect`: 附点需 `dy0-2 <= cy <= dy1+2`（与数字同高），排除右下方低八点被误判 |

## 性能与实测

**多谱验证**（`tools/verify_multi.py`，与 `train-work/gt/*.txt` 对比）：

| 谱 | 音数 | GT | OK | 命中率 | 评估 |
|---|---|---|---|---|---|
| 春天在哪里 | 142 | 114 | **87** | **76%** | ✅ 可部署 |
| 排排坐 | 26 | 31 | **25** | **81%** | ✅ 可部署 |
| 时间都去哪了 | 173 | 153 | 55 | 36% | ⚠️ 多切 |
| 兄弟抱一下 | 248 | 192 | 23 | 12% | ❌ 多切 |

- **耗时**：约 2 分钟/首（2B 模型逐块前向；瓶颈是视觉编码）
- 旧 Qwen2.5 6 头管线基线：spring = 83

## 与 jianpu-db 对接（`tools/to_jianpu_db.py`）

把 `batch-out/*.txt`（裸 token）转成 jianpu-db 的 `scores/*.txt` 格式：

```powershell
py -3.13 tools/to_jianpu_db.py --mbid --transcriber "jianpu2-auto(Qwen3-VL-2B)"
```

- **高八度**：我们的 `'1`（撇在前）→ jianpu-ly 的 **`1'`**（撇在后）
- **中文文件名 mojibake**（爬虫把 UTF-8 当 Latin-1 存）→ 自动还原
- **MBID**：用 MusicBrainz Web Service 按曲名查（含**相似度把关**，避免"一分钱"错配成"一切從簡"）
- **无 MBID 时**：`MBID=` 留空 + `%TODO: MBID 待补`（**不用内部占位标记**，因为这是公开库）

### ⚠️ 上游库的两个坑（供 jianpu-db 维护者参考）

1. **MusicBrainz 中文覆盖差**：实测 94 首里 **79% 查不到 MBID**（中文儿歌/民歌基本未收录），
   而 README 规定 MBID 必填 → 建议允许空值 + `%TODO`，或允许其它唯一标识。
2. **`score.py` 用 `mbid` 当 `data.json` 的 key**（`b.update({i.mbid: i.others})`）→
   **多个空 MBID 会互相覆盖**（只剩最后一个）。若允许空 MBID，key 建议改用文件名。

## 热度优先（`tools/rank_by_bili.py`）

按 **B站播放量**给谱图排热度（"最可能被搜索的曲目优先转写"）：
- 搜 B站视频 → 取播放量，**标题含"合集/串烧/连播/催眠"降权 ×0.15**（播放量不属于单曲），
  **不含歌名的降权 ×0.2**，**歌名 <3 字判无效**（易匹配到无关视频）
- 输出 `rank-out/ranked.jsonl`；`batch_transcribe.py` 检测到它会**自动按热度顺序**转写

## 已知限制

**"音符行与歌词粘连"的谱（时间/兄弟）切分偏多**：`fine_rows` 未把音符行与下方歌词行分开
（行高 ~116，正常 ~40）→ **歌词字被切成块当音符** → 音数远超 GT → OK 低。

**尝试过但无效/有害的修法**（记录下来避免重走）：
- 提高 `bar_extent` 的细高门槛 → 真小节线因"与歌词连通"(w>5) 被排除，更糟
- 调小 `ROW_GAP`(4) → 音符行被跳过、歌词行被当音符（反了）
- 限制附属距离(数字底+20px) → spring 退化 87→79

**正确方向**（未做）：行内 y 分割（按暗像素低谷把"音符行"与"歌词行"切开）。

## 评测脚本

- `tools/verify_multi.py` —— 4 谱跑 OK
- `tools/combo_unified.py` —— 单跑 spring 并出图

