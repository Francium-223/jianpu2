# D 阶段 · 关机交接（2026-10-01 约 16:00）

用户要关机。这份写给自己下次开机看：**状态、下一步、怎么恢复**。

## 三个仓库都干净且已推送

| 仓库 | HEAD | 未提交 |
|---|---|---|
| `jianpu-db.github.io`（站点/写后端/Worker） | `a1600c3` D 阶段(一) | 0 |
| `jianpu-db`（语料） | `e48a6dbc4` 留档两次 link 投稿 | 0 |
| `jianpu2`（流水线工具） | `39fac95d` sync_docs 自动同步 | 0 |

## 关机期间哪些还活着

* **读路径照常**（Cloudflare 边缘: 检索/卡片/谱页/OG/sitemap/原图代理）—— 域名 `https://jianpu-db.org/` 不受影响。
* **写路径会下线**（投稿要本机服务 + 隧道）。`/api/health` 会显示
  `api:true` 但 **`upstreamOk:false`**（这正是 C 阶段补的那个判据在起作用 —— 它把"配置在不在"和"上游活不活"分开了）。
* 计划任务 `jp_mandopop_absorb3` 会在关机时被打断；**转写是按目录幂等的**，重启后再跑会续上。

## 下次开机：一条命令恢复写路径

```
D:\Documents_D\jianpu2\tools\tunnel_up.cmd
```
它会：① 发现 8770 没服务 -> 起 **FastAPI 版**（`app/api.py`，带 `JPSUBMIT_TOKEN`）
-> ② 重建快速隧道 -> ③ 把 `API_UPSTREAM` / `API_TOKEN` 写进 Worker secret。
（想退回标准库版: `py -3.13 tools/tunnel_up.py --impl legacy`）

## D 阶段：已完成 / 未完成

**已完成并落库**（都有实测）
* `/metrics`（Prometheus 官方客户端；真语料上 `jianpu_corpus_songs 11495`，官方解析器校验 14 个指标族）；
* `tools/lint_python.py`（ruff + mypy **渐进门槛**，5 文件过 ruff / `app/api.py` 过 mypy）；
* `.pre-commit-config.yaml`（11 个钩子实测全过）+ `.gitattributes`（LF 定死，仓库级 `core.autocrlf=false`）；
* `Dockerfile` + `docker-compose.yml` + `.dockerignore`（**本机没 Docker，只做了步骤等价性验证**）；
* `tools/make_isolated_db.py`（隔离语料库，对拍/CI 共用）；
* `.github/workflows/checks.yml`（web / python / docker 三条 + 矩阵）。

**未完成**
1. **D 阶段文档同步**: `TECH_STACK.md` / `ARCHITECTURE.md` / `RESUME.md` 还要补 Docker+Compose、ruff/mypy、
   pre-commit、`/metrics` 这几行，以及一条 STAR（"没有 Docker 的机器上怎么保证镜像能构建"）。
2. **看 CI 结果**: push 已经触发 `checks.yml`，下次开机去仓库 Actions 看三条流水线（尤其 `docker build` ——
   那是镜像可构建性的唯一证据）。
3. 若 CI 报错，优先看 `python` 那条里"起两份写后端 + 对拍"那一步（CI 环境和本机的差异最可能在这儿）。

## 之后：E 阶段

匹配核心 **Rust→Wasm** 或 embedding+ANN（语义/哼唱相似度）。当前基线:
查询中位 **139.9 ms**、索引就绪 **179–201 ms**（`node tools/bench_search.mjs 40`）。

---

## 更新（2026-10-01 晚，D 阶段收尾）

* **CI 五条全绿** ✓ `checks`（web node20/22 · python 3.11/3.13 · docker build）+ `Deploy to GitHub Pages`。
  **`docker build` 绿了** —— 镜像可构建性终于有 CI 背书（本机没装 Docker，只做了步骤等价性验证）。
* 写路径已恢复（`tools\tunnel_up.py` 修了三处恢复路径上的 bug，见 jianpu2 提交 `cb74de35`）：
  域名 `<https://jianpu-db.org/api/health>` 现在 `{"api":true,"upstreamOk":true,"og":11495}`。
* D 阶段文档已同步（`TECH_STACK.md` 加了 Docker/Compose、ruff+mypy、pre-commit、`/metrics`、Actions 矩阵，
  以及 STAR 第 10、11 条）。**D 阶段完成**。
* **下一阶段: E（算法侧）**。本机**没有 Rust 工具链**（cargo/rustc/wasm-pack 都没有，装齐要 ~1GB 下载，
  而这台机器现在只剩 ~3GB 空闲内存），所以 E 阶段选 **TS 里的倒排/ngram 预筛剪枝**：
  当前基线 `查询中位 144.6 ms / p90 169.7 ms / 索引就绪 213 ms`（`node tools/bench_search.mjs 40`），
  要求"剪枝后金曲四榜的 Top-1/3/5 **一格不掉**"才算成功（用现成的 `eval_golden.py` 验）。
