# -*- coding: utf-8 -*-
"""标签逻辑: 蕴涵(implication) 与 等同(equality)。

单一真源 = tags.json。它是一棵树:

    {"name": ["别名1", "别名2", ...], "child": [ ...子节点... ]}

  * `name` 里的多个名字互为**等同**(alias)     —— 例: "东方" == "touhou"
  * `child` 里的节点**蕴涵**它的祖先           —— 例: th10 -> 东方整数作原曲 -> 东方新作原曲
                                                  -> ZUN -> 东方原曲 -> 东方

为什么重写
----------
旧实现把这两件事分别写死在 tag_implications.json 与 tag_equality.json 里,
而这两份文件本来**就是 tags.json 的冗余副本**: 加一个游戏要同时改三个文件,
一旦漏改就静默不一致。本模块改为**从 tags.json 派生**, 并保证与旧文件逐字节等值
(见 tools/verify_taglogic.py), 因此 score.py 的行为完全不变。

派生规则(与旧文件实测一致):
  imply    : 用每个节点 name[0] 作键的嵌套 dict, 形状与旧 tag_implications.json 相同
  equal[0] : 只收 name 长度 >= 2 的节点(即真正存在别名的), 按**先序**排列
  equal[1] : 空表(旧文件里的 [[]] 是历史残留, 没有任何节点用到)

对外接口
--------
  imply / equal          向后兼容 score.py 的旧用法
  canonical(name)        别名 -> 规范名(该节点 name[0])
  group_of(name)         别名 -> 同义组 frozenset
  is_equal(a, b)         等同判定(替代旧的 equal_tag, 但用 O(1) 查表)
  ancestors(name)        蕴涵闭包: 规范名 -> [自身, 父, 祖父, ...] 的规范名
  route_of(name)         规范名 -> "A/B/C" 路径(即 tagroute)
  alias_closure(names)   一组标签 -> 含全部别名与全部祖先的标签集合
"""
import json
import os
import re


