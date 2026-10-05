# 转换器口径：ABC / MIDI → 简谱

> 这份文档回答五件事：**什么算 `converted`**、三种输入各自怎么映射、公共口径（调号 / 八度 /
> 和弦 / 休止 / 反复 / source / 头部）在哪、**怎么跑**、**怎么验**。
>
> 口径的**唯一实现**是 `jianpu2/tools/convert_common.py`。`abc_to_jianpu.py`（ABC）与
> `midi_to_jianpu.py`（MIDI）都从它 import，**不许在自己的文件里再抄一份** —— 这个项目吃过
> 三次"同一口径写两份、慢慢漂掉"的亏（带 `#` 的音在 `data.jsonl` 里整段消失；后缀时值被静默
> 丢掉；和弦 token 整批丢音），所以口径只能有一处落点。

---

## 1. 什么算 `converted`

`status=converted` = **由 ABC 等记谱格式机械转换而来**（作者 2026-10-04 定）。要点：

* 它跟 `status=midi` 的区别不在"是不是机器转的"，而在于 **converted 是这个仓库自己的口径**
  （小调 La-based、`1=` 参考音、八度归一、和弦 token 写成"数字连写"），而 `midi` 那批是历史上
  另一条线硬转进来的。
* **MIDI 转换属于同一类，继续写 `converted`**，不新造状态。
* 它在四个地方都在白名单里（改状态名会同时打断这四处）：

  | 位置 | 作用 |
  | --- | --- |
  | `jianpu-db/parse_scores.py` 的 `OK_STATUS = ('ok', 'ocr', 'converted')` | 决定能不能进 `data.jsonl` |
  | `jianpu-db/tools/check_data_sane.py` | 数据体检 |
  | `jianpu2/tools/check_corpus_invariants.py` | 语料不变量 |
  | `jianpu2/tools/melody_search.py` | 查歌（机器人那条路） |

## 2. 三种输入各映射什么

| 输入 | 入口 | 音高怎么来 | 时值怎么来 | 调号怎么来 | 主旋律怎么来 |
| --- | --- | --- | --- | --- | --- |
| **ABC** | `tools/abc_to_jianpu.py` | 音名字母 + 变音记号 + 八度记号（源里写死的） | `L:` × 音符长度 | `K:` 头（源里写死的） | 单声部记谱，`V:` 多声部判错不做 |
| **MIDI** | `tools/midi_to_jianpu.py` | 绝对半音 → **十二音级表**（见 §3.2） | `tick / PPQ`（四分音符数） | `FF 59` 调号 meta；没有就 K-S 推断或 `--key` | 见 §2.1 的选轨策略 |
| 以后新增（如 MusicXML） | 新增 `tools/<fmt>_to_jianpu.py` | 自己读成"音高 + 时值"事件 | 同上 | 同上 | 同上 |

共同点：转换器只做"**记谱语法 → 音高 + 时值事件**"这一段，之后的音级 / 八度 / token / 头部
一律走 `convert_common`。

### 2.1 MIDI 的选主旋律策略（多轨）

默认 `--melody auto`，判据按优先级，**每一条都有依据，不是硬猜**：

1. **轨道名**命中 `melody|lead|vocal|solo|main|tune|主旋律|旋律|主奏`。依据：POP909 的
   `index.mid` 公开说明就是 “MELODY track for the main melody, BRIDGE track for the
   sub-melody, PIANO track for the accompaniment”（<https://github.com/music-x-lab/POP909-Dataset>）。
2. 没有命名时，取**同时发声率为 0（单声部）且平均音高最高**的那一轨。依据：本仓库的口径是
   “只记**具有特征性的、响度最大**的**线性**旋律”（`jianpu-db/README.md`）—— 主旋律是单声部，
   且通常在高音区。
3. 仍然分不出来（没有单声部轨）→ 取平均音高最高的一轨并记 `melody_ambiguous`（**不静默猜**）。

其它策略：`--melody 2`（第 N 轨，含它所有通道）、`--melody name:PIANO`、`top`、`most`、`all`。
`format 0`（全部塞在一轨里、靠通道分开）会**按通道再拆成候选** —— 否则钢琴伴奏会和主旋律混成
一片和弦（实测：本地真素材里的 `format 0` 就是这种布局）。

