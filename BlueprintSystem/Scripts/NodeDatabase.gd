# NodeDatabase.gd
class_name NodeDatabase
extends RefCounted

# ============================================================================
# 颜色常量（统一管理，方便调整主题色）
# ============================================================================

# ---- 大类颜色（对应右键菜单最外层） ----
const COLOR_SPECIAL = Color(0.85, 0.85, 0.85)         # 特殊节点（开始/结束）
const COLOR_EVENT = Color(0.694, 0.753, 1)            # 添加事件
const COLOR_CONTROL = Color(1, 0.886, 0.663)          # 添加控制
const COLOR_MATH = Color(0.424, 0.855, 0.855)         # 添加计算
const COLOR_OBJECT = Color(0.859, 0.741, 0.741)       # 添加对象
const COLOR_DETECT = Color(0.549, 0.741, 0.933)       # 添加检测
const COLOR_VARIABLE = Color(0.867, 0.706, 0.506)     # 添加变量
const COLOR_CUSTOM_FUNC = Color(0.875, 0.522, 0.522)  # 自定义函数

# ---- 计算子类（继承自 COLOR_MATH） ----
const COLOR_ARITHMETIC = COLOR_MATH
const COLOR_POWER = COLOR_MATH
const COLOR_TRANSCENDENTAL = COLOR_MATH
const COLOR_COMBINATORICS = COLOR_MATH
const COLOR_COMPARE = COLOR_MATH
const COLOR_LOGIC = COLOR_MATH
const COLOR_VECTOR = COLOR_MATH

# ---- 对象子类（继承自 COLOR_OBJECT） ----
const COLOR_OBJECT_ITEM = COLOR_OBJECT
const COLOR_OBJECT_ITEM_ACTION = COLOR_OBJECT

# ---- 检测子类（继承自 COLOR_DETECT） ----
const COLOR_DETECT_COLLISION = COLOR_DETECT
const COLOR_DETECT_INPUT = COLOR_DETECT
const COLOR_DETECT_ENVIRONMENT = COLOR_DETECT
const COLOR_DETECT_STATE = COLOR_DETECT
const COLOR_DETECT_PROPERTY = COLOR_DETECT

# ---- 变量子类（继承自 COLOR_VARIABLE） ----
const COLOR_TYPE_BOOL = COLOR_VARIABLE
const COLOR_TYPE_INT = COLOR_VARIABLE
const COLOR_TYPE_FLOAT = COLOR_VARIABLE
const COLOR_TYPE_STRING = COLOR_VARIABLE
const COLOR_TYPE_VECTOR2 = COLOR_VARIABLE
const COLOR_TYPE_VECTOR3 = COLOR_VARIABLE
const COLOR_TYPE_VECTOR4 = COLOR_VARIABLE
const COLOR_TYPE_ARRAY = COLOR_VARIABLE
const COLOR_TYPE_DICTIONARY = COLOR_VARIABLE

# ---- 数据操作子类（继承自 COLOR_VARIABLE 或独立） ----
const COLOR_DATA_OPERATION = Color(0.788, 0.933, 0.569)    # 数据操作

# ---- 类型转换子类 ----
const COLOR_TYPE_CAST = Color(0.933, 0.565, 0.933)         # 类型转换


