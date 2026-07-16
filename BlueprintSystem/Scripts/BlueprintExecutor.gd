# ============================================================================
# BlueprintExecutor.gd - 状态机驱动的蓝图执行器
# ============================================================================
# 核心设计：
#   1. 每帧执行有限数量的节点（MAX_STEPS_PER_FRAME = 60）
#   2. 使用执行栈 (_execution_stack) 管理待执行的节点帧
#   3. 节点执行分为两步：先计算数据依赖，再执行控制流
#   4. 变量采用双层存储：context（全局变量）+ node_var_cache（节点级缓存）
# ============================================================================

class_name BlueprintExecutor
extends RefCounted

# ============================================================================
# 核心数据
# ============================================================================

## 运行时上下文（存储全局变量和临时数据）
var context: Dictionary = {}

## 节点级变量缓存（key: node_id, value: 该节点输出的值）
## 用于隔离不同数据节点的输出，避免同名变量冲突
var node_var_cache: Dictionary = {}

## 蓝图数据引用
var data: BlueprintData = null

# ============================================================================
# 状态机变量
# ============================================================================

## 执行栈：存储待执行的帧
## 每帧格式：{ "node_id": int, "port": int, "skip_output": bool, "compute_only": bool }
var _execution_stack: Array = []

## 运行状态
var is_running: bool = false		  # 是否正在执行
var is_paused: bool = false		   # 是否暂停
var _signal_listeners: Dictionary = {}  # signal_name -> Array of node_id
var _signal_state: Dictionary = {}  # signal_name -> bool 是否已发射

## 每帧执行步数控制
var _steps_this_frame: int = 0
const MAX_STEPS_PER_FRAME: int = 60   # 每帧最多执行 60 步
## 等待状态：{ "node_id": int, "start_time": int, "duration": float, "skip_output": bool }
var _wait_state: Dictionary = {}

## 执行深度（防止无限递归）
var _execution_depth: int = 0
const MAX_EXECUTION_DEPTH: int = 30000

## 执行日志
var _execution_log: Array = []

## 控制流标志
var _break_requested: bool = false
var _continue_requested: bool = false
var _abort_current_flow: bool = false

## 场景树缓存（用于节点查找）
var cached_scene_tree: SceneTree = null

## 自保持引用（防止 RefCounted 被过早释放）
var _self_hold: RefCounted = null

func _init():
	_self_hold = self

# ============================================================================
# 公共 API
# ============================================================================

## 启动蓝图执行
func execute(blueprint: BlueprintData) -> Array:
	data = blueprint
	
	# 重置所有状态
	context.clear()
	node_var_cache.clear()
	_execution_log = []
	_execution_stack = []
	_execution_depth = 0
	_break_requested = false
	_continue_requested = false
	_abort_current_flow = false
	_steps_this_frame = 0
	is_running = false
	is_paused = false
	_signal_listeners = {}
	_signal_state = {}
	
	# 清空全局计时器
	if GlobalData:
		GlobalData.clear_all_timers()
	
	# 预初始化所有变量声明节点（type_xxx）
	_preinitialize_variables()

	# 预注册所有接收信号节点
	for node in data.nodes.values():
		if node.type_id == "event_receive":
			var signal_name = node.properties.get("名称", "signal")
			if not _signal_listeners.has(signal_name):
				_signal_listeners[signal_name] = []
			_signal_listeners[signal_name].append(node.id)
			print("注册接收信号: ", signal_name, " (节点 ", node.id, ")")
	
	# 查找开始节点
	var start_node = _find_start_node()
	if start_node == null:
		print("错误：没有找到'开始'节点")
		return _execution_log
	
	# 将开始节点压入执行栈
	_execution_stack.append({
		"node_id": start_node.id,
		"port": 0,
		"skip_output": false,
		"compute_only": false
	})
	
	is_running = true
	print("===== 开始执行蓝图 =====")
	
	return _execution_log

## 每帧调用一次，驱动执行器前进
func step():
	if not is_running or is_paused:
		return
	
	# 检查是否有正在等待的节点
	if _wait_state:
		var elapsed = (Time.get_ticks_usec() - _wait_state["start_time"]) / 1000000.0
		if elapsed >= _wait_state["duration"]:
			# 等待完成，继续执行
			var node_id = _wait_state["node_id"]
			var skip_output = _wait_state["skip_output"]
			_wait_state = {}
			# 执行后续节点
			_push_outputs(node_id, 0, skip_output)
		return  # 等待期间不执行其他节点
	
	if _execution_stack.is_empty():
		is_running = false
		print("===== 蓝图执行完成 =====")
		return
	
	_steps_this_frame = 0
	
	while _steps_this_frame < MAX_STEPS_PER_FRAME and not _execution_stack.is_empty():
		_steps_this_frame += 1
		var frame = _execution_stack.pop_back()
		_execute_node_frame(frame)

## 暂停执行
func pause():
	is_paused = true
	print("蓝图执行已暂停")

## 继续执行
func resume():
	is_paused = false
	print("蓝图执行已恢复")

## 停止执行
func stop():
	is_running = false
	_execution_stack.clear()
	print("蓝图执行已停止")

## 获取执行日志
func get_execution_log() -> Array:
	return _execution_log

## 获取当前上下文（调试用）
func get_context() -> Dictionary:
	return context

# ============================================================================
# 初始化辅助函数
# ============================================================================