## 3. 公共口径（`convert_common.py`）

### 3.1 调号与小调：大调 Do-based、小调 **La-based**

* 大调：主音记 `1`（Do-based）。
* 小调：主音记 **`,6`**（与 `jianpu-db/README.md`“小调一级记作 `,6`；大调一级记作 `1`”一致）。
  实现：`1=` 取**同调号的关系大调主音**，且比小调主音**高一个小三度**（落在主音上方最近的位置），
  于是自然小调音阶写成 `,6 ,7 1 2 3 4 5 6`。
* ABC 侧由 `K:Am` 这类调号算出参考音；MIDI 侧由 `key_from_tonic_midi(主音音高, 是否小调)` 算 ——
  **两者对同一段自然小调音阶给出逐音相同的 token**（`convert_common.py --selfcheck` 里钉住了）。

### 3.2 变音拼写（MIDI 必须写死规则，因为 MIDI 只有半音）

相对 `1=` 的十二音级表：

```
半音 0  1   2  3   4  5  6   7  8   9  10  11
音级 1  #1  2  b3  3  4  #4  5  b6  6  b7  7
```

**依据是实测**（不是抄惯例）：全库 270 首 `status=midi` 的谱里，5 个两可半音槽的写法计数是

| 槽 | 计数 | 槽 | 计数 |
| --- | --- | --- | --- |
| `#1` / `b2` | 183107 / 169852 | `b3` / `#2` | 244991 / 125684 |
| `#4` / `b5` | 485353 / 218949 | `b6` / `#5` | 239791 / 179310 |
| `b7` / `#6` | 344009 / 135076 | | |

**5 个槽全部与表同向**，所以默认按表拼写（`--spell degree`）。想要“按调号方向挑音名字母”的
另一种写法用 `--spell letter`（实测差异：`K:F` 的 B 自然默认给 `#4`、letter 模式给 `b5`，音高相同）。

### 3.3 八度归一

整首升 / 降 12 个半音这两个方案里，取 `,` + `'` 总数最少的那种；**平手或都更差则保持原样**。
实测：只整体平移，音级序列一个都不动；平移若让任何音超出 jianpu-ly 认的 ±3 个记号，该方案作废。

⚠ 一个**不打算改**的细节：归一之后，原本**一个八度记号都没有**的音会把正记号写在数字**前面**
（`1` → `'1`）。这看着与"负的写前、正的写后"的约定不一致，但**既有 492 首产物就是这个形态**：
我按约定改成写后面，492 首真素材回归立刻从 **492/492 掉到 485/492**，于是改回。
`jptok` 的正则里 `oct1`/`oct2` 都在，两种写法都认，下游不受影响。

### 3.4 时值

`c`=1 拍（四分）、`q`=1/2、`s`=1/4、`d`=1/8、`h`=1/16，附点 ×1.5；延长用 `-`（1 拍）、
`q-`/`s-`/`d-`/`h-`（各按字母）。表示不出来的时值：

* ABC 侧：`dur_approx` 记账，音头按时值档近似（**绝不丢音**）；
* MIDI 侧：先试精确表示，其次是"音头吃 1 + 小数部分、整数拍用 `-` 接"的长音拆法
  （8.25 拍 → (1 + 0.25) 拍的音头 + 7 个 `-`）；再不行才近似。零时值（`note_on`/`note_off`
  同 tick，实测本仓库 train-data 里的"原子"夹具就是）记 `note_too_short` 并用最短的 `h` 记下来。

小节线按拍号合成，且**插在时值分量之间**（一个音跨两小节时，`|` 落在它的延长记号中间）。
源里没有拍号的（MIDI 没写 `FF 58`、ABC 没写 `M:`）**默认 4/4 并在头部注明**。

### 3.5 和弦：数字连写，记号各归各的

同时发声的几个音写成一个 token：`[时值字母][(八度记号 变音 音级) …][附点]`，八度/变音写在
**各自音级左边**（`,1'35`、`d,4,,b5,,3,,1`）。不摊平成序列、也不丢音。