static var node_types: Dictionary = {
	# ===== 特殊节点（不可删除） =====
	"start": {
		"name": "开始",
		"color": COLOR_SPECIAL,
		"category": "事件",
		"inputs": [],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {},
		"exec_func": "start",
		"deletable": false
	},
	
	# ===== 事件 =====
	"event_signal": {
		"name": "发射信号",
		"color": COLOR_EVENT,
		"category": "事件",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {"名称": {"type": "String", "default": "signal"}},
		"exec_func": "emit_signal",
		"deletable": true
	},
	"event_receive": {
		"name": "接受信号",
		"color": COLOR_EVENT,
		"category": "事件",
		"inputs": [],
		"outputs": [{"name": "输出", "type": "bool"}],
		"properties": {"名称": {"type": "String", "default": "signal"}},
		"exec_func": "receive_signal",
		"deletable": true
	},
	"event_pause": {
		"name": "暂停模拟",
		"color": COLOR_EVENT,
		"category": "事件",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {},
		"exec_func": "pause_simulation",
		"deletable": true
	},
	"event_resume": {
		"name": "继续模拟",
		"color": COLOR_EVENT,
		"category": "事件",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {},
		"exec_func": "resume_simulation",
		"deletable": true
	},
	"event_stop": {
		"name": "终止模拟",
		"color": COLOR_EVENT,
		"category": "事件",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [],
		"properties": {},
		"exec_func": "stop_simulation",
		"deletable": true
	},
	"event_print": {
		"name": "打印",
		"color": COLOR_EVENT,
		"category": "事件",
		"inputs": [
			{"name": "执行", "type": "exec"},
			{"name": "值", "type": "Variant"}
		],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {},
		"exec_func": "print_text",
		"deletable": true
	},
	
	# ===== 控制 =====
	"control_if": {
		"name": "if分支",
		"color": COLOR_CONTROL,
		"category": "控制",
		"inputs": [{"name": "执行", "type": "exec"}, {"name": "条件", "type": "bool"}],
		"outputs": [{"name": "那么", "type": "exec"}],
		"properties": {},
		"exec_func": "if_then",
		"deletable": true
	},
	"control_if_else": {
		"name": "if-else分支",
		"color": COLOR_CONTROL,
		"category": "控制",
		"inputs": [{"name": "执行", "type": "exec"}, {"name": "条件", "type": "bool"}],
		"outputs": [{"name": "那么", "type": "exec"}, {"name": "否则", "type": "exec"}],
		"properties": {},
		"exec_func": "if_else",
		"deletable": true
	},
	"control_while": {
		"name": "while循环",
		"color": COLOR_CONTROL,
		"category": "控制",
		"inputs": [{"name": "执行", "type": "exec"}, {"name": "条件", "type": "bool"}],
		"outputs": [{"name": "循环体", "type": "exec"}, {"name": "执行", "type": "exec"}],
		"properties": {},
		"exec_func": "while_loop",
		"deletable": true
	},
	"control_for": {
		"name": "for循环",
		"color": COLOR_CONTROL,
		"category": "控制",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "循环体", "type": "exec"}, {"name": "执行", "type": "exec"}],
		"properties": {"开始": {"type": "int", "default": 0}, 
						"结束": {"type": "int", "default": 10}, 
						"步长": {"type": "int", "default": 1}},
		"exec_func": "for_loop",
		"deletable": true
	},
	# ===== 控制 - 重复执行 =====
	"control_repeat": {
		"name": "重复执行",
		"color": COLOR_CONTROL,
		"category": "控制",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "循环体", "type": "exec"}, {"name": "执行", "type": "exec"}],
		"properties": {},
		"exec_func": "repeat",
		"deletable": true
	},
	"control_repeat_limit": {
		"name": "重复执行n次",
		"color": COLOR_CONTROL,
		"category": "控制",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "循环体", "type": "exec"}, {"name": "执行", "type": "exec"}],
		"properties": {"次数": {"type": "int", "default": 10}},
		"exec_func": "repeat_limit",
		"deletable": true
	},
	"control_repeat_until": {
		"name": "重复执行...直到...",
		"color": COLOR_CONTROL,
		"category": "控制",
		"inputs": [{"name": "执行", "type": "exec"}, {"name": "条件", "type": "exec"}],
		"outputs": [{"name": "循环体", "type": "exec"}, {"name": "执行", "type": "exec"}],
		"properties": {},
		"exec_func": "repeat_until",
		"deletable": true
	},
	"control_break": {
		"name": "终止",
		"color": COLOR_CONTROL,
		"category": "控制",
		"inputs": [{"name": "跳出", "type": "exec"}],
		"outputs": [],
		"properties": {},
		"exec_func": "break",
		"deletable": true
	},
	"control_continue": {
		"name": "继续",
		"color": COLOR_CONTROL,
		"category": "控制",
		"inputs": [{"name": "跳出", "type": "exec"}],
		"outputs": [],
		"properties": {},
		"exec_func": "continue",
		"deletable": true
	},
	
	# ===== 计算 =====
	# ---------- 四则运算 ----------
	"math_add": {
		"name": "加法",
		"color": COLOR_ARITHMETIC,
		"category": "计算",
		"inputs": [{"name": "A", "type": "float"}, {"name": "B", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "add",
		"deletable": true
	},
	"math_subtract": {
		"name": "减法",
		"color": COLOR_ARITHMETIC,
		"category": "计算",
		"inputs": [{"name": "A", "type": "float"}, {"name": "B", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "subtract",
		"deletable": true
	},
	"math_multiply": {
		"name": "乘法",
		"color": COLOR_ARITHMETIC,
		"category": "计算",
		"inputs": [{"name": "A", "type": "float"}, {"name": "B", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "multiply",
		"deletable": true
	},
	"math_divide": {
		"name": "除法",
		"color": COLOR_ARITHMETIC,
		"category": "计算",
		"inputs": [{"name": "A", "type": "float"}, {"name": "B", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "divide",
		"deletable": true
	},
	
	# ---------- 幂/根/模运算 ----------
	"math_power": {
		"name": "幂运算",
		"color": COLOR_POWER,
		"category": "计算",
		"inputs": [{"name": "底数", "type": "float"}, {"name": "指数", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "power",
		"deletable": true
	},
	"math_sqrt": {
		"name": "平方根",
		"color": COLOR_POWER,
		"category": "计算",
		"inputs": [{"name": "数值", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "sqrt",
		"deletable": true
	},
	"math_mod": {
		"name": "取模",
		"color": COLOR_POWER,
		"category": "计算",
		"inputs": [{"name": "被除数", "type": "float"}, {"name": "除数", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "mod",
		"deletable": true
	},
	
	# ---------- 超越函数 ----------
	"math_sin": {
		"name": "正弦",
		"color": COLOR_TRANSCENDENTAL,
		"category": "计算",
		"inputs": [{"name": "角度", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "sin",
		"deletable": true
	},
	"math_cos": {
		"name": "余弦",
		"color": COLOR_TRANSCENDENTAL,
		"category": "计算",
		"inputs": [{"name": "角度", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "cos",
		"deletable": true
	},
	"math_tan": {
		"name": "正切",
		"color": COLOR_TRANSCENDENTAL,
		"category": "计算",
		"inputs": [{"name": "角度", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "tan",
		"deletable": true
	},
	"math_asin": {
		"name": "反正弦",
		"color": COLOR_TRANSCENDENTAL,
		"category": "计算",
		"inputs": [{"name": "数值", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "asin",
		"deletable": true
	},
	"math_acos": {
		"name": "反余弦",
		"color": COLOR_TRANSCENDENTAL,
		"category": "计算",
		"inputs": [{"name": "数值", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "acos",
		"deletable": true
	},
	"math_atan": {
		"name": "反正切",
		"color": COLOR_TRANSCENDENTAL,
		"category": "计算",
		"inputs": [{"name": "数值", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "atan",
		"deletable": true
	},
	"math_log": {
		"name": "自然对数",
		"color": COLOR_TRANSCENDENTAL,
		"category": "计算",
		"inputs": [{"name": "数值", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "log",
		"deletable": true
	},
	"math_log10": {
		"name": "常用对数",
		"color": COLOR_TRANSCENDENTAL,
		"category": "计算",
		"inputs": [{"name": "数值", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "log10",
		"deletable": true
	},
	"math_exp": {
		"name": "指数",
		"color": COLOR_TRANSCENDENTAL,
		"category": "计算",
		"inputs": [{"name": "指数", "type": "float"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "exp",
		"deletable": true
	},
	
	# ---------- 计数组合 ----------
	"math_factorial": {
		"name": "阶乘",
		"color": COLOR_COMBINATORICS,
		"category": "计算",
		"inputs": [{"name": "数值", "type": "int"}],
		"outputs": [{"name": "结果", "type": "int"}],
		"properties": {},
		"exec_func": "factorial",
		"deletable": true
	},
	"math_permutation": {
		"name": "排列",
		"color": COLOR_COMBINATORICS,
		"category": "计算",
		"inputs": [{"name": "总数", "type": "int"}, {"name": "选取数", "type": "int"}],
		"outputs": [{"name": "结果", "type": "int"}],
		"properties": {},
		"exec_func": "permutation",
		"deletable": true
	},
	"math_combination": {
		"name": "组合",
		"color": COLOR_COMBINATORICS,
		"category": "计算",
		"inputs": [{"name": "总数", "type": "int"}, {"name": "选取数", "type": "int"}],
		"outputs": [{"name": "结果", "type": "int"}],
		"properties": {},
		"exec_func": "combination",
		"deletable": true
	},
	
	# ---------- 数值比较 ----------
	"compare_equal": {
		"name": "等于",
		"color": COLOR_COMPARE,
		"category": "计算",
		"inputs": [{"name": "A", "type": "float"}, {"name": "B", "type": "float"}],
		"outputs": [{"name": "结果", "type": "bool"}],
		"properties": {},
		"exec_func": "compare_equal",
		"deletable": true
	},
	"compare_not_equal": {
		"name": "不等于",
		"color": COLOR_COMPARE,
		"category": "计算",
		"inputs": [{"name": "A", "type": "float"}, {"name": "B", "type": "float"}],
		"outputs": [{"name": "结果", "type": "bool"}],
		"properties": {},
		"exec_func": "compare_not_equal",
		"deletable": true
	},
	"compare_greater": {
		"name": "大于",
		"color": COLOR_COMPARE,
		"category": "计算",
		"inputs": [{"name": "A", "type": "float"}, {"name": "B", "type": "float"}],
		"outputs": [{"name": "结果", "type": "bool"}],
		"properties": {},
		"exec_func": "compare_greater",
		"deletable": true
	},
	"compare_greater_equal": {
		"name": "大于等于",
		"color": COLOR_COMPARE,
		"category": "计算",
		"inputs": [{"name": "A", "type": "float"}, {"name": "B", "type": "float"}],
		"outputs": [{"name": "结果", "type": "bool"}],
		"properties": {},
		"exec_func": "compare_greater_equal",
		"deletable": true
	},
	"compare_less": {
		"name": "小于",
		"color": COLOR_COMPARE,
		"category": "计算",
		"inputs": [{"name": "A", "type": "float"}, {"name": "B", "type": "float"}],
		"outputs": [{"name": "结果", "type": "bool"}],
		"properties": {},
		"exec_func": "compare_less",
		"deletable": true
	},
	"compare_less_equal": {
		"name": "小于等于",
		"color": COLOR_COMPARE,
		"category": "计算",
		"inputs": [{"name": "A", "type": "float"}, {"name": "B", "type": "float"}],
		"outputs": [{"name": "结果", "type": "bool"}],
		"properties": {},
		"exec_func": "compare_less_equal",
		"deletable": true
	},
	
	# ---------- 逻辑运算 ----------
	"logic_and": {
		"name": "与 (AND)",
		"color": COLOR_LOGIC,
		"category": "计算",
		"inputs": [{"name": "A", "type": "bool"}, {"name": "B", "type": "bool"}],
		"outputs": [{"name": "结果", "type": "bool"}],
		"properties": {},
		"exec_func": "logic_and",
		"deletable": true
	},
	"logic_or": {
		"name": "或 (OR)",
		"color": COLOR_LOGIC,
		"category": "计算",
		"inputs": [{"name": "A", "type": "bool"}, {"name": "B", "type": "bool"}],
		"outputs": [{"name": "结果", "type": "bool"}],
		"properties": {},
		"exec_func": "logic_or",
		"deletable": true
	},
	"logic_not": {
		"name": "非 (NOT)",
		"color": COLOR_LOGIC,
		"category": "计算",
		"inputs": [{"name": "输入", "type": "bool"}],
		"outputs": [{"name": "结果", "type": "bool"}],
		"properties": {},
		"exec_func": "logic_not",
		"deletable": true
	},
	"logic_xor": {
		"name": "异或 (XOR)",
		"color": COLOR_LOGIC,
		"category": "计算",
		"inputs": [{"name": "A", "type": "bool"}, {"name": "B", "type": "bool"}],
		"outputs": [{"name": "结果", "type": "bool"}],
		"properties": {},
		"exec_func": "logic_xor",
		"deletable": true
	},
	
	# ---------- 拓展运算（向量） ----------
	"math_vec_add": {
		"name": "向量加法",
		"color": COLOR_VECTOR,
		"category": "计算",
		"inputs": [{"name": "V1", "type": "Vector3"}, {"name": "V2", "type": "Vector3"}],
		"outputs": [{"name": "结果", "type": "Vector3"}],
		"properties": {},
		"exec_func": "vec_add",
		"deletable": true
	},
	"math_vec_subtract": {
		"name": "向量减法",
		"color": COLOR_VECTOR,
		"category": "计算",
		"inputs": [{"name": "V1", "type": "Vector3"}, {"name": "V2", "type": "Vector3"}],
		"outputs": [{"name": "结果", "type": "Vector3"}],
		"properties": {},
		"exec_func": "vec_subtract",
		"deletable": true
	},
	"math_vec_dot": {
		"name": "向量点积",
		"color": COLOR_VECTOR,
		"category": "计算",
		"inputs": [{"name": "V1", "type": "Vector3"}, {"name": "V2", "type": "Vector3"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "vec_dot",
		"deletable": true
	},
	"math_vec_cross": {
		"name": "向量叉积",
		"color": COLOR_VECTOR,
		"category": "计算",
		"inputs": [{"name": "V1", "type": "Vector3"}, {"name": "V2", "type": "Vector3"}],
		"outputs": [{"name": "结果", "type": "Vector3"}],
		"properties": {},
		"exec_func": "vec_cross",
		"deletable": true
	},
	"math_vec_normalize": {
		"name": "向量归一化",
		"color": COLOR_VECTOR,
		"category": "计算",
		"inputs": [{"name": "向量", "type": "Vector3"}],
		"outputs": [{"name": "结果", "type": "Vector3"}],
		"properties": {},
		"exec_func": "vec_normalize",
		"deletable": true
	},
	"math_vec_length": {
		"name": "向量长度",
		"color": COLOR_VECTOR,
		"category": "计算",
		"inputs": [{"name": "向量", "type": "Vector3"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "vec_length",
		"deletable": true
	},
	
	# ===== 对象 =====
	"object_panel": {
		"name": "对象引用",
		"color": COLOR_OBJECT_ITEM,
		"category": "对象",
		"inputs": [],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {
			"id_code": {"type": "String", "default": "000000"},
			"display_name": {"type": "String", "default": "对象"}
		},
		"exec_func": "object_panel",
		"deletable": true
	},
	"obj_print_data": {
		"name": "打印对象数据",
		"color": COLOR_OBJECT_ITEM,
		"category": "对象操作",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {
			"id_code": {"type": "String", "default": ""}
		},
		"exec_func": "obj_print_data",
		"deletable": true
	},
	"obj_enable": {
		"name": "启用对象",
		"color": COLOR_OBJECT_ITEM,
		"category": "对象操作",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {
			"id_code": {"type": "String", "default": ""}
		},
		"exec_func": "obj_enable",
		"deletable": true
	},
	"obj_disable": {
		"name": "禁用对象",
		"color": COLOR_OBJECT_ITEM,
		"category": "对象操作",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {
			"id_code": {"type": "String", "default": ""}
		},
		"exec_func": "obj_disable",
		"deletable": true
	},
	"obj_property_type": {
		"name": "对象类型",
		"color": COLOR_OBJECT_ITEM,
		"category": "对象",
		"inputs": [],
		"outputs": [{"name": "类型", "type": "int"}],
		"properties": {"id_code": {"type": "String", "default": "000000"}},
		"exec_func": "obj_property_type",
		"deletable": true
	},
	"obj_property_position": {
		"name": "对象位置",
		"color": COLOR_OBJECT_ITEM,
		"category": "对象",
		"inputs": [],
		"outputs": [
			{"name": "X", "type": "float"},
			{"name": "Y", "type": "float"},
			{"name": "Z", "type": "float"}
		],
		"properties": {"id_code": {"type": "String", "default": "000000"}},
		"exec_func": "obj_property_position",
		"deletable": true
	},
	"obj_property_value": {
		"name": "对象数值",
		"color": COLOR_OBJECT_ITEM,
		"category": "对象",
		"inputs": [],
		"outputs": [{"name": "数值", "type": "float"}],
		"properties": {"id_code": {"type": "String", "default": "000000"}},
		"exec_func": "obj_property_value",
		"deletable": true
	},
	"obj_property_direction": {
		"name": "对象方向",
		"color": COLOR_OBJECT_ITEM,
		"category": "对象",
		"inputs": [],
		"outputs": [
			{"name": "X", "type": "float"},
			{"name": "Y", "type": "float"},
			{"name": "Z", "type": "float"}
		],
		"properties": {"id_code": {"type": "String", "default": "000000"}},
		"exec_func": "obj_property_direction",
		"deletable": true
	},
	"obj_property_name": {
		"name": "对象名称",
		"color": COLOR_OBJECT_ITEM,
		"category": "对象",
		"inputs": [],
		"outputs": [{"name": "名称", "type": "String"}],
		"properties": {"id_code": {"type": "String", "default": "000000"}},
		"exec_func": "obj_property_name",
		"deletable": true
	},
	"obj_property_size": {
		"name": "对象尺寸",
		"color": COLOR_OBJECT_ITEM,
		"category": "对象",
		"inputs": [],
		"outputs": [
			{"name": "X", "type": "float"},
			{"name": "Y", "type": "float"},
			{"name": "Z", "type": "float"}
		],
		"properties": {"id_code": {"type": "String", "default": "000000"}},
		"exec_func": "obj_property_size",
		"deletable": true
	},
	"obj_property_color": {
		"name": "对象颜色",
		"color": COLOR_OBJECT_ITEM,
		"category": "对象",
		"inputs": [],
		"outputs": [
			{"name": "R", "type": "float"},
			{"name": "G", "type": "float"},
			{"name": "B", "type": "float"},
			{"name": "A", "type": "float"}
		],
		"properties": {"id_code": {"type": "String", "default": "000000"}},
		"exec_func": "obj_property_color",
		"deletable": true
	},
	
	# ===== 碰撞检测 =====
	"detect_collision": {
		"name": "碰撞检测",
		"color": COLOR_DETECT_COLLISION,
		"category": "检测",
		"inputs": [{"name": "对象A", "type": "Node"}, {"name": "对象B", "type": "Node"}],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {},
		"exec_func": "detect_collision",
		"deletable": true
	},

	# ===== 输入检测 =====
	"detect_key_pressed": {
		"name": "按键是否按下",
		"color": COLOR_DETECT_INPUT,
		"category": "检测",
		"inputs": [],
		"outputs": [{"name": "是否按下", "type": "bool"}],
		"properties": {
			"key": {
				"type": "enum",
				"default": "space",
				"options": ["space", "w", "a", "s", "d", "escape", "enter", "shift", "ctrl", "mouse_left", "mouse_right"]
			}
		},
		"exec_func": "detect_key_pressed",
		"deletable": true
	},
	"detect_mouse_pressed": {
		"name": "鼠标是否按下",
		"color": COLOR_DETECT_INPUT,
		"category": "检测",
		"inputs": [],
		"outputs": [{"name": "是否按下", "type": "bool"}],
		"properties": {
			"button": {
				"type": "enum",
				"default": "left",
				"options": ["left", "right", "middle"]
			}
		},
		"exec_func": "detect_mouse_pressed",
		"deletable": true
	},
	"detect_mouse_click": {
		"name": "鼠标点击",
		"color": COLOR_DETECT_INPUT,
		"category": "检测",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "执行", "type": "exec"}, {"name": "点击位置", "type": "Vector2"}],
		"properties": {
			"button": {
				"type": "enum",
				"default": "left",
				"options": ["left", "right", "middle"]
			}
		},
		"exec_func": "detect_mouse_click",
		"deletable": true
	},
	"detect_mouse_release": {
		"name": "鼠标松开",
		"color": COLOR_DETECT_INPUT,
		"category": "检测",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {
			"button": {
				"type": "enum",
				"default": "left",
				"options": ["left", "right", "middle"]
			}
		},
		"exec_func": "detect_mouse_release",
		"deletable": true
	},

	# ===== 环境数据 =====
	"detect_mouse_position": {
		"name": "鼠标坐标",
		"color": COLOR_DETECT_ENVIRONMENT,
		"category": "检测",
		"inputs": [],
		"outputs": [{"name": "X", "type": "float"}, {"name": "Y", "type": "float"}],
		"properties": {},
		"exec_func": "detect_mouse_position",
		"deletable": true
	},
	"detect_distance_to_mouse": {
		"name": "对象距离鼠标",
		"color": COLOR_DETECT_ENVIRONMENT,
		"category": "检测",
		"inputs": [{"name": "对象", "type": "Node"}],
		"outputs": [{"name": "距离", "type": "float"}],
		"properties": {},
		"exec_func": "detect_distance_to_mouse",
		"deletable": true
	},
	"detect_distance": {
		"name": "距离检测",
		"color": COLOR_DETECT_ENVIRONMENT,
		"category": "检测",
		"inputs": [{"name": "对象A", "type": "Node"}, {"name": "对象B", "type": "Node"}],
		"outputs": [{"name": "距离", "type": "float"}],
		"properties": {},
		"exec_func": "detect_distance",
		"deletable": true
	},

	# ===== 计时器 =====
	"timer_define": {
		"name": "定义计时器",
		"color": COLOR_DETECT_ENVIRONMENT,
		"category": "计时器",
		"inputs": [],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {"名称": {"type": "String", "default": "timer"}},
		"exec_func": "timer_define",
		"deletable": true
	},
	"timer_call": {
		"name": "调用计时器",
		"color": COLOR_DETECT_ENVIRONMENT,
		"category": "计时器",
		"inputs": [],
		"outputs": [{"name": "数值", "type": "float"}],
		"properties": {"名称": {"type": "enum", "options": []}},
		"exec_func": "timer_call",
		"deletable": true
	},
	"timer_start": {
		"name": "开始计时",
		"color": COLOR_DETECT_ENVIRONMENT,
		"category": "计时器",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {"名称": {"type": "enum", "options": []}},
		"exec_func": "timer_start",
		"deletable": true
	},
	"timer_pause": {
		"name": "暂停计时",
		"color": COLOR_DETECT_ENVIRONMENT,
		"category": "计时器",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {"名称": {"type": "enum", "options": []}},
		"exec_func": "timer_pause",
		"deletable": true
	},
	"timer_stop": {
		"name": "终止计时",
		"color": COLOR_DETECT_ENVIRONMENT,
		"category": "计时器",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {"名称": {"type": "enum", "options": []}},
		"exec_func": "timer_stop",
		"deletable": true
	},
	"timer_wait": {
		"name": "等待时间(秒)",
		"color": COLOR_DETECT_ENVIRONMENT,
		"category": "计时器",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {"数值": {"type": "float", "default": 1.0}},
		"exec_func": "timer_wait",
		"deletable": true
	},
	"timer_runtime": {
		"name": "运行时间",
		"color": COLOR_DETECT_ENVIRONMENT,
		"category": "计时器",
		"inputs": [],
		"outputs": [{"name": "数值", "type": "float"}],
		"properties": {},
		"exec_func": "timer_runtime",
		"deletable": true
	},
	
	# ===== 数据类型 =====
	"type_bool": {
		"name": "布尔",
		"color": COLOR_VARIABLE,
		"category": "变量",
		"inputs": [],
		"outputs": [{"name": "值", "type": "bool"}],
		"properties": {
			"变量": {"type": "String", "default": "bool"},
			"默认": {"type": "bool", "default": false}
		},
		"exec_func": "type_bool",
		"deletable": true
	},
	"type_int": {
		"name": "整数",
		"color": COLOR_VARIABLE,
		"category": "变量",
		"inputs": [],
		"outputs": [{"name": "值", "type": "int"}],
		"properties": {
			"变量": {"type": "String", "default": "int"},
			"默认": {"type": "int", "default": 0}
		},
		"exec_func": "type_int",
		"deletable": true
	},
	"type_float": {
		"name": "浮点数",
		"color": COLOR_VARIABLE,
		"category": "变量",
		"inputs": [],
		"outputs": [{"name": "值", "type": "float"}],
		"properties": {
			"变量": {"type": "String", "default": "float"},
			"默认": {"type": "float", "default": 0.0}
		},
		"exec_func": "type_float",
		"deletable": true
	},
	"type_string": {
		"name": "字符串",
		"color": COLOR_VARIABLE,
		"category": "变量",
		"inputs": [],
		"outputs": [{"name": "值", "type": "String"}],
		"properties": {
			"变量": {"type": "String", "default": "string"},
			"默认": {"type": "String", "default": ""}
		},
		"exec_func": "type_string",
		"deletable": true
	},
	"type_vector2": {
		"name": "二维向量",
		"color": COLOR_VARIABLE,
		"category": "变量",
		"inputs": [],
		"outputs": [{"name": "值", "type": "Vector2"}],
		"properties": {
			"变量": {"type": "String", "default": "vec2"},
			"默认X": {"type": "float", "default": 0.0},
			"默认Y": {"type": "float", "default": 0.0}
		},
		"exec_func": "type_vector2",
		"deletable": true
	},
	"type_vector3": {
		"name": "三维向量",
		"color": COLOR_VARIABLE,
		"category": "变量",
		"inputs": [],
		"outputs": [{"name": "值", "type": "Vector3"}],
		"properties": {
			"变量": {"type": "String", "default": "vec3"},
			"默认X": {"type": "float", "default": 0.0},
			"默认Y": {"type": "float", "default": 0.0},
			"默认Z": {"type": "float", "default": 0.0}
		},
		"exec_func": "type_vector3",
		"deletable": true
	},
	"type_vector4": {
		"name": "四维向量",
		"color": COLOR_VARIABLE,
		"category": "变量",
		"inputs": [],
		"outputs": [{"name": "值", "type": "Vector4"}],
		"properties": {
			"变量": {"type": "String", "default": "vec4"},
			"默认X": {"type": "float", "default": 0.0},
			"默认Y": {"type": "float", "default": 0.0},
			"默认Z": {"type": "float", "default": 0.0},
			"默认W": {"type": "float", "default": 0.0}
		},
		"exec_func": "type_vector4",
		"deletable": true
	},
	"type_array": {
		"name": "数组",
		"color": COLOR_VARIABLE,
		"category": "变量",
		"inputs": [],
		"outputs": [{"name": "值", "type": "Array"}],
		"properties": {
			"变量": {"type": "String", "default": "array"},
			"默认": {"type": "Array", "default": []}
		},
		"exec_func": "type_array",
		"deletable": true
	},
	"type_dictionary": {
		"name": "字典",
		"color": COLOR_VARIABLE,
		"category": "变量",
		"inputs": [],
		"outputs": [{"name": "值", "type": "Dictionary"}],
		"properties": {
			"变量": {"type": "String", "default": "dict"},
			"默认": {"type": "Dictionary", "default": {}}
		},
		"exec_func": "type_dictionary",
		"deletable": true
	},
	"get_variable": {
		"name": "获取变量",
		"color": COLOR_VARIABLE,
		"category": "变量",
		"inputs": [],
		"outputs": [{"name": "值", "type": "Variant"}],
		"properties": {
			"变量": {"type": "enum", "default": "", "options": []}
		},
		"exec_func": "get_variable",
		"deletable": true
	},
	"set_variable": {
		"name": "设置变量",
		"color": COLOR_DATA_OPERATION,
		"category": "操作",
		"inputs": [
			{"name": "执行", "type": "exec"},
			{"name": "操作", "type": "Variant"}
		],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {
			"变量": {"type": "enum", "default": "", "options": []}
		},
		"exec_func": "set_variable",
		"deletable": true
	},

	# ===== 数据操作 =====
	"op_type_cast": {
		"name": "类型转换",
		"color": COLOR_DATA_OPERATION,
		"category": "操作",
		"inputs": [{"name": "输入", "type": "Variant"}],
		"outputs": [{"name": "结果", "type": "Variant"}],
		"properties": {
			"target_type": {
				"type": "enum",
				"default": "int",
				"options": ["int", "float", "string", "bool", "Vector2", "Vector3", "Vector4"]
			}
		},
		"exec_func": "op_type_cast",
		"deletable": true
	},
	"op_get_length": {
		"name": "获取长度",
		"color": COLOR_DATA_OPERATION,
		"category": "操作",
		"inputs": [{"name": "数据", "type": "Variant"}],
		"outputs": [{"name": "长度", "type": "int"}],
		"properties": {},
		"exec_func": "op_get_length",
		"deletable": true
	},
	"op_iterate_dict": {
		"name": "遍历字典",
		"color": COLOR_DATA_OPERATION,
		"category": "操作",
		"inputs": [{"name": "执行", "type": "exec"}, {"name": "字典", "type": "Dictionary"}],
		"outputs": [{"name": "执行", "type": "exec"}, {"name": "键", "type": "Variant"}, {"name": "值", "type": "Variant"}],
		"properties": {},
		"exec_func": "op_iterate_dict",
		"deletable": true
	},
	"op_get_array_element": {
		"name": "获取数组元素",
		"color": COLOR_DATA_OPERATION,
		"category": "操作",
		"inputs": [{"name": "数组", "type": "Array"}, {"name": "索引", "type": "int"}],
		"outputs": [{"name": "元素", "type": "Variant"}],
		"properties": {},
		"exec_func": "op_get_array_element",
		"deletable": true
	},
	"op_get_vector_component": {
		"name": "获取向量数值",
		"color": COLOR_DATA_OPERATION,
		"category": "操作",
		"inputs": [{"name": "向量", "type": "Variant"}],
		"outputs": [{"name": "分量值", "type": "float"}],
		"properties": {
			"选取分量": {"type": "enum", "default": "x", "options": ["x","y","z","w"]}
		},
		"exec_func": "op_get_vector_component",
		"deletable": true
	},
	"op_is_empty": {
		"name": "判断是否为空",
		"color": COLOR_DATA_OPERATION,
		"category": "操作",
		"inputs": [{"name": "数据", "type": "Variant"}],
		"outputs": [{"name": "是否为空", "type": "bool"}],
		"properties": {},
		"exec_func": "op_is_empty",
		"deletable": true
	},

	# ===== 类型转换 =====
	"cast_float_to_int": {
		"name": "float → int",
		"color": COLOR_TYPE_CAST,
		"category": "转换",
		"inputs": [{"name": "数值", "type": "float"}],
		"outputs": [{"name": "结果", "type": "int"}],
		"properties": {},
		"exec_func": "cast_float_to_int",
		"deletable": true
	},
	"cast_int_to_float": {
		"name": "int → float",
		"color": COLOR_TYPE_CAST,
		"category": "转换",
		"inputs": [{"name": "数值", "type": "int"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "cast_int_to_float",
		"deletable": true
	},
	"cast_string_to_float": {
		"name": "string → float",
		"color": COLOR_TYPE_CAST,
		"category": "转换",
		"inputs": [{"name": "字符串", "type": "String"}],
		"outputs": [{"name": "结果", "type": "float"}],
		"properties": {},
		"exec_func": "cast_string_to_float",
		"deletable": true
	},
	"cast_string_to_int": {
		"name": "string → int",
		"color": COLOR_TYPE_CAST,
		"category": "转换",
		"inputs": [{"name": "字符串", "type": "String"}],
		"outputs": [{"name": "结果", "type": "int"}],
		"properties": {},
		"exec_func": "cast_string_to_int",
		"deletable": true
	},
	"cast_string_to_vector2": {
		"name": "string → Vector2",
		"color": COLOR_TYPE_CAST,
		"category": "转换",
		"inputs": [{"name": "字符串", "type": "String"}],
		"outputs": [{"name": "结果", "type": "Vector2"}],
		"properties": {},
		"exec_func": "cast_string_to_vector2",
		"deletable": true
	},
	"cast_string_to_vector3": {
		"name": "string → Vector3",
		"color": COLOR_TYPE_CAST,
		"category": "转换",
		"inputs": [{"name": "字符串", "type": "String"}],
		"outputs": [{"name": "结果", "type": "Vector3"}],
		"properties": {},
		"exec_func": "cast_string_to_vector3",
		"deletable": true
	},

	# ===== 自定义函数 =====
	"func_define_new": {
		"name": "定义函数",
		"color": COLOR_CUSTOM_FUNC,
		"category": "自定义",
		"inputs": [],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {
			"func": {"type": "String", "default": "func"},
			"params": {"type": "Array", "default": []},
			"returns": {"type": "String", "default": "void"}
		},
		"exec_func": "func_define_new",
		"deletable": true
	},
	"func_call": {
		"name": "调用函数",
		"color": COLOR_CUSTOM_FUNC,
		"category": "自定义",
		"inputs": [{"name": "执行", "type": "exec"}],
		"outputs": [{"name": "执行", "type": "exec"}],
		"properties": {"func": {"type": "enum", "options": []}},
		"exec_func": "func_call",
		"deletable": true
	}
}

static func get_node_type(type_id: String) -> Dictionary:
	return node_types.get(type_id, {})

static func is_deletable(type_id: String) -> bool:
	return node_types.get(type_id, {}).get("deletable", true)