## 预初始化所有变量声明节点
func _preinitialize_variables():
	var var_types = [
		"type_bool", "type_int", "type_float", "type_string",
		"type_vector2", "type_vector3", "type_vector4",
		"type_array", "type_dictionary"
	]
	for node in data.nodes.values():
		if node.type_id in var_types:
			_compute_node_value(node)

## 查找开始节点
func _find_start_node():
	for node in data.nodes.values():
		if node.type_id == "start":
			return node
	return null

# ============================================================================
# 核心执行函数
# ============================================================================

## 执行单个节点帧（状态机核心）
func _execute_node_frame(frame: Dictionary):
	var node_id = frame["node_id"]
	var skip_output = frame.get("skip_output", false)
	var compute_only = frame.get("compute_only", false)
	
	# 深度保护
	_execution_depth += 1
	if _execution_depth > MAX_EXECUTION_DEPTH:
		print("错误：执行深度超过最大限制 ", MAX_EXECUTION_DEPTH)
		_execution_depth -= 1
		return
	
	# 中断检测
	if _abort_current_flow:
		_execution_depth -= 1
		return
	
	var node = data.get_node(node_id)
	if node == null:
		_execution_depth -= 1
		return
	
	# 1. 读取所有输入端口的数据（触发上游数据节点计算）
	_read_node_inputs(node_id)
	
	# 2. 计算当前节点的值（仅计算，不触发控制流）
	_compute_node_value(node)
	
	# 3. 如果是纯计算帧，到此结束
	if compute_only:
		_execution_depth -= 1
		return
	
	# 4. 执行控制流（推送后续节点到执行栈）
	_execute_node_control(node, skip_output)
	
	_execution_depth -= 1

# ============================================================================
# 数据读取与计算
# ============================================================================

## 读取节点的所有非执行输入端口
func _read_node_inputs(node_id: int):
	var node = data.get_node(node_id)
	if node == null:
		return
	
	var inputs = node.get_input_ports()
	for i in range(inputs.size()):
		var port_def = inputs[i]
		var port_name = port_def["name"]
		var port_type = port_def.get("type", "")
		if port_type == "exec":
			continue
		
		var incoming_links = _get_links_to_node(node_id)
		var value = null
		for link in incoming_links:
			if link.to_port == i:
				var from_node = data.get_node(link.from_node_id)
				if from_node != null:
					# 递归执行整条上游链路
					_exec_single_upstream(from_node.id)
					value = _get_node_output_value(from_node, link.from_port)
		if value != null:
			context[port_name] = value
			print("读取端口 ", port_name, " 成功，值：", value)
		else:
			context[port_name] = node.properties.get(port_name, null)
			print("读取端口 ", port_name, " 失败，使用默认值：", context[port_name])

## 递归计算节点及其所有依赖
func _compute_node_recursive(node_id: int):
	var node = data.get_node(node_id)
	if node == null:
		return
	
	# 先计算所有输入依赖
	var inputs = node.get_input_ports()
	for i in range(inputs.size()):
		var port_def = inputs[i]
		if port_def.get("type", "") == "exec":
			continue
		
		var links = _get_links_to_node(node_id)
		for link in links:
			if link.to_port == i:
				_compute_node_recursive(link.from_node_id)
	
	# 计算当前节点
	_compute_node_value(node)

