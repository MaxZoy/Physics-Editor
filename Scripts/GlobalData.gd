# GlobalData.gd
extends Node

# 当前项目是否读取文件（新建项目、打开项目）
var current_project_read_file: bool = false
# 当前项目的文件路径
var current_project_file_path: String = ""
# 用于存放初始化时项目文件的内容 检测项目文件是否被修改过
var init_project_data: Dictionary = {}
# 用于存放运行时项目文件的内容 检测项目文件是否被修改过
var run_project_data: Dictionary = {}
# 刷新所有的元素发送信号
signal refresh_all_items
# float 保留位数
const FLOAT_SNAPPED = 1

# 预加载两个场景
# const START_SCENE: PackedScene = preload("res://Scenes/Start.tscn")
const EDITOR_SCENE: PackedScene = preload("res://Scenes/Editor/Editor3D.tscn")
# 预加载模拟场景
const SIMULATION_SCENE: PackedScene = preload("res://Scenes/Editor/Root3d.tscn")
# 子窗口主题
const DIALOG_WINDOWS_THEME = preload("res://Themes/Dark/ChildWindows.tres")
# 加载物理场的侧栏面板
const field_panel: PackedScene = preload("res://Scenes/Fields/FieldPanel.tscn")
# 物理场区域节点
const field_area: PackedScene = preload("res://Scenes/Fields/FieldArea3d.tscn")
# 物理场标准材质
const base_field_mat = preload("res://Shader/BaseFieldMaterial.tres")
# 加载研究对象的侧栏面板
const object_panel: PackedScene = preload("res://Scenes/Objects/ObjPanel.tscn")
# 研究对象节点
var object: PackedScene = null
var obj_property: PackedScene = null
# 研究对象标准材质
const base_object_mat = preload("res://Shader/BaseObjectMaterial.tres")
# 研究对象列表
const obj_particle: PackedScene = preload("res://Scenes/Objects/Obj_Particle.tscn")
const obj_block: PackedScene = preload("res://Scenes/Objects/Obj_Block.tscn")
const obj_charged_particle: PackedScene = preload("res://Scenes/Objects/Obj_ChargedParticle.tscn")
# 研究对象属性列表
const obj_particle_property: PackedScene = preload("res://Scenes/BuildInWindows/ObjectProperty/ParticleProperty.tscn")
const obj_block_property: PackedScene = preload("res://Scenes/BuildInWindows/ObjectProperty/BlockPropertyt.tscn")
const obj_charged_particle_property: PackedScene = preload("res://Scenes/BuildInWindows/ObjectProperty/ChargedParticleProperty.tscn")
# 加载接触面的侧栏面板
const  ground_panel: PackedScene = preload("res://Scenes/Ground/GroundPanel.tscn")
# 接触面节点
var ground: PackedScene = null
# 接触面标准材质
const base_ground_mat: = preload("res://Shader/BaseGroundMaterial.tres")
# 接触面列表
const ground_constraint_surface: PackedScene = preload("res://Scenes/Ground/ConstraintSurface.tscn")
const ground_boundary: PackedScene = preload("res://Scenes/Ground/Boundary.tscn")
const ground_obstacle: PackedScene = preload("res://Scenes/Ground/Obstacle.tscn")
const ground_incline: PackedScene = preload("res://Scenes/Ground/Incline.tscn")
const ground_u_track: PackedScene = preload("res://Scenes/Ground/U_Track.tscn")

# 编辑器操作
var is_paused = true # 是否暂停程序
var view_is_rotate = false # 旋转模式
# 视角仪传递的鼠标旋转位移，相机每帧应用后清零
var mouse_rotate_delta: Vector2 = Vector2.ZERO
# Camera旋转角度
var camera_yaw = 0.0
var camera_pitch = 0.0
# 计时器
var _timers: Dictionary = {}  # timer_name -> { "start_time": int, "paused_time": int, "is_running": bool, "elapsed": float }

# “Editor”节点所处的路径
var editor_node_path: String = ""
# “Root3d”节点所处的路径
var root3d_node_path: String = ""
# DebugMonitor是否显示坐标轴
var debug_is_show_axis = false
# DebugMonitor是否显示碰撞区域
var debug_is_show_field_area = false
# DebugMonitor是否显示边框
var debug_is_show_outline = false

