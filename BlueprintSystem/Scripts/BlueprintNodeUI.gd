# BlueprintNodeUI.gd
class_name BlueprintNodeUI
extends GraphNode

var node_data: BlueprintNode = null

func _ready() -> void:
	# 连接拖动信号
	dragged.connect(_on_dragged)
	
	# 延迟一帧强制设置尺寸
	call_deferred("_apply_size")

func setup(node: BlueprintNode):
	node_data = node
	var def = NodeDatabase.get_node_type(node.type_id)
	title = def["name"]
	modulate = def["color"]
	
	# 清空原有子控件（如果有）
	for child in get_children():
		if child is not GraphNode:  # 保留GraphNode自身控件
			child.queue_free()
	
	# --- 如果是对象面板，显示对象详情 ---
	if node.type_id == "object_panel":
		_setup_object_panel(node)
		return
	
	# --- 添加端口（关键修复） ---
	var inputs = def.get("inputs", [])
	var outputs = def.get("outputs", [])
	
	# 创建输入端口（左侧）
	for i in range(inputs.size()):
		var port_name = inputs[i]["name"]
		# 判断端口类型（执行流用红色，数据流用蓝色）
		var port_def = inputs[i]
		var color = _get_port_color(port_def)
		# set_slot(索引, 是否输入, 端口类型, 颜色, 是否输出, 端口类型, 颜色)
		set_slot(i, true, 0, color, false, 0, color)
		# 添加端口标签
		var label = Label.new()
		label.text = port_name
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(label)
	
	# 创建输出端口（右侧）
	for i in range(outputs.size()):
		var port_name = outputs[i]["name"]
		# 判断端口类型（执行流用红色，数据流用蓝色）
		var port_def = outputs[i]
		var color = _get_port_color(port_def)
		var port_idx = inputs.size() + i
		set_slot(port_idx, false, 0, color, true, 0, color)
		# 添加端口标签
		var label = Label.new()
		label.text = port_name
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(label)
	
	
	# 添加属性控件
	var props = def.get("properties", {})
	if not props.is_empty():
		var sep = HSeparator.new()
		add_child(sep)
		for prop_name in props:
			var prop_def = props[prop_name]
			
			# 如果是变量属性，动态更新选项
			if prop_def.get("type") == "enum":
				match prop_name:
					"变量":
						prop_def["options"] = _get_declared_variable_names()
					"func":
						prop_def["options"] = _get_declared_function_names()
					"名称":
						prop_def["options"] = _get_declared_timer_names()
			
			var hbox = HBoxContainer.new()
			var label = Label.new()
			label.text = prop_name + ":"
			label.custom_minimum_size.x = 20
			hbox.add_child(label)
			var current_value = node.properties.get(prop_name, prop_def.get("default", ""))
			var control = _create_property_control(prop_def, prop_name, current_value)
			hbox.add_child(control)
			add_child(hbox)
			
	custom_minimum_size = Vector2(20, 12)
	size = Vector2(20, 12)

func _create_property_control(prop_def: Dictionary, prop_name: String, current_value):
	var control: Control
	match prop_def["type"]:
		"String":
			var le = LineEdit.new()
			le.text = str(current_value)
			# 实时同步属性数据（每次打字更新）
			le.text_changed.connect(func(v): 
				node_data.properties[prop_name] = v
			)
			# 场景1：按回车键提交名称，刷新下拉列表
			le.text_submitted.connect(func(_unused):
				_trigger_refresh_if_needed(prop_name)
			)
			# 场景2：点击别处、输入框失焦退出编辑，刷新下拉列表
			le.editing_toggled.connect(func(is_editing: bool):
				if not is_editing:
					_trigger_refresh_if_needed(prop_name)
			)
			control = le
		"float":
			var sb = SpinBox.new()
			sb.value = float(current_value)
			sb.value_changed.connect(func(v): node_data.properties[prop_name] = v)
			control = sb
		"int":
			var sb = SpinBox.new()
			sb.value = int(current_value)
			sb.value_changed.connect(func(v): node_data.properties[prop_name] = v)
			control = sb
		"bool":
			var cb = CheckButton.new()
			cb.button_pressed = bool(current_value)
			cb.flat = true
			cb.toggled.connect(func(v): node_data.properties[prop_name] = v)
			control = cb
		"enum":
			var ob = OptionButton.new()

			# 获取节点颜色并应用到下拉菜单
			var node_color = modulate
			var style = StyleBoxFlat.new()
			style.bg_color = Color(node_color.r * 0.6, node_color.g * 0.6, node_color.b * 0.6, 0.8)
			style.corner_radius_top_left = 3
			style.corner_radius_top_right = 3
			style.corner_radius_bottom_left = 3
			style.corner_radius_bottom_right = 3
			ob.get_popup().add_theme_stylebox_override("panel", style)
			ob.get_popup().add_theme_stylebox_override("hover", style)
			ob.get_popup().add_theme_color_override("font_color", Color(1, 1, 1))
			ob.get_popup().min_size.x = 180
			
			# 从数据中读取保存值，优先用存档数据，没有则用默认值
			var saved_value = node_data.properties.get(prop_name, "")
			var default_value = prop_def.get("default", "")
			var current_str = str(saved_value) if saved_value != "" else str(default_value)
			
			# 填充选项
			var options = prop_def.get("options", [])
			if options.is_empty() and prop_name == "变量":
				options = _get_declared_variable_names()
			elif options.is_empty() and prop_name == "func":
				options = _get_declared_function_names()
			
			for opt in options:
				ob.add_item(opt)
			
			# 查找匹配项
			var selected_idx = -1
			for i in range(ob.get_item_count()):
				if ob.get_item_text(i) == current_str:
					selected_idx = i
					break
			
			# 选中逻辑：找到就选中；找不到且属性为空时才用第一项当默认值
			if selected_idx != -1:
				ob.select(selected_idx)
			elif ob.get_item_count() > 0 and saved_value == "":
				ob.select(0)
				node_data.properties[prop_name] = ob.get_item_text(0)
			
			# 选项改变时更新数据
			ob.item_selected.connect(func(idx):
				var new_value = ob.get_item_text(idx)
				node_data.properties[prop_name] = new_value
				var editor = _find_editor()
				if editor and editor.has_method("_mark_modified"):
					editor._mark_modified()
			)
			control = ob
		_:
			var le = LineEdit.new()
			le.text = str(current_value)
			le.text_changed.connect(func(v): node_data.properties[prop_name] = v)
			control = le
	
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control