## 计算节点的值（纯计算，不触发控制流）
func _compute_node_value(node: BlueprintNode):
	var type_id = node.type_id
	var unique_out_key = "out_" + str(node.id)
	
	match type_id:
		"event_receive":
			var signal_name = node.properties.get("名称", "signal")
			var state = _signal_state.get(signal_name, false)
			context["输出"] = state
			# print("接收信号节点计算: ", signal_name, " 状态: ", state)
		# ===== 变量声明节点 =====
		"type_bool", "type_int", "type_float", "type_string",\
		"type_vector2", "type_vector3", "type_vector4",\
		"type_array", "type_dictionary":
			_compute_variable_declaration(node)
		
		# ===== 获取变量 =====
		"get_variable":
			_compute_get_variable(node)
		
		# ===== 四则运算 =====
		"add", "math_add":
			context[unique_out_key] = context.get("A", 0.0) + context.get("B", 0.0)
		"subtract", "math_subtract":
			context[unique_out_key] = context.get("A", 0.0) - context.get("B", 0.0)
		"multiply", "math_multiply":
			context[unique_out_key] = context.get("A", 0.0) * context.get("B", 0.0)
		"divide", "math_divide":
			var b = context.get("B", 0.0)
			context[unique_out_key] = context.get("A", 0.0) / b if b != 0 else 0
		
		# ===== 幂/根/模 =====
		"power":
			context[unique_out_key] = pow(context.get("底数", 0.0), context.get("指数", 0.0))
		"sqrt":
			context[unique_out_key] = sqrt(context.get("数值", 0.0))
		"mod":
			var b = context.get("除数", 0.0)
			context[unique_out_key] = fmod(context.get("被除数", 0.0), b) if b != 0 else 0.0
		
		# ===== 比较节点 =====
		"compare_equal":	  context[unique_out_key] = context.get("A", 0.0) == context.get("B", 0.0)
		"compare_not_equal":  context[unique_out_key] = context.get("A", 0.0) != context.get("B", 0.0)
		"compare_greater":	context[unique_out_key] = context.get("A", 0.0) > context.get("B", 0.0)
		"compare_greater_equal": context[unique_out_key] = context.get("A", 0.0) >= context.get("B", 0.0)
		# "compare_less":	   context[unique_out_key] = context.get("A", 0.0) < context.get("B", 0.0)
		"compare_less":
			var a = context.get("A", 0.0)
			var b = context.get("B", 0.0)
			print("比较: A=", a, " B=", b, " 结果=", a < b)
			context[unique_out_key] = a < b
		"compare_less_equal": context[unique_out_key] = context.get("A", 0.0) <= context.get("B", 0.0)
		
		# ===== 逻辑节点 =====
		"logic_and": context[unique_out_key] = context.get("A", false) and context.get("B", false)
		"logic_or":  context[unique_out_key] = context.get("A", false) or context.get("B", false)
		"logic_not": context[unique_out_key] = not context.get("输入", false)
		"logic_xor": context[unique_out_key] = (context.get("A", false) or context.get("B", false)) and not (context.get("A", false) and context.get("B", false))
		
		# ===== 超越函数 =====
		"sin":  context[unique_out_key] = sin(context.get("角度", 0.0))
		"cos":  context[unique_out_key] = cos(context.get("角度", 0.0))
		"tan":  context[unique_out_key] = tan(context.get("角度", 0.0))
		"asin": context[unique_out_key] = asin(clamp(context.get("数值", 0.0), -1.0, 1.0))
		"acos": context[unique_out_key] = acos(clamp(context.get("数值", 0.0), -1.0, 1.0))
		"atan": context[unique_out_key] = atan(context.get("数值", 0.0))
		"log":  context[unique_out_key] = log(context.get("数值", 0.0)) if context.get("数值", 0.0) > 0 else 0.0
		"log10":
			var val = context.get("数值", 0.0)
			context[unique_out_key] = log(val) / log(10.0) if val > 0 else 0.0
		"exp": context[unique_out_key] = exp(context.get("指数", 0.0))
		
		# ===== 向量运算 =====
		"vec_add":		context[unique_out_key] = context.get("V1", Vector3.ZERO) + context.get("V2", Vector3.ZERO)
		"vec_subtract":   context[unique_out_key] = context.get("V1", Vector3.ZERO) - context.get("V2", Vector3.ZERO)
		"vec_dot":		context[unique_out_key] = context.get("V1", Vector3.ZERO).dot(context.get("V2", Vector3.ZERO))
		"vec_cross":	  context[unique_out_key] = context.get("V1", Vector3.ZERO).cross(context.get("V2", Vector3.ZERO))
		"vec_normalize":
			var v = context.get("向量", Vector3.ZERO)
			context[unique_out_key] = v.normalized() if v.length() > 0 else Vector3.ZERO
		"vec_length": context[unique_out_key] = context.get("向量", Vector3.ZERO).length()
		
		# ===== 组合计数 =====
		"combination":   context[unique_out_key] = _compute_combination(context.get("总数", 0), context.get("选取数", 0))
		"permutation":   context[unique_out_key] = _compute_permutation(context.get("总数", 0), context.get("选取数", 0))
		"factorial":	 context[unique_out_key] = _compute_factorial(context.get("数值", 0))
		
		# ===== 类型转换 =====
		"cast_float_to_int":   context[unique_out_key] = int(context.get("数值", 0.0))
		"cast_int_to_float":   context[unique_out_key] = float(context.get("数值", 0))
		"cast_string_to_float":
			var s = context.get("字符串", "")
			context[unique_out_key] = float(s) if s.is_valid_float() else 0.0
		"cast_string_to_int":
			var s = context.get("字符串", "")
			context[unique_out_key] = int(s) if s.is_valid_int() else 0
		"cast_string_to_vector2":
			context[unique_out_key] = _parse_vector2(context.get("字符串", ""))
		"cast_string_to_vector3":
			context[unique_out_key] = _parse_vector3(context.get("字符串", ""))
		
		# ===== 数据操作 =====
		"op_type_cast":
			context[unique_out_key] = _compute_type_cast(node)
		"op_get_length":
			var d = context.get("数据", null)
			if d is Array or d is Dictionary:
				context["长度"] = d.size()
			elif d is String:
				context["长度"] = d.length()
			else:
				context["长度"] = 0
		"op_get_array_element":
			var arr = context.get("数组", [])
			var idx = int(context.get("索引", 0))
			context["元素"] = arr[idx] if arr is Array and idx >= 0 and idx < arr.size() else null
		"op_get_vector_component":
			context["分量值"] = _get_vector_component(context.get("向量", Vector4.ZERO), node.properties.get("选取分量", "x"))
		"op_is_empty":
			var d = context.get("数据", null)
			if d is Array or d is String or d is Dictionary:
				context["是否为空"] = d.is_empty()
			else:
				context["是否为空"] = d == null
		
		# ===== 计时器 =====
		"timer_call":
			var name = str(node.properties.get("名称", "")).strip_edges()
			if name != "" and GlobalData:
				context[unique_out_key] = GlobalData.get_timer_time(name)
		"timer_runtime":
			context["数值"] = Time.get_ticks_usec() / 1000000.0 if Engine else 0.0
		
		# ===== 输入检测 =====
		"detect_key_pressed":
			context["是否按下"] = _detect_key_pressed(node.properties.get("key", "space"))
		"detect_distance":
			var a = context.get("对象A", null)
			var b = context.get("对象B", null)
			if a != null and b != null and a.has_method("get_global_position") and b.has_method("get_global_position"):
				context["距离"] = a.get_global_position().distance_to(b.get_global_position())
			else:
				context["距离"] = 0.0
		# ===== 对象属性 =====
		"obj_property_type":
			var data = _find_object_data(node.properties.get("id_code", "000000"))
			context["类型"] = data.get("type", 0) if data else 0
		"obj_property_value":
			var data = _find_object_data(node.properties.get("id_code", "000000"))
			context["数值"] = data.get("value", 0.0) if data else 0.0
		"obj_property_name":
			var data = _find_object_data(node.properties.get("id_code", "000000"))
			context["名称"] = data.get("name", "") if data else ""
		"obj_property_position":
			var data = _find_object_data(node.properties.get("id_code", "000000"))
			if data:
				var pos = data.get("position", [0.0, 0.0, 0.0])
				context["X"] = pos[0] if pos.size() > 0 else 0.0
				context["Y"] = pos[1] if pos.size() > 1 else 0.0
				context["Z"] = pos[2] if pos.size() > 2 else 0.0
			else:
				context["X"] = 0.0
				context["Y"] = 0.0
				context["Z"] = 0.0
		"obj_property_direction":
			var data = _find_object_data(node.properties.get("id_code", "000000"))
			if data:
				var dir = data.get("direction", [0.0, 0.0, 0.0])
				context["X"] = dir[0] if dir.size() > 0 else 0.0
				context["Y"] = dir[1] if dir.size() > 1 else 0.0
				context["Z"] = dir[2] if dir.size() > 2 else 0.0
			else:
				context["X"] = 0.0
				context["Y"] = 0.0
				context["Z"] = 0.0
		"obj_property_size":
			var data = _find_object_data(node.properties.get("id_code", "000000"))
			if data:
				var size = data.get("size", [1.0, 1.0, 1.0])
				context["X"] = size[0] if size.size() > 0 else 1.0
				context["Y"] = size[1] if size.size() > 1 else 1.0
				context["Z"] = size[2] if size.size() > 2 else 1.0
			else:
				context["X"] = 1.0
				context["Y"] = 1.0
				context["Z"] = 1.0
		"obj_property_color":
			var data = _find_object_data(node.properties.get("id_code", "000000"))
			if data:
				var col = data.get("coll_color", [1.0, 1.0, 1.0, 1.0])
				context["R"] = col[0] if col.size() > 0 else 1.0
				context["G"] = col[1] if col.size() > 1 else 1.0
				context["B"] = col[2] if col.size() > 2 else 1.0
				context["A"] = col[3] if col.size() > 3 else 1.0
			else:
				context["R"] = 1.0
				context["G"] = 1.0
				context["B"] = 1.0
				context["A"] = 1.0