# 侧边栏操作
var can_clear_console_content = false
# 物理场无限延伸的长度
var field_ext_length: float = 2000.0
# 初始化数据
var init_field_info: Dictionary = {
	"enabled": true, # 是否立刻启用
	"name": "", # 名称
	"type": 0, # 类型
	"value": 0.0, # 数值
	"direction": [0.0, -1.0, 0.0], # 方向
	"can_extense": true,
	"extense_mode": "a", # 默认全伸展
	"position": [0.0, 0.0, 0.0], # 位置
	"size": [1.0, 1.0, 1.0], # 尺寸
	"is_show_coll": true, # 是否显示碰撞区域
	"coll_color": [120.0, 90.0, 255.0, 32.0], # 碰撞区域颜色
	"description": "" # 描述
}
var init_object_info: Dictionary = {
	"enabled": true, # 是否立刻启用
	"name": "", # 名称
	"mark": "", # 标记
	"type": 0, # 类型
	"position": [0.0, 0.0, 0.0], # 位置
	"vel_value": 0.0, # 初速度大小
	"vel_dir": [1.0, 0.0, 0.0], # 初速度方向
	"description": "", # 描述
	"property": {}
}
var init_obj_particle_info: Dictionary = {
	"mass": 1.0, # 质量大小
	"mass_e": 0  # 质量大小的指数
}
var init_obj_block_info: Dictionary = {
	"as_particle": true,
	"mass": 1.0, # 质量大小
	"mass_e": 0,  # 质量大小的指数
	"scale": [1.0, 1.0, 1.0], # 缩放
	"shape": 0, # 形状
	"color": [1.0, 1.0, 1.0, 1.0] # 填充颜色
}
var init_obj_charged_particle_info: Dictionary = {
	"mass": 1.0, # 质量大小
	"mass_e": 0,  # 质量大小的指数
	"as_charge_point": true, # 是否视为点电荷
	"charge_type": 0, # 带电种类：0正电性 1负电性 2电中性
	"charge": 1, # 带电量大小
	"charge_e": 0, # 带电量大小的指数
	# "total_charge": 1.0, # 总电荷大小
	# "total_charge_e": 0, # 总电荷大小的指数
	# "net_charge": 1.0, # 净电荷大小
	# "net_charge_e": 0 # 净电荷大小的指数
}
var init_ground_info: Dictionary = {
	"enabled": true, # 是否立刻启用
	"name": "", # 名称
	"type": 0, # 类型
	"rotation": [0.0, 0.0, 0.0], # 方向
	"position": [0.0, 0.0, 0.0], # 位置
	"size": [1.0, 1.0, 1.0], # 尺寸
	"coll_color": [1.0, 1.0, 1.0, 1.0], # 碰撞区域颜色
	"description": "" # 描述
}


func _init() -> void:
	# 启动时获取空项目文件
	init_project_data = _get_default_empty_save("")
	run_project_data = init_project_data.duplicate(true)
	print("打开空项目文件")
	
func _ready():
	# 限制主窗口最小为 1024×600
	get_window().min_size = Vector2i(600, 400)
	# 关闭引擎自动退出，交给我们手动控制，保证前置函数完整执行完再退出
	get_tree().set_auto_accept_quit(false)

func _process(delta: float) -> void:
	run_project_data["debug"]["is_paused"] = is_paused

	run_project_data["simulation_settings"]["debug_is_show_axis"] = debug_is_show_axis
	run_project_data["simulation_settings"]["debug_is_show_field_area"] = debug_is_show_field_area
	run_project_data["simulation_settings"]["debug_is_show_outline"] = debug_is_show_outline
	run_project_data["simulation_settings"]["time_scale"] = Engine.time_scale