# 查找编辑器
func _find_editor():
	var parent = get_parent()
	while parent:
		if parent is BlueprintEditor:
			return parent
		else:
			parent = parent.get_parent()
			return parent
	return null

# 获取所有变量
func _get_declared_variable_names() -> Array:
	var names = []
	var var_types = [
		"type_bool", "type_int", "type_float", "type_string",
		"type_vector2", "type_vector3", "type_vector4",
		"type_array", "type_dictionary"
	]
	var editor = _find_editor()
	if editor:
		for node in editor.blueprint_data.nodes.values():
			if node.type_id in var_types:
				var var_name = node.properties.get("变量", "")
				if var_name != "" and var_name not in names:
					names.append(var_name)
	return names


func get_node_id() -> int:
	return node_data.id

func _get_port_color(port_def: Dictionary) -> Color:
	match port_def.get("type", ""):
		"exec":
			return Color(1.0, 0.2, 0.2)
		"bool":
			return Color(1.0, 0.6, 0.2)
		"float":
			return Color(0.2, 0.6, 1.0)
		"int":
			return Color(0.2, 0.8, 0.2)
		"String":
			return Color(0.8, 0.2, 0.8)
		"Vector2":
			return Color(0.2, 0.8, 0.8)
		"Vector3":
			return Color(0.2, 0.6, 0.6)
		"Vector4":
			return Color(0.6, 0.2, 0.6)
		"Array":
			return Color(0.8, 0.8, 0.2)
		"Dictionary":
			return Color(0.8, 0.6, 0.2)
		"Variant":
			return Color(0.8, 0.8, 0.8)
		_:
			return Color(0.5, 0.5, 0.5)

# 专门设置对象面板的显示
func _setup_object_panel(node: BlueprintNode):
	var id_code = node.properties.get("id_code", "000000")
	var display_name = node.properties.get("display_name", "对象")
	var data_source = node.properties.get("data_source", "objects")
	var object_data = node.properties.get("object_data", {})
	
	# 设置标题为 ID
	title = id_code
	
	# 显示对象名称
	var name_label = Label.new()
	name_label.text = "名称: " + display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)
	
	# 显示数据来源
	var source_label = Label.new()
	source_label.text = "来源: " + data_source
	source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(source_label)
	
	# 显示对象的主要属性
	if not object_data.is_empty():
		var sep = HSeparator.new()
		add_child(sep)
		
		# 根据数据源显示不同属性
		match data_source:
			"fields":
				_add_object_property_row("类型", str(object_data.get("type", "未知")))
				_add_object_property_row("值", str(object_data.get("value", "0")))
				_add_object_property_row("方向", str(object_data.get("direction", [0,0,0])))
				_add_object_property_row("可扩展", str(object_data.get("can_extense", false)))
			"objects":
				_add_object_property_row("类型", str(object_data.get("type", "未知")))
				_add_object_property_row("位置", str(object_data.get("position", [0,0,0])))
				_add_object_property_row("标记", str(object_data.get("mark", "")))
				# if object_data.has("property"):
				# 	var prop = object_data["property"]
				# 	_add_object_property_row("质量", str(prop.get("mass", 1.0)) + "×10^" + str(prop.get("mass_e", 0)))
			"grounds":
				_add_object_property_row("类型", str(object_data.get("type", "未知")))
				_add_object_property_row("位置", str(object_data.get("position", [0,0,0])))
				_add_object_property_row("尺寸", str(object_data.get("size", [1,1,1])))

