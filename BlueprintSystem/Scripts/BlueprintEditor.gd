# BlueprintEditor.gd
class_name BlueprintEditor
extends Control

# 节点引用
@onready var graph_edit: GraphEdit = $GraphEdit	  # 图编辑器主控件
@onready var popup_menu: PopupMenu = $PopupMenu	  # 右键弹出菜单

# 数据与状态
var blueprint_data: BlueprintData = BlueprintData.new()		  # 蓝图数据（节点和连接）
var node_ui_map: Dictionary = {}								 # node_id -> BlueprintNodeUI 映射表
var _is_modified: bool = false

const NODE_UI_SCENE = preload("res://BlueprintSystem/BlueprintNodeUI.tscn")

var _objects_list_menu: PopupMenu = null	  # "添加对象"子菜单引用

var _clipboard_data: Dictionary = {}

var _selected_node_id: int = -1		  # 当前选中的节点ID（-1表示无选中）
var _call_func_menu: PopupMenu = null	# "调用函数"子菜单引用（用于动态刷新）
var _call_var_menu: PopupMenu = null  # "调用变量"菜单引用
var _call_timer_menu: PopupMenu = null # "调用计时器"菜单引用
var blueprint_runtime: BlueprintExecutor = null

func _ready():
	_init_graph_view()
	_setup_editor_layout()
	_create_palette_panel()

	# 连接 GraphEdit 信号
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.popup_request.connect(_on_popup_request)
	graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	graph_edit.node_selected.connect(_on_node_selected_save)
	graph_edit.scroll_offset_changed.connect(_on_zoom_changed)
	
	# 构建右键菜单
	_setup_popup_menu()

	_refresh_all_dynamic_lists()
	# 启用输入处理
	set_process_input(true)
	set_process(false)

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F5:
			_execute_current_blueprint()
			get_viewport().set_input_as_handled()
		# Ctrl+S 保存
		if event.ctrl_pressed and event.keycode == KEY_S:
			save_blueprint()
			get_viewport().set_input_as_handled()
		
		# Ctrl+O 加载
		if event.ctrl_pressed and event.keycode == KEY_O:
			load_blueprint()
			get_viewport().set_input_as_handled()

func _process(delta: float):
	# print("_process 执行中")
	if blueprint_runtime and blueprint_runtime.is_running:
		blueprint_runtime.step()
	else:
		set_process(false)

## 执行当前蓝图
func _execute_current_blueprint():
	if blueprint_data.nodes.is_empty():
		# print("蓝图为空，无法执行")
		return
	
	blueprint_runtime = BlueprintExecutor.new()
	blueprint_runtime.execute(blueprint_data)
	
	if blueprint_runtime.is_running:
		set_process(true)   # 这一行必须执行

func _init_graph_view():
	# 等待一帧确保布局完成
	await get_tree().process_frame

	var viewport_size = graph_edit.size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1000, 800)
	
	# 获取当前缩放值
	var current_zoom = graph_edit.zoom if graph_edit.has_method("get_zoom") else 1.0
	if current_zoom <= 0:
		current_zoom = 1.0
	
	# 将视口中心映射到画布坐标（考虑缩放）
	# scroll_offset 是画布在视口中的偏移量，需要除以 zoom
	var offset = -viewport_size / (2 * current_zoom)
	graph_edit.scroll_offset = offset

	# 创建节点（位置不受 zoom 影响，是画布坐标系）
	var start = blueprint_data.add_node("start", Vector2(0, 0))
	_create_node_ui(start)

	load_blueprint()
	get_viewport().set_input_as_handled()


func _setup_editor_layout():
	# 将现有 GraphEdit 从根节点移动到新的布局容器中
	remove_child(graph_edit)
	add_child(graph_edit)
	move_child(graph_edit, 0)
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND

func _create_palette_panel():
	var palette_container = HBoxContainer.new()
	palette_container.name = "PaletteContainer"
	palette_container.set_anchors_preset(PRESET_LEFT_WIDE)
	palette_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	palette_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(palette_container)

	var palette = PanelContainer.new()
	palette.name = "PalettePanel"
	palette.custom_minimum_size = Vector2(120, 0)
	palette.size_flags_horizontal = Control.SIZE_EXPAND
	palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_container.add_child(palette)

	var scroll = ScrollContainer.new()
	scroll.name = "PaletteContent"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.clip_contents = true

	palette.add_child(scroll)

	var content = VBoxContainer.new()
	content.name = "PaletteContent"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	for category_name in _get_scratch_palette().keys():
		var section = VBoxContainer.new()
		section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var header = Label.new()
		header.text = category_name
		header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		header.add_theme_font_size_override("font_size", 14)
		section.add_child(header)

		for type_id in _get_scratch_palette()[category_name]:
			var def = NodeDatabase.get_node_type(type_id)
			if def.is_empty():
				continue
			var btn = Button.new()
			btn.text = def.get("name", type_id)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.focus_mode = Control.FOCUS_NONE
			btn.pressed.connect(func(tid=type_id): _on_palette_node_pressed(tid))
			section.add_child(btn)

		content.add_child(section)

	var toggle_btn = Button.new()
	toggle_btn.name = "PaletteToggleButton"
	toggle_btn.text = "隐藏"
	toggle_btn.custom_minimum_size = Vector2(36, 24)
	toggle_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	toggle_btn.focus_mode = Control.FOCUS_NONE
	toggle_btn.pressed.connect(func(pal=palette, btn=toggle_btn):
		pal.visible = not pal.visible
		btn.text = "隐藏" if pal.visible else "显示"
	)
	palette_container.add_child(toggle_btn)

	# 让 GraphEdit 右移以给 palette 留出位置
	# 这个布局由 HBoxContainer 管理，不需要手动设置 margin

func _get_scratch_palette() -> Dictionary:
	return {
		"事件": ["event_print", "event_receive", "event_signal"],
		"控制": ["control_if", "control_if_else", "control_repeat", "control_repeat_limit", "control_while", "control_for", "control_break", "control_continue"],
		"运算": ["math_add", "math_subtract", "math_multiply", "math_divide", 
				"compare_equal", "compare_not_equal", "compare_greater", "compare_greater_equal", "compare_less", "compare_less_equal", 
				"logic_and", "logic_or", "logic_not", "logic_xor"],
		"变量": ["type_int", "type_float", "type_string", "type_bool", "get_variable", "set_variable"],
		"检测": ["detect_distance", "timer_define", "timer_call", "timer_start", "timer_pause", "timer_stop", "timer_wait", "timer_elapsed"],
		"函数": ["func_define_new", "func_call"]
	}