# 空白默认存档（无存档时使用）
func _get_default_empty_save(file_path: String) -> Dictionary:
	
	var file_final_path: String = ""
	
	if file_path != "":
		file_final_path = file_path.get_file().get_basename()
	
	return {
		# 调试信息
		"debug":{
			"current_project_read_file": current_project_read_file,
			"current_project_file_path": current_project_file_path,
			"is_paused": is_paused
		},
		# 项目信息
		"project_info": {
			"name": file_final_path,
			"created_time": Time.get_datetime_string_from_system(false, true),
			"changed_time": "",
			"version": ProjectSettings.get_setting("application/config/version"),
			"read_only": false
		},
		# 项目设置
		"project_settings":{},
		# 基础运行设置
		"simulation_settings": {
			"debug_is_show_axis": false,
			"debug_is_show_field_area": false,
			"debug_is_show_outline": true,
			"time_scale": 1.0,
		},
		# 物理场
		"fields": {
			"000000": {
				"enabled": true, # 是否立刻启用
				"name": "G1", # 名称
				"type": 3, # 类型
				"value": 9.8, # 数值
				"direction": [0.0, -1.0, 0.0], # 方向
				"can_extense": true,
				"extense_mode": "a", # 默认全伸展
				"position": [0.0, 0.0, 0.0], # 位置
				"size": [3.0, 3.0, 3.0], # 尺寸
				"is_show_coll": true, # 是否显示碰撞区域
				"coll_color": [120.0, 90.0, 255.0, 32.0], # 碰撞区域颜色
				"description": "" # 描述
				}
		},
		# 研究对象
		"objects": {
			# "000001": {
			# 	"enabled": true, # 是否立刻启用
			# 	"name": "obj1", # 名称
			# 	"mark": "m1", # 标记
			# 	"type": 0, # 类型
			# 	"position": [0.0, 5.0, 0.0], # 位置
			# 	"vel_value": 0.0, # 初速度大小
			# 	"vel_dir": [1.0, 0.0, 0.0], # 初速度方向
			# 	"description": "", # 描述
			# 	"property": {
			# 		"mass": 1.0, # 质量大小
			# 		"mass_e": 0  # 质量大小的指数
			# 	}
			# },
			# "000002": {
			# 	"enabled": true, # 是否立刻启用
			# 	"name": "obj2", # 名称
			# 	"mark": "m2", # 标记
			# 	"type": 1, # 类型
			# 	"position": [-5.0, 3.0, 0.0], # 位置
			# 	"vel_value": 0.0, # 初速度大小
			# 	"vel_dir": [1.0, 0.0, 0.0], # 初速度方向
			# 	"description": "", # 描述
			# 	"property": {
			# 		"as_particle": true,
			# 		"mass": 1.0, # 质量大小
			# 		"mass_e": 0,  # 质量大小的指数
			# 		"scale": [1.0, 1.0, 1.0],
			# 		"shape": 0,
			# 		"color": [1.0, 0.0, 0.0, 1.0]
			# 	}
			# }
		},
		# 接触面
		"grounds": {
			# "000003": {
			# 	"enabled": true, # 是否立刻启用
			# 	"name": "ground", # 名称
			# 	"type": 0, # 类型
			# 	"rotation": [0.0, 0.0, 0.0], # 方向
			# 	"position": [0.0, -5.0, 0.0], # 位置
			# 	"size": [5.0, 5.0, 5.0], # 尺寸
			# 	"coll_color": [1.0, 1.0, 1.0, 1.0], # 碰撞区域颜色
			# 	"description": "" # 描述
			# }
		},
		# # 实验器材
		# "apparatus": {},
		# # 电路
		# "circuits": {},
		# 程序
		"programme":{},
		# id_code全集
		"id_code": [
			000000,
			# 000001,
			# 000002,
			# 000003
		]
	}

# 退出前执行 不管是get_tree().quit()还是直接点击右上角按钮
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# 这里写关闭前要执行的函数
		print("程序即将退出，执行保存、释放资源、日志写入等操作")
		check_data_before_quit()
		
# 在退出程序前检查存档文件是否改变
func check_data_before_quit():
	if not check_data_equal():
		# 分支1：打开“退出前关闭”窗口逻辑
		open_quit_and_save_window()
		# 分支2：直接关闭程序
	else:
		get_tree().quit()

# 检查存档文件是否改变
func check_data_equal():
	return data_deep_equal(init_project_data, run_project_data)

# 打开“退出前关闭”窗口逻辑
func open_quit_and_save_window():
	WindowsManager.open_window("QuitAndSaveFile")

# 保存文件时执行
func save_data():
	if run_project_data.has("debug"):
		run_project_data["debug"]["current_project_read_file"] = current_project_read_file
		run_project_data["debug"]["current_project_file_path"] = current_project_file_path
	init_project_data = run_project_data.duplicate(true)

# 递归遍历字典 / 数组所有基础值，逐数字比对，只有真正数值变更才判定脏
# true 一样   false 不一样
func data_deep_equal(a, b) -> bool:
	# 类型不同直接不相等
	if typeof(a) != typeof(b):
		return false
	# 基础值直接比较
	if a is int || a is float || a is String || a is bool:
		return a == b
	# 数组递归对比
	if a is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not data_deep_equal(a[i], b[i]):
				return false
		return true
	# 字典递归对比
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) || !data_deep_equal(a[key], b[key]):
				return false
		return true
	# 其他复杂对象直接判定不等（节点、资源等）
	return false

