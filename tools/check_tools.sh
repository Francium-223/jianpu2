#!/usr/bin/env bash
# 命令行工具的冒烟自检: 每个 tools/*.py 都得能 import 并打出 --help。
# 为什么需要它: 工具都 import jianpu-db/score.py 或 linkurl.py, 那两份是"唯一实现";
# 改了它们(比如把 jptok 变成硬依赖)很容易把整个工具链 import 崩, 而平时没人跑。
#
#     bash tools/check_tools.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."
fail=0
TOOLS="add_link propose_tags harvest_artists refine_titles_from_pages audit_corpus_quality
       quarantine_short_scores audit_arrangements verify_source_urls corpus_fingerprint
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
echo
[ "$fail" = 0 ] && echo "工具链冒烟自检 通过" || echo "工具链冒烟自检 失败"
exit $fail
