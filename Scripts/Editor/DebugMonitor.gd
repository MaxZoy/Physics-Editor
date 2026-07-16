extends MenuButton

var pm: PopupMenu

@onready var subviewport_obj: SubViewport = $"../../../../RunPanel/RunWindow/SimulationViewport"
var camera: Camera3D

func _ready():
	pm = get_popup()
	pm.hide_on_checkable_item_selection = false
	pm.id_pressed.connect(_on_menu_pressed)
	
	camera = subviewport_obj.get_camera_3d()
	
	# 初始化选项状态
	if pm.is_item_checked(0):
		GlobalData.debug_is_show_field_area = true
	else:
		GlobalData.debug_is_show_field_area = false
	if pm.is_item_checked(1):
		GlobalData.debug_is_show_outline = true
	else:
		GlobalData.debug_is_show_outline = false

func _on_menu_pressed(id: int) -> void:
	pm.toggle_item_checked(pm.get_item_index(id))
	
	match id:
		0: # 显示碰撞区域
			GlobalData.debug_is_show_field_area = pm.is_item_checked(0)
			if GlobalData.debug_is_show_field_area:
				print("显示物理场区域")
			else:
				print("隐藏物理场区域")
		3: # 显示边框
			GlobalData.debug_is_show_outline = pm.is_item_checked(1)
			if GlobalData.debug_is_show_outline:
				print("显示边框")
			else:
				print("隐藏边框")
		2: # 显示监测点
			print("显示监测点")
		1: # 显示运动轨迹
			print("显示运动轨迹")
		5: # 主视图
			print("重置相机主视图")
			camera.yaw = 0
			camera.pitch = 0
			camera.direction = Vector3(0, 0, 1).normalized()
			camera.global_position = Vector3(0, 0, camera.distance)
			camera.global_position.x = camera.orbit_center.x
			camera.global_position.y = camera.orbit_center.y
			camera.global_rotation = Vector3(0, 0, 0)
			GlobalData.camera_yaw = 0.0
			GlobalData.camera_pitch = 0.0
			# print(camera.global_position, camera.global_rotation)
		6: # 初始视图
			print("重置相机初始视图")
			camera.yaw = 0
			camera.pitch = 0
			camera.direction = Vector3(0, 0, 1).normalized()
			camera.global_position = Vector3(0, 0, camera.distance)
			camera.orbit_center.x = 0
			camera.orbit_center.y = 0
			camera.global_rotation = Vector3(0, 0, 0)
			camera.size = camera.original_size
			GlobalData.camera_yaw = 0.0
			GlobalData.camera_pitch = 0.0
		7: # 右视图
			print("重置相机右视图")
			camera.yaw = camera.get_nearest_half_pi(camera.yaw)
			camera.pitch = 0
			camera.direction = Vector3(1, 0, 0).normalized()
			camera.global_position = Vector3(camera.distance, 0, 0)
			camera.global_position.y = camera.orbit_center.y
			camera.global_position.z = camera.orbit_center.z
			camera.global_rotation = Vector3(0, PI / 2, 0)
			GlobalData.camera_yaw = camera.get_nearest_half_pi(camera.yaw)
			GlobalData.camera_pitch = 0.0
		8: # 俯视图
			print("重置相机俯视图")
			camera.yaw = 0
			camera.pitch = -1 * (PI / 2)
			camera.direction = Vector3(0, 1, 0).normalized()
			camera.global_position = Vector3(0, camera.distance, 0)
			camera.global_position.x = camera.orbit_center.x
			camera.global_position.z = camera.orbit_center.z
			camera.global_rotation = Vector3(-1 * (PI / 2), 0, 0)
			GlobalData.camera_yaw = 0.0
			GlobalData.camera_pitch = -1 * (PI / 2)
		10: # 打印程序运行数据 run_project_data
			GlobalTools.print_dict(GlobalData.run_project_data)
			
	
