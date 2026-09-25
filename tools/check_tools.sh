#!/usr/bin/env bash
# 命令行工具的冒烟自检: 每个 tools/*.py 都得能 import 并打出 --help。
# 为什么需要它: 工具都 import jianpu-db/score.py 或 linkurl.py, 那两份是"唯一实现";
# 改了它们(比如把 jptok 变成硬依赖)很容易把整个工具链 import 崩, 而平时没人跑。
#
#     bash tools/check_tools.sh
#     JIANPU_QUICK=1 bash tools/check_tools.sh   # 跳过最慢的"口径一致"那一步
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."
fail=0
TOOLS="add_link propose_tags harvest_artists refine_titles_from_pages audit_corpus_quality
       quarantine_short_scores audit_arrangements verify_source_urls corpus_fingerprint
       coverage_gap verify_crawl_matches slice_systems audit_melody_clones
       check_transcribe_ready audit_meter check_images set_artists
       mbid_lookup transcribe melody_search
       crawl_jianpujia crawl_jianpucn crawl_qupu123 crawl_batch_jianpujia
       crawl_jianpucn_by_title crawl_jianpujia_search
       queue_from_crawl batch_transcribe_queue fix_residual_titles
       detect_sections tlsfetch propose_title_cleanup fix_image_dir_entities"
# 2026-09-25: 这份清单是**手写**的, 于是烂了两个口子:
#   ① `batch_pipeline`/`make_score`/`mbz_lookup` 三个文件早就没了, 循环里 `|| continue` 直接跳过,
#      清单看着覆盖了其实没有(已换成真实存在的 `mbid_lookup`);
#   ② `crawl_jianpucn_by_title.py` 里硬编码着作者 Windows 的 `os.chdir(D:\...)`, 在 Linux 上必崩,
#      却因为不在清单里而没人发现 —— 直到这一轮要用它补金曲缺口才撞上。
# 所以下面把"清单里有、文件却没有"改成**明确失败**, 让清单漂移藏不住。
for t in $TOOLS; do
  printf '%-28s ' "$t"
  if [ ! -f "tools/$t.py" ]; then
    echo "!! 清单里有它, 但 tools/$t.py 不存在(清单过时了 —— 改名了就同步改这里)"; fail=1
    continue
  fi
  if out=$(timeout 120 python3 "tools/$t.py" --help 2>&1); then
    echo "OK"
  else
    echo "!! 失败"; echo "$out" | tail -3 | sed 's/^/      /'; fail=1
  fi
done
# 功能自测: 查歌(melody_search) —— 机器人的「<数字>是什么歌」走的就是它。
# 2026-09-24 之前的版本搜的是旧流水线的 batch-out/(里面没有 th10_06), 永远返回"命中 0 首"且不报错;
# 现在搜 data.jsonl 并用 jptok 切 token, 这条自检把"已知答案 + 音数交叉验证"钉住。
if [ -f tools/check_melody_search.py ]; then
  echo
  echo "=== 功能: 查歌 melody_search(机器人用) ==="
  python3 tools/check_melody_search.py | tail -3 || fail=1
fi

# 静态检查: "调用了但没定义"的名字 —— 专抓"重构删了函数、调用还留着"
# (2026-09-24 实测: propose_tags.py 的 apply_tsv/emit_template 就是这么没的, 而 --help 走不到那行)
if [ -f tools/check_undefined.py ]; then
  echo
  echo "=== 静态: 未定义名检查 ==="
  python3 tools/check_undefined.py | tail -3 || fail=1
fi