## 计算变量声明节点
func _compute_variable_declaration(node: BlueprintNode):
	var var_name = node.properties.get("变量", "")
	var default_val = node.properties.get("默认", 0)
	
	# 存入节点缓存
	node_var_cache[node.id] = default_val
	
	# 存入 context（供 get_variable 读取）
	if var_name != "" and not context.has(var_name):
		context[var_name] = default_val
	context["值"] = default_val

## 计算"获取变量"节点
func _compute_get_variable(node: BlueprintNode):
	# 从节点属性中获取变量名
	var var_name = node.properties.get("变量", "")
	# 如果变量名为空，尝试从其他可能的键获取（向后兼容）
	if var_name == "":
		var_name = node.properties.get("变量名", "")
	if var_name == "":
		var_name = node.properties.get("var_name", "")
	
	# 如果仍然为空，打印警告并返回
	if var_name == "":
		print("警告：获取变量节点属性中没有变量名")
		context["值"] = null
		return
	
	var value = context.get(var_name, null)
	
	# 如果变量不存在，尝试从声明节点初始化
	if value == null:
		var var_types = ["type_bool", "type_int", "type_float", "type_string",
						 "type_vector2", "type_vector3", "type_vector4",
						 "type_array", "type_dictionary"]
		for n in data.nodes.values():
			if n.type_id in var_types:
				# 获取声明节点的变量名（同样需要兼容不同键名）
				var declared_name = n.properties.get("变量", "")
				if declared_name == "":
					declared_name = n.properties.get("变量名", "")
				if declared_name == var_name:
					_compute_node_value(n)
					value = context.get(var_name, null)
					break
	
	# 仍然为空则创建默认值
	if value == null:
		value = 0
		context[var_name] = value
	
	context["值"] = value

# ============================================================================
# 控制流执行
# ============================================================================

