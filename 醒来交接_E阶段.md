# 醒来交接（2026-10-01 深夜 / 用户睡觉期间自动推进）

## 一、当前状态一句话

**A–D 阶段完成且 CI 全绿；E 阶段做了一大半，拿到一个"真收益"和一个"诚实的否决"。**
写路径正常（域名 `upstreamOk:true`）；**只有 Cloudflare 正式部署卡在登录态上**（需要你一条命令，见第四节）。

## 二、E 阶段结果（算法侧）

| 项 | 结果 |
|---|---|
| **真收益（已上线到镜像/仓库）** | 查出 `search()` 的排序比较器**每次都现算 `versOf()`**（内部 `new Set(...)`）→ `O(n log n)` 次 Set 分配。改成"每个候选只算一次排序键"后：查询中位 **144.6 → 105.9 ms（-27%）**，p90 113.6 ms |
| **Rust→Wasm（试过，否决）** | 装了 Rust 1.99 + `wasm32-unknown-unknown`，写了 0.9 KB 的内层代价循环（零依赖、不用 wasm-bindgen）。**逐首对拍**：12 查询 × 11,495 首 = **137,940 次**比较，代价逐首一致 ✓；**端到端对拍**：15 条查询（含多段）结果逐条相同 ✓；但**实测端到端 0.84×（更慢）** ✗ —— wasm 全库扫 36 ms，而它替换掉的那部分本来就是小头。**所以默认不走 wasm**（代码与对拍留着，`search(..., {scan})` 是可选参数） |
| 教训 | **先量再改**：我以为瓶颈是"11,495 首的匹配扫描"，实际是排序比较器。加速器只有在**它替换的部分确实是瓶颈**时才有意义 |

产物：`jianpu2/wasm-matcher/`（Rust crate + 冒烟测试）、站点仓库 `tools/check_wasm_parity.mjs`（逐首 + 端到端对拍）、
`tools/bench_wasm.mjs`（端到端对照）、`tools/_wasm_prune_diag.mjs`（诊断"最小代价成员有几个"）。

## 三、模型：4B 与误删

* **`Qwen3-VL-4B-Instruct` 确认没在用** ✓（证据链：计划任务 → `mandopop_absorb3.ps1`（不设模型变量）
  → `transcribe_source.py` → `jp_transcribe.py`（`MODEL = QWEN_VL_MODEL or models/Qwen3-VL-2B-Instruct`）
  + `batch_transcribe.py`（只用 `transcribe.py` 的几何函数，不加载 LoRA））。
* **但我删多了** ✗（已记为失误）：`Qwen2.5-VL-3B-Instruct`（是 `qwen_loader.py` 的默认模型，
  被 **27 个** diag/eval 脚本引用）、`jianpu-lora-v15` 等 LoRA、`qwen-mt-v1` 的 heads ——
  后两者是**自训产物、无备份**，只能重训。
* **正在补**：`Qwen2.5-VL-3B-Instruct` 下载中（**5.06 / ~7.0 GB**，走 hf-mirror、可续传；
  断点文件在 `.cache/huggingface/**/*.incomplete`）。中断了就再跑一次：
  `py -3.13 tools/fetch_base_model.py Qwen/Qwen2.5-VL-3B-Instruct`
* 记录在 [models删除记录_20261001.md](models删除记录_20261001.md)（含"事后核查"与教训：判断能不能删
  要查**谁引用它**，不能只看文档怎么描述它）。

## 四、需要你做的一件事（一条命令）

Cloudflare 正式站的部署**卡在 wrangler 登录态**上：
`C:\Users\qinxi\AppData\Roaming\xdg.config\.wrangler\config\default.toml` 里凭据在，但已过期，
refresh 又赶上网络抽风 → wrangler 现在要求 `CLOUDFLARE_API_TOKEN`。

```powershell
cd D:\Documents_D\jianpu-db.github.io
npx wrangler login          # 浏览器点一下授权
npx wrangler deploy         # 把带 -27% 性能改进的前端发上去
```

在此之前：**镜像（https://jianpu-db.github.io/）会先吃到新构建**（CI 每次 push 都重建），
正式域名还是旧产物 —— 功能一样，只是慢一点。另外**写路径不受影响**（Worker 没动）。

## 五、磁盘与后台

* D 盘空闲 **51.5 GB**（删实验模型 24.9 GB + 缓存/临时 0.57 GB）；C 盘 11.6 GB。
* Rust 装在 `D:\rust`（`RUSTUP_HOME`/`CARGO_HOME`），用的时候：
  `$env:PATH="D:\rust\cargo\bin;$env:PATH"`。
