extends Node3D

@onready var gizmo = $Gizmo3D
@onready var camera = $Camera3D
@onready var all_fields = $AllFields
@onready var all_objects = $AllObjects
@onready var all_grounds = $AllGrounds

var is_ctrl_pressed: bool = false
var selectable_objects: Array[Node3D] = []

func _ready():
	# 场景树加载完毕后执行
	await get_tree().process_frame
	FieldManager.initialize(all_fields)
	
	# ----- 手动添加可选物体（根据你的场景修改） -----
	# if has_node("Obj_Particle"):
	# 	selectable_objects.append($Obj_Particle)
	# if has_node("Particle"):
	# 	selectable_objects.append($Particle)

	# if has_node("ObjsBox"):
	#	 selectable_objects.append($ObjsBox)
	
	# print("可选择的物体数量: ", selectable_objects.size())
	# for obj in selectable_objects:
		# print("  - ", obj.name)
	
	# 默认选中第一个
	# if selectable_objects.size() > 0:
	#	 gizmo.select(selectable_objects[0])
		# print("默认选中: ", selectable_objects[0].name)

func _input(event: InputEvent):
	if event is InputEventKey:
		if event.keycode == KEY_CTRL:
			is_ctrl_pressed = event.pressed
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if gizmo.editing or gizmo.hovering:
			return
		
		var clicked = _raycast_select(event.position)
		print("点击位置: ", event.position, " 检测到的物体: ", str(clicked))
		
		if clicked:
			_handle_selection(clicked)
		else:
			gizmo.clear_selection()
			print("取消所有选择")

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
		print("射线命中了: ", result.collider, " 位置: ", result.position)
		var hit_node = result.collider
		while hit_node:
			if hit_node is Node3D and hit_node in selectable_objects:
				return hit_node
			hit_node = hit_node.get_parent()
	else:
		print("射线未命中任何物体")
	
	return null

func _handle_selection(clicked_object: Node3D):
	if is_ctrl_pressed:
		if gizmo.is_selected(clicked_object):
			gizmo.deselect(clicked_object)
			print("取消选中: ", clicked_object.name)
		else:
			gizmo.select(clicked_object)
			print("添加选中: ", clicked_object.name)
	else:
		var was_selected = gizmo.is_selected(clicked_object)
		gizmo.clear_selection()
		if not was_selected:
			gizmo.select(clicked_object)
			print("选中: ", clicked_object.name)
		else:
			print("取消选中: ", clicked_object.name)