func _on_palette_node_pressed(type_id: String):
	var world_pos = _get_viewport_center_position()
	var node = blueprint_data.add_node(type_id, world_pos)
	_create_node_ui(node)

## 获取当前 GraphEdit 视口中心的画布坐标
func _get_viewport_center_position() -> Vector2:
	# 获取 GraphEdit 的视口尺寸
	var viewport_size = graph_edit.size
	# 视口中心在屏幕上的位置
	var viewport_center = viewport_size / 2
	# 获取当前缩放
	var current_zoom = 1.0
	if graph_edit.has_method("get_zoom"):
		current_zoom = graph_edit.get_zoom()
	elif "zoom" in graph_edit:
		current_zoom = graph_edit.zoom
	# 转换为画布坐标（考虑滚动偏移和缩放）
	var canvas_pos = (viewport_center + graph_edit.scroll_offset) / current_zoom
	return canvas_pos

# 右键菜单构建（主入口）
func _setup_popup_menu():
	popup_menu.clear()
	
	# ----- 添加事件 -----
	var event_menu = PopupMenu.new()
	event_menu.add_item("发射信号")
	event_menu.add_item("接受信号")
	event_menu.add_item("暂停模拟")
	event_menu.add_item("继续模拟")
	event_menu.add_item("终止模拟")
	event_menu.add_item("打印")
	event_menu.id_pressed.connect(_on_event_menu_pressed)
	popup_menu.add_submenu_node_item("添加事件", event_menu)
	
	# ----- 添加控制 -----
	var control_menu = PopupMenu.new()
	
	# 判断子菜单
	var if_menu = PopupMenu.new()
	if_menu.add_item("if分支")
	if_menu.add_item("if/else分支")
	if_menu.id_pressed.connect(_on_if_menu_pressed)
	control_menu.add_submenu_node_item("添加判断", if_menu)
	
	# 循环子菜单
	var loop_menu = PopupMenu.new()
	loop_menu.add_item("while循环")
	loop_menu.add_item("for循环")
	loop_menu.add_item("重复执行")
	loop_menu.add_item("重复执行n次")
	loop_menu.add_item("重复执行...直到...")
	loop_menu.id_pressed.connect(_on_loop_menu_pressed)
	control_menu.add_submenu_node_item("添加循环", loop_menu)
	
	control_menu.add_item("break")
	control_menu.add_item("continue")
	control_menu.id_pressed.connect(_on_control_menu_pressed)
	popup_menu.add_submenu_node_item("添加控制", control_menu)

	# ----- 添加计算 -----
	var calculate_menu = _build_calculate_menu()
	popup_menu.add_submenu_node_item("添加计算", calculate_menu)

	# ----- 添加对象 -----
	var object_menu = _build_object_menu()
	popup_menu.add_submenu_node_item("添加对象", object_menu)

	# ----- 添加检测 -----
	var detection_menu = _build_detection_menu()
	popup_menu.add_submenu_node_item("添加检测", detection_menu)
	
	# ----- 添加变量 -----
	var variate_menu = _build_variate_menu()
	popup_menu.add_submenu_node_item("添加变量", variate_menu)

	# ----- 自定义函数 -----
	_build_custom_function_menu()
	
	# ----- 分割线 + 复制/粘贴/删除 -----
	popup_menu.add_separator()
	popup_menu.add_item("复制", 8)
	popup_menu.add_item("粘贴", 9)
	popup_menu.add_item("删除", 10)
	# 验证 ID 是否设置正确
	# print("添加后验证:")
	# print("复制 ID: ", popup_menu.get_item_id(popup_menu.get_item_index(8)))
	# print("粘贴 ID: ", popup_menu.get_item_id(popup_menu.get_item_index(9)))
	# print("删除 ID: ", popup_menu.get_item_id(popup_menu.get_item_index(10)))
	
	# 连接主菜单信号
	popup_menu.id_pressed.connect(_on_popup_menu_pressed)

# 子菜单构建函数
## 构建"添加计算"菜单
func _build_calculate_menu() -> PopupMenu:
	# 1. 四则运算
	var arithmetic_menu = PopupMenu.new()
	arithmetic_menu.add_item("加法")
	arithmetic_menu.add_item("减法")
	arithmetic_menu.add_item("乘法")
	arithmetic_menu.add_item("除法")
	arithmetic_menu.id_pressed.connect(_on_arithmetic_menu_pressed)

	# 2. 幂/根/模
	var power_menu = PopupMenu.new()
	power_menu.add_item("幂运算")
	power_menu.add_item("平方根")
	power_menu.add_item("取模")
	power_menu.id_pressed.connect(_on_power_menu_pressed)

	# 3. 超越函数
	var transcendental_menu = PopupMenu.new()
	transcendental_menu.add_item("正弦")
	transcendental_menu.add_item("余弦")
	transcendental_menu.add_item("正切")
	transcendental_menu.add_item("反正弦")
	transcendental_menu.add_item("反余弦")
	transcendental_menu.add_item("反正切")
	transcendental_menu.add_item("自然对数")
	transcendental_menu.add_item("常用对数")
	transcendental_menu.add_item("指数")
	transcendental_menu.id_pressed.connect(_on_transcendental_menu_pressed)

	# 4. 计数组合
	var combinatorics_menu = PopupMenu.new()
	combinatorics_menu.add_item("阶乘")
	combinatorics_menu.add_item("排列")
	combinatorics_menu.add_item("组合")
	combinatorics_menu.id_pressed.connect(_on_combinatorics_menu_pressed)

	# 5. 数值比较
	var compare_menu = PopupMenu.new()
	compare_menu.add_item("等于")
	compare_menu.add_item("不等于")
	compare_menu.add_item("大于")
	compare_menu.add_item("大于等于")
	compare_menu.add_item("小于")
	compare_menu.add_item("小于等于")
	compare_menu.id_pressed.connect(_on_compare_menu_pressed)

	# 6. 逻辑运算
	var logic_menu = PopupMenu.new()
	logic_menu.add_item("与 (AND)")
	logic_menu.add_item("或 (OR)")
	logic_menu.add_item("非 (NOT)")
	logic_menu.add_item("异或 (XOR)")
	logic_menu.id_pressed.connect(_on_logic_menu_pressed)

	# 7. 拓展运算（向量）
	var extension_menu = PopupMenu.new()
	extension_menu.add_item("向量加法")
	extension_menu.add_item("向量减法")
	extension_menu.add_item("向量点积")
	extension_menu.add_item("向量叉积")
	extension_menu.add_item("向量归一化")
	extension_menu.add_item("向量长度")
	extension_menu.id_pressed.connect(_on_extension_menu_pressed)

	# 组装
	var calculate_menu = PopupMenu.new()
	calculate_menu.add_submenu_node_item("四则运算", arithmetic_menu)
	calculate_menu.add_submenu_node_item("幂/根/模", power_menu)
	calculate_menu.add_submenu_node_item("超越函数", transcendental_menu)
	calculate_menu.add_submenu_node_item("计数组合", combinatorics_menu)
	calculate_menu.add_submenu_node_item("数值比较", compare_menu)
	calculate_menu.add_submenu_node_item("逻辑运算", logic_menu)
	calculate_menu.add_submenu_node_item("拓展运算", extension_menu)

	return calculate_menu

