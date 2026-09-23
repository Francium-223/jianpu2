# -*- coding: utf-8 -*-
"""对 jianpu-db/score.py 做一次**内容定位**的重构手术(不靠行号, 便于复核)。

1) 删掉已迁到 schema.py 的 load_tag_rules 块
2) 删掉 Score 上已迁走的 5 个方法(find_tag/find_nottag/where_imply/where_not_imply/getusertag)
3) 把 read() + process_others() 换成"两阶段 + 依赖序"的新实现
4) parse() 里的 process_others() -> derive_others()
"""
import io
import os
import sys

REPO = r"D:\Documents_D\jianpu-db"
P = os.path.join(REPO, "score.py")
sys.stdout.reconfigure(encoding="utf-8")
s = io.open(P, encoding="utf-8").read()
orig = s


def cut(s, start_marker, end_marker, repl=""):
    i = s.index(start_marker)
    j = s.index(end_marker, i)
    return s[:i] + repl + s[j:]


# 1) load_tag_rules 块(从 def 到别名注释之前)
s = cut(s, "def load_tag_rules(path='tags.json'):", "# 标签图的机械", "")

# 2) 五个方法
s = cut(s, "\tdef find_tag(self, n):", "\tdef prioritize_title_and_tag(self):")
s = cut(s, "\tdef getusertag(self, a):", "\tdef to_record(self):")

NEW_READ = '''	def read(self):
		try:
			with open(self.score, 'r', encoding='utf-8') as f:
				self.raw = f.readlines()
				self.raw2 = f.read()
			# 阶段 1: 只收集**原文**(字段名 -> 按出现顺序的原文列表), 不在这里解析。
			#   为什么分两阶段: 属性的生成有依赖(tag/tagroute 要吃 usertag 的**聚合结果**),
			#   边读边算会让"多行 usertag"在中途被重算; 谁先谁后交给 schema.order()。
			raws = {}
			for i in get_meta_lines(self.raw):
				i = i.rstrip('\\n')
				if i.replace(' ', '').startswith('%--') or i.replace(' ', '').startswith('tag=') or i.replace(' ', '').startswith('tagroute='):
					continue
				if i.replace(' ', '').lower().startswith('file='):
					# file 由文件名派生(write_buf 里写进 JSON), 不是源字段 ——
					# 曲谱文件里若残留这一行(历史误写)要忽略, 否则会被读回来又写回去。
					continue
				if '=' in i:
					k, raw = i.split('=', 1)
					raws.setdefault(k.strip(' '), []).append(raw.strip(' '))
					continue
				if i == '%' + self.score.split('/')[-1]:
					continue
				if i.startswith('%'):
					self.comments.append(i.rstrip('\\n'))
					continue
				# 裸行 = 旧格式的 usertag(没有 `=`); 实测 0 命中, 保留兼容。
				raws.setdefault('usertag', []).append(i.strip())
			# 阶段 2a: 一阶字段(deps 为空)按**文件出现顺序**逐条原文解析后累加
			#   —— list 字段去重保序、str 字段后者覆盖前者(与搬迁前一致)。
			#   叶子之间没有依赖, 文件顺序本身就是一个合法的拓扑序; 保持它还让
			#   data.json 的键顺序与搬迁前逐字节一致。
			for i in raws:
				_attr = schema.schema.get(i)
				if _attr is not None and _attr.deps:
					continue                      # 衍生字段留到 2b
				_fn = _attr.fn if _attr is not None else schema.default_parse
				for raw in raws[i]:
					v = _fn(raw)
					if isinstance(v, list) and isinstance(self.others.get(i), list):
						# 多值字段: 同一个字段可以写多行, 累加去重
						self.others[i] = safe_add(self.others[i], v)
					else:
						self.others[i] = v
			# 阶段 2b: 衍生字段按**依赖拓扑序**执行(每个吃 Score 对象, 整份谱只跑一次)
			for i in schema.order():
				_attr = schema.schema[i]
				if _attr.deps:
					self.others[i] = _attr.fn(self)
			# title 现在也由 schema 解析进 others(字符串) -> 同步到 self.title(文件命名要用)
			if isinstance(self.others.get('title'), str):
				self.title = self.others['title']
		except NotTitleError:
			print(f'Error: no title!')
			print(f'Try adding \\'title=(your preferred title)\\' to {self.score}.')
			raise
		except FileNotFoundError:
			print(f'Error: file \\'{self.score}\\' not found!')
			raise NoScoreError
	def derive_others(self):
		"""衍生字段(tag/tagroute)已在 read() 里按 schema.order() 生成完毕。

		这里保留一个显式收尾点: 只做**依赖表自检** —— 成环会让 schema.order() 自己 Warning
		(CI 里可以用 schema.order(strict=True) 把它升级成错误)。
		"""
		schema.order()
'''

# 3) read()+process_others -> 新 read()+derive_others
s = cut(s, "\tdef read(self):", "\tdef write_buf(self):", NEW_READ)
# 4) parse() 调用点
s = s.replace("\t\t\t\t\tself.process_others()\n", "\t\t\t\t\tself.derive_others()\n")

if s == orig:
    sys.exit("没有任何改动 —— 标记没匹配上, 请检查")
io.open(P, "w", encoding="utf-8").write(s)
print("手术完成: score.py", len(orig), "->", len(s), "字节")