形态不是推的，是抄语料：全库实测 **261611 个和弦 token / 223 首（全是 `status=midi`）**，
和 `jianpu-ly.py:1861 chordNotes_markup()` + `grace_octave_fix()`（把写在数字右边的记号搬回
左边）一致。下游 `jptok.parse_token_all()` 逐音返回，`seq()` 不再丢音。

### 3.6 休止 / 念白 / 反复

* 休止一律写 `0`，**不静默丢**（自检里钉"见到 = 输出"）。
* ABC 的 `x`（不可见休止）也写 `0` 并记 `invisible_rest_x`（语料里的 `x` 是念白，语义不同）。
* **MIDI 没有念白语义，所以只出 `0`，不出 `x`**（诚实说明，不是省略）。
* 正文里**没有反复记号**：ABC 的 `|:` `:|` `::` `[1/[2`、`P:`/`Y:` 段序一律展开成平铺正文；
  MIDI 本身没有反复，但文本/标记里的 `D.C.` `Segno` `Fine` 这类**会改演奏顺序**的记号判为
  结构性（`jump_mark`），不当普通注释剥掉。

### 3.7 source 命名

形状 `^[a-z0-9]+-[0-9a-z_]+$`，即 `<站点token>-<id>`，`id = sha1(仓库路径 + '#' + 序号)[:12]`：

* ABC：站点 token = 来源集合名（`abcgh`/`abczd`/`abcnm`），**序号 = 文件内第几首**
  （必须含，否则一个 `X:` 块里粘的第二首会撞车）；
* MIDI：站点 token = `midi`，**序号 = 选中的轨道号**（同一份 MIDI 换一条轨必须算不同的 source）。

### 3.8 头部（语料形态）

排版在 `convert_common.corpus_text()`（正文按 100 列折行），字段顺序：
`%<文件名>` → `title=` → `alias=`（可选）→ `tag=` → `usertag=`（**留空，不编**）→ `tagroute=` →
`transcriber=` → `status=converted` → `source=` → `%` 记账注释 → `%--` → 拍号 → `subtitle=score`
→ 正文 → `%END`。`link=` **只在确有收录页时写**（ABC 的原始文件直链、MIDI 的文件路径都不是收录页）。

`transcriber`：ABC = `abc2jianpu`，MIDI = `midi2jianpu`。

## 4. 怎么跑

```bash
# 只验口径本身（不需要任何输入文件）
py -3.13 tools/convert_common.py --selfcheck

# ABC -> 简谱
py -3.13 tools/abc_to_jianpu.py <file.abc> [--tune N] [--json] [--all] [--scan] [--corpus]
py -3.13 tools/abc_to_jianpu.py --selfcheck
py -3.13 tools/abc_to_jianpu.py --run <manifest.tsv> --outdir <dir> --per-file 5

# MIDI -> 简谱
py -3.13 tools/midi_to_jianpu.py <file.mid>                      # 看它选哪一轨 + 结果
py -3.13 tools/midi_to_jianpu.py <file.mid> --corpus --outdir <dir>
py -3.13 tools/midi_to_jianpu.py <file.mid> --key Am --melody name:MELODY --json
py -3.13 tools/midi_to_jianpu.py *.mid --corpus --outdir <dir>   # 批量
py -3.13 tools/midi_to_jianpu.py --selftest
```

**纪律：这两个工具都不会往 `jianpu-db/scores/` 写任何文件。** 入库是另一个动作（例如
`_analysis/_cc0_ingest.py` 那种一次性的写盘脚本），要写也得由人明确决定。

## 5. 怎么验

| 验什么 | 命令 | 现在的结果 |
| --- | --- | --- |
| 公共口径本身 | `convert_common.py --selfcheck` | **31/31 通过** |
| ABC 转换器（原有 53 条 + 新增 3 条） | `abc_to_jianpu.py --selfcheck` | **56/56 通过** |
| MIDI 转换器（合成用例） | `midi_to_jianpu.py --selftest` | **33/33 通过** |
| 入库产物没被搬运弄坏 | `abc_to_jianpu.py --regress-cc0 <清单> --samples-dir <cc0_all>` | **492 首逐 token 一致 492/492** |
| 工具链整体 | `bash tools/check_tools.sh` | 见该脚本输出 |