## 构建"添加计算"菜单
func _build_object_menu() -> PopupMenu:
	# ----- 添加对象 -----
	var object_menu = PopupMenu.new()
	object_menu.name = "添加对象"

	# 1. 调用对象（现有列表）
	_objects_list_menu = PopupMenu.new()
	_objects_list_menu.name = "调用对象"
	_populate_objects_menu(_objects_list_menu)
	object_menu.add_submenu_node_item("调用对象", _objects_list_menu)

	# 2. 对象属性
	var property_menu = PopupMenu.new()
	property_menu.name = "对象属性"
	property_menu.add_item("类型")
	property_menu.add_item("位置")
	property_menu.add_item("数值")
	property_menu.add_item("方向")
	property_menu.add_item("名称")
	property_menu.add_item("尺寸")
	property_menu.add_item("颜色")
	property_menu.id_pressed.connect(_on_object_property_menu_pressed)
	object_menu.add_submenu_node_item("对象属性", property_menu)

	# 3. 对象操作
	var action_menu = PopupMenu.new()
	action_menu.name = "对象操作"
	action_menu.add_item("打印对象数据")
	action_menu.add_item("启用对象")
	action_menu.add_item("禁用对象")
	action_menu.id_pressed.connect(_on_object_action_menu_pressed)
	object_menu.add_submenu_node_item("对象操作", action_menu)

	return object_menu

## 构建"添加检测"菜单
func _build_detection_menu() -> PopupMenu:
	var detection_menu = PopupMenu.new()
	detection_menu.name = "添加检测"

	# 1. 碰撞检测
	var collision_menu = PopupMenu.new()
	collision_menu.name = "碰撞检测"
	collision_menu.add_item("碰撞检测")
	collision_menu.id_pressed.connect(_on_collision_menu_pressed)
	detection_menu.add_submenu_node_item("碰撞检测", collision_menu)

	# 2. 输入检测
	var input_menu = PopupMenu.new()
	input_menu.name = "输入检测"
	input_menu.add_item("按键是否按下")
	input_menu.id_pressed.connect(_on_input_menu_pressed)
	detection_menu.add_submenu_node_item("输入检测", input_menu)

	# 3. 环境数据
	var environment_menu = PopupMenu.new()
	environment_menu.name = "环境数据"
	environment_menu.add_item("距离检测")
	environment_menu.id_pressed.connect(_on_environment_menu_pressed)
	detection_menu.add_submenu_node_item("环境数据", environment_menu)

	# 4. 计时器
	var state_menu = PopupMenu.new()
	state_menu.name = "计时器"
	state_menu.add_item("定义计时器")
	
	# 调用计时器作为子菜单（像调用变量一样）
	var timer_call_submenu = PopupMenu.new()
	timer_call_submenu.name = "调用计时器"
	_refresh_all_dynamic_lists()
	state_menu.add_submenu_node_item("调用计时器", timer_call_submenu)
	# 保存引用
	_call_timer_menu = timer_call_submenu
	
	state_menu.add_item("开始计时")
	state_menu.add_item("暂停计时")
	state_menu.add_item("终止计时")
	state_menu.add_item("等待时间")
	state_menu.add_item("运行时间")
	state_menu.id_pressed.connect(_on_state_menu_pressed)
	detection_menu.add_submenu_node_item("计时器", state_menu)

	return detection_menu

## 构建"添加变量"菜单
func _build_variate_menu() -> PopupMenu:
	var variate_menu = PopupMenu.new()
	variate_menu.name = "添加变量"

	# 1. 数据类型
	var data_type_menu = PopupMenu.new()
	data_type_menu.name = "数据类型"
	data_type_menu.add_item("bool (布尔)")
	data_type_menu.add_item("int (整数)")
	data_type_menu.add_item("float (浮点数)")
	data_type_menu.add_item("string (字符串)")
	data_type_menu.add_item("Vector2 (二维向量)")
	data_type_menu.add_item("Vector3 (三维向量)")
	data_type_menu.add_item("Vector4 (四维向量)")
	data_type_menu.add_item("Array (数组)")
	data_type_menu.add_item("Dictionary (字典)")
	data_type_menu.id_pressed.connect(_on_data_type_menu_pressed)
	variate_menu.add_submenu_node_item("数据类型", data_type_menu)

	# 2. 数据操作
	var data_operation_menu = PopupMenu.new()
	data_operation_menu.name = "数据操作"
	data_operation_menu.add_item("类型转换")
	data_operation_menu.add_item("获取长度")
	data_operation_menu.add_item("遍历字典")
	data_operation_menu.add_item("获取数组元素")
	data_operation_menu.add_item("获取向量数值")
	data_operation_menu.add_item("判断是否为空")
	data_operation_menu.add_separator()
	data_operation_menu.add_item("设置变量")
	data_operation_menu.add_item("获取变量")
	data_operation_menu.id_pressed.connect(_on_data_operation_menu_pressed)
	variate_menu.add_submenu_node_item("数据操作", data_operation_menu)

	# 3. 类型转换（快捷方式）
	var cast_menu = PopupMenu.new()
	cast_menu.name = "类型转换"
	cast_menu.add_item("float → int")
	cast_menu.add_item("int → float")
	cast_menu.add_item("string → float")
	cast_menu.add_item("string → int")
	cast_menu.add_item("string → Vector2")
	cast_menu.add_item("string → Vector3")
	cast_menu.id_pressed.connect(_on_cast_menu_pressed)
	variate_menu.add_submenu_node_item("类型转换", cast_menu)

	# 4. 调用变量
	var call_var_menu = PopupMenu.new()
	call_var_menu.name = "调用变量"
	_refresh_all_dynamic_lists()
	variate_menu.add_submenu_node_item("调用变量", call_var_menu)
	
	# 保存引用到全局变量（新增）
	_call_var_menu = call_var_menu

	return variate_menu