## 执行节点的控制流逻辑（推送后续节点到执行栈）
func _execute_node_control(node: BlueprintNode, skip_output: bool):
	var exec_func = node.get_exec_func()
	
	match exec_func:
		# ===== 特殊节点 =====
		"start":
			_push_outputs(node.id, 0, skip_output)
		
		"emit_signal":
			var signal_name = node.properties.get("名称", "signal")
			print("发射信号: ", signal_name)
			# 将信号状态设为 true
			_signal_state[signal_name] = true
			# 触发所有已注册的接收节点
			var has_listeners = _signal_listeners.has(signal_name) and not _signal_listeners[signal_name].is_empty()
			if has_listeners:
				for node_id in _signal_listeners[signal_name]:
					_push_outputs(node_id, 0, false)
			# 如果没有监听者，才继续执行发射节点自身的后续节点
			# 如果有监听者，执行流已经由接收节点传递，不再继续发射节点自身
			if not has_listeners:
				_push_outputs(node.id, 0, skip_output)

		"receive_signal":
			var signal_name = node.properties.get("名称", "signal")
			print("收到信号: ", signal_name)
			pass
		
		"pause_simulation":
			print("暂停模拟")
		
		"resume_simulation":
			print("继续模拟")
		
		"stop_simulation":
			print("终止模拟")
		
		"print_text":
			_print_node(node)
		
		# ===== 条件分支 =====
		"if_then":
			if context.get("条件", false):
				_push_outputs(node.id, 0, skip_output)
		
		"if_else":
			if context.get("条件", false):
				_push_outputs(node.id, 0, skip_output)
			else:
				_push_outputs(node.id, 1, skip_output)
		
		# ===== 循环节点 =====
		"while_loop":
			_execute_while_loop(node, skip_output)
		
		"for_loop":
			_execute_for_loop(node, skip_output)
		
		"repeat":
			_execute_repeat(node, skip_output)
		
		"repeat_limit":
			_execute_repeat_limit(node, skip_output)
		
		"repeat_until":
			_execute_repeat_until(node, skip_output)
		
		"break":
			_break_requested = true
			_abort_current_flow = true
		
		"continue":
			_continue_requested = true
			_abort_current_flow = true
		
		# ===== 对象操作 =====
		"obj_print_data":
			_obj_print_data(node)
		"obj_enable":
			_obj_enable(node)
		"obj_disable":
			_obj_disable(node)
		
		# ===== 设置变量 =====
		"set_variable":
			_execute_set_variable(node, skip_output)
		
		# ===== 计时器操作 =====
		"timer_define":
			var name = node.properties.get("名称", "timer")
			if GlobalData:
				GlobalData.define_timer(name)
			_push_outputs(node.id, 0, skip_output)
		"timer_start":
			var name = node.properties.get("名称", "timer")
			if GlobalData:
				GlobalData.start_timer(name)
			_push_outputs(node.id, 0, skip_output)
		"timer_pause":
			var name = str(node.properties.get("名称", "")).strip_edges()
			if name != "" and GlobalData:
				GlobalData.pause_timer(name)
			_push_outputs(node.id, 0, skip_output)
		"timer_resume":
			var name = str(node.properties.get("名称", "")).strip_edges()
			if name != "" and GlobalData:
				GlobalData.start_timer(name)
			_push_outputs(node.id, 0, skip_output)
		"timer_stop":
			var name = str(node.properties.get("名称", "")).strip_edges()
			if name != "" and GlobalData:
				GlobalData.stop_timer(name)
			_push_outputs(node.id, 0, skip_output)
		"timer_wait":
			var duration = node.properties.get("数值", 1.0)
			print("等待 ", duration, " 秒")
			# 记录等待状态，而非立即继续
			_wait_state = {
				"node_id": node.id,
				"start_time": Time.get_ticks_usec(),
				"duration": duration,
				"skip_output": skip_output
			}
		
		# ===== 自定义函数调用 =====
		"func_call":
			_call_defined_function(node.properties.get("func", ""))
			_push_outputs(node.id, 0, skip_output)
		
		# ===== 数据操作（带执行流） =====
		"op_iterate_dict":
			_execute_iterate_dict(node, skip_output)

## 打印节点
func _print_node(node: BlueprintNode):
	var content = null
	
	# 从 context 读取内容
	for port in node.get_input_ports():
		if port.get("type", "") != "exec":
			content = context.get(port["name"], null)
			break
	
	# 如果 context 中没有，尝试从连接读取
	if content == null:
		for link in _get_links_to_node(node.id):
			var from_node = data.get_node(link.from_node_id)
			if from_node != null:
				content = _get_node_output_value(from_node, link.from_port)
				break
	
	if content == null:
		content = "null"
	
	print(_format_value(content))
	_execution_log.append(_format_value(content))

## While 循环
func _execute_while_loop(node: BlueprintNode, skip_output: bool):
	var condition = context.get("条件", false)
	if condition and not _break_requested:
		_push_outputs(node.id, 0, skip_output)
		# 重新压入自身，用于下一次循环判断
		_execution_stack.append({
			"node_id": node.id,
			"port": 0,
			"skip_output": skip_output,
			"compute_only": false
		})
	else:
		if _break_requested:
			_break_requested = false
		_push_outputs(node.id, 1, skip_output)

## For 循环
func _execute_for_loop(node: BlueprintNode, skip_output: bool):
	var loop_key = "_for_loop_" + str(node.id)
	
	if not context.has(loop_key):
		context[loop_key] = {
			"i": node.properties.get("开始", 0),
			"end": node.properties.get("结束", 10),
			"step": node.properties.get("步长", 1)
		}
	
	var state = context[loop_key]
	var i = state["i"]
	var end = state["end"]
	var step = state["step"]
	
	if i < end and not _break_requested:
		context["loop_index"] = i
		state["i"] = i + step
		context[loop_key] = state
		_push_outputs(node.id, 0, skip_output)
		_execution_stack.append({
			"node_id": node.id,
			"port": 0,
			"skip_output": skip_output,
			"compute_only": false
		})
	else:
		context.erase(loop_key)
		if _break_requested:
			_break_requested = false
		_push_outputs(node.id, 1, skip_output)