# 加载项目文件的入口函数
func load_project(project_path: String) -> Dictionary:
	print("Editor加载项目：", project_path)

	# 1. 读取项目文件
	var file = FileAccess.open(project_path, FileAccess.READ)
	if not file:
		print("错误：无法打开项目文件")
		return _get_default_empty_save("")
	
	var json_str = file.get_as_text()
	file.close()

	# 2. 解析JSON数据
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		print("JSON解析错误：", err)
		return _get_default_empty_save("")
	var _project_data = json.data
	
	return _project_data

# 所有物理场的 is_show_coll 都变为 trigger
func all_fields_show_coll_trigger(project_data: Dictionary, trigger: bool):
	for field_id in project_data["fields"]:
		var field = project_data["fields"][field_id]
		field["is_show_coll"] = trigger

# 安全修改嵌套字段（不存在自动创建，防止报错）
# path_arr：层级数组，如["simulation_settings","camera","distance"]
# 使用方法：修改摄像机距离 set_dict_deep(project_data, ["simulation_settings", "camera", "distance"], 2000)
func set_dict_deep(target_dict: Dictionary, path_arr: Array, value):
	var current = target_dict
	for i in range(path_arr.size() - 1):
		var key = path_arr[i]
		if not current.has(key):
			current[key] = {}
		current = current[key]
	# 最后一层赋值
	current[path_arr.back()] = value

# 安全删除嵌套字段（不存在不报错）
# 使用方法：删除重力场描述 erase_dict_deep(project_data, ["fields", "000000", "description"])
func erase_dict_deep(target_dict: Dictionary, path_arr: Array) -> bool:
	var current = target_dict
	for i in range(path_arr.size() - 1):
		var key = path_arr[i]
		if not current.has(key):
			return false
		current = current[key]
	var last_key = path_arr.back()
	if current.has(last_key):
		current.erase(last_key)
		return true
	return false

# 在 run_project_data 中添加新的物理场的数据
func add_field_dict(id_code: int, info: Dictionary):
	# 生成6位补零字符串id
	var key_str = str(id_code).pad_zeros(6)
	# 给字典新增key
	run_project_data["fields"][key_str] = info

# 在 run_project_data 中添加新的研究对象的数据
func add_object_dict(id_code: int, info: Dictionary):
	# 生成6位补零字符串id
	var key_str = str(id_code).pad_zeros(6)
	# 给字典新增key
	run_project_data["objects"][key_str] = info.duplicate(true)

# 在 run_project_data 中添加新的研究对象的数据
func add_ground_dict(id_code: int, info: Dictionary):
	# 生成6位补零字符串id
	var key_str = str(id_code).pad_zeros(6)
	# 给字典新增key
	run_project_data["grounds"][key_str] = info.duplicate(true)