## 构建"自定义函数"菜单
func _build_custom_function_menu():
	var custom_func_menu = PopupMenu.new()
	custom_func_menu.name = "自定义函数"

	# 1. 定义函数
	var define_menu = PopupMenu.new()
	define_menu.name = "定义函数"
	define_menu.add_item("定义新函数")
	define_menu.id_pressed.connect(_on_custom_define_menu_pressed)
	custom_func_menu.add_submenu_node_item("定义函数", define_menu)

	# 2. 调用函数（动态填充）
	var call_menu = PopupMenu.new()
	call_menu.name = "调用函数"
	_refresh_all_dynamic_lists()
	custom_func_menu.add_submenu_node_item("调用函数", call_menu)

	# 保存引用用于动态刷新
	_call_func_menu = call_menu
	popup_menu.add_submenu_node_item("自定义函数", custom_func_menu)

# 自定义函数 → 调用函数动态刷新
## 刷新"调用函数"子菜单（根据已定义的函数动态更新）
func _refresh_call_function_menu(menu: PopupMenu):
	if menu == null:
		# print("错误: 调用函数菜单引用为空")
		return
	
	menu.clear()
	# print("=== 刷新调用函数菜单 ===")
	
	var func_names = _get_defined_function_names()
	# print("找到的函数: ", func_names)
	
	if func_names.is_empty():
		menu.add_item("暂无已定义函数")
		# 直接设置禁用状态，无需 get_item_index
		menu.set_item_disabled(0, true)
		return
	
	for func_name in func_names:
		menu.add_item(func_name)
		# print("添加函数: ", func_name)
	
	# 断开旧连接，避免重复
	if menu.id_pressed.is_connected(_on_call_function_pressed):
		menu.id_pressed.disconnect(_on_call_function_pressed)
	menu.id_pressed.connect(_on_call_function_pressed)
	# print("=== 刷新完成，共 ", menu.get_item_count(), " 项 ===")

func _get_defined_function_names() -> Array:
	var names = []
	for node in blueprint_data.nodes.values():
		if node.type_id == "func_define_new":
			var func_name = node.properties.get("func", "")
			if func_name != "" and func_name != "func":
				if func_name not in names:
					names.append(func_name)
	return names

## 获取所有已定义的计时器名称（从蓝图节点中收集）
func _get_defined_timer_names() -> Array:
	var names = []
	for node in blueprint_data.nodes.values():
		if node.type_id == "timer_define":
			var timer_name = node.properties.get("名称", "")
			if timer_name != "" and timer_name != "timer":
				if timer_name not in names:
					names.append(timer_name)
	return names

func _on_call_function_pressed(id: int):
	var menu = _call_func_menu
	if menu == null:
		return
	if id < menu.get_item_count():
		var func_name = menu.get_item_text(id)
		# 使用画布坐标
		var canvas_pos = _get_mouse_canvas_position()
		var node = blueprint_data.add_node("func_call", canvas_pos)
		node.properties["func"] = func_name
		_create_node_ui(node)
		# print("调用函数: ", func_name)


# 主菜单点击处理（含复制/粘贴/删除）
func _on_popup_menu_pressed(id: int):
	# print("=== _on_popup_menu_pressed 被调用，ID: ", id, " ===")
	match id:
		8:
			# print("执行复制")
			_copy_selected_node()
			return
		9:
			# print("执行粘贴")
			_paste_node()
			return
		10:
			# print("执行删除")
			_delete_selected_node()
			return


# "添加对象"菜单（从 GlobalData 动态读取）
## 填充"添加对象"子菜单
func _populate_objects_menu(menu: PopupMenu):
	menu.clear()
	
	if not GlobalData:
		menu.add_item("无数据")
		menu.set_item_disabled(0, true)
		return
	
	if not "run_project_data" in GlobalData:
		menu.add_item("无数据")
		menu.set_item_disabled(0, true)
		return
	
	var data = GlobalData.run_project_data
	if data == null or data.is_empty():
		menu.add_item("无数据")
		menu.set_item_disabled(0, true)
		return
	
	# 收集所有来源的ID（fields / objects / grounds）
	var all_ids = []
	var data_sources = ["fields", "objects", "grounds"]
	
	for source in data_sources:
		if data.has(source):
			var source_data = data[source]
			if source_data is Dictionary:
				for key in source_data.keys():
					var key_str = str(key).pad_zeros(6)
					if key_str not in all_ids:
						all_ids.append(key_str)
	
	if all_ids.is_empty():
		menu.add_item("暂无对象")
		menu.set_item_disabled(0, true)
		return
	
	all_ids.sort()
	
	for id_str in all_ids:
		var source_name = _get_id_source(id_str, data)
		menu.add_item(id_str + " (" + source_name + ")")
	
	menu.id_pressed.connect(_on_objects_menu_pressed)

## 获取ID对应的数据来源名称
func _get_id_source(id_str: String, data: Dictionary = {}) -> String:
	if data.is_empty():
		data = GlobalData.run_project_data
	
	var data_sources = ["fields", "objects", "grounds"]
	for source in data_sources:
		if data.has(source):
			var source_data = data[source]
			if source_data is Dictionary and source_data.has(id_str):
				match source:
					"fields": return "物理场"
					"objects": return "研究对象"
					"grounds": return "接触面"
	return "未知"

func _get_objects_menu() -> PopupMenu:
	return _objects_list_menu

## 点击对象菜单项 → 在蓝图中创建对象面板
func _on_objects_menu_pressed(id: int):
	var menu = _get_objects_menu()
	if menu == null:
		return
	
	if id < menu.get_item_count():
		var display_text = menu.get_item_text(id)
		var parts = display_text.split(" ")
		if parts.size() > 0:
			_add_object_node(parts[0])