## 无限重复
func _execute_repeat(node: BlueprintNode, skip_output: bool):
	var loop_key = "_repeat_" + str(node.id)
	if not context.has(loop_key):
		context[loop_key] = 0
	
	var iter = context[loop_key]
	if iter < MAX_EXECUTION_DEPTH and not _break_requested:
		context[loop_key] = iter + 1
		_push_outputs(node.id, 0, skip_output)
		_execution_stack.append({
			"node_id": node.id,
			"port": 0,
			"skip_output": skip_output,
			"compute_only": false
		})
	else:
		context.erase(loop_key)
		if _break_requested:
			_break_requested = false
			print("重复执行被 break 终止")
		if iter >= MAX_EXECUTION_DEPTH:
			print("警告：重复执行达到最大迭代次数 ", MAX_EXECUTION_DEPTH)
		_push_outputs(node.id, 1, skip_output)

## 重复 N 次
func _execute_repeat_limit(node: BlueprintNode, skip_output: bool):
	var loop_key = "_repeat_limit_" + str(node.id)
	
	if not context.has(loop_key):
		var count = node.properties.get("次数", 10)
		if count > MAX_EXECUTION_DEPTH:
			count = MAX_EXECUTION_DEPTH
			print("警告：重复次数超过最大限制，已限制为 ", MAX_EXECUTION_DEPTH)
		context[loop_key] = {"count": count, "current": 0}
	
	var state = context[loop_key]
	if state["current"] < state["count"] and not _break_requested:
		state["current"] += 1
		context[loop_key] = state
		_push_outputs(node.id, 0, skip_output)
		_execution_stack.append({
			"node_id": node.id,
			"port": 0,
			"skip_output": skip_output,
			"compute_only": false
		})
	else:
		context.erase(loop_key)
		if _break_requested:
			_break_requested = false
			print("重复执行n次被 break 终止")
		_push_outputs(node.id, 1, skip_output)

## 重复...直到...
func _execute_repeat_until(node: BlueprintNode, skip_output: bool):
	var loop_key = "_repeat_until_" + str(node.id)
	
	if not context.has(loop_key):
		context[loop_key] = {"first": true, "iter": 0}
	
	var state = context[loop_key]
	var condition = context.get("条件", false)
	
	if state["first"]:
		state["first"] = false
		_push_outputs(node.id, 0, skip_output)
		_execution_stack.append({
			"node_id": node.id,
			"port": 0,
			"skip_output": skip_output,
			"compute_only": false
		})
	elif condition or _break_requested:
		context.erase(loop_key)
		if _break_requested:
			_break_requested = false
		_push_outputs(node.id, 1, skip_output)
	else:
		if state["iter"] >= MAX_EXECUTION_DEPTH:
			print("警告：重复执行...直到...达到最大迭代次数 ", MAX_EXECUTION_DEPTH)
			context.erase(loop_key)
			_push_outputs(node.id, 1, skip_output)
		else:
			state["iter"] += 1
			context[loop_key] = state
			_push_outputs(node.id, 0, skip_output)
			_execution_stack.append({
				"node_id": node.id,
				"port": 0,
				"skip_output": skip_output,
				"compute_only": false
			})

## 设置变量
func _execute_set_variable(node: BlueprintNode, skip_output: bool):
	var var_name = node.properties.get("变量", "var")
	var value = context.get("操作", null)
	
	# 如果 context 中没有，尝试从连接读取
	if value == null:
		var links = _get_links_to_node(node.id)
		for link in links:
			var inputs = node.get_input_ports()
			for i in range(inputs.size()):
				if inputs[i].get("name") == "操作" and link.to_port == i:
					var from_node = data.get_node(link.from_node_id)
					if from_node != null:
						_compute_node_recursive(from_node.id)
						value = _get_node_output_value(from_node, link.from_port)
						break
			if value != null:
				break
	
	if value != null:
		context[var_name] = value
	else:
		print("警告：设置变量 ", var_name, " 没有收到值")
	
	_push_outputs(node.id, 0, skip_output)

## 遍历字典
func _execute_iterate_dict(node: BlueprintNode, skip_output: bool):
	var dict_data = context.get("字典", {})
	var max_iter = MAX_EXECUTION_DEPTH
	var count = 0
	
	if dict_data is Dictionary:
		for key in dict_data.keys():
			if count >= max_iter or _break_requested:
				break
			count += 1
			context["键"] = key
			context["值"] = dict_data[key]
			_push_outputs(node.id, 0, skip_output)
			_execution_stack.append({
				"node_id": node.id,
				"port": 0,
				"skip_output": skip_output,
				"compute_only": false
			})
	
	if _break_requested:
		_break_requested = false
	if count >= max_iter:
		print("警告：字典遍历达到最大迭代次数 ", max_iter)

# ============================================================================
# 对象操作辅助
# ============================================================================

func _obj_print_data(node: BlueprintNode):
	var target_id = node.properties.get("id_code", "")
	var data = GlobalData.run_project_data if GlobalData else {}
	var matched = {}
	if data.has("fields") and data["fields"].has(target_id):
		matched = data["fields"][target_id]
	elif data.has("objects") and data["objects"].has(target_id):
		matched = data["objects"][target_id]
	elif data.has("grounds") and data["grounds"].has(target_id):
		matched = data["grounds"][target_id]
	if GlobalTools:
		GlobalTools.print_dict(matched)
	else:
		print(matched)