# 根据 info 来调整自身属性
func info_to_change_field(field, data):
	# 无限延伸模式 无视“位置”、“尺寸”
	if data["can_extense"] == true:
		field.scale = Vector3(GlobalData.field_ext_length,GlobalData.field_ext_length,GlobalData.field_ext_length)
		# 关闭物理检测 减少性能开销
		field.monitoring = false
		field.monitorable = false
		field.coll.disabled = true
		# 位置变化
		match data["extense_mode"]:
			"a": # 全伸展（中心）
				field.position = Vector3(0, 0, 0)
			"1": # 第 Ⅰ 卦限，x>0 y>0 z>0
				field.position = Vector3(GlobalData.field_ext_length/2, GlobalData.field_ext_length/2, GlobalData.field_ext_length/2)
			"2": # 第 Ⅱ 卦限，x<0 y>0 z>0
				field.position = Vector3(-GlobalData.field_ext_length/2, GlobalData.field_ext_length/2, GlobalData.field_ext_length/2)
			"3": # 第 Ⅲ 卦限，x<0 y<0 z>0
				field.position = Vector3(-GlobalData.field_ext_length/2, -GlobalData.field_ext_length/2, GlobalData.field_ext_length/2)
			"4": # 第 Ⅳ 卦限，x>0 y<0 z>0
				field.position = Vector3(GlobalData.field_ext_length/2, -GlobalData.field_ext_length/2, GlobalData.field_ext_length/2)
			"5": # 第 Ⅴ 卦限，x>0 y>0 z<0
				field.position = Vector3(GlobalData.field_ext_length/2, GlobalData.field_ext_length/2, -GlobalData.field_ext_length/2)
			"6": # 第 Ⅵ 卦限，x<0 y>0 z<0
				field.position = Vector3(-GlobalData.field_ext_length/2, GlobalData.field_ext_length/2, -GlobalData.field_ext_length/2)
			"7": # 第 Ⅶ 卦限，x<0 y<0 z<0
				field.position = Vector3(-GlobalData.field_ext_length/2, -GlobalData.field_ext_length/2, -GlobalData.field_ext_length/2)
			"8": # 第 Ⅷ 卦限，x>0 y<0 z<0
				field.position = Vector3(GlobalData.field_ext_length/2, -GlobalData.field_ext_length/2, -GlobalData.field_ext_length/2)
			"x_+": # x 正半空间，x>0
				field.position = Vector3(GlobalData.field_ext_length/2, 0, 0)
			"x_-": # x 负半空间，x<0
				field.position = Vector3(-GlobalData.field_ext_length/2, 0, 0)
			"y_+": # y 正半空间，y>0
				field.position = Vector3(0, GlobalData.field_ext_length/2, 0)
			"y_-": # y 负半空间，y<0
				field.position = Vector3(0, -GlobalData.field_ext_length/2, 0)
			"z_+": # z 正半空间，z>0
				field.position = Vector3(0, 0, GlobalData.field_ext_length/2)
			"z_-": # z 负半空间，z<0
				field.position = Vector3(0, 0, -GlobalData.field_ext_length/2)

		if data["extense_mode"] == "a":
			field.shape.visible = false
		else:
			field.shape.visible = true
	# 非无限延伸，需要关注“位置”、“尺寸”
	else:
		field.monitoring = true
		field.monitorable = true
		field.coll.disabled = false
		field.shape.visible = true
		# position三维数组赋值
		var pos_arr = data["position"]
		field.position.x = pos_arr[0]
		field.position.y = pos_arr[1]
		field.position.z = pos_arr[2]

		# size三维数组赋值
		var size_arr = data["size"]
		field.scale.x = size_arr[0]
		field.scale.y = size_arr[1]
		field.scale.z = size_arr[2]
	
	# 修改碰撞区域颜色
	var mesh_material = null
	# 设置成独立材质，各个属性互不影响
	mesh_material = base_field_mat.duplicate(true)
	# 读取颜色数组并归一化
	var color_arr = data["coll_color"]
	var r = color_arr[0] / 255.0
	var g = color_arr[1] / 255.0
	var b = color_arr[2] / 255.0
	var a = color_arr[3] / 255.0
	# 赋值给材质反照率颜色
	mesh_material.albedo_color = Color(r, g, b, a)
	field.shape.set_surface_override_material(0, mesh_material)
	field.shape.visible = data["is_show_coll"]
	# print("刷新：", field.name)

# 根据 info 来调整自身属性
func info_to_change_object(_object, data):
	_object.label.text = data["mark"]
	# position三维数组赋值
	var pos_arr = data["position"]
	_object.position.x = pos_arr[0]
	_object.position.y = pos_arr[1]
	_object.position.z = pos_arr[2]
	# 旋转角度初始化
	_object.rotation = Vector3.ZERO
	# 速度初始化
	var vel_arr = data["vel_dir"]
	var vel_dir = Vector3(vel_arr[0], vel_arr[1], vel_arr[2])
	_object.velocity = data["vel_value"] * vel_dir
	_object.saved_velocity = _object.velocity

	match int(data["type"]):
		0, 2:
			pass
		1:
			# 修改缩放
			_object.coll.scale.x = data["property"]["scale"][0]
			_object.coll.scale.y = data["property"]["scale"][1]
			_object.coll.scale.z = data["property"]["scale"][2]

			# 修改形状
			var new_mesh: Mesh
			match int(data["property"]["shape"]):
				0:
					new_mesh = BoxMesh.new()
				1:
					new_mesh = SphereMesh.new()
					new_mesh.radial_segments = 16
					new_mesh.rings = 8
			
			# 先给网格设置一个基础材质（使网格拥有材质槽）
			var base_material = StandardMaterial3D.new()
			new_mesh.material = base_material
			
			# 赋值给 MeshInstance3D
			_object.mesh.mesh = new_mesh
			
			# 创建独立材质并覆盖
			var color_arr = data["property"]["color"]
			var mesh_material = base_object_mat.duplicate(true)
			mesh_material.albedo_color = Color(color_arr[0], color_arr[1], color_arr[2], color_arr[3])
			# 应用材质
			mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			
			# 应用材质
			_object.mesh.set_surface_override_material(0, mesh_material)
	# print("刷新：", _object.name)
	# GlobalTools.print_dict(_object.info)