## 在蓝图中创建对象面板（节点）
func _add_object_node(id_str: String):
	if not GlobalData or not "run_project_data" in GlobalData:
		return
	
	var data = GlobalData.run_project_data
	if data == null:
		return
	
	var data_sources = ["fields", "objects", "grounds"]
	var found_data = null
	var found_source = ""
	
	for source in data_sources:
		if data.has(source):
			var source_data = data[source]
			if source_data is Dictionary and source_data.has(id_str):
				found_data = source_data[id_str]
				found_source = source
				break
	
	if found_data == null:
		# print("警告: 未找到 ID ", id_str)
		return
	
	# 使用与 _add_node 相同的位置计算
	var canvas_pos = _get_mouse_canvas_position()
	var world_pos = _find_free_position(canvas_pos)
	
	var node_type = "object_panel"
	var node = blueprint_data.add_node(node_type, world_pos)
	node.properties["id_code"] = id_str
	node.properties["data_source"] = found_source
	node.properties["object_data"] = found_data.duplicate(true)
	node.properties["display_name"] = found_data.get("name", id_str)
	
	_create_node_ui(node)


# 节点创建与UI管理
## 添加节点（根据类型）
func _add_node(type_id: String):
	var canvas_pos = _get_mouse_canvas_position()
	var world_pos = _find_free_position(canvas_pos)
	var node = blueprint_data.add_node(type_id, world_pos)
	_create_node_ui(node)


## 查找空闲位置（避免节点重叠）
func _find_free_position(base_pos: Vector2, size: Vector2 = Vector2(80, 80)) -> Vector2:
	var test_pos = base_pos
	var attempts = 0
	var max_attempts = 10
	var offset_step = 10
	
	while attempts < max_attempts:
		var occupied = false
		for node in node_ui_map.values():
			var rect = Rect2(node.position, node.size)
			if rect.intersects(Rect2(test_pos, size)):
				occupied = true
				break
		if not occupied:
			return test_pos
		var angle = attempts * 1.5
		test_pos = base_pos + Vector2(cos(angle), sin(angle)) * offset_step * attempts
		attempts += 1
	
	return base_pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))

## 创建节点UI
func _create_node_ui(node: BlueprintNode):
	var ui = BlueprintNodeUI.new()
	ui.setup(node)
	ui.name = str(node.id)		  # 先设置名称
	graph_edit.add_child(ui)		# 再添加
	ui.name = str(node.id)		  # 再次确认（防止被覆盖）
	ui.position_offset = node.position
	node_ui_map[node.id] = ui
	
	_refresh_all_dynamic_lists()

# 连接管理
func _on_connection_request(from_node: String, from_port: int, to_node: String, to_port: int):
	var from_id = int(from_node)
	var to_id = int(to_node)
	
	# print("连接请求: ", from_id, " (端口", from_port, ") -> ", to_id, " (端口", to_port, ")")
	
	# 检查连接是否已存在
	for link in blueprint_data.links.values():
		if link.from_node_id == from_id and link.from_port == from_port and link.to_node_id == to_id and link.to_port == to_port:
			# print("连接已存在，跳过")
			return
	
	# 检查是否连接到自身
	if from_id == to_id:
		# print("不能连接到自身")
		return
	
	# 添加到数据
	var _link = blueprint_data.add_link(from_id, from_port, to_id, to_port)
	# print("连接已添加")
	
	# 添加到 GraphEdit
	graph_edit.connect_node(from_node, from_port, to_node, to_port)


func _on_disconnection_request(from_node: String, from_port: int, to_node: String, to_port: int):
	var from_id = int(from_node)
	var to_id = int(to_node)
	
	for link_id in blueprint_data.links.keys():
		var link = blueprint_data.links[link_id]
		if link.from_node_id == from_id and link.from_port == from_port and link.to_node_id == to_id and link.to_port == to_port:
			blueprint_data.remove_link(link_id)
			graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
			break

# 删除节点
func _on_delete_nodes_request(nodes: Array):
	for node_name in nodes:
		var node_id = int(node_name)
		var node = blueprint_data.get_node(node_id)
		if node != null and node.is_deletable():
			_delete_node(node_id)
	_refresh_graph_edit()

func _delete_node(node_id: int):
	var ui = node_ui_map.get(node_id)
	if ui:
		ui.queue_free()
		node_ui_map.erase(node_id)
	
	blueprint_data.remove_node(node_id)
	
	_refresh_all_dynamic_lists()

## 刷新GraphEdit中的连接显示
func _refresh_graph_edit():
	# 清除所有连接
	for conn in graph_edit.get_connection_list():
		graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
	
	# 重新添加
	for link in blueprint_data.links.values():
		var from_node = str(link.from_node_id)
		var to_node = str(link.to_node_id)
		graph_edit.connect_node(from_node, link.from_port, to_node, link.to_port)


# 右键菜单弹出与交互控制
func _on_popup_request(position: Vector2):
	# 刷新调用函数菜单
	_refresh_call_function_menu(_call_func_menu)
	# 刷新调用变量子菜单
	_refresh_call_variable_menu(_call_var_menu)
	# 刷新调用计时器子菜单
	_refresh_call_timer_menu(_call_timer_menu)
	
	# 获取鼠标在 GraphEdit 中的局部位置
	var local_mouse = graph_edit.get_local_mouse_position()
	# print("鼠标局部位置: ", local_mouse)
	
	# 获取当前缩放
	var current_zoom = 1.0
	if graph_edit.has_method("get_zoom"):
		current_zoom = graph_edit.get_zoom()
	elif "zoom" in graph_edit:
		current_zoom = graph_edit.zoom
	
	# 转换为画布坐标（与节点位置一致）
	var canvas_pos = (local_mouse + graph_edit.scroll_offset) / current_zoom
	# print("画布坐标: ", canvas_pos)
	
	# 检测鼠标下的节点（使用画布坐标）
	var hit_node: BlueprintNodeUI = null
	for node in node_ui_map.values():
		if node is BlueprintNodeUI:
			var rect = Rect2(node.position_offset, node.size)
			if rect.has_point(canvas_pos):
				hit_node = node
				# print("命中节点: ", node.title, " 位置: ", node.position_offset)
				break
	
	# 更新选中状态
	if hit_node != null:
		_select_node(hit_node)
	else:
		_clear_selection()
	
	# 获取复制、粘贴、删除的索引
	var copy_idx = popup_menu.get_item_index(8)
	var paste_idx = popup_menu.get_item_index(9)
	var delete_idx = popup_menu.get_item_index(10)
	
	# 默认禁用所有操作
	popup_menu.set_item_disabled(copy_idx, true)
	popup_menu.set_item_disabled(paste_idx, true)
	popup_menu.set_item_disabled(delete_idx, true)
	
	if hit_node != null:
		var node_data = blueprint_data.get_node(hit_node.get_node_id())
		if node_data != null:
			var type_id = node_data.type_id
			# print("右键点击节点类型: ", type_id)
			if type_id == "start":
				# print("开始/结束：全部禁用")
				# 保持禁用
				pass
			elif type_id == "func_define_new":
				# print("定义函数：复制禁用，粘贴删除启用")
				popup_menu.set_item_disabled(copy_idx, true)
				popup_menu.set_item_disabled(paste_idx, false)
				popup_menu.set_item_disabled(delete_idx, false)
			else:
				# print("普通节点：全部启用")
				popup_menu.set_item_disabled(copy_idx, false)
				popup_menu.set_item_disabled(paste_idx, false)
				popup_menu.set_item_disabled(delete_idx, false)
	else:
		# print("空白区域：仅粘贴可用")
		if not _clipboard_data.is_empty():
			popup_menu.set_item_disabled(paste_idx, false)
	
	# print("最终状态: 复制=", popup_menu.is_item_disabled(copy_idx), 
			# " 粘贴=", popup_menu.is_item_disabled(paste_idx),
			# " 删除=", popup_menu.is_item_disabled(delete_idx))
	
	popup_menu.position = DisplayServer.mouse_get_position()
	popup_menu.popup()


