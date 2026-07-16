extends Node

func _ready() -> void:
	# 启动时扫描全局所有输入框
	disable_all_text_context_menu()
	# 监听动态创建的UI节点，自动处理
	get_tree().node_added.connect(_on_ui_node_added)

# 全局递归查找指定名称节点，无视层级父级
func find_node_from_global(target_name: String) -> Node:
	var root = get_tree().root
	return recursive_find(root, target_name)

# 获取直接调用本函数的上层函数名
func get_current_func_name() -> String:
	var stack_frames = get_stack()
	# 堆栈层数不足 返回空字符串
	if stack_frames.size() < 2:
		return ""
	# stack_frames[0] = get_current_func_name 自身
	# stack_frames[1] = 调用该函数的目标函数
	var frame_info = stack_frames[1]
	return frame_info["function"]

# 全局递归查找指定名称节点的辅助函数
func recursive_find(parent: Node, name: String) -> Node:
	if parent.name == name:
		return parent
	for child in parent.get_children():
		var res = recursive_find(child, name)
		if res != null:
			return res
	return null

# 按比例缩放几何体
func resize_mesh(mesh_inst, scale_factor: Vector3):
	var original_mesh = mesh_inst.mesh
	if original_mesh == null:
		print("错误：节点没有挂载Mesh资源")
		return

	print("原始Mesh类型：", original_mesh.get_class())
	var new_mesh = ArrayMesh.new()
	var surface_count = original_mesh.get_surface_count()
	print("网格表面数量：", surface_count)

	var mdt = MeshDataTool.new()

	for surf_idx in range(surface_count):
		# 读取原网格的顶点数据
		var err = mdt.create_from_surface(original_mesh, surf_idx)
		if err != OK:
			print("读取表面", surf_idx, "失败，错误码：", err)
			continue

		var vertex_count = mdt.get_vertex_count()
		print("表面", surf_idx, "顶点总数：", vertex_count)

		# 遍历缩放所有顶点坐标
		for i in range(vertex_count):
			var vertex = mdt.get_vertex(i)
			mdt.set_vertex(i, vertex * scale_factor)

		# 将修改后的数据写入新网格
		mdt.commit_to_surface(new_mesh)
		mdt.clear()

	# 同步缩放阴影网格，避免阴影错位
	if original_mesh.shadow_mesh != null:
		var shadow_src = original_mesh.shadow_mesh
		var new_shadow = ArrayMesh.new()
		var shadow_surf_count = shadow_src.get_surface_count()
		for surf_idx in range(shadow_surf_count):
			var err = mdt.create_from_surface(shadow_src, surf_idx)
			if err != OK:
				continue
			for i in range(mdt.get_vertex_count()):
				mdt.set_vertex(i, mdt.get_vertex(i) * scale_factor)
			mdt.commit_to_surface(new_shadow)
			mdt.clear()
		new_mesh.shadow_mesh = new_shadow

	# 替换模型，节点 scale 始终保持 (1,1,1)
	mesh_inst.mesh = new_mesh
	print("几何体顶点缩放完成")

# 为3d模型创建描边模型
func create_outline_3d(my_mi: MeshInstance3D, thickness: float):
	var my_mesh = my_mi.mesh
	var new_mesh = my_mesh.create_outline(thickness)
	var new_mi = MeshInstance3D.new()
	new_mi.mesh = new_mesh
	var black_mat = StandardMaterial3D.new()
	black_mat.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	new_mi.set_surface_override_material(0, black_mat)
	my_mi.add_child(new_mi)
	print("为 ", my_mi.get_parent().name, " 创建轮廓网格")

# 生成id_code并检查集合中是否有重复 重复则重新生成 不重复则返回
func get_id_code() -> int:
	var id_arr = GlobalData.run_project_data["id_code"].duplicate(true)
	var result: int
	# 循环直到拿到不存在的ID
	while true:
		result = create_random_6digit()
		if not id_arr.has(result):
			break
	# print(GlobalData.run_project_data["id_code"])
	return result

# 生成一个随机六位数作为id_code
func create_random_6digit() -> int:
	# 生成真随机字节数组
	var crypto = Crypto.new()
	var seed_bytes: PackedByteArray = crypto.generate_random_bytes(8)
	
	# 把字节数组转换为整数
	var seed_int: int = 0
	for i in range(seed_bytes.size()):
		seed_int = (seed_int << 8) | seed_bytes[i]
	
	# 初始化随机数生成器
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_int
	
	# 生成 6 位随机数（000000 ~ 999999）
	return rng.randi_range(0, 999999)

# 打印所有子节点
func print_all_children(node: Node):
	for child in node.get_children():
		print(child.name)
		print_all_children(child)