# 功能自测: 在**隔离副本**里真的写一次标签(apply_tsv 路径), 必须写成功 + 幂等 + 不碰真语料
if [ -f tools/propose_tags.py ]; then
  echo
  echo "=== 功能: 补标签 TSV 写回(隔离副本) ==="
  T="$(mktemp -d)"
  DB0="${JIANPU_DB:-$(cd .. && pwd)/jianpu-db}"
  mkdir -p "$T/scores"
  cp "$DB0"/scores/th10_06.txt "$T/scores/" 2>/dev/null || cp "$(ls "$DB0"/scores/*.txt | head -1)" "$T/scores/"
  cp "$DB0"/linkurl.py "$DB0"/schema.py "$DB0"/score.py "$DB0"/tags.json "$T/" 2>/dev/null
  SAMPLE="$(ls "$T/scores" | head -1)"
  printf 'file\ttitle\tsite\tsource_url\tsuggested_tag\thuman_tag\n%s\tx\tq\t\t\t自检标签甲,自检标签乙\n' "$SAMPLE" > "$T/in.tsv"
  out1="$(JIANPU_DB="$T" python3 tools/propose_tags.py --from-tsv "$T/in.tsv" 2>&1)"
  out2="$(JIANPU_DB="$T" python3 tools/propose_tags.py --from-tsv "$T/in.tsv" 2>&1)"
  if grep -q '自检标签甲' "$T/scores/$SAMPLE" && echo "$out1" | grep -q '新增 2 条' && echo "$out2" | grep -q '已存在 2 条'; then
    echo "  ✓ 标签写回成功且幂等 ($(echo "$out1" | grep -m1 '从 TSV 写入'))"
  else
    echo "  !! 标签写回有问题"; echo "     第一次: $out1"; echo "     第二次: $out2"; fail=1
  fi
  rm -rf "$T"
fi

# 功能自测: 补收录页写盘(add_link)在隔离副本里: 写进去 + 幂等 + 搜索页被拒 + 不碰真语料
if [ -f tools/add_link.py ]; then
  echo
  echo "=== 功能: 补收录页写回(隔离副本) ==="
  T3="$(mktemp -d)"
  DB0="${JIANPU_DB:-$(cd .. && pwd)/jianpu-db}"
  mkdir -p "$T3/scores"
  cp "$DB0"/linkurl.py "$DB0"/schema.py "$T3/" 2>/dev/null
  S3="th10_06.txt"; [ -f "$DB0/scores/$S3" ] || S3="$(ls "$DB0"/scores/*.txt | head -1 | xargs basename)"
  cp "$DB0/scores/$S3" "$T3/scores/"
  printf '%s\thttps://www.qupu123.com/tongsu/erziyixia/p215000.html\n' "$S3" > "$T3/in.tsv"
  o1="$(JIANPU_DB="$T3" python3 tools/add_link.py --from-tsv "$T3/in.tsv" --no-refresh 2>&1)"
  o2="$(JIANPU_DB="$T3" python3 tools/add_link.py --from-tsv "$T3/in.tsv" --no-refresh 2>&1)"
  o3="$(JIANPU_DB="$T3" python3 tools/add_link.py "$S3" 'https://www.qupu123.com/search?q=x' --dry 2>&1)"
  if grep -q '^link=https://www.qupu123.com/tongsu/erziyixia/p215000.html' "$T3/scores/$S3" \
     && echo "$o2" | grep -q '已存在' && echo "$o3" | grep -q '搜索页'; then
    echo "  ✓ 写入成功 + 幂等 + 搜索页被拒"
  else
    echo "  !! 补收录页写回有问题"; echo "     写入: $(echo "$o1" | tail -1)"; echo "     幂等: $(echo "$o2" | tail -1)"; echo "     拒搜索页: $(echo "$o3" | tail -1)"; fail=1
  fi
  rm -rf "$T3"
fi

# 功能自测: 标题提案工具在隔离副本里跑 --offline(不联网、不写语料), 必须出提案且不炸
if [ -f tools/refine_titles_from_pages.py ]; then
  echo
  echo "=== 功能: 标题提案 --offline(隔离副本) ==="
  T2="$(mktemp -d)"
  DB0="${JIANPU_DB:-$(cd .. && pwd)/jianpu-db}"
  mkdir -p "$T2/scores"
  cp "$DB0"/source_pages.json "$T2/" 2>/dev/null
  cp "$DB0"/scores/th10_06.txt "$T2/scores/" 2>/dev/null || cp "$(ls "$DB0"/scores/*.txt | head -1)" "$T2/scores/"
  if JIANPU_DB="$T2" python3 tools/refine_titles_from_pages.py --offline --out "$T2/prop.tsv" >/dev/null 2>&1 \
     && head -1 "$T2/prop.tsv" | grep -q 'proposed_title'; then
    echo "  ✓ --offline 出提案正常 ($(($(wc -l < "$T2/prop.tsv")-1)) 条)"
  else
    echo "  !! --offline 失败"; fail=1
  fi
  rm -rf "$T2"