func _apply_size():
	if node_data:
		var min_size = get_combined_minimum_size()
		if min_size.x < 80:
			min_size.x = 80  # 最小宽度
		custom_minimum_size = min_size
		size = min_size
		queue_redraw()

## 辅助方法：添加属性行
func _add_object_property_row(key: String, value: String):
	var hbox = HBoxContainer.new()
	var key_label = Label.new()
	key_label.text = key + ":"
	key_label.custom_minimum_size.x = 60
	var value_label = Label.new()
	value_label.text = value
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(key_label)
	hbox.add_child(value_label)
	add_child(hbox)


func _on_dragged(from: Vector2, to: Vector2):
	if node_data != null:
		node_data.position = to   # position_offset 是 GraphNode 的实际位置


func refresh_variable_options(var_names: Array):
	for child in get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is OptionButton:
					# 从数据中取当前值，不从UI取，避免UI状态错误影响数据
					var current_value = node_data.properties.get("变量", "")
					sub.clear()
					for name in var_names:
						sub.add_item(name)
					
					# 查找匹配索引
					var idx = -1
					for i in range(sub.item_count):
						if sub.get_item_text(i) == current_value:
							idx = i
							break
					
					if idx != -1:
						sub.select(idx)
					elif var_names.size() > 0 and current_value == "":
						# 只有值为空时才默认选第一项
						sub.select(0)
						node_data.properties["变量"] = var_names[0]
					break

## 获取所有已定义的函数名
func _get_declared_function_names() -> Array:
	var names = []
	var editor = _find_editor()
	if editor and editor.has_method("get_declared_function_names"):
		return editor.get_declared_function_names()
	return names

# BlueprintNodeUI.gd

## 刷新函数名下拉列表
func refresh_function_options(func_names: Array):
	for child in get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is OptionButton:
					var current_value = node_data.properties.get("func", "")
					sub.clear()
					for name in func_names:
						sub.add_item(name)
					
					var idx = -1
					for i in range(sub.item_count):
						if sub.get_item_text(i) == current_value:
							idx = i
							break
					
					if idx != -1:
						sub.select(idx)
					elif func_names.size() > 0 and current_value == "":
						sub.select(0)
						node_data.properties["func"] = func_names[0]
					break

func force_update_selection():
	for child in get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is OptionButton:
					var prop_name = _find_property_name_for_optionbutton(sub)
					if prop_name != "":
						var saved_value = node_data.properties.get(prop_name, "")
						if saved_value != "":
							var idx = -1
							for i in range(sub.get_item_count()):
								if sub.get_item_text(i) == saved_value:
									idx = i
									break
							if idx != -1:
								sub.select(idx)
							elif sub.get_item_count() > 0:
								sub.select(0)

func _find_property_name_for_optionbutton(ob: OptionButton) -> String:
	# 通过属性名判断，简单实现：遍历 properties 查找对应的值
	for prop_name in node_data.properties.keys():
		if node_data.properties[prop_name] == ob.get_item_text(ob.selected):
			return prop_name
	return ""

func _get_declared_timer_names() -> Array:
	var names = []
	var editor = _find_editor()
	if editor and editor.has_method("_get_defined_timer_names"):
		return editor._get_defined_timer_names()
	return names


func refresh_timer_options(timer_names: Array):
	for child in get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is OptionButton:
					var current_value = node_data.properties.get("名称", "")
					sub.clear()
					for name in timer_names:
						sub.add_item(name)
					
					var idx = -1
					for i in range(sub.item_count):
						if sub.get_item_text(i) == str(current_value):
							idx = i
							break
					
					if idx != -1:
						sub.select(idx)
					else:
						# 旧值不在选项列表中 → 自动更新为第一项，同步修改属性数据，清除残留旧值
						if timer_names.size() > 0:
							sub.select(0)
							node_data.properties["名称"] = timer_names[0]
						else:
							# 没有任何可用选项时，清空属性值
							node_data.properties["名称"] = ""
					break


## 如果修改的是定义类节点的名称属性，通知编辑器刷新所有下拉列表
func _trigger_refresh_if_needed(prop_name: String) -> void:
	var editor = _find_editor()
	if editor == null:
		return
	
	var type_id = node_data.type_id
	var need_refresh = false
	
	# 匹配所有定义类节点的名称属性
	match type_id:
		# 函数定义
		"func_define_new":
			need_refresh = (prop_name == "func")
		# 变量定义（所有数据类型节点）
		"type_bool", "type_int", "type_float", "type_string",\
		"type_vector2", "type_vector3", "type_vector4","type_array", "type_dictionary":
			need_refresh = (prop_name == "变量")
		# 计时器定义
		"timer_define":
			need_refresh = (prop_name == "名称")
			
	if need_refresh:
		# 触发全局刷新
		if editor.has_method("_refresh_all_dynamic_lists"):
			editor._refresh_all_dynamic_lists()
		# 同步标记蓝图已修改
		if editor.has_method("_mark_modified"):
			editor._mark_modified()