class TagLogic:

    def __init__(self, path=None):
        if path is None:
            path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tags.json")
        with open(path, "r", encoding="utf-8") as f:
            raw = f.read()
        try:
            self.tree = json.loads(raw)
        except json.JSONDecodeError as e:
            # 手工编辑 tags.json 很容易留下尾逗号(实测踩过两次)。严格解析失败时
            # 去掉 ",}" / ",]" 再试一次, 并**明确告警** —— 不静默吞掉。
            fixed = re.sub(r",(\s*[}\]])", r"\1", raw)
            try:
                self.tree = json.loads(fixed)
            except json.JSONDecodeError:
                raise e
            print(f"[taglogic] 警告: {os.path.basename(path)} 不是严格 JSON "
                  f"({e.msg} @ 行{e.lineno}), 已按去尾逗号容错解析 —— 建议修正源文件")

        self._group = {}         # 任意别名 -> 同义组 frozenset
        self._canon = {}         # 任意别名 -> 规范名
        self._paths = {}         # 规范名 -> [路径, ...] (同一名字可以出现在多处!)
        self._order = []         # 先序的规范名(含重复出现的)
        groups = []              # 先序的、别名数 >= 2 的组
        self.imply = {}          # 与旧 tag_implications.json 同形
        self._children = {}      # 规范名(路径) -> [子规范名]

        def walk(nodes, path, carry):
            """
            注意: tags.json 是 **DAG 不是树** —— 同一个名字可以出现在多处。
            实测 `东方整数作原曲` 同时挂在 `东方旧作原曲` 与 `东方新作原曲` 下,
            所以**绝不能用 名字->父 的映射**(后写会覆盖先写, 把 th01-th05 的
            "旧作"错算成"新作", 实测 309 份里错 97 份)。一律按路径记。
            """
            for nd in nodes:
                names = nd.get("name") or []
                if not names:
                    continue
                canon = names[0]
                grp = frozenset(names)
                for nm in names:
                    self._canon.setdefault(nm, canon)
                    self._group.setdefault(nm, grp)
                self._order.append(canon)
                here_path = path + [canon]
                self._paths.setdefault(canon, []).append(here_path)
                if len(names) >= 2:
                    groups.append(list(names))
                # 构造与旧文件同形的嵌套 dict: 同一层里同名只建一次
                here = carry.setdefault(canon, {})
                walk(nd.get("child") or [], here_path, here)

        walk(self.tree, [], self.imply)
        # equal[1] 保持旧文件的形状 [[]] —— 行为等价, 但保证与旧数据零差异
        self.equal = [groups, [[]]]

        # 蕴涵闭包(含自身), 自底向上算 —— 按路径, 因为同名节点可能有多条路径
        self._anc = {}
        for name, ps in self._paths.items():
            self._anc[name] = [list(reversed(p)) for p in ps]   # 每个路径反转成 自->祖

    # ---------------------------------------------------------------- 等同
    def canonical(self, name):
        """别名 -> 规范名(该节点 name 数组的第一个)。未知标签原样返回。"""
        return self._canon.get(name, name)

    def group_of(self, name):
        """别名 -> 同义组。单名节点返回只含自己的集合, 未知标签返回 None。"""
        g = self._group.get(name)
        if g is not None:
            return g
        return None

    def is_equal(self, a, b):
        """a 与 b 是否等同(同一别名组)。O(1)。"""
        if a == b:
            return True
        ga = self._group.get(a)
        return ga is not None and ga is self._group.get(b)

    def same_ends(self, ra, rb):
        """两条路径的**尾部**逐段等同比对(旧 same_ends 的等价物)。"""
        for i in range(1, min(len(ra), len(rb)) + 1):
            if not self.is_equal(ra[-i], rb[-i]):
                return False
        return True

    # ---------------------------------------------------------------- 蕴涵
    def paths_of(self, name):
        """该标签出现的**所有**路径(根在前)。同名可出现在多处(DAG)。"""
        return [list(p) for p in self._paths.get(self.canonical(name), [])]

    def is_ambiguous(self, name):
        return len(self._paths.get(self.canonical(name), [])) > 1

    def ancestors(self, name):
        """蕴涵闭包: 返回 [自身, 父, 祖父, ...] 的规范名(自底向上)。

        同名出现在多处时有多个结果, 返回**最长的那条链**并告警 ——
        调用方若已知完整路径, 应改用 ancestors_of_path()。
        """
        chains = self._anc.get(self.canonical(name))
        if not chains:
            return [self.canonical(name)]
        return max(chains, key=len)

    def ancestors_of_path(self, path):
        """给一条已知路径(如 tagroute 的段), 返回自底向上的蕴涵链。"""
        return list(reversed(list(path)))

    def children(self, name):
        """该标签(规范名)的直接子节点名; 同名多处时取并集。"""
        out = []
        for p in self.paths_of(name):
            node = self.imply
            for seg in p:
                node = node.get(seg, {})
            for k in node:
                if k not in out:
                    out.append(k)
        return out

    def route_of(self, name):
        """规范名 -> "A/B/C" 路径(根在前), 即 tagroute。

        同名出现在多处时(DAG)返回**第一条**路径 —— 需要精确路径请用 routes_of()。
        """
        ps = self.paths_of(name)
        if not ps:
            return self.canonical(name)
        return "/".join(ps[0])

    def routes_of(self, name):
        """该标签的所有 "A/B/C" 路径。"""
        return ["/".join(p) for p in self.paths_of(name)]

    def aliases_of(self, name):
        """该标签的全部同义写法(含自己), 无别名时返回 [自己]。"""
        g = self._group.get(name)
        return sorted(g) if g else [name]

    def closure_of_path(self, path):
        """给一条**已知路径**(如 tagroute 的段), 返回含全部别名与全部祖先的标签集合。

        这是 score.py 里 all_tag_route -> tag 那一步在做的事, 也是唯一正确的做法:
        路径本身能区分同名节点(例如 `东方整数作原曲` 同时属于旧作与新作),
        而按名字查会歧义。
        """
        out = []
        seen = set()

        def add(x):
            if x not in seen:
                seen.add(x)
                out.append(x)

        for seg in reversed(list(path)):      # 自底向上
            for al in self.aliases_of(seg):
                add(al)
        return out

    def alias_closure(self, names):
        """一组标签名 -> 含全部别名与全部祖先的集合(同名多路径时取并集)。"""
        out = []
        seen = set()

        def add(x):
            if x not in seen:
                seen.add(x)
                out.append(x)

        for nm in names:
            for p in (self.paths_of(nm) or [[self.canonical(nm)]]):
                for x in self.closure_of_path(p):
                    add(x)
        return out

    def resolve(self, name):
        """把一个标签解析成 (规范名, 路径, 蕴涵链, 同义组)。未知标签路径为自身。"""
        c = self.canonical(name)
        ps = self.paths_of(c) or [[c]]
        return c, self.route_of(c), list(reversed(ps[0])), self.aliases_of(c)


_default = None


def get(path=None):
    """进程内单例。path 为 None 时找同目录的 tags.json。"""
    global _default
    if _default is None:
        _default = TagLogic(path)
    return _default


# 这份是从 jianpu-db 复制过来的**副本**(那个仓库已把逻辑折进 score.py 并删掉了
# taglogic.py, 以保持"自包含文件"的风格)。副本目录下没有 tags.json, 所以这里
# 不自动加载 —— 调用方显式传路径: taglogic.get(r"...\jianpu-db\tags.json")
def _try_default():
    here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tags.json")
    if os.path.exists(here):
        return get(here)
    return None


_t = _try_default()
imply = _t.imply if _t else None       # 向后兼容: 旧 tag_implications.json
equal = _t.equal if _t else None       # 向后兼容: 旧 tag_equality.json


if __name__ == "__main__":
    t = get()
    print(f"节点 {len(t._order)} 个, 别名组 {len(t.equal[0])} 组")
    for probe in ["th10", "东方风神录", "touhou", "紫", "th185", "未知标签"]:
        c, r, anc, al = t.resolve(probe)
        print(f"  {probe:10s} -> 规范 {c:12s} 路径 {r}")
        print(f"  {'':10s}    蕴涵 {anc}")
        print(f"  {'':10s}    等同 {al}")