func _obj_enable(node: BlueprintNode):
	var target = locate_node_by_id(node.properties.get("id_code", ""))
	if target != null:
		target.visible = true
		target.set_process_mode(Node.PROCESS_MODE_INHERIT)

func _obj_disable(node: BlueprintNode):
	var target = locate_node_by_id(node.properties.get("id_code", ""))
	if target != null:
		target.visible = false
		target.set_process_mode(Node.PROCESS_MODE_DISABLED)

# ============================================================================
# 数据获取辅助
# ============================================================================

## 获取节点的输出值
## 获取节点的输出值
func _get_node_output_value(node: BlueprintNode, output_port: int):
	var node_id = node.id
	var unique_out_key = "out_" + str(node_id)

	# 在函数开头，变量声明节点之前添加（或放在通用节点前面）
	if node.type_id == "event_receive":
		# 确保输出值是最新的（更新 signal_state）
		_compute_node_value(node)
		var _outputs = node.get_output_ports()
		if output_port < _outputs.size():
			var port_name = _outputs[output_port]["name"]
			return context.get(port_name, null)
		return null
	
	# 1. 变量声明节点 → 从缓存读取
	var var_types = ["type_bool", "type_int", "type_float", "type_string",
					 "type_vector2", "type_vector3", "type_vector4",
					 "type_array", "type_dictionary"]
	if node.type_id in var_types:
		if node_var_cache.has(node_id):
			return node_var_cache[node_id]
		else:
			# 如果缓存中没有，尝试从属性读取默认值（通常不会发生，因为预初始化会填充）
			return node.properties.get("默认", 0)
	
	# 2. 获取变量节点 → 从 context 读取变量值
	if node.type_id == "get_variable":
		var var_name = node.properties.get("变量", "")
		return context.get(var_name, null)
	
	# 3. 计时器调用 → 从 context 读取 unique_out_key
	if node.type_id == "timer_call":
		return context.get(unique_out_key, null)
	
	# 4. 其他所有节点（计算、比较、逻辑、向量、类型转换、数据操作等）
	#	先尝试从端口名读取，再尝试从 unique_out_key 读取
	var outputs = node.get_output_ports()
	if output_port < outputs.size():
		var port_name = outputs[output_port]["name"]
		var val = context.get(port_name, null)
		if val != null:
			return val
		# 如果端口名没有，尝试 unique_out_key
		return context.get(unique_out_key, null)
		
	# 如果没有输出端口定义，尝试直接读取 unique_out_key（兜底）
	return context.get(unique_out_key, null)

## 查找对象数据
func _find_object_data(id_code: String):
	var data = GlobalData.run_project_data if GlobalData else {}
	for source in ["fields", "objects", "grounds"]:
		if data.has(source) and data[source] is Dictionary and data[source].has(id_code):
			return data[source][id_code]
	return null

## 定位场景节点
func locate_node_by_id(code: String) -> Node:
	if cached_scene_tree == null:
		return null
	for child in cached_scene_tree.root.find_children("*", "Node", true, false):
		if child.has_meta("id_code") and child.get_meta("id_code") == code:
			return child
	return null

# ============================================================================
# 连接管理
# ============================================================================

## 获取从某节点出发的所有连接
func _get_links_to_node(node_id: int) -> Array:
	var result = []
	for link in data.links.values():
		if link.to_node_id == node_id:
			result.append(link)
	return result

## 获取连接到某节点的所有连接
func _get_links_from_node(node_id: int) -> Array:
	var result = []
	for link in data.links.values():
		if link.from_node_id == node_id:
			result.append(link)
	return result

# ============================================================================
# 执行栈管理
# ============================================================================

## 将后续节点压入执行栈
func _push_outputs(node_id: int, port: int, skip_output: bool):
	if _abort_current_flow:
		_abort_current_flow = false
		return
	var node = data.get_node(node_id)
	var node_name = node.type_id if node else str(node_id)  # 如果没有节点，回退到ID
	print("执行流从节点 ", node_name, " 端口 ", port, " 出发")
	for link in _get_links_from_node(node_id):
		if link.from_port == port:
			var target_node = data.get_node(link.to_node_id)
			var target_name = target_node.type_id if target_node else str(link.to_node_id)
			print("  → 进入节点 ", target_name)
			_execution_stack.append({
				"node_id": link.to_node_id,
				"port": 0,
				"skip_output": skip_output,
				"compute_only": false
			})

## 调用自定义函数
func _call_defined_function(func_name: String):
	for node in data.nodes.values():
		if node.type_id == "func_define_new" and node.properties.get("func", "") == func_name:
			_push_outputs(node.id, 0, false)
			return
	print("未找到函数: ", func_name)

# ============================================================================
# 工具函数
# ============================================================================