* 后台：写路径隧道看护（15 分钟一次，判据 = `api && upstreamOk`）；模型下载在跑。

---

## 更新（同日更晚）

* **ngram 剪枝已落地并接入应用** ✓（`static/search.ts` 的 `ensureGrams` / `candidateMask`，`app.ts` 空闲时建）：
  * 采用条件**可证明安全**：只在"每段都能精确命中"且"代价 0 的结果够填满榜单"时才用剪枝结果；
  * 实测：长查询 **69.1 → 48.2 ms/条（-30%）**；短查询/模糊查询退回全扫（不变慢）；
  * 等价性对拍 `tools/check_prune_parity.mjs`：60 条（含模糊与多段）**结果逐条相同** ✓；
  * 剪枝索引 ~136 ms，放**空闲时**建 —— "打开就能用"的时间没变（仍 ~200 ms）。
* **Qwen2.5-VL-3B 已补回** ✓（29 个文件 / **7.52 GB**，`fetch_base_model.py` 走 hf-mirror 断点续传）。
* 全套自检 10 项 + typecheck + ruff/mypy 门槛**全绿**；`check_prune_parity.mjs` 也挂进了 CI。
* **Cloudflare 正式站已部署成功** ✓（网络恢复后 wrangler 自己刷新了登录态）：
  线上已是 `app.3a8cd15f.js` + `search.6cbacf4d.js`（含两处性能改动），`/` 返回的 HTML 也指向新哈希 ✓。
  （中途我以为"首页 HTML 指向旧哈希"是个构建 bug，先去看本地文件发现**本地是对的** ——
   其实是边缘缓存滞后几分钟。**又一次"先量再改"**：没确认就动手，就会去修一个不存在的问题。）
* 镜像（GitHub Pages）会稍后自动跟上：等站点仓库那 3 个提交推上去，CI 就会重建（GitHub 网络时断时续，已挂自动重试）。
---

## 待你定（我不擅自动手的两件）

1. **15 份"多页未转全"的碎片谱**（真数据损失 ✓）—— 名单在 `train-work/redo_fragments_v1.txt`，
   等流水线空闲会自动重转（看护任务已挂：计划任务不跑 + 显存 < 1.5 GB + 内存 > 3 GB 才动手），
   日志 `_analysis/redo_fragments_run.log`。分类依据：`_analysis/qa_fragments_triaged.txt`。
2. **23 个组名被拆成 46 个组的"用户可见重复"** —— 大小写（`Amani`/`AMANI`、`Love`/`love`、`THE`/`The`）
   与标点/下划线（`中国_中国` / `中国，中国`）。映射表：`_analysis/group_merge_map.txt`。
   修法在 `build_web_data.py` 的归组口径（大小写不敏感 + 去标点/下划线/空格，显示名取出现次数最多的写法），
   **要重建索引** —— 我没在流水线跑着的时候动它（会跟它自己的"空闲重建"打架）。你点头我就做。

## 低置信度 162 份怎么看

`_analysis/qa_lowconf.txt`（按 `conf_p10` 升序）。它不是"错了"，而是"最低 10% 那批数字里有个别音虚"——
优先级低于上面第 1 条（那 15 份是真的少转了几页）。建议：等碎片谱修完，再用重转后的 `conf` 对比这批名单，
筛出"重转后置信度明显回升"的样本，反推转写哪里容易虚。

---

## 新加的夜间自检（一句话就能撤）

注册了计划任务 **jp_night_qa_ext**（每天 08:20，只读、秒级）：查语料↔站点索引一致性、碎片谱分类、
低置信度、归组重复、近 24 小时增量（用 git 历史，不用 mtime）。它与你原有的"夜班 QA 监视"
（全丢 / 准入缺口 / %END / 磁盘水位）**互补不重复**，日志在 `_analysis/night_qa_ext.log`。

```powershell
Unregister-ScheduledTask -TaskName jp_night_qa_ext    # 撤掉
cmd /c D:\Documents_D\jianpu2\tools\night_qa.cmd      # 手动跑一次
```

**一条会咬人的坑**：`tools/*.cmd` 必须是 **CRLF** 行尾。LF 时 cmd 会把 `rem` 行的首字母吃掉，
报 `'ightly' is not recognized` 这种莫名其妙的错。仓库 `.gitattributes` 已锁 `*.cmd/*.bat/*.ps1 text eol=crlf`。