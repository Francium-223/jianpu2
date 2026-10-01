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
