# FieldManager
extends Node

# 存储计算后的均匀子区域
# 每个元素: { "min": Vector3, "max": Vector3, "field": Vector3 }
var _field_regions: Array = []

# AllFields 节点的引用，需外部初始化
var _all_fields: Node3D = null

signal regions_changed()

# 外部调用，传入 AllFields 节点
func initialize(all_fields: Node) -> void:
	if _all_fields:
		# 如果重复初始化，先断开旧信号
		_disconnect_field_signals()
	_all_fields = all_fields
	_connect_field_signals()
	rebuild_regions()

# 连接 AllFields 子节点的增删信号
func _connect_field_signals() -> void:
	if not _all_fields:
		return
	if not _all_fields.child_entered_tree.is_connected(_on_field_child_entered):
		_all_fields.child_entered_tree.connect(_on_field_child_entered)
	if not _all_fields.child_exiting_tree.is_connected(_on_field_child_exiting):
		_all_fields.child_exiting_tree.connect(_on_field_child_exiting)

func _disconnect_field_signals() -> void:
	if not _all_fields:
		return
	if _all_fields.child_entered_tree.is_connected(_on_field_child_entered):
		_all_fields.child_entered_tree.disconnect(_on_field_child_entered)
	if _all_fields.child_exiting_tree.is_connected(_on_field_child_exiting):
		_all_fields.child_exiting_tree.disconnect(_on_field_child_exiting)

# 子节点进入时：如果是场节点，连接其 field_changed 信号
func _on_field_child_entered(node: Node) -> void:
	if node is Area3D and node.has_method("get_field_info"):
		if node.has_signal("field_changed"):
			if not node.field_changed.is_connected(_on_field_property_changed):
				node.field_changed.connect(_on_field_property_changed)
		rebuild_regions()

# 子节点退出时：断开信号，重建区域
func _on_field_child_exiting(node: Node) -> void:
	if node is Area3D:
		if node.has_signal("field_changed") and node.field_changed.is_connected(_on_field_property_changed):
			node.field_changed.disconnect(_on_field_property_changed)
		rebuild_regions()

# 场属性修改时重建区域
func _on_field_property_changed() -> void:
	rebuild_regions()

# 强制重建（供外部调用，例如全局数据刷新）
func force_rebuild() -> void:
	rebuild_regions()

# ---------- 区域划分核心 ----------
func rebuild_regions() -> void:
	_field_regions.clear()
	if not _all_fields:
		return

	# 重新收集激活的场（用于实际划分）
	var active_fields: Array = []
	for child in _all_fields.get_children():
		if not (child is Area3D and child.has_method("get_field_info")):
			continue
		var info: Dictionary = child.get_field_info()
		if not info.get("enabled", false):
			continue
		var aabb = _calc_field_aabb(child, info)
		if aabb == null:
			continue

		# 解析类型
		var type = int(info.get("type", 0))
		var type_key = ""
		match type:
			0: type_key = "custom"
			1: type_key = "electric"
			2: type_key = "magnetic"
			3: type_key = "gravity"
			_: continue   # 未知类型不处理

		# 计算该场的向量
		var dir_arr: Array = info.get("direction", [0.0, -1.0, 0.0])
		var dir = Vector3(dir_arr[0], dir_arr[1], dir_arr[2]).normalized()
		var value = float(info.get("value", 0.0))
		var field_vec = dir * value

		# 初始化所有类型为 ZERO，然后填入对应类型的值
		var vectors = {
			"custom": Vector3.ZERO,
			"electric": Vector3.ZERO,
			"magnetic": Vector3.ZERO,
			"gravity": Vector3.ZERO
		}
		vectors[type_key] = field_vec

		active_fields.append({
			"aabb": aabb,
			"vectors": vectors
		})

	if active_fields.is_empty():
		regions_changed.emit()
		return

	# 收集所有分割坐标
	var xs = []
	var ys = []
	var zs = []
	for f in active_fields:
		var aabb: AABB = f["aabb"]
		xs.append_array([aabb.position.x, aabb.end.x])
		ys.append_array([aabb.position.y, aabb.end.y])
		zs.append_array([aabb.position.z, aabb.end.z])

	xs.sort()
	ys.sort()
	zs.sort()
	xs = _unique_sorted(xs)
	ys = _unique_sorted(ys)
	zs = _unique_sorted(zs)

	# 遍历网格单元
	for i in range(xs.size() - 1):
		var x0 = xs[i]
		var x1 = xs[i + 1]
		if is_equal_approx(x0, x1):
			continue
		for j in range(ys.size() - 1):
			var y0 = ys[j]
			var y1 = ys[j + 1]
			if is_equal_approx(y0, y1):
				continue
			for k in range(zs.size() - 1):
				var z0 = zs[k]
				var z1 = zs[k + 1]
				if is_equal_approx(z0, z1):
					continue

				var cell_center = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)

				# 初始化累加器
				var acc = {
					"custom": Vector3.ZERO,
					"electric": Vector3.ZERO,
					"magnetic": Vector3.ZERO,
					"gravity": Vector3.ZERO
				}
				for f in active_fields:
					if f["aabb"].has_point(cell_center):
						for key in acc:
							acc[key] += f["vectors"][key]

				# 检查是否有任何非零场
				var any_nonzero = false
				for v in acc.values():
					if v.length_squared() > 0.0001:
						any_nonzero = true
						break

				if any_nonzero:
					_field_regions.append({
						"min": Vector3(x0, y0, z0),
						"max": Vector3(x1, y1, z1),
						"fields": acc
					})
	regions_changed.emit()