# 根据 info 来调整自身属性
func info_to_change_ground(ground, data):
	if data["type"] != 1:
		# 修改缩放
		ground.scale.x = data["size"][0]
		ground.scale.y = data["size"][1]
		ground.scale.z = data["size"][2]
	
	# 读取角度数组
	var rot_deg = data["rotation"]
	# 角度统一转弧度
	# rotation 编辑器里是角度值，结果写代码就要转弧度制，你说搞不搞
	var rot_rad = Vector3(
		deg_to_rad(rot_deg[0]),
		deg_to_rad(rot_deg[1]),
		deg_to_rad(rot_deg[2])
	)
	ground.rotation = rot_rad

	# 位置修改
	ground.position.x = data["position"][0]
	ground.position.y = data["position"][1]
	ground.position.z = data["position"][2]
	
	# ！！！ArrayMesh 不可以给网格设置材料！！！
	if not ground.mesh.mesh is ArrayMesh:
		# 先给网格设置一个基础材质（使网格拥有材质槽）
		var base_material = StandardMaterial3D.new()
		ground.mesh.mesh.material = base_material
	
	# 创建独立材质并覆盖
	var color_arr = data["coll_color"]
	var mesh_material = base_ground_mat.duplicate(true)
	mesh_material.albedo_color = Color(color_arr[0], color_arr[1], color_arr[2], color_arr[3])
	
	# 应用材质
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# 应用材质
	ground.mesh.set_surface_override_material(0, mesh_material)
	# print("刷新：", ground.name)

# 把 type_option_btn 的数据传过来，返回对应的研究对象类型和属性
func select_obj_type(select: int) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	match select:
		0:
			result.append(obj_particle.duplicate(true))
			result.append(obj_particle_property.duplicate(true))
		1:
			result.append(obj_block.duplicate(true))
			result.append(obj_block_property.duplicate(true))
		2:
			result.append(obj_charged_particle.duplicate(true))
			result.append(obj_charged_particle_property.duplicate(true))
	return result

# 把 type_option_btn 的数据传过来，返回对应的研究对象类型和属性
func select_ground_type(select: int) -> PackedScene:
	var result: PackedScene = null
	match select:
		0:
			result = ground_constraint_surface
		1:
			result = ground_obstacle
		2:
			result = ground_incline
		3:
			result = ground_u_track
		4:
			result = ground_boundary
	return result