三条自检都包含**同一条底线**：产出的**每个 token 过 `jptok` 白名单**（平台唯一的 token 实现），
并且整份语料文本交给 **`jianpu-db/score.py` 真解析一遍**（`read → write_buf → expand → to_record`，
中间文件只落临时目录），断言读回来的正文与原输出逐 token 相同。理由是历史上"自己算得挺对、
平台认不出"正是丢音的入口。

### 5.1 492 首真素材回归的四个数（ABC）

拿已入库那 492 首（`status=converted`）的**原始 ABC 文件**重跑一遍，与库里现存文件对拍：

| 指标 | 结果 | 说明 |
| --- | --- | --- |
| 逐 token 一致 | **492/492** | 搬运 + 抽公共模块**没有改动任何一条口径** |
| 字段 + 正文逐字节一致（顺序不计） | **492/492** | 连头部字段、注释文字、折行都没动 |
| `%` 注释集合一致 | **492/492** | |
| 生字节一致 | 0/492 | **差异全部来自入库之后的平台动作**，不是转换器 |

生字节差异的两条来源（已逐条对账）：

1. `jianpu-db/score.py` 的 `write_buf()` 会把 `%` 注释从"字段之后"搬到"字段之前"，并把
   `alias=` 各项的空格重新拼掉 —— 每次解析都会做；
2. 入库之后补的那行 `link=<原始文件直链>`（转换器输出里没有它）。

### 5.2 MIDI 侧的真素材

POP909 **不在本机**（`--selftest` 的选轨策略依据的是它公开的轨道命名）。本机能用的真素材是
`train-data-*` 下的真 `.mid`（简谱 → LilyPond → MIDI 的渲染产物）：

| 样本 | 结果 |
| --- | --- |
| `train-data-*/pdf` 随机 400 份 | 解析 398 份（2 份**一个音符都没有**，明确报错）；398/398 `ok` + `pitch_safe` + 零丢失 |
| 全仓库最大的 200 份（音符 41~260，合计 20207 音） | **200/200** `ok` + `pitch_safe` + 零丢失；163 份有调号 meta、37 份走 K-S 推断；107 份归一平移过 |

**往返抽查做不了**（如实说）：`train-data-seq/img` 里的 `.mid` 是**片段**（例：`th01_01.mid`
只有 16 个音，而语料 `th01_01.txt` 是 111 个音），与语料不是整首对应，所以不能拿它当
"简谱 → MIDI → 简谱"的往返素材。要真做往返，得先有 `jianpu-ly → LilyPond → MIDI` 的整首渲染
（本机没有这条链路的产物）。

## 6. 已知不确定 / 未做（诚实清单）

* **MIDI 的半音拼写**是"按实测语料多数写法"定的（§3.2）。ABC 侧的拼写来自源里的音名字母，所以
  个别音两边写法可能不同、**音高相同**（例：`K:F` 的 B 自然，ABC 记 `#4`，MIDI 默认也记 `#4`；
  但若用 `--spell letter` 会记 `b5`）。检索口径用 (音级, 变音)，这类差异会影响跨记谱的匹配。
* **MIDI 的调号推断**是 Krumhansl-Schmuckler 相关（启发式），一律记 `key_inferred`；有
  `FF 59` meta 才用 meta。批量转换建议显式给 `--key`。
* **MIDI 的调号变更**（同一首里换调）没有实现：只取第一处 `FF 59`（ABC 侧的换调是记账
  `key_change` 并继续用新调号）。
* **MIDI 的力度/踏板/颤音/连音线**不记：只取"音高 + 时值"。弦乐/人声的滑音、装饰音会变成
  一串短音（`dur_approx` / `note_too_short` 记账，但旋律形状会被改变）。
* **MIDI 的重叠音**（单声部 legato）按"下一个起音"截断并记 `overlap_trimmed` —— 简谱一行记不下重叠。
* ABC 侧的**未做清单**照旧（连音 `(3` / broken rhythm 的时值比例不缩放、`V:` 多声部不做、
  三连音组内的时值压缩不实现），详见 `abc_to_jianpu.py` 文件头的"仍未做（诚实清单）"。
* 本文档里的所有实测数字都是 2026-10-06 在本机跑出来的；换语料批次要重跑 §5 的命令再改数字。