# ---------- 根据 info 计算有效长方体 ----------
func _calc_field_aabb(node: Area3D, info: Dictionary):
	var center = node.global_position
	var scale = node.global_transform.basis.get_scale()
	var half = scale * 0.5
	var base_min = center - half
	var base_max = center + half

	var mode: String = info.get("extense_mode", "a")
	match mode:
		"a": pass
		# 第 Ⅰ ～ Ⅳ 卦限：z>0
		"1": base_min.x = max(base_min.x, center.x); base_min.y = max(base_min.y, center.y); base_min.z = max(base_min.z, center.z)
		"2": base_max.x = min(base_max.x, center.x); base_min.y = max(base_min.y, center.y); base_min.z = max(base_min.z, center.z)
		"3": base_max.x = min(base_max.x, center.x); base_max.y = min(base_max.y, center.y); base_min.z = max(base_min.z, center.z)
		"4": base_min.x = max(base_min.x, center.x); base_max.y = min(base_max.y, center.y); base_min.z = max(base_min.z, center.z)
		# 第 Ⅴ ～ Ⅷ 卦限：z<0
		"5": base_min.x = max(base_min.x, center.x); base_min.y = max(base_min.y, center.y); base_max.z = min(base_max.z, center.z)
		"6": base_max.x = min(base_max.x, center.x); base_min.y = max(base_min.y, center.y); base_max.z = min(base_max.z, center.z)
		"7": base_max.x = min(base_max.x, center.x); base_max.y = min(base_max.y, center.y); base_max.z = min(base_max.z, center.z)
		"8": base_min.x = max(base_min.x, center.x); base_max.y = min(base_max.y, center.y); base_max.z = min(base_max.z, center.z)
		# 半空间模式
		"x_+": base_min.x = max(base_min.x, center.x)
		"x_-": base_max.x = min(base_max.x, center.x)
		"y_+": base_min.y = max(base_min.y, center.y)
		"y_-": base_max.y = min(base_max.y, center.y)
		"z_+": base_min.z = max(base_min.z, center.z)
		"z_-": base_max.z = min(base_max.z, center.z)

	if base_min.x >= base_max.x or base_min.y >= base_max.y or base_min.z >= base_max.z:
		return null
	return AABB(base_min, base_max - base_min)

# ---------- 工具 ----------
func _unique_sorted(arr: Array) -> Array:
	var out = []
	var last = null
	for val in arr:
		if last == null or not is_equal_approx(val, last):
			out.append(val)
			last = val
	return out

# ---------- 对外查询接口 ----------
func get_field_at(position: Vector3) -> Dictionary:
	# 返回固定结构的字典，即使场内无数据也返回默认零值
	var result = {
		"custom":   {"value": 0.0, "dir": [0.0, 0.0, 0.0]},
		"electric": {"value": 0.0, "dir": [0.0, 0.0, 0.0]},
		"magnetic": {"value": 0.0, "dir": [0.0, 0.0, 0.0]},
		"gravity":  {"value": 0.0, "dir": [0.0, 0.0, 0.0]}
	}
	
	for region in _field_regions:
		var aabb = AABB(region["min"], region["max"] - region["min"])
		if aabb.has_point(position):
			var fields = region["fields"]
			for key in fields:
				var v = fields[key]
				var len = v.length()
				if len > 0.0001:
					result[key]["value"] = len
					var n = v.normalized()
					result[key]["dir"] = [n.x, n.y, n.z]
			return result
	return result

# 若需要获取总向量（所有场之和），可以添加一个辅助函数
func get_total_field_at(position: Vector3) -> Vector3:
	var d = get_field_at(position)
	var total = Vector3.ZERO
	for key in d:
		var info = d[key]
		total += Vector3(info["dir"][0], info["dir"][1], info["dir"][2]) * info["value"]
	return total

# ---------- 对外查询接口 ----------
func get_all_regions() -> Array:
	return _field_regions.duplicate(true)

