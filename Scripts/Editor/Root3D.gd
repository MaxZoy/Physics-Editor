extends Node3D

var sim_data: Dictionary

@onready var gizmo = $Gizmo3D
@onready var camera = $"../Camera3D"

@onready var all_fields = $AllFields
@onready var all_objects = $AllObjects
@onready var all_grounds = $AllGrounds

var is_ctrl_pressed: bool = false
var selectable_objects: Array[Node3D] = [] 

func _ready() -> void:
	GlobalData.root3d_node_path = self.get_path()
	sim_data = GlobalData.run_project_data.duplicate(true)
	GlobalData.refresh_all_items.connect(element_reset)
	# 启动时刷新所有的 items
	if get_tree().current_scene.name == "MainUI":
		GlobalData.refresh_all_items_by_data(GlobalData.run_project_data)

	print("模拟场景刷新")

	var del_win = WindowsManager.get_window_by_name("DeleteWindows")
	del_win.root3d = self


# 场景中所有的元素全部归位
func element_reset():
	# 清空，防止无限叠加物体
	selectable_objects.clear()
	# 获取所有的可选中物体
	for child in all_objects.get_children():
		selectable_objects.append(child)
	# print("刷新")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("mouse_left") and not GlobalData.view_is_rotate:
		# 执行点击逻辑
		# 注意：这里需要自己计算鼠标位置
		var mouse_pos = get_viewport().get_mouse_position()
		var clicked = _raycast_select(mouse_pos)
		if gizmo.editing or gizmo.hovering:
			return
		# print("点击位置: ", mouse_pos, " 检测到的物体: ", str(clicked))
		
		if clicked:
			_handle_selection(clicked)
			clicked.be_selected_by_gizmo = true
		else:
			gizmo.clear_selection()
			for child in selectable_objects:
				if child != null:
					child.be_selected_by_gizmo = false
			# print("取消所有选择")

func _raycast_select(mouse_pos: Vector2) -> Node3D:
	if not camera:
		print("警告: 没有相机")
		return null
	
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	var max_dist = 4000.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, from + dir * max_dist)
	query.exclude = [gizmo]
	query.collision_mask = 0xFFFFFFFF  # 检测所有层
	
	var result = space_state.intersect_ray(query)
	if result:
		# print("射线命中了: ", result.collider, " 位置: ", result.position)
		var hit_node = result.collider
		while hit_node:
			if hit_node is Node3D and hit_node in selectable_objects:
				return hit_node
			hit_node = hit_node.get_parent()
	# else:
	# 	print("射线未命中任何物体")
	
	return null

func _handle_selection(clicked_object: Node3D):
	if is_ctrl_pressed:
		if gizmo.is_selected(clicked_object):
			gizmo.deselect(clicked_object)
			# print("取消选中: ", clicked_object.name)
		else:
			gizmo.select(clicked_object)
			# print("添加选中: ", clicked_object.name)
	else:
		var was_selected = gizmo.is_selected(clicked_object)
		gizmo.clear_selection()
		if not was_selected:
			gizmo.select(clicked_object)
			# print("选中: ", clicked_object.name)
		# else:
		# 	print("取消选中: ", clicked_object.name)