# 将所有的元素全都加载到场景中
func refresh_all_items_by_data(run_data):
	# 场景树加载完毕后执行
	await get_tree().process_frame
	var data = run_data

	# 遍历 data 中 fields 的内容
	for field_id in data["fields"].keys():
		# 获取基本信息
		var field_info = data["fields"][field_id]
		# 创建新的物理场面板
		var new_field_panel = null
		var field_panel_fold = get_tree().root.get_node(editor_node_path + 
		"/HBoxContainer/RightSplit/TabContainer/ScenePack/SceneScroll/ObjContainer/Field/VBoxContainer")
		var has_panel: bool = false
		for child in field_panel_fold.get_children():
			if child is PanelContainer:
				if child.id_code == int(field_id):
					has_panel = true
					new_field_panel = child
					break
		if not has_panel:
			new_field_panel = field_panel.instantiate()
			new_field_panel.id_code = int(field_id)
			new_field_panel.info = field_info.duplicate(true)
			field_panel_fold.add_child(new_field_panel) # 同步挂载，立刻生效
			field_panel_fold.call_deferred("move_child", new_field_panel, 0)
		# 场景树加载完毕后执行
		await get_tree().process_frame
		# 创建物理场
		var new_field_area = null
		var field_area_fold = get_tree().root.get_node(root3d_node_path + "/AllFields")
		var has_field: bool = false
		for child in field_area_fold.get_children():
			if child is Area3D:
				if child.id_code == int(field_id):
					has_field = true
					new_field_area = child
					break
		if not has_field:
			new_field_area = field_area.instantiate()
			field_area_fold.add_child(new_field_area)
			new_field_panel.field_area = new_field_area
			# （初始化新建物理场专用）当数据被修改后，对应面板的 text 也要被修改
			new_field_panel.id_code_label.text = "*" + str(new_field_panel.id_code).pad_zeros(6)
			new_field_panel.name_label.text = new_field_panel.info["name"]
			new_field_panel.value_spinbox.value = new_field_panel.info["value"]
			new_field_panel.unit_label.text = GlobalTools.field_type_select_to_unit(new_field_panel.info["type"])
			new_field_panel.x_line_edit.text = str(new_field_panel.info["direction"][0])
			new_field_panel.y_line_edit.text = str(new_field_panel.info["direction"][1])
			new_field_panel.z_line_edit.text = str(new_field_panel.info["direction"][2])
			# 刷新物理场区域
			new_field_panel.field_area.id_code = new_field_panel.id_code
			new_field_panel.field_area.info = new_field_panel.info
			new_field_panel.field_area.refresh_field()
		# 刷新状态
		info_to_change_field(new_field_area, field_info)

	# 遍历 data 中 objects 的内容
	for object_id in data["objects"].keys():
		# 获取基本信息
		var object_info = data["objects"][object_id]
		# 创建新的研究对象面板
		var new_object_panel = null
		var object_panel_fold = get_tree().root.get_node(editor_node_path + 
		"/HBoxContainer/RightSplit/TabContainer/ScenePack/SceneScroll/ObjContainer/Object/VBoxContainer")
		var has_panel: bool = false
		for child in object_panel_fold.get_children():
			if child is PanelContainer:
				if child.id_code == int(object_id):
					has_panel = true
					new_object_panel = child
					break
		if not has_panel:
			new_object_panel = object_panel.instantiate()
			new_object_panel.id_code = int(object_id)
			new_object_panel.info = object_info.duplicate(true)
			object_panel_fold.add_child(new_object_panel)
			object_panel_fold.call_deferred("move_child", new_object_panel, 0)
		# 场景树加载完毕后执行
		await get_tree().process_frame
		# 创建研究对象
		object = select_obj_type(object_info["type"])[0]
		var new_object = null
		var object_fold = get_tree().root.get_node(root3d_node_path + "/AllObjects")
		var has_object: bool = false
		for child in object_fold.get_children():
			if child is CharacterBody3D:
				if child.id_code == int(object_id):
					has_object = true
					new_object = child
					break
		if not has_object:
			new_object = object.instantiate()
			object_fold.add_child(new_object)
			new_object_panel.object = new_object
			# （初始化新建研究对象专用）当数据被修改后，对应面板的 text 也要被修改
			new_object_panel.id_code_label.text = "*" + str(new_object_panel.id_code).pad_zeros(6)
			new_object_panel.name_label.text = new_object_panel.info["name"]
			new_object_panel.x_line_edit.text = str(new_object_panel.info["position"][0])
			new_object_panel.y_line_edit.text = str(new_object_panel.info["position"][1])
			new_object_panel.z_line_edit.text = str(new_object_panel.info["position"][2])
			# 刷新研究对象
			new_object_panel.object.id_code = new_object_panel.id_code
			new_object_panel.object.info = new_object_panel.info
			new_object_panel.object.refresh_object()
		# 刷新状态
		info_to_change_object(new_object, object_info)
	
	# 遍历 data 中 grounds 的内容
	for ground_id in data["grounds"].keys():
		# 获取基本信息
		var ground_info = data["grounds"][ground_id]
		# 创建新的接触面面板
		var new_ground_panel = null
		var ground_panel_fold = get_tree().root.get_node(editor_node_path + 
		"/HBoxContainer/RightSplit/TabContainer/ScenePack/SceneScroll/ObjContainer/Ground/VBoxContainer")
		var has_panel: bool = false
		for child in ground_panel_fold.get_children():
			if child is PanelContainer:
				if child.id_code == int(ground_id):
					has_panel = true
					new_ground_panel = child
					break
		if not has_panel:
			new_ground_panel = ground_panel.instantiate()
			new_ground_panel.id_code = int(ground_id)
			new_ground_panel.info = ground_info.duplicate(true)
			ground_panel_fold.add_child(new_ground_panel)
			ground_panel_fold.call_deferred("move_child", new_ground_panel, 0)
		# 场景树加载完毕后执行
		await get_tree().process_frame
		# 创建接触面
		ground = select_ground_type(ground_info["type"])
		var new_ground = null
		var ground_fold = get_tree().root.get_node(root3d_node_path + "/AllGrounds")
		var has_ground: bool = false
		for child in ground_fold.get_children():
			if child is StaticBody3D:
				if child.id_code == int(ground_id):
					has_ground = true
					new_ground = child
					break
		if not has_ground:
			new_ground = ground.instantiate()
			ground_fold.add_child(new_ground)
			new_ground_panel.ground = new_ground
			# （初始化新建接触面专用）当数据被修改后，对应面板的 text 也要被修改
			new_ground_panel.id_code_label.text = "*" + str(new_ground_panel.id_code).pad_zeros(6)
			new_ground_panel.name_label.text = new_ground_panel.info["name"]
			new_ground_panel.x_line_edit.text = str(new_ground_panel.info["position"][0])
			new_ground_panel.y_line_edit.text = str(new_ground_panel.info["position"][1])
			new_ground_panel.z_line_edit.text = str(new_ground_panel.info["position"][2])
			# 刷新接触面
			new_ground_panel.ground.id_code = new_ground_panel.id_code
			new_ground_panel.ground.info = new_ground_panel.info
			new_ground_panel.ground.refresh_ground()
		# 刷新状态
		info_to_change_ground(new_ground, ground_info)
	refresh_all_items.emit()
	var all_fields = get_tree().root.get_node(
		GlobalData.root3d_node_path + "/AllFields")
	FieldManager.initialize(all_fields)


