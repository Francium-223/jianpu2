// node tools/_wasm_smoke.mjs <path-to.wasm>
// 冒烟测试: 加载 wasm、塞一个**手算得出期望**的小语料、逐项核对代价表与滑窗。
//
// ⚠ 第一版这个测试自己写错了期望值（曲 0 是 `1 2 3 4 5`，根本不含查询 `5 6 5`，
//   正确答案就是全不匹配的 12；我却写了 0）。**先怀疑测试、再怀疑被测物** ——
//   正式的全库对拍是 tools/check_wasm_parity.mjs，这个只管"能不能用、算得对不对"。
import { readFileSync } from 'node:fs';

const path = process.argv[2]
  || 'D:/Documents_D/jianpu2/wasm-matcher/target/wasm32-unknown-unknown/release/jianpu_matcher.wasm';
const bytes = readFileSync(path);
const { instance } = await WebAssembly.instantiate(bytes, {});
const ex = instance.exports;

const dec = new TextDecoder();
console.log(`wasm: ${dec.decode(new Uint8Array(ex.memory.buffer, ex.jp_version(), ex.jp_version_len()))}`
            + ` · 文件 ${(bytes.length / 1024).toFixed(1)} KB`);

/** 把一个"音符序列的数组"塞进 wasm，返回 { pPtr, aPtr, oPtr, n } */
function setCorpus(notes) {
  const flat = [], acc = [], off = [0];
  for (const s of notes) {
    for (const [d, a] of s) { flat.push(48 + d); acc.push(a); }
    off.push(flat.length);
  }
  const pPtr = ex.jp_alloc(flat.length);
  const aPtr = ex.jp_alloc(acc.length || 1);
  const oPtr = ex.jp_alloc(off.length * 4);
  new Uint8Array(ex.memory.buffer, pPtr, flat.length).set(flat);
  new Int8Array(ex.memory.buffer, aPtr, acc.length || 1).set(acc.length ? acc : [0]);
  new Uint32Array(ex.memory.buffer, oPtr, off.length).set(off);
  ex.jp_set_corpus(pPtr, aPtr, oPtr, notes.length);
  return { n: notes.length };
}

/** 跑一次扫描，返回每首的 [cost, at]（没命中 = null） */
function scan(query) {
  const qd = Uint8Array.from(query.map((x) => 48 + x[0]));
  const qa = Int8Array.from(query.map((x) => x[1]));
  const qPtr = ex.jp_alloc(qd.length);
  const qaPtr = ex.jp_alloc(qa.length);
  new Uint8Array(ex.memory.buffer, qPtr, qd.length).set(qd);
  new Int8Array(ex.memory.buffer, qaPtr, qa.length).set(qa);
  const outPtr = ex.jp_alloc(1024 * 8);
  const n = ex.jp_scan_all(qPtr, qaPtr, qd.length, outPtr);
  const raw = new Uint32Array(ex.memory.buffer, outPtr, n * 2);
  const res = [];
  for (let i = 0; i < n; i++) {
    res.push(raw[i * 2] === 0xffffffff ? null : [raw[i * 2], raw[i * 2 + 1]]);
  }
  return res;
}

let bad = 0;
function check(label, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) bad++;
  console.log(`  ${ok ? '✓' : '✗'} ${label}: 得 ${JSON.stringify(got)} 期望 ${JSON.stringify(want)}`);
}

// ── 语料（每首是 [音级, 变音] 的数组）─────────────────────────────────────────
const N = (d) => [d, 0];
setCorpus([
  [N(1), N(2), N(3), N(4), N(5)],                 // 0: 1 2 3 4 5
  [N(5), N(5), N(6), N(5), N(3), N(2), N(1)],     // 1: 5 5 6 5 3 2 1
  [N(7), N(7), N(7)],                             // 2: 7 7 7（比下面的查询短）
]);

// ── 手算过程写在注释里（我在这里错过两次：凭感觉写期望值，结果两次都是 wasm 对、我错）──
// 查询 `1 2 3`:
//   曲0 `1 2 3 4 5`   : 窗口@0 = (1,2,3) 全对 -> cost 0 @0
//   曲1 `5 5 6 5 3 2 1`: 逐窗看，最后一个窗 (3,2,1) vs (1,2,3) = 4+0+4 = 8 @2（最小）
//   曲2 `7 7 7`       : 与查询**等长**(3)，不是"太短"，逐窗只有 (7,7,7) -> 12 @0
console.log('\n① 精确命中 / 模糊命中 / 等长全不匹配');
check('查询 1 2 3', scan([N(1), N(2), N(3)]), [[0, 0], [8, 2], [12, 0]]);
// 查询 `5 6 5`:
//   曲0: 最小窗是 (3,4,5) vs (5,6,5) = 4+4+0 = 8 @2
//   曲1: 窗口@1 = (5,6,5) 全对 -> 0 @1
//   曲2: 12 @0
console.log('\n② "发送从严、接收从宽"的代价表');
check('查询 5 6 5（曲1 里有 5 6 5）', scan([N(5), N(6), N(5)]), [[8, 2], [0, 1], [12, 0]]);
// 再加一首**真比查询短**的，验证"太短 -> null"
check('查询 1 2 3 4 5（曲2 只有 3 个音 -> null）', (() => {
  setCorpus([[N(7), N(7), N(7)], [N(1), N(2), N(3), N(4), N(5)]]);
  return scan([N(1), N(2), N(3), N(4), N(5)]);
})(), [null, [0, 0]]);
check('查询 5 6 #5（库是自然 5 -> 2；库是 #5 -> 0）', (() => {
  setCorpus([
    [N(5), N(6), N(5)],           // 0: 自然
    [N(5), N(6), [5, 1]],         // 1: 升号
  ]);
  return scan([N(5), N(6), [5, 1]]);
})(), [[2, 0], [0, 0]]);
check('查询 5（不带记号）能匹配到库里的 #5', (() => {
  setCorpus([[N(5), N(6), [5, 1]]]);
  return scan([N(5), N(6), N(5)]);
})(), [[1, 0]]);

console.log(bad === 0 ? '\n冒烟测试通过：wasm 装载 + 代价表 + 滑窗 + 短曲跳过 都对' : `\n冒烟测试失败 ${bad} 项`);
process.exit(bad ? 1 : 0);
