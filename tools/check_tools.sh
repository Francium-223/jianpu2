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
       make_score mbz_lookup transcribe batch_pipeline melody_search
       crawl_jianpujia crawl_jianpucn crawl_qupu123 crawl_batch_jianpujia
       queue_from_crawl batch_transcribe_queue fix_residual_titles"
for t in $TOOLS; do
  [ -f "tools/$t.py" ] || continue
  printf '%-28s ' "$t"
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