fi

# 口径一致性: jptok(唯一实现) 与 score.py 里的兜底 _FallbackJptok 必须逐项一致
# (2026-09-23 这两份一起漂过, 36 首受损 -> 现在用全语料 723 万 token 把它锁住; 约 1-2 分钟)
if [ -f tools/check_jptok_parity.py ]; then
  echo
  if [ "${JIANPU_QUICK:-0}" = "1" ]; then
    echo "=== 口径: jptok 与兜底逐项一致性 === (JIANPU_QUICK=1, 跳过; 它要 2-3 分钟)"
  else
    echo "=== 口径: jptok 与兜底逐项一致性 === (全语料, 约 2-3 分钟)"
    python3 tools/check_jptok_parity.py | tail -3 || fail=1
  fi
fi

# 功能自测: 补标签的提案路径**别漏掉"usertag= 空且没挂 todo"的歌**(2026-09-24 修的 bug:
# 原来那种歌被整批跳过, 于是 qupu123 栏目能映射成分类的 31 首从没被提议过)
if [ -f tools/propose_tags.py ]; then
  echo
  echo "=== 功能: 补标签提案不漏歌(隔离副本) ==="
  T5="$(mktemp -d)"; mkdir -p "$T5/scores"
  printf '{"qupu123-1": {"url": "https://www.qupu123.com/puyou/shangchuan/p1.html", "t": "x"}}' > "$T5/source_pages.json"
  printf '%%自检曲.txt\ntitle=自检曲\ntag=\nusertag=\ntagroute=\nstatus=ocr\nsource=qupu123-1\n%%--\n4/4\nsubtitle=score\n1 2 3 4 5 6 7 1'\'' 2'\'' 3'\'' 4'\'' 5'\'' 6'\'' 7'\''\n%%END\n' > "$T5/scores/自检曲.txt"
  out="$(JIANPU_DB="$T5" python3 tools/propose_tags.py --out "$T5/prop.tsv" 2>&1)"
  if [ -f "$T5/prop.tsv" ] && grep -q 'qupu123-1' "$T5/prop.tsv" && grep -q '谱友上传\|puyou' "$T5/prop.tsv"; then
    echo "  ✓ usertag= 空且无 todo 的歌也进了提案"
  else
    echo "  !! 该歌没进提案(过滤 bug 又回来了?)"; echo "$out" | tail -3; fail=1
  fi
  rm -rf "$T5"
fi

# 功能自测: 隔离跑时**不许写进真工作台**(2026-09-24 实测踩过: 隔离跑 audit_corpus_quality
# 把 _analysis/quality_proposal.tsv 覆盖成了 1 行表头; 现在 safeout.default_out 会写进那个 DB 目录)
if [ -f tools/safeout.py ]; then
  echo
  echo "=== 功能: 隔离跑不许污染工作台 ==="
  T4="$(mktemp -d)"; mkdir -p "$T4/scores"
  DB0="${JIANPU_DB:-$(cd .. && pwd)/jianpu-db}"
  cp "$DB0"/source_pages.json "$DB0"/tags.json "$DB0"/linkurl.py "$DB0"/schema.py "$DB0"/score.py "$DB0"/parse_scores.py "$T4/" 2>/dev/null
  cp "$DB0"/scores/th10_06.txt "$T4/scores/" 2>/dev/null || cp "$(ls "$DB0"/scores/*.txt | head -1)" "$T4/scores/"
  before="$(md5sum ../_analysis/quality_proposal.tsv 2>/dev/null | cut -d' ' -f1)"
  ( cd "$T4" && JIANPU_JTOK="$DB0/../jianpu2/skills/jianpu-melody-lookup" python3 parse_scores.py >/dev/null 2>&1 )
  JIANPU_DB="$T4" python3 tools/audit_corpus_quality.py >/dev/null 2>&1
  after="$(md5sum ../_analysis/quality_proposal.tsv 2>/dev/null | cut -d' ' -f1)"
  if [ "$before" = "$after" ] && [ -f "$T4/quality_proposal.tsv" ]; then
    echo "  ✓ 隔离跑的输出落在隔离目录里, 真工作台未被改动"
  else
    echo "  !! 隔离跑动了真工作台(before=$before after=$after)"; fail=1
  fi
  rm -rf "$T4"
