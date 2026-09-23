# Kaggle 免费 GPU 部署说明（jianpu2 简谱转写）

免费借 Kaggle 的 P100/T4 跑批量转写。**总花费 0 元**，代价是要手动传数据、受 12 小时/会话限制。

---

## 一、为什么可行

| 条件 | 我们的情况 |
|---|---|
| 模型大小 | Qwen3-VL-2B ≈ **4 GB**，P100 16GB 绰绰有余 |
| 数据量 | 1577 张谱图 ≈ **1.5 GB**（压缩后更小）|
| 任务性质 | 纯推理、可断点续传（已有 `txt` 自动跳过）|
| 依赖 | torch + transformers，Kaggle 全都有 |

**唯一的坑**：**Kaggle 的 P100/T4 不支持 `bfloat16`**。代码已改成可配（`JP_DTYPE=float16`），
在 Kaggle 上会自动用 fp16。

---

## 二、操作步骤

### 第 1 步：上传两个 Dataset

在 Kaggle 页面 → **Datasets → New Dataset**，上传这两个 zip：

| 本地文件 | 上传后的 Dataset 名 |
|---|---|
| `deploy/kaggle-images.zip` | `jianpu-images` |
| `deploy/kaggle-tools.zip` | `jianpu-tools` |

（zip 里保留了 `images-prep/xxx/001.jpg` 这样的相对路径，解压即可用。）

### 第 2 步：建 Notebook

**New Notebook** → 右侧设置：

```
Accelerator : GPU P100        (或 GPU T4 x2)
Internet    : On              ← 必须开, 要下模型
Persistence : Files only
```

左侧 **Add Input** → 把上面两个 Dataset 挂上。

### 第 3 步：粘贴运行

把 `deploy/kaggle_run.py` 的全部内容粘进第一个 cell，**改这两行为你的实际路径**：

```python
IMG_ZIP   = "/kaggle/input/jianpu-images/kaggle-images.zip"
TOOLS_ZIP = "/kaggle/input/jianpu-tools/kaggle-tools.zip"
```

然后 Run All。

### 第 4 步：断点续传（重要）

**Kaggle 会话最长 12 小时**，到点会强断。**不用怕**——我们的转写脚本是**断点续传**的：

- 已完成的谱（`batch-out/xxx.txt` 存在）**自动跳过**
- 重新 Run All 就会**接着上次的位置继续**

**但要注意**：`/kaggle/working` 的内容**在会话结束后不保留**，除非：
- 用 **Save Version**（保存 Notebook 版本，输出会保留）✓
- 或者中途把 `batch-out/` **下载走** ✓

**建议流程**：
```
Run 6 小时 → 中断 → Save Version → 下载 batch-out 备份
→ 下次开新会话 → 先把 batch-out 传回去 → 继续跑
```

### 第 5 步：取回结果

跑完后 **Save Version** → 页面右上 **Output** 标签 → 下载 `jianpu-out.zip`。

本地解压到 `D:\Documents_D\jianpu2\batch-out\`，然后照常跑：

```powershell
py -3.13 tools/to_jianpu_db.py --meter --transcriber "jianpu2-auto(Qwen3-VL-2B)"
```

---

## 三、限额与预期

| 项 | 值 |
|---|---|
| **免费 GPU 时长** | **30 小时/周** |
| **单次会话上限** | 12 小时 |
| **P100 相对 4070 速度** | 约 **0.7×**（更慢） |
| **T4×2 相对 4070** | 约 **1.3×**（双卡批处理） |
| **全量 1577 张预计** | P100 约 **35 小时** → **分 2 周** 走完 |

**建议**：**只跑受影响最严重的那批**（B 类 462 张，时值全丢的那批），约 **10 小时**，一周内能搞定。

---

## 四、如果卡住了

| 症状 | 处理 |
|---|---|
| `unzip: command not found` | Kaggle 有 unzip；改用 Python `zipfile` 解压 |
| 模型下载失败 | 已设 `HF_ENDPOINT=https://hf-mirror.com`（国内镜像）；也可先下载后作为 Dataset 上传 |
| `RuntimeError: not implemented for BFloat16` | 确认 `JP_DTYPE=float16` 生效 |
| CUDA out of memory | 调小 `JP_BATCH`（8 → 4） |
| 会话断了白跑 | **不会白跑**，进度在 `batch-out/`；按第 4 步接着来 |

---

## 五、替代方案对比

| 方案 | 花钱 | 麻烦度 | 速度 |
|---|---|---|---|
| **本机 4070（现状）** | 0 | 无 | ~3.7 天跑完全量 |
| **Kaggle 免费** | 0 | 中（要传数据、会断） | ~35 小时（分两周）|
| **AutoDL 4090** | ~35 元 | 低（一条命令） | ~17 小时 |
| **AutoDL A100** | ~40 元 | 低 | ~8 小时 |
