import { readFileSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';
import { buildIndex, search } from '../static/search.js';
import { parseQuery, show } from '../static/jptok.js';
const gz = readFileSync(new URL('../data/songs.jsonl.gz', import.meta.url));
const idx = buildIndex(gunzipSync(gz).toString('utf8'));
console.log('索引', idx.count, '首');
for (const [q, note] of [['22264531657', '不带升号'], ['22264#531657', '带升号']]) {
  const segs = [parseQuery(q)].filter((s) => s.length >= 5);
  const res = search(idx, segs, { top: 3 });
  console.log(`=== ${q}  (${note})  解析 ${show(segs[0])}`);
  for (const r of res.slice(0, 3)) {
    console.log(`   group="${r.group}" title="${r.title}" 代价 ${r.cost} 记号 ${r.exact}/${r.n} 位置 ${r.at}`);
  }
}