func define_timer(timer_name: String):
	if _timers.has(timer_name):
		return
	# 新建时一次性补齐全部字段，从根源杜绝键缺失
	_timers[timer_name] = {
		"start_ms": 0,
		"is_paused": false,
		"pause_ms": 0,
		"elapsed": 0.0
	}

func start_timer(timer_name: String):
	if not _timers.has(timer_name):
		# 兜底：没定义过的计时器自动创建完整结构
		_timers[timer_name] = {
			"start_ms": Time.get_ticks_msec(),
			"is_paused": false,
			"pause_ms": 0,
			"elapsed": 0.0
		}
		return
	
	var item = _timers[timer_name]
	if item["is_paused"]:
		# 恢复暂停：计算暂停时长，补偿起始时间
		var pause_duration = Time.get_ticks_msec() - item["pause_ms"]
		item["start_ms"] += pause_duration
		item["is_paused"] = false
	else:
		# 非暂停状态 → 全新启动，重置起始时间
		item["start_ms"] = Time.get_ticks_msec()

func pause_timer(name: String):
	name = name.strip_edges()
	if name == "" or not _timers.has(name):
		return
	var timer = _timers[name]
	if timer["is_paused"]:
		return
	timer["is_paused"] = true
	timer["pause_ms"] = Time.get_ticks_msec()

func stop_timer(name: String):
	name = name.strip_edges()
	if name == "" or not _timers.has(name):
		return
	# 停止前先计算最终已用时间，存入elapsed
	var timer = _timers[name]
	var elapsed_sec = 0.0
	if not timer["is_paused"]:
		elapsed_sec = (Time.get_ticks_msec() - timer["start_ms"]) / 1000.0
	else:
		elapsed_sec = (timer["pause_ms"] - timer["start_ms"]) / 1000.0
	# 重置为停止状态，字段和define_timer完全一致
	_timers[name] = {
		"start_ms": 0,
		"is_paused": false,
		"pause_ms": 0,
		"elapsed": elapsed_sec
	}

func get_timer_time(name: String) -> float:
	name = name.strip_edges()
	if name == "" or not _timers.has(name):
		return 0.0
	var timer = _timers[name]
	var current_ms = Time.get_ticks_msec()
	if timer["is_paused"]:
		# 暂停状态：用暂停时刻减去起始时刻，得到已运行毫秒数，转秒返回
		return (timer["pause_ms"] - timer["start_ms"]) / 1000.0
	else:
		# 运行状态：当前时刻减去起始时刻，转秒返回
		return (current_ms - timer["start_ms"]) / 1000.0

## 获取所有已定义的计时器名称
func get_timer_names() -> Array:
	return _timers.keys()

func clear_all_timers():
	_timers.clear()


