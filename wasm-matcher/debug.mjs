// 调试: 指针、内存回读、单个函数调用（定位"Rust 读到空数据"的原因）
import { readFileSync } from 'node:fs';
const path = process.argv[2];
const bytes = readFileSync(path);
const { instance } = await WebAssembly.instantiate(bytes, {});
const ex = instance.exports;
console.log('  memory 初始字节:', ex.memory.buffer.byteLength);

const p = [49, 50, 51, 52, 53];      // "1 2 3 4 5"
const pPtr = ex.jp_alloc(p.length);
console.log('  jp_alloc(5) ->', pPtr, '· 之后 memory 字节:', ex.memory.buffer.byteLength);
new Uint8Array(ex.memory.buffer, pPtr, p.length).set(p);
console.log('  回读语料:', Array.from(new Uint8Array(ex.memory.buffer, pPtr, 5)));

const a = [0, 0, 0, 0, 0];
const aPtr = ex.jp_alloc(a.length);
new Int8Array(ex.memory.buffer, aPtr, a.length).set(a);
const off = [0, 5];
const oPtr = ex.jp_alloc(8);
new Uint32Array(ex.memory.buffer, oPtr, 2).set(off);
console.log('  aPtr/oPtr:', aPtr, oPtr, '· 回读 off:', Array.from(new Uint32Array(ex.memory.buffer, oPtr, 2)));
console.log('  回读语料(再查一次, 确认没被后来的分配覆盖):', Array.from(new Uint8Array(ex.memory.buffer, pPtr, 5)));

ex.jp_set_corpus(pPtr, aPtr, oPtr, 1);

const q = [49, 50, 51];
const qPtr = ex.jp_alloc(3), qaPtr = ex.jp_alloc(3);
new Uint8Array(ex.memory.buffer, qPtr, 3).set(q);
new Int8Array(ex.memory.buffer, qaPtr, 3).set([0, 0, 0]);
const outPtr = ex.jp_alloc(8);
console.log('  qPtr/qaPtr/outPtr:', qPtr, qaPtr, outPtr);
console.log('  回读查询:', Array.from(new Uint8Array(ex.memory.buffer, qPtr, 3)));

const one = ex.jp_best_in_song(0, qPtr, qaPtr, 3);
console.log('  jp_best_in_song(0) ->', one, '(期望 0；u64::MAX 表示"找不到")');
const n = ex.jp_scan_all(qPtr, qaPtr, 3, outPtr);
console.log('  jp_scan_all ->', n, '结果:', Array.from(new Uint32Array(ex.memory.buffer, outPtr, 4)));
