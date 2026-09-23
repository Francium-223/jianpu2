# jianpu2 项目进度总结

## 一、模型

### jianpu-atom（= jianpu-lora-v15）
真实谱面单音符识别模型（LoRA, 基于 Qwen2.5-VL-3B）。
- 数字: 100%
- 低八度: 99%
- 高八度: 100%
- 附点: 99%
- 时值: 96%

训练链路: 合成原子数据(v4) → v13 从零 → 真实微调 → v15(=jianpu-atom)

## 二、端到端工具链

| 脚本 | 作用 |
|------|------|
| tools/transcribe.py | 简谱图片 → jianpu-ly 序列(拆分→jianpu-atom识别→拼回) |
| tools/batch_pipeline.py | 图片目录 → 批量转写 → score 文件 |
| tools/make_score.py | 序列+元数据 → 标准 jianpu-db 曲谱文件 |
| tools/mbz_lookup.py | MusicBrainz API 查 MBID/title/type |
| tools/verify_source_urls.py | **原谱站确切页**: `source=<站>-<id>` → 那一页的真实 URL, **逐条抓取核对页面标题**, 写 `jianpu-db/source_pages.json` |
| tools/add_link.py | **人工补收录页**(命令行): 把某站的具体页面写进 `scores/<file>.txt` 的 `link=`; 支持 `--show` / `--from-tsv` 批量 / `--dry` |
| ../jianpu-web/tools/refresh.sh | 重建索引链: `parse_scores.py` → `build_web_data.py`(网页「＋ 补收录页」保存后由服务端在后台调用) |
| tools/propose_tags.py | **按原谱站栏目提议/落盘分类标签**(映射表从既有数据反推; 低置信度只提案); `--emit-template` 导出人工补标签清单, `--from-tsv` 写回 |
| tools/harvest_artists.py | 从原谱站页面抽**歌手**(jianpucn 标题尾段 / jianpujia `…_<歌手>演唱_…`); 抓取结果缓存可断点续跑, `--reparse` 离线重跑规则, `--apply` 落盘 |
| tools/audit_arrangements.py | 审计**被纯度门挡下的改编/器乐谱**(锦囊 §8-5): 数量/图在哪/是否新曲, 出可审清单 |
| tools/audit_corpus_quality.py | **语料体检**: A 明确垃圾(单音占比>=90% / 音符占 token<25%) 隔离、B 同源逐字相同的重复 去重、C 拿不准的只出提案; 移动不删, 可逆 |
| tools/quarantine_short_scores.py | 隔离**旋律音 < 5**(检索下限)的垃圾曲谱, `--min` 可调 |
| tools/refine_titles_from_pages.py | 给 `todo=refine the filename` 的曲从原谱页提议官方曲名(`--offline` 用缓存, `--apply` 落地) |

## 三、爬虫

| 脚本 | 网站 | 状态 |
|------|------|------|
| tools/crawl_jianpujia.py | jianpujia.com 简谱之家 | 全链路通, 431链接, 下载中 |
| tools/crawl_qupu123.py | qupu123.com 中国曲谱网(30万篇) | 全链路通, 分页已修, 抓取中 |

后续可选数据源(未做):
- sooopu.com 搜谱网(33万首, /html/组/ID.html, indexN.html 分页, 但 GBK 编码 + dl.asp 脚本下载, 较复杂)
- jianpu.cn 歌谱简谱网
- jian-pu.com 简谱大全
- qupumao.com 曲谱猫

数据目录:
- images-prep/jianpujia-crawl/ (每首歌一个文件夹 歌名__jianpujia-<ID>/001.jpg) — 已下载 493 首/738图
- images-prep/qupu123-crawl/ — 3893 链接, 下载中
- images-prep/test-jianpujia/ (已有 2077 文件)
- images-prep/ready* (已有 1767 文件)

## 四、端到端验证(澎湖湾)

- 转写 219 音, 单音符质量 96-100%
- 序列对齐 61.4% (差异来自图片展开反复段 vs GT 循环记号, 非识别错误)

## 五、下一步(待定)

1. 扩大爬取规模(多分类/多网站)
2. 下载完成后批量转写
3. 转写结果人工校验
