//! 简谱旋律匹配的**内层代价循环**（Rust → wasm32-unknown-unknown）。
//!
//! ## 它负责什么 / 不负责什么（这个分界是刻意的）
//!
//! **负责**: 对给定的一首歌，在它的音高串上滑窗，算"这段查询落在这里要花多少代价"，
//! 返回**最小代价**与**取到它的位置**。这是整个检索里最热的一段（11,381 首 × 2.5M 音符）。
//!
//! **不负责**: 并列怎么裁、段落权重怎么算、卡片怎么排 —— 那些是**产品口径**（`static/search.ts`），
//! 留在 TS 里。Rust 这边只做"算代价"这一件事，于是行为完全由同一套规则描述，容易被验证。
//!
//! ## 与 TS 侧逐字对齐的代价表（`static/search.ts` 的 `cost()`）
//!
//! ```text
//! query\lib   自然   #    b
//! 自然         0    1    1     <- 用户没写记号: 宽容
//! #            2    0    3     <- 用户写了记号: 必须对上才 0
//! b            2    3    0
//! ```
//! 音级不同 = 4（最重）。**改这里必须同时改 TS 与 Python 侧** —— 口径只能有一份，
//! 而这份是"第三份实现"，靠 `tools/check_wasm_parity.mjs` 逐例比对锁住。
//!
//! ## 为什么不用 wasm-bindgen
//!
//! 见 `Cargo.toml`：数据只有三个 typed array（音高/变音/每首起点），用 `extern "C"` +
//! 线性内存 + 一个 `alloc` 就能传，省掉 JS glue 与额外工具链，也符合这个项目"零运行时依赖"的调性。
//! 代价是要自己管内存：**谁 alloc 谁负责 free**，这里给一个 `jp_free`。

#![no_std]

use core::alloc::{GlobalAlloc, Layout};
use core::panic::PanicInfo;

// ── 一个极小的 wasm 分配器 ────────────────────────────────────────────────────
// 为什么不用 dlmalloc/wee_alloc: 我们只做"一次性把语料与查询塞进来"，分配次数是个位数，
// 一个 bump allocator 就够（代码小、无依赖）。**不能 free 单块**（`jp_free` 是空操作），
// 语义上等价于"arena 生命周期 = 页面生命周期" —— 前端就是这么用的（索引建一次用到底）。
struct Bump;

static mut BUMP: usize = 0;   // 0 = 还没开始分配（第一次分配时从 __heap_base 起算）

unsafe impl GlobalAlloc for Bump {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let align = layout.align().max(8);
        let mut p = if BUMP == 0 { heap_base() } else { BUMP };
        p = (p + align - 1) & !(align - 1);
        let need = p + layout.size();
        // ⚠ 真实语料是 2.5M 音符（音高 2.5 MB + 变音 2.5 MB + 偏移 46 KB），**远超** wasm 的初始
        //   线性内存（1 MiB 左右）。第一版只做了"超界返回 null" -> 前端会直接退回 TS 实现，
        //   而我自己的对拍脚本会看到"每首都是 null"，很难一眼看出是内存没长。
        //   这里自己 grow: 不够就按需扩页（64 KiB 一页），扩不动才返回 null。
        if need > wasm_memory_end() {
            let deficit = need - wasm_memory_end();
            let pages = (deficit + 65535) / 65536;
            if core::arch::wasm32::memory_grow(0, pages) == usize::MAX {
                return core::ptr::null_mut();
            }
        }
        BUMP = need;
        p as *mut u8
    }

    unsafe fn dealloc(&self, _ptr: *mut u8, _layout: Layout) {
        // bump: 不回收（见上）
    }
}

extern "C" {
    // ⚠ 这里踩过两次，写下来免得再犯:
    //   ① 第一版写成 `fn __heap_base() -> usize`（当函数）—— wasm 校验直接报
    //      `not enough arguments on the stack for call (need 4, got 1)`，**实例化都过不去**；
    //   ② 删掉它之后忘了给起点，于是 bump 从地址 0 开始分配 —— 读写落在 wasm 的静态区里，
    //      冒烟测试表现成"每首歌代价都是 12（=3×4，全不匹配）"。
    //   正确做法: `__heap_base` 是链接器提供的**地址符号**，用 `static` 声明 + **取地址**。
    static __heap_base: u8;
}

fn heap_base() -> usize {
    unsafe { &__heap_base as *const u8 as usize }
}

fn wasm_memory_end() -> usize {
    // 线性内存上界（字节）。bump allocator 只用它做溢出检查。
    (core::arch::wasm32::memory_size(0) as usize) * 65536
}

#[global_allocator]
static ALLOC: Bump = Bump;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    // wasm 里 panic 无法 unwind（Cargo.toml 里设了 panic=abort）；直接 trap，
    // 前端在 try/catch 里会看到 RuntimeError 并退回 TS 实现。
    core::arch::wasm32::unreachable()
}

// ── 语料（由 JS 填好指针后调用 jp_set_corpus）──────────────────────────────────
static mut P_PTR: *const u8 = core::ptr::null();      // 全部曲目的音高数字（'1'..'7' 的 ASCII = 49..55）
static mut A_PTR: *const i8 = core::ptr::null();      // 变音：1=#, -1=b, 0=自然
static mut OFF_PTR: *const u32 = core::ptr::null();   // 每首起点（长度 = 曲数+1）
static mut N_SONGS: usize = 0;

