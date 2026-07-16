extends CharacterBody3D

# 研究对象的基本属性
var id_code: int = 000000
var info: Dictionary = {
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

# 研究对象的特有性质
var property: Dictionary = {
	"mass": 1.0, # 质量大小
	"mass_e": 0  # 质量大小的指数
}

# 每帧所用的时间 delta_time = delta * Engine.time_scale
var delta_time = 0.0
# 碰撞箱 质点mesh 标签文字
@onready var coll = $CollisionShape3D
@onready var mesh = $CollisionShape3D/ObjectShape3D
@onready var label = $Label3D
# 是否可以用 gizmo 选中
var be_selected_by_gizmo: bool = false
# 暂停前保存的速度
var saved_velocity: Vector3 = Vector3.ZERO
# 上一帧是否处于暂停
var was_paused: bool = false
# 初速度大小、方向
@export var vel: float = 2.0
@export var vel_dir: Vector3 = Vector3(1.0, 0.0, 0.0)
# 质量
@export var mass: float = 1.0
# 获取物理场的信息
var fields = null
# 当前加速度
var current_acceleration: Vector3 = Vector3.ZERO
# 0=完全非弹性, 1=完全弹性
@export var restitution: float = 1.0

# 初始化 
func _ready():
	await get_tree().process_frame
	linear_move(vel, vel_dir)
	pass

# 物理帧计算 delta固定
func _physics_process(delta: float) -> void:
	# get_lowest_record()
	current_acceleration = Vector3.ZERO
	# 暂停模拟则静止不动
	if get_tree().current_scene.name != "Root3d_test":
		vel = info["vel_value"]
		var vel_arr = info["vel_dir"]
		vel_dir = Vector3(vel_arr[0], vel_arr[1], vel_arr[2])
		if GlobalData.is_paused:
			if not was_paused:
				saved_velocity = velocity       # 第一次暂停时保存当前速度
				was_paused = true
			velocity = Vector3.ZERO             # 速度清零
			return                              # 跳过本帧物理计算
		else:
			if was_paused:
				velocity = saved_velocity       # 恢复暂停前的速度
				was_paused = false
	# 变量赋值
	delta_time = 1.0 /(ProjectSettings.get_setting("physics/common/physics_ticks_per_second") / Engine.time_scale)
	mass = get_mass()
	# 从全局场管理器获取当前位置场信息
	fields = FieldManager.get_field_at(global_position)

	gravity_movement()
	custom_movement()
	
	velocity += current_acceleration * delta_time
	
	# 执行移动
	var collided = move_and_slide()

	# 如果发生了碰撞
	if collided:
		var collision = get_last_slide_collision()   # 获取 KinematicCollision3D 对象
		if collision:
			var normal = collision.get_normal()
			velocity = CollisionSolver.solve_static_collision(
				velocity, 
				normal, 
				mass, 
				restitution
			)

### ====================================== 物理场下的运动 ============================
# 重力场下的运动
func gravity_movement():
	# 重力 F = mg
	var g = fields["gravity"]
	if g["value"] > 0.0:
		var g_dir = Vector3(g["dir"][0], g["dir"][1], g["dir"][2])
		# 重力加速度直接等于场向量
		current_acceleration += g_dir * g["value"]


# 自定义场下的运动
func custom_movement():
	# 外力 F = ma
	var c = fields["custom"]
	if c["value"] > 0.0:
		var c_dir = Vector3(c["dir"][0], c["dir"][1], c["dir"][2])
		current_acceleration += c_dir * c["value"]


# 线性运动 _vel初速度大小 _dir初速度方向
func linear_move(_vel: float, _dir: Vector3) -> Vector3:
	# _dir.normalized()方向归一化得单位向量
	var v = _vel * _dir.normalized()
	return v

# 停止运动
func is_fixed():
	velocity = Vector3.ZERO


# 修改完属性后刷新
func refresh_object():
	# 修改 run_project_data 的数据
	GlobalData.run_project_data["objects"][str(id_code).pad_zeros(6)] = info.duplicate(true)
	GlobalData.info_to_change_object(self, info)

# 获取质量：假设 mass = 1.67, mass_e = -27  →  实际质量 = 1.67 × 10^-27（质子质量数量级）
func get_mass() -> float:
	if get_tree().current_scene.name != "Root3d_test":
		var m = info["property"]["mass"]
		var e = info["property"]["mass_e"]
		return m * pow(10.0, e)
	else:
		var m = property["mass"]
		var e = property["mass"]
		return m * pow(10.0, e)

