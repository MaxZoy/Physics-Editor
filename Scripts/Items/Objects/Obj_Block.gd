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
	"mass_e": 0,  # 质量大小的指数	
	"as_particle": true,
	"scale": [1.0, 1.0, 1.0],
	"shape": 0,
	"color": [1.0, 1.0, 1.0, 1.0]
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

# 方块几何参数（用于转动惯量）
@export var box_size: Vector3 = Vector3(1.0, 1.0, 1.0)   # 长、高、宽（世界单位）
# 内部状态
var half_size: Vector3
# 接触状态
var in_contact: bool = false
var contact_normal: Vector3 = Vector3.ZERO
const COLLISION_VELOCITY_THRESHOLD: float = 0.1   # 低于此速度视为静接触


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
	box_size = get_cube_size()
	half_size = box_size * 0.5
	# 从全局场管理器获取当前位置场信息
	fields = FieldManager.get_field_at(global_position)

	gravity_movement()
	custom_movement()
	
	velocity += current_acceleration * delta_time

	# 如果当前处于接触状态，将速度投影到切平面（保持贴面滑动）
	if in_contact:
		var vn = velocity.dot(contact_normal)
		if vn < 0:
			# 正在压向表面 → 去除法向分量（模拟支持力抵消穿透）
			velocity -= vn * contact_normal
		else:
			# 正在离开表面 → 解除接触，让它自由运动（反弹效果）
			in_contact = false
	# 移动
	var collided = move_and_slide()
	rotation_collided(collided)

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

# 获取方块的边长
func get_cube_size() -> Vector3:
	if get_tree().current_scene.name != "Root3d_test":
		var sca_arr = info["property"]["scale"]
		var my_size = Vector3.ZERO
		my_size.x = sca_arr[0]
		my_size.y = sca_arr[1]
		my_size.z = sca_arr[2]
		return my_size
	else:
		var sca_arr = property["scale"]
		var my_size = Vector3.ZERO
		my_size.x = sca_arr[0]
		my_size.y = sca_arr[1]
		my_size.z = sca_arr[2]
		return my_size

func rotation_collided(collided):
	if collided:
		var col = get_last_slide_collision()
		if col:
			var normal = col.get_normal()
			var vn = velocity.dot(normal)

			if vn < -COLLISION_VELOCITY_THRESHOLD:
				# 检查是否需要更新旋转（首次接触或法线方向变化 > 阈值）
				var need_rotate = false
				if not in_contact:
					need_rotate = true
				elif contact_normal.dot(normal) < 0.99:   # 法线角度变化 > 约8°
					need_rotate = true

				if need_rotate:
					# 瞬间将物体底面贴合到斜面
					snap_to_surface(normal)

				# 反弹（可选）
				velocity = _bounce(velocity, normal, restitution)

				contact_normal = normal
				in_contact = true
			else:
				in_contact = false
	else:
		in_contact = false

# 瞬间旋转物体，使底面与斜面平行（上方向 = 法线）
func snap_to_surface(normal: Vector3) -> void:
	var n = normal.normalized()
	# 保持原有的前方向（z轴），但需要正交化
	var forward = -global_transform.basis.z   # Godot 中 -z 为前方
	# 如果前方向与法线平行，则改用世界 X 轴作为前方向
	if abs(forward.dot(n)) > 0.99:
		forward = Vector3(1, 0, 0) if abs(n.x) < 0.99 else Vector3(0, 0, 1)
	# 重新正交基：上方向 = n，右方向 = forward.cross(n).normalized()，前方向 = n.cross(右)
	var right = forward.cross(n).normalized()
	forward = n.cross(right).normalized()
	# 构建新的基（注意 Godot 的 Basis 列向量：x=右, y=上, z=-前）
	global_transform.basis = Basis(right, n, -forward)

# 速度反弹（保留 CollisionSolver 的逻辑，也可直接调用它的函数）
func _bounce(v: Vector3, normal: Vector3, e: float) -> Vector3:
	var vn = v.dot(normal)
	if vn < 0:
		return v - (1.0 + e) * vn * normal
	return v