func _on_node_selected_save(node: Node):
	if node is BlueprintNodeUI:
		_selected_node_id = node.get_node_id()
	else:
		_selected_node_id = -1

# 复制 / 粘贴 / 删除（针对单个选中节点）
## 获取当前选中的节点（从 GraphEdit 子节点中查找）
func _get_selected_node() -> BlueprintNodeUI:
	for node in graph_edit.get_children():
		if node is BlueprintNodeUI and node.is_selected():
			return node
	return null

## 选中指定节点，并取消其他节点的选中状态
func _select_node(node: BlueprintNodeUI):
	# 取消所有节点的选中状态
	for child in graph_edit.get_children():
		if child is BlueprintNodeUI:
			child.set_selected(false)
	# 选中目标节点
	if node:
		node.set_selected(true)
		# 将节点置于顶层（可选）
		node.move_to_front()

## 清空所有选中状态
func _clear_selection():
	for child in graph_edit.get_children():
		if child is BlueprintNodeUI:
			child.set_selected(false)


func _copy_selected_node():
	var selected = _get_selected_node()
	if selected == null:
		# print("复制失败：没有选中的节点")
		return
	
	var node_data = blueprint_data.get_node(selected.get_node_id())
	if node_data == null:
		return
	
	if node_data.type_id == "start":
		# print("复制失败：开始/结束节点不可复制")
		return
	
	_clipboard_data = {
		"type_id": node_data.type_id,
		"properties": node_data.properties.duplicate(true),
		"position": node_data.position
	}
	print("复制成功：", node_data.type_id)

func _paste_node():
	if _clipboard_data.is_empty():
		# print("粘贴失败：剪贴板为空")
		return
	
	# 使用画布坐标
	var canvas_pos = _get_mouse_canvas_position()
	var new_pos = canvas_pos + Vector2(30, 30)  # 偏移避免完全重叠
	
	var node = blueprint_data.add_node(_clipboard_data["type_id"], new_pos)
	node.properties = _clipboard_data["properties"].duplicate(true)
	
	_create_node_ui(node)
	
	var ui = node_ui_map.get(node.id)
	if ui:
		_select_node(ui)
	
	print("粘贴成功，新节点 ID: ", node.id)

func _delete_selected_node():
	var selected = _get_selected_node()
	if selected == null:
		# print("删除失败：没有选中的节点")
		return
	
	var node_data = blueprint_data.get_node(selected.get_node_id())
	if node_data == null:
		return
	
	if node_data.type_id == "start":
		# print("删除失败：开始/结束节点不可删除")
		return
	
	_delete_node(selected.get_node_id())
	_clear_selection()
	print("删除成功")

## 清空所有选中节点
func clear_selection():
	for node in graph_edit.get_children():
		if node is BlueprintNodeUI:
			node.set_selected(false)

## 选中指定节点
func select_graph_element(node: BlueprintNodeUI):
	node.set_selected(true)

## 获取鼠标在画布坐标系中的位置
func _get_mouse_canvas_position() -> Vector2:
	var local_mouse = graph_edit.get_local_mouse_position()
	var current_zoom = 1.0
	if graph_edit.has_method("get_zoom"):
		current_zoom = graph_edit.get_zoom()
	elif "zoom" in graph_edit:
		current_zoom = graph_edit.zoom
	return (local_mouse + graph_edit.scroll_offset) / current_zoom

## 刷新"调用变量"子菜单
func _refresh_call_variable_menu(menu: PopupMenu):
	if menu == null:
		return
	
	menu.clear()
	
	var var_names = _get_declared_variable_names()
	
	if var_names.is_empty():
		menu.add_item("暂无已声明变量")
		menu.set_item_disabled(0, true)
		return
	
	for var_name in var_names:
		menu.add_item(var_name)
	
	if menu.id_pressed.is_connected(_on_call_variable_pressed):
		menu.id_pressed.disconnect(_on_call_variable_pressed)
	menu.id_pressed.connect(_on_call_variable_pressed)

## 获取所有已声明的变量
func _get_declared_variable_names() -> Array:
	var names = []
	var var_types = [
		"type_bool", "type_int", "type_float", "type_string",
		"type_vector2", "type_vector3", "type_vector4",
		"type_array", "type_dictionary"
	]
	for node in blueprint_data.nodes.values():
		if node.type_id in var_types:
			var var_name = node.properties.get("变量", "")
			if var_name != "" and var_name not in names:
				names.append(var_name)
	return names

## 点击调用变量菜单项 → 创建调用变量节点
func _on_call_variable_pressed(id: int):
	var menu = _call_var_menu
	if menu == null:
		return
	if id < menu.get_item_count():
		var var_name = menu.get_item_text(id)
		var canvas_pos = _get_mouse_canvas_position()
		# 创建"获取变量"节点
		var node = blueprint_data.add_node("get_variable", canvas_pos)
		node.properties["变量"] = var_name
		_create_node_ui(node)
		print("调用变量: ", var_name)

## 保存蓝图到文件
# BlueprintEditor.gd