# 输入任意3D节点，只要自身/任意父Node3D隐藏，返回false
func is_fully_visible(target: Node3D) -> bool:
	var curr: Node = target
	while curr != null:
		# 所有继承 Node3D 的节点都有 visible 属性
		if curr is Node3D:
			if not curr.visible:
				return false
		curr = curr.get_parent()
	return true

# 物理场单位变换：输入 type_option_btn 的值，返回对应的单位
func field_type_select_to_unit(select: int) -> String:
	var result = ""
	# 匹配对应的单位
	match select:
		0, 3:
			result = "m/s²"
		1:
			result = "N/C"
		2:
			result = "T"
	
	return result

# 物理场延伸模式变换：输入 ext_mode_btn 的值，返回对应的模式
func field_ext_select_to_extense_mode(select: int) -> String:
	var result = ""
	# 匹配对应的模式
	match select:
		0:
			result = "a" # 全伸展（覆盖全局）
		1:
			result = "1" # 第 Ⅰ 卦限，x>0 y>0 z>0
		2:
			result = "2" # 第 Ⅱ 卦限，x<0 y>0 z>0
		3:
			result = "3" # 第 Ⅲ 卦限，x<0 y<0 z>0
		4:
			result = "4" # 第 Ⅳ 卦限，x>0 y<0 z>0
		5:
			result = "5" # 第 Ⅴ 卦限，x>0 y>0 z<0
		6:
			result = "6" # 第 Ⅵ 卦限，x<0 y>0 z<0
		7:
			result = "7" # 第 Ⅶ 卦限，x<0 y<0 z<0
		8:
			result = "8" # 第 Ⅷ 卦限，x>0 y<0 z<0
		9:
			result = "x_+" # x 正半空间，x>0
		10:
			result = "x_-" # x 负半空间，x<0
		11:
			result = "y_+" # y 正半空间，y>0
		12:
			result = "y_-" # y 负半空间，y<0
		13:
			result = "z_+" # z 正半空间，z>0
		14:
			result = "z_-" # z 负半空间，z<0
	return result

# 物理场延伸模式变换：输入对应的模式，返回 ext_mode_btn 的值
func field_extense_mode_to_select(mode: String) -> int:
	var result = 0
	match mode:
		"a":
			result = 0
		"1":
			result = 1
		"2":
			result = 2
		"3":
			result = 3
		"4":
			result = 4
		"5":
			result = 5
		"6":
			result = 6
		"7":
			result = 7
		"8":
			result = 8
		"x_+":
			result = 9
		"x_-":
			result = 10
		"y_+":
			result = 11
		"y_-":
			result = 12
		"z_+":
			result = 13
		"z_-":
			result = 14
	return result

# 工整输出字典
func print_dict(data: Dictionary):
	print(JSON.stringify(data, "\t", false))

# 全局一次性禁用所有文本右键菜单
func disable_all_text_context_menu():
	# 1. 处理独立LineEdit、TextEdit
	var all_line = get_tree().root.find_children("*", "LineEdit", true, false)
	var all_text = get_tree().root.find_children("*", "TextEdit", true, false)
	for edit in all_line + all_text:
		edit.context_menu_enabled = false
	
	# 2. 全局遍历所有SpinBox，关闭内部LineEdit右键菜单
	var all_spin = get_tree().root.find_children("*", "SpinBox", true, false)
	for spin in all_spin:
		if spin.get_line_edit() != null:
			spin.get_line_edit().context_menu_enabled = false

# 动态新增节点自动处理
func _on_ui_node_added(node: Node):
	# 独立输入框
	if node is LineEdit or node is TextEdit:
		node.context_menu_enabled = false
	# 新增SpinBox，立刻处理内部输入框
	elif node is SpinBox:
		if node.get_line_edit() != null:
			node.get_line_edit().context_menu_enabled = false

# 研究对象类型变换：输入 type_option_btn 的值，返回对应的类型
func object_type_select_to_id(select: int) -> int:
	var result
	match select:
		0:
			result = 0 # particle
		1:
			result = 1 # rigidbody_obj
	return result

# 写入JSON文件工具
func write_json_file(path: String, save_data) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("写入文件失败：", FileAccess.get_open_error())
		return false
	var json_str = JSON.stringify(save_data, "\t", false)
	file.store_string(json_str)
	file.close()
	return true

# 读取JSON文件工具
func read_json_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("读取文件失败：", FileAccess.get_open_error())
		return {}
	var text = file.get_as_text()
	file.close()

	var json_parser = JSON.new()
	# 第二个参数 keep_text = true：按文件原始顺序解析，不重排键
	var err = json_parser.parse(text, true)
	if err != OK:
		print("JSON解析失败：", json_parser.get_error_message(), " 行号：", json_parser.get_error_line())
		return {}
	return json_parser.data

# 保留指定位数小数（四舍五入）
func round_to_decimals(val: float) -> float:
	var decimals = GlobalData.FLOAT_SNAPPED
	var factor = pow(10.0, decimals)
	return round(val * factor) / factor