/// JS 调用：把三块数据的指针交给 Rust（指针来自 `jp_alloc` 后由 JS 写入）。
#[no_mangle]
pub unsafe extern "C" fn jp_set_corpus(p: *const u8, a: *const i8, off: *const u32, n: usize) {
    P_PTR = p;
    A_PTR = a;
    OFF_PTR = off;
    N_SONGS = n;
}

/// JS 调用：分配 `len` 字节，返回指针（0 = 分配失败）。
#[no_mangle]
pub extern "C" fn jp_alloc(len: usize) -> *mut u8 {
    unsafe {
        let layout = Layout::from_size_align_unchecked(len, 8);
        ALLOC.alloc(layout)
    }
}

/// 语义上的释放（bump allocator 不回收，保留接口以免调用方误以为泄漏）。
#[no_mangle]
pub extern "C" fn jp_free(_ptr: *mut u8, _len: usize) {}

/// 与 `static/search.ts` 的 `cost()` **逐字对齐**（见文件头表格）。
#[inline(always)]
fn cost(qd: u8, qacc: i8, cd: u8, cacc: i8) -> u32 {
    if qd != cd {
        return 4;
    }
    if qacc == cacc {
        return 0;
    }
    if qacc == 0 {
        return 1;
    }
    if cacc == 0 {
        return 2;
    }
    3
}

/// 在**第 `song` 首**上给查询 `q` 找最小代价窗口。
///
/// 返回 `(cost << 32) | at`（打包成一个 u64 方便过边界）；找不到（该曲比查询短）返回 `u64::MAX`。
/// **只返回位置最小的那个最小代价窗口** —— 段落权重导致的"同代价取哪个窗口"由 JS 在
/// 最终候选上再算一遍（保持产品口径在 TS 里，见文件头）。
#[inline]
unsafe fn best_in_song(song: usize, qd: *const u8, qacc: *const i8, qn: usize) -> u64 {
    let start = *OFF_PTR.add(song) as usize;
    let end = *OFF_PTR.add(song + 1) as usize;
    let len = end - start;
    if len < qn {
        return u64::MAX;
    }
    let p = P_PTR.add(start);
    let a = A_PTR.add(start);
    let mut best = u32::MAX;
    let mut best_at = 0u32;
    let mut i = 0usize;
    while i + qn <= len {
        let mut c = 0u32;
        let mut k = 0usize;
        while k < qn {
            c += cost(*qd.add(k), *qacc.add(k), *p.add(i + k), *a.add(i + k));
            // 与 TS 一致：**严格大于**才早退（同分窗口要看段落权重，不能被 >= 砍掉）
            if best != u32::MAX && c > best {
                break;
            }
            k += 1;
        }
        if c < best {
            best = c;
            best_at = i as u32;
        }
        i += 1;
    }
    if best == u32::MAX {
        u64::MAX
    } else {
        ((best as u64) << 32) | best_at as u64
    }
}

/// 单首查询（调试/小批量用）：JS 传歌曲下标。
#[no_mangle]
pub unsafe extern "C" fn jp_best_in_song(
    song: usize,
    qd: *const u8,
    qacc: *const i8,
    qn: usize,
) -> u64 {
    best_in_song(song, qd, qacc, qn)
}

/// 全库扫描：对每首歌算最小代价，**每首一个槽位**写进 `out`（2 个 u32: cost, at）。
///
/// 为什么是"每首一个槽位"而不是"压缩输出": 前端要按**歌曲下标**把结果对回去（算总代价、
/// 并列裁决、段落权重都在 TS 里）。第一版写成压缩输出（只写有命中的），结果我自己的冒烟测试
/// 都没法把结果和歌曲对上 —— 那是个"看着省内存、实际让人写错"的接口。
/// 没命中（该曲比查询短）就写 `cost = u32::MAX`。
///
/// 返回写入的槽数（= 曲数）。**排序/并列裁决不在这里**（留在 TS，见文件头）。
#[no_mangle]
pub unsafe extern "C" fn jp_scan_all(
    qd: *const u8,
    qacc: *const i8,
    qn: usize,
    out: *mut u32,
) -> usize {
    let mut s = 0usize;
    while s < N_SONGS {
        let r = best_in_song(s, qd, qacc, qn);
        if r == u64::MAX {
            *out.add(s * 2) = u32::MAX;
            *out.add(s * 2 + 1) = 0;
        } else {
            *out.add(s * 2) = (r >> 32) as u32;
            *out.add(s * 2 + 1) = (r & 0xffff_ffff) as u32;
        }
        s += 1;
    }
    N_SONGS
}

/// 版本串（给自检打印，确认加载的是哪一版 wasm）。
static VERSION: &[u8] = b"jianpu-matcher 0.1.0";

#[no_mangle]
pub extern "C" fn jp_version() -> *const u8 {
    VERSION.as_ptr()
}

#[no_mangle]
pub extern "C" fn jp_version_len() -> usize {
    VERSION.len()
}