## 格式化值
func _format_value(value) -> String:
	if value == null:
		return "null"
	match typeof(value):
		TYPE_BOOL: return "true" if value else "false"
		TYPE_INT: return str(value)
		TYPE_FLOAT: return str(value)
		TYPE_STRING: return value
		TYPE_VECTOR2: return "Vector2(" + str(value.x) + ", " + str(value.y) + ")"
		TYPE_VECTOR3: return "Vector3(" + str(value.x) + ", " + str(value.y) + ", " + str(value.z) + ")"
		TYPE_VECTOR4: return "Vector4(" + str(value.x) + ", " + str(value.y) + ", " + str(value.z) + ", " + str(value.w) + ")"
		TYPE_ARRAY:
			var parts = []
			for item in value:
				parts.append(_format_value(item))
			return "[" + ", ".join(parts) + "]"
		TYPE_DICTIONARY:
			var parts = []
			for key in value.keys():
				parts.append(str(key) + ": " + _format_value(value[key]))
			return "{" + ", ".join(parts) + "}"
		TYPE_OBJECT:
			return "Node(" + value.name + ")" if value is Node else "Object(" + str(value) + ")"
	return str(value)

## 按键检测
func _detect_key_pressed(key_name: String) -> bool:
	var map = {
		"space": KEY_SPACE, "w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D,
		"escape": KEY_ESCAPE, "enter": KEY_ENTER, "shift": KEY_SHIFT, "ctrl": KEY_CTRL,
		"mouse_left": 0, "mouse_right": 0, "mouse_middle": 0
	}
	if map.has(key_name):
		if key_name.begins_with("mouse"):
			return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT if key_name == "mouse_left" else MOUSE_BUTTON_RIGHT if key_name == "mouse_right" else MOUSE_BUTTON_MIDDLE)
		return Input.is_key_pressed(map[key_name])
	return false

## 组合数计算
func _compute_combination(n: int, k: int) -> int:
	if n < 0 or k < 0 or k > n:
		return 0
	var result = 1
	for i in range(k):
		result *= (n - i)
		result /= (i + 1)
	return result

## 排列数计算
func _compute_permutation(n: int, k: int) -> int:
	if n < 0 or k < 0 or k > n:
		return 0
	var result = 1
	for i in range(k):
		result *= (n - i)
	return result

## 阶乘计算
func _compute_factorial(n: int) -> int:
	if n < 0:
		return 0
	var result = 1
	for i in range(2, n + 1):
		result *= i
	return result

## 解析 Vector2
func _parse_vector2(s: String) -> Vector2:
	var cleaned = s.replace("(", "").replace(")", "").replace(" ", "")
	var parts = cleaned.split(",")
	if parts.size() >= 2:
		return Vector2(float(parts[0]) if parts[0].is_valid_float() else 0.0,
					   float(parts[1]) if parts[1].is_valid_float() else 0.0)
	return Vector2.ZERO

## 解析 Vector3
func _parse_vector3(s: String) -> Vector3:
	var cleaned = s.replace("(", "").replace(")", "").replace(" ", "")
	var parts = cleaned.split(",")
	if parts.size() >= 3:
		return Vector3(float(parts[0]) if parts[0].is_valid_float() else 0.0,
					   float(parts[1]) if parts[1].is_valid_float() else 0.0,
					   float(parts[2]) if parts[2].is_valid_float() else 0.0)
	return Vector3.ZERO

## 类型转换
func _compute_type_cast(node: BlueprintNode):
	var input_val = context.get("输入", null)
	var target = node.properties.get("target_type", "int")
	match target:
		"int":
			if input_val is String:
				return int(input_val) if input_val.is_valid_int() else 0
			return int(input_val) if input_val != null else 0
		"float":
			if input_val is String:
				return float(input_val) if input_val.is_valid_float() else 0.0
			return float(input_val) if input_val != null else 0.0
		"string": return str(input_val)
		"bool": return bool(input_val)
		"Vector2": return _parse_vector2(str(input_val))
		"Vector3": return _parse_vector3(str(input_val))
		"Vector4":
			var parts = str(input_val).replace("(", "").replace(")", "").replace(" ", "").split(",")
			if parts.size() >= 4:
				return Vector4(float(parts[0]) if parts[0].is_valid_float() else 0.0,
							   float(parts[1]) if parts[1].is_valid_float() else 0.0,
							   float(parts[2]) if parts[2].is_valid_float() else 0.0,
							   float(parts[3]) if parts[3].is_valid_float() else 0.0)
			return Vector4.ZERO
	return input_val

## 获取向量分量
func _get_vector_component(vec, axis: String) -> float:
	var v4 = Vector4.ZERO
	if vec is Vector2:
		v4 = Vector4(vec.x, vec.y, 0.0, 0.0)
	elif vec is Vector3:
		v4 = Vector4(vec.x, vec.y, vec.z, 0.0)
	elif vec is Vector4:
		v4 = vec
	elif vec is int or vec is float:
		v4 = Vector4(vec, vec, vec, vec)
	match axis:
		"x": return v4.x
		"y": return v4.y
		"z": return v4.z
		"w": return v4.w
	return 0.0

func _exec_single_upstream(node_id: int):
	var node = data.get_node(node_id)
	if node == null:
		return
	# 先跑完该节点所有输入上游
	var inputs = node.get_input_ports()
	for i in range(inputs.size()):
		var p = inputs[i]
		if p["type"] == "exec":
			continue
		var links = _get_links_to_node(node_id)
		for l in links:
			if l.to_port == i:
				_exec_single_upstream(l.from_node_id)
	# 读取自身输入、执行节点
	_read_node_inputs(node_id)
	_compute_node_value(node)