fi

# 功能: 爬取队列的**分拣 + 入库**(2026-09-25 夜间新增的两个工具) —— 全离线、临时目录、不碰真语料。
# 为什么值得单列: 这两个工具决定"哪些爬回来的图算新歌、哪些是改编、怎么写进语料",
# 而输入是几千个目录名的字符串解析 —— 最容易悄无声息退化成"永远 0 首"。
if [ -f tools/queue_from_crawl.py ] && [ -f tools/batch_transcribe_queue.py ]; then
  echo
  echo "=== 功能: 爬取队列分拣 + 入库(隔离) ==="
  TMP="$(mktemp -d)"
  mkdir -p "$TMP/imgs/kw/新歌甲__qupu123-999999" "$TMP/imgs/kw/新歌乙钢琴__qupu123-999998" "$TMP/imgs/kw/祝福__qupu123-1"
  for d in "$TMP/imgs/kw"/*/; do printf 'x' > "$d/001.jpg"; done
  mkdir -p "$TMP/db/scores" "$TMP/work"
  printf '1 2 3 4 5\n' > "$TMP/work/qupu123-999999.txt"
  if python3 tools/queue_from_crawl.py --images "$TMP/imgs" --dirs "$TMP/imgs/kw" \
        --with-images --out "$TMP/q.tsv" > "$TMP/q.log" 2>&1; then
    n=$(grep -c "qupu123-999999" "$TMP/q.tsv" || true)
    if [ "$n" = 1 ] && grep -q "改编" "$TMP/q.log"; then
      echo "  ✓ 分拣: 新歌进队列 / 改编标注 / 库里已有的排除"
    else
      echo "  ✗ 分拣结果不对"; tail -6 "$TMP/q.log"; fail=1
    fi
  else
    echo "  ✗ queue_from_crawl 跑失败"; tail -5 "$TMP/q.log"; fail=1
  fi
  if JIANPU_DB="$TMP/db" python3 tools/batch_transcribe_queue.py --stage import \
        --queue "$TMP/q.tsv" --work "$TMP/work" > "$TMP/imp.log" 2>&1; then
    f="$TMP/db/scores/新歌甲.txt"
    if [ -f "$f" ] && grep -q '^status=ocr' "$f" && grep -q '^transcriber=' "$f" && grep -q '1 2 3 4 5' "$f"; then
      echo "  ✓ 入库: 写出 scores/*.txt(带 status/transcriber 与正文)"
    else
      echo "  ✗ 入库产物不对"; ls -la "$TMP/db/scores" | tail -3; fail=1
    fi
  else
    echo "  ✗ batch_transcribe_queue 跑失败"; tail -5 "$TMP/imp.log"; fail=1
  fi
  rm -rf "$TMP"
fi

# 功能: 段落权重泛化(重复度)探测器 —— 它的价值是**否定结论**, 所以要保证它随时跑得动、
# 而且"chorus 重复度高"这个反例还在(2026-09-26: 逐首看它有时对, 但 37 首整体是反相关的)。
if [ -f tools/detect_sections.py ]; then
  echo
  echo "=== 功能: 重复度探测段落(否定结论的证据) ==="
  if out=$(timeout 120 python3 tools/detect_sections.py profile th01_01.txt 2>&1); then
    if echo "$out" | grep -Eq "chorus +\[ *50, *173\) +重复分中位数 1\.00"; then
      echo "  ✓ th01_01: chorus 重复度最高(该曲符合「副歌会重复」的直觉)"
    else
      echo "  ✗ th01_01 的 chorus 重复度不对"; echo "$out" | head -6; fail=1
    fi
  else
    echo "  ✗ detect_sections profile 跑失败"; fail=1
  fi
fi

# 功能: 括号不配对曲名的提案(隔离) —— 2026-09-25 审计出 208 首。判据是**括号配对扫描**,
# 不是正则猜; 必须保证"配对的曲名一个都不许进提案"(否则会提出把 `（吻别）` 砍掉的坏建议)。
if [ -f tools/propose_title_cleanup.py ]; then
  echo
  echo "=== 功能: 括号不配对曲名提案(隔离) ==="
  T="$(mktemp -d)"; mkdir -p "$T/jianpu-db"
  printf '%s\n%s\n%s\n%s\n' \
    '{"file":["坏.txt"],"title":"世界末日（","source":["qupu123-1"],"status":"ocr"}' \
    '{"file":["好.txt"],"title":"Take Me To Your Heart（吻别）","source":["qupu123-2"],"status":"ocr"}' \
    '{"file":["散.txt"],"title":"OVER THE RAINBOW）","source":["qupu123-3"],"status":"ocr"}' \
    '{"file":["多.txt"],"title":"难忘的爱人】彩谱】","source":["qupu123-4"],"status":"ocr"}' \
    > "$T/jianpu-db/data.jsonl"
  # 页面标题给前两条**佐证**; 第三条故意给个对不上的, 第四条是"多个多余闭括号"(必须标 0)
  printf '%s\n' '{"qupu123-1":{"t":"世界末日（简谱版）_谱友园地_中国曲谱网","url":"u","via":"title","at":"x"},"qupu123-2":{"t":"Good_谱友园地_中国曲谱网","url":"u","via":"title","at":"x"},"qupu123-3":{"t":"夜来香（简谱）_谱友园地_中国曲谱网","url":"u","via":"title","at":"x"},"qupu123-4":{"t":"难忘的爱人（台语）】彩谱】_谱友园地_中国曲谱网","url":"u","via":"title","at":"x"}}' \
    > "$T/jianpu-db/source_pages.json"
  if JIANPU_DB="$T/jianpu-db" python3 tools/propose_title_cleanup.py > "$T/log" 2>&1; then
    P="$T/jianpu-db/title_bracket_proposal.tsv"
    rows=$(tail -n +2 "$P" | wc -l)
    if [ "$rows" = 3 ] \
       && grep -q '^坏.txt	世界末日（	世界末日	未闭合开括号	1	1' "$P" \
       && grep -q '^散.txt	OVER THE RAINBOW）	OVER THE RAINBOW	多余闭括号	0	0' "$P" \
       && grep -q '^多.txt	难忘的爱人】彩谱】	难忘的爱人彩谱】	多余闭括号(多个)	0' "$P" \
       && ! grep -q '^好.txt' "$P"; then
      echo "  ✓ 佐证才给 accepted=1 / 配对的曲名不进提案 / 多个多余闭括号标 0"
    else
      echo "  ✗ 提案不对(应 3 行: 佐证 1、无佐证 0、多个闭括号 0; 且不含 好.txt)"
      cat "$P"; fail=1
    fi
    # --apply 只许动 accepted=1 的那一条, 且首行 `%<本名>` 要同步
    # (文件名必须与 data.jsonl 的 `file` 一致 —— 第一版夹具写成 世界末日（.txt 而 file 是 坏.txt,
    #  于是 apply 找不到文件、改名 0 首, 自检报假失败)
    mkdir -p "$T/jianpu-db/scores"
    printf '%%坏.txt\ntitle=世界末日（\ntag=x\nsource=qupu123-1\n%%--\n4/4\n1 2 3\n' > "$T/jianpu-db/scores/坏.txt"
    printf '%%散.txt\ntitle=OVER THE RAINBOW）\ntag=x\nsource=qupu123-3\n%%--\n4/4\n1 2 3\n' > "$T/jianpu-db/scores/散.txt"
    JIANPU_DB="$T/jianpu-db" python3 tools/propose_title_cleanup.py --apply > "$T/log2" 2>&1
    if [ -f "$T/jianpu-db/scores/世界末日.txt" ] && grep -qx 'title=世界末日' "$T/jianpu-db/scores/世界末日.txt" \
       && [ "$(head -1 "$T/jianpu-db/scores/世界末日.txt")" = '%世界末日.txt' ] \
       && [ -f "$T/jianpu-db/scores/散.txt" ] && grep -qx 'title=OVER THE RAINBOW）' "$T/jianpu-db/scores/散.txt"; then
      echo "  ✓ --apply 只动 accepted=1, 且首行 %<名> 同步"
    else
      echo "  ✗ --apply 结果不对"; ls "$T/jianpu-db/scores"; fail=1
    fi
  else
    echo "  ✗ 跑失败"; tail -5 "$T/log"; fail=1
  fi
  rm -rf "$T"
fi

# 功能: 曲名尾部悬挂分隔符的清理(隔离副本) —— 2026-09-25 新发现的病灶(`title=可惜没如果 —`)。
# 为什么必须单列: 改名时**漏改首行 `%<本文件名>`** 的话, score.py 的 `i != '%'+文件名` 判为不等,
# 会把那行当**普通注释**收进 comments(实测 40 首中招), 所以这里要连首行一起验。
if [ -f tools/refine_titles_from_pages.py ]; then
  echo
  echo "=== 功能: 悬挂曲名清理 + 首行自述同步(隔离) ==="
  T="$(mktemp -d)"; mkdir -p "$T/jianpu-db/scores"
  printf '{}\n' > "$T/jianpu-db/source_pages.json"
  printf '%%测试_—.txt\ntitle=测试 —\ntag=x\nsource=jianpucn-1\n%%--\n4/4\n1 2 3\n' > "$T/jianpu-db/scores/测试_—.txt"
  if JIANPU_DB="$T/jianpu-db" python3 tools/refine_titles_from_pages.py --strip-dangling --apply > "$T/log" 2>&1; then
    if [ -f "$T/jianpu-db/scores/测试.txt" ] && [ ! -f "$T/jianpu-db/scores/测试_—.txt" ] \
       && grep -qx 'title=测试' "$T/jianpu-db/scores/测试.txt" \
       && [ "$(head -1 "$T/jianpu-db/scores/测试.txt")" = '%测试.txt' ]; then
      echo "  ✓ 去尾巴 + 改名 + 首行 %<名> 同步"
    else
      echo "  ✗ 结果不对"; ls "$T/jianpu-db/scores"; head -3 "$T/jianpu-db/scores/测试.txt" 2>/dev/null; fail=1
    fi
  else
    echo "  ✗ 跑失败"; tail -5 "$T/log"; fail=1
  fi
  # 不该动的别动: 尾部没有分隔符的曲名必须原样留着
  printf '%%正常.txt\ntitle=正常\ntag=x\nsource=jianpucn-2\n%%--\n4/4\n1 2 3\n' > "$T/jianpu-db/scores/正常.txt"
  JIANPU_DB="$T/jianpu-db" python3 tools/refine_titles_from_pages.py --strip-dangling --plan > "$T/log2" 2>&1
  if [ -f "$T/jianpu-db/scores/正常.txt" ] && grep -qx 'title=正常' "$T/jianpu-db/scores/正常.txt"; then
    echo "  ✓ 没有悬挂分隔符的曲名不被误动"
  else
    echo "  ✗ 误动了正常曲名"; fail=1
  fi
  rm -rf "$T"
fi

# 功能: 取页时的"证书过期兜底" —— 2026-09-25 实测 qupu123 证书过期(09-23 到期)被误判成"站点打不开",
# 两天没人发现。自检离线, 只验"证书错误才兜底、超时/404 不兜底"这个分流。
if [ -f tools/tlsfetch.py ]; then
  echo
  echo "=== 功能: 证书过期兜底的分流(tlsfetch) ==="
  if out=$(timeout 60 python3 tools/tlsfetch.py 2>&1) && echo "$out" | grep -q "自检通过"; then
    echo "$out" | sed 's/^/  /'
  else
    echo "  ✗ tlsfetch 自检失败"; echo "$out" | tail -5; fail=1
  fi
fi

# 解析副作用自检(别让"读一份谱"改掉仓库: by_* 污染、tags.json 的 cwd 依赖)
if [ -f tools/check_sideeffects.py ]; then
  echo
  echo "=== 解析副作用自检 ==="
  python3 tools/check_sideeffects.py || fail=1
fi
echo
if [ "${JIANPU_QUICK:-0}" = "1" ]; then
  PARITY_NOTE="(口径一致那步被 JIANPU_QUICK 跳过)"
else
  PARITY_NOTE="+ 两份口径一致"
fi
[ "$fail" = 0 ] && echo "工具链自检 通过(冒烟 --help + 静态未定义名 + 功能写回 + 解析副作用 $PARITY_NOTE)" \
                || echo "工具链自检 失败(见上面 !! 处)"
exit $fail