## 保存蓝图（不额外包裹）
func save_blueprint(path: String = "user://blueprint.save"):
	var data = blueprint_data.serialize()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("保存失败：无法打开文件 ", path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("蓝图已保存到: ", path)

## 加载蓝图
func load_blueprint(path: String = "user://blueprint.save"):
	if not FileAccess.file_exists(path):
		print("加载失败：文件不存在 ", path)
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("解析JSON失败: ", json.get_error_message())
		return
	
	var data = json.data as Dictionary
	
	# 清空当前蓝图
	_clear_all_nodes()
	blueprint_data.deserialize(data)

	# 重建节点
	for node_id in blueprint_data.nodes.keys():
		var node = blueprint_data.get_node(node_id)
		_create_node_ui(node)

	# 调试：打印所有节点名称
	# print("=== 加载后的节点列表 ===")
	# for child in graph_edit.get_children():
	# 	if child is GraphNode:
	# 		print("节点名称: ", child.name, " 类型: ", child.get_class())
	# print("==========================")

	await get_tree().process_frame
	 # 刷新变量下拉列表
	refresh_all_variable_options()
	# 刷新函数名下啦列表
	refresh_all_function_options()
	# 刷新计时器菜单和下拉选项
	_refresh_call_timer_menu(_call_timer_menu)
	_refresh_timer_options()
	_restore_connections()

	# 再次强制刷新选中的值
	for ui in node_ui_map.values():
		if ui is BlueprintNodeUI:
			ui.force_update_selection()


func _restore_connections():
	# 清除所有现有连接
	for conn in graph_edit.connections:
		graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
	
	# print("=== 开始恢复连接 ===")
	# print("连接总数: ", blueprint_data.links.size())
	
	# 打印所有节点名称
	var node_names = []
	for child in graph_edit.get_children():
		if child is GraphNode:
			node_names.append(child.name)
	# print("GraphEdit 中的节点: ", node_names)
	
	# var count = 0
	for link in blueprint_data.links.values():
		var from_node = str(link.from_node_id)
		var to_node = str(link.to_node_id)
		# print("尝试连接: ", from_node, " -> ", to_node)
		if graph_edit.has_node(from_node) and graph_edit.has_node(to_node):
			graph_edit.connect_node(from_node, link.from_port, to_node, link.to_port)
			# count += 1
			# print("  连接成功")
		# else:
		# 	print("  连接失败：节点不存在")
	
	# print("已恢复 ", count, " 条连接")
	graph_edit.queue_redraw()

func _clear_all_nodes():
	# 移除 GraphEdit 中的所有 GraphNode
	for child in graph_edit.get_children():
		if child is GraphNode:
			graph_edit.remove_child(child)
			child.queue_free()

	node_ui_map.clear()
	graph_edit.connections.clear()
	blueprint_data.nodes.clear()
	blueprint_data.links.clear()
	blueprint_data.next_id = 0


func _refresh_variable_options():
	var var_names = _get_declared_variable_names()
	# print("刷新变量列表: ", var_names)
	for node_ui in node_ui_map.values():
		if node_ui.node_data.type_id in ["get_variable", "set_variable"]:
			node_ui.refresh_variable_options(var_names)

func _on_zoom_changed(zoom: Vector2):
	# 隐藏所有 OptionButton 的下拉菜单
	_close_all_dropdowns()

func _close_all_dropdowns():
	for node_ui in node_ui_map.values():
		for child in node_ui.get_children():
			if child is HBoxContainer:
				for sub in child.get_children():
					if sub is OptionButton:
						sub.get_popup().hide()

func _refresh_function_options():
	var func_names = get_declared_function_names()
	for ui in node_ui_map.values():
		if ui.node_data.type_id == "func_call":
			ui.refresh_function_options(func_names)

func get_declared_function_names() -> Array:
	var names = []
	for node in blueprint_data.nodes.values():
		if node.type_id == "func_define_new":
			var func_name = node.properties.get("func", "")
			if func_name != "" and func_name not in names:
				names.append(func_name)
	return names

## 刷新所有变量下拉列表
func refresh_all_variable_options():
	var var_names = _get_declared_variable_names()
	for ui in node_ui_map.values():
		if ui.node_data.type_id in ["get_variable", "set_variable"]:
			ui.refresh_variable_options(var_names)
	# 同时刷新调用变量菜单
	_refresh_call_variable_menu(_call_var_menu)

## 刷新所有函数名下拉列表
func refresh_all_function_options():
	var func_names = get_declared_function_names()
	for ui in node_ui_map.values():
		if ui.node_data.type_id == "func_call":
			ui.refresh_function_options(func_names)
	# 同时刷新调用函数菜单
	_refresh_call_function_menu(_call_func_menu)

func _mark_modified():
	_is_modified = true


func _refresh_timer_options():
	var timer_names = _get_defined_timer_names()
	for ui in node_ui_map.values():
		if ui.node_data.type_id in ["timer_call", "timer_start", "timer_pause", "timer_stop"]:
			ui.refresh_timer_options(timer_names)


func _refresh_call_timer_menu(menu: PopupMenu):
	if menu == null:
		return
	menu.clear()
	
	var timer_names = _get_defined_timer_names()
	if timer_names.is_empty():
		menu.add_item("暂无已定义计时器")
		menu.set_item_disabled(0, true)
		return
	
	for name in timer_names:
		menu.add_item(name)
	
	# 断开旧连接，避免重复触发
	if menu.id_pressed.is_connected(_on_call_timer_menu_pressed):
		menu.id_pressed.disconnect(_on_call_timer_menu_pressed)
	menu.id_pressed.connect(_on_call_timer_menu_pressed)

func _on_call_timer_menu_pressed(id: int):
	if _call_timer_menu == null:
		return
		
	if id < _call_timer_menu.get_item_count():
		var timer_name = _call_timer_menu.get_item_text(id)
		var canvas_pos = _get_mouse_canvas_position()
		var node = blueprint_data.add_node("timer_call", canvas_pos)
		node.properties["名称"] = timer_name
		_create_node_ui(node)

## 统一刷新所有动态下拉列表（变量/函数/计时器的右键菜单 + 节点内下拉框）
func _refresh_all_dynamic_lists() -> void:
	# 刷新右键菜单的子列表
	_refresh_call_function_menu(_call_func_menu)
	_refresh_call_variable_menu(_call_var_menu)
	_refresh_call_timer_menu(_call_timer_menu)
	
	# 刷新所有节点内的 OptionButton 选项
	_refresh_variable_options()
	_refresh_function_options()
	_refresh_timer_options()

# 右键菜单回调函数（各子菜单的点击处理）
func _on_event_menu_pressed(id: int):
	match id:
		0:
			_add_node("event_signal")
		1:
			_add_node("event_receive")
		2:
			_add_node("event_pause")
		3:
			_add_node("event_resume")
		4:
			_add_node("event_stop")
		5:
			_add_node("event_print")
		_:
			printerr("未知的事件菜单ID: ", id)

func _on_if_menu_pressed(id: int):
	match id:
		0:
			_add_node("control_if")
		1:
			_add_node("control_if_else")
		_:
			printerr("未知的判断菜单ID: ", id)

func _on_loop_menu_pressed(id: int):
	match id:
		0:
			_add_node("control_while")
		1:
			_add_node("control_for")
		2:
			_add_node("control_repeat")
		3:
			_add_node("control_repeat_limit")
		4:
			_add_node("control_repeat_until")
		_:
			printerr("未知的循环菜单ID: ", id)

func _on_control_menu_pressed(id: int):
	match id:
		2:  # break
			_add_node("control_break")
		3:  # continue
			_add_node("control_continue")
		_:
			printerr("未知的控制菜单ID: ", id)

func _on_arithmetic_menu_pressed(id: int):
	match id:
		0:
			_add_node("math_add")
		1:
			_add_node("math_subtract")
		2:
			_add_node("math_multiply")
		3:
			_add_node("math_divide")
		_:
			printerr("未知的四则运算菜单ID: ", id)

func _on_power_menu_pressed(id: int):
	match id:
		0:
			_add_node("math_power")
		1:
			_add_node("math_sqrt")
		2:
			_add_node("math_mod")
		_:
			printerr("未知的幂/根/模菜单ID: ", id)

func _on_transcendental_menu_pressed(id: int):
	match id:
		0:
			_add_node("math_sin")
		1:
			_add_node("math_cos")
		2:
			_add_node("math_tan")
		3:
			_add_node("math_asin")
		4:
			_add_node("math_acos")
		5:
			_add_node("math_atan")
		6:
			_add_node("math_log")
		7:
			_add_node("math_log10")
		8:
			_add_node("math_exp")
		_:
			printerr("未知的超越函数菜单ID: ", id)

func _on_combinatorics_menu_pressed(id: int):
	match id:
		0:
			_add_node("math_factorial")
		1:
			_add_node("math_permutation")
		2:
			_add_node("math_combination")
		_:
			printerr("未知的计数组合菜单ID: ", id)

func _on_compare_menu_pressed(id: int):
	match id:
		0:
			_add_node("compare_equal")
		1:
			_add_node("compare_not_equal")
		2:
			_add_node("compare_greater")
		3:
			_add_node("compare_greater_equal")
		4:
			_add_node("compare_less")
		5:
			_add_node("compare_less_equal")
		_:
			printerr("未知的数值比较菜单ID: ", id)

func _on_logic_menu_pressed(id: int):
	match id:
		0:
			_add_node("logic_and")
		1:
			_add_node("logic_or")
		2:
			_add_node("logic_not")
		3:
			_add_node("logic_xor")
		_:
			printerr("未知的逻辑运算菜单ID: ", id)

func _on_extension_menu_pressed(id: int):
	match id:
		0:
			_add_node("math_vec_add")
		1:
			_add_node("math_vec_subtract")
		2:
			_add_node("math_vec_dot")
		3:
			_add_node("math_vec_cross")
		4:
			_add_node("math_vec_normalize")
		5:
			_add_node("math_vec_length")
		_:
			printerr("未知的拓展运算菜单ID: ", id)

func _on_object_property_menu_pressed(id: int):
	match id:
		0:
			_add_node("obj_property_type")
		1:
			_add_node("obj_property_position")
		2:
			_add_node("obj_property_value")
		3:
			_add_node("obj_property_direction")
		4:
			_add_node("obj_property_name")
		5:
			_add_node("obj_property_size")
		6:
			_add_node("obj_property_color")
		_:
			printerr("未知的对象属性菜单ID: ", id)

func _on_object_action_menu_pressed(id: int):
	match id:
		0:
			_add_node("obj_print_data")
		1:
			_add_node("obj_enable")
		2:
			_add_node("obj_disable")
		_:
			printerr("未知的对象操作菜单ID: ", id)


func _on_collision_menu_pressed(id: int):
	match id:
		0:
			_add_node("detect_collision")
		_:
			printerr("未知的碰撞检测菜单ID: ", id)

func _on_input_menu_pressed(id: int):
	match id:
		0:
			_add_node("detect_key_pressed")
		_:
			printerr("未知的输入检测菜单ID: ", id)

func _on_environment_menu_pressed(id: int):
	match id:
		0:
			_add_node("detect_distance")
		_:
			printerr("未知的环境数据菜单ID: ", id)

func _on_state_menu_pressed(id: int):
	match id:
		0:
			_add_node("timer_define")
		# 1 已经被子菜单占用，不再需要
		2:  # 开始计时
			_add_node("timer_start")
		3:  # 暂停计时
			_add_node("timer_pause")
		4:  # 终止计时
			_add_node("timer_stop")
		5:  # 等待时间
			_add_node("timer_wait")
		6:  # 运行时间
			_add_node("timer_runtime")
		_:
			printerr("未知的计时器菜单ID: ", id)


func _on_data_type_menu_pressed(id: int):
	match id:
		0:
			_add_node("type_bool")
		1:
			_add_node("type_int")
		2:
			_add_node("type_float")
		3:
			_add_node("type_string")
		4:
			_add_node("type_vector2")
		5:
			_add_node("type_vector3")
		6:
			_add_node("type_vector4")
		7:
			_add_node("type_array")
		8:
			_add_node("type_dictionary")
		_:
			printerr("未知的数据类型菜单ID: ", id)

func _on_data_operation_menu_pressed(id: int):
	match id:
		0:
			_add_node("op_type_cast")
		1:
			_add_node("op_get_length")
		2:
			_add_node("op_iterate_dict")
		3:
			_add_node("op_get_array_element")
		4:
			_add_node("op_get_vector_component")
		5:
			_add_node("op_is_empty")
		7: 
			_add_node("set_variable")
		8: 
			_add_node("get_variable")
		_:
			printerr("未知的数据操作菜单ID: ", id)

func _on_cast_menu_pressed(id: int):
	match id:
		0:
			_add_node("cast_float_to_int")
		1:
			_add_node("cast_int_to_float")
		2:
			_add_node("cast_string_to_float")
		3:
			_add_node("cast_string_to_int")
		4:
			_add_node("cast_string_to_vector2")
		5:
			_add_node("cast_string_to_vector3")
		_:
			printerr("未知的类型转换菜单ID: ", id)

func _on_custom_define_menu_pressed(id: int):
	match id:
		0:
			_add_node("func_define_new")
		_:
			printerr("未知的自定义定义菜单ID: ", id)


