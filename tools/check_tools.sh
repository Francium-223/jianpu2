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
       make_score mbz_lookup transcribe batch_pipeline"
for t in $TOOLS; do
  [ -f "tools/$t.py" ] || continue
  printf '%-28s ' "$t"
  if out=$(timeout 120 python3 "tools/$t.py" --help 2>&1); then
    echo "OK"
  else
    echo "!! 失败"; echo "$out" | tail -3 | sed 's/^/      /'; fail=1
  fi
done
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
