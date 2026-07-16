extends CharacterBody3D

# 研究对象的基本属性
var id_code: int = 000001
var info: Dictionary = {
	"enabled": true, # 是否立刻启用
	"name": "a", # 名称
	"mark": "m1", # 标记
	"type": 0, # 类型
	"position": [0.0, 0.0, 0.0], # 位置
	"vel_value": 1.0, # 初速度大小
	"vel_dir": [1.0, 0.0, 0.0], # 初速度方向
	"description": "", # 描述
	"property": {}
}

# 研究对象的特有性质
var property: Dictionary = {
	# 质点
	"mass": 1.0, # 质量大小
	"mass_e": 0,  # 质量大小的指数
	# 刚体物块
	"as_particle": true,
	"scale": [1.0, 1.0, 1.0],
	"shape": 0,
	"color": [1.0, 1.0, 1.0, 1.0],
	# 带电粒子
	"as_charge_point": true, # 是否视为点电荷
	"charge_type": 0, # 带电种类：0正电性 1负电性 2电中性
	"charge": 1, # 带电量大小
	"charge_e": 0, # 带电量大小的指数
	# "total_charge": 1.0, # 总电荷大小
	# "total_charge_e": 0, # 总电荷大小的指数
	# "net_charge": 1.0, # 净电荷大小
	# "net_charge_e": 0 # 净电荷大小的指数
}

# 每帧所用的时间 delta_time = delta * Engine.time_scale
var delta_time = 0.0
# 碰撞箱 质点mesh 标签文字
@onready var coll = $CollisionShape3D
@onready var mesh = $CollisionShape3D/ObjectShape3D
@onready var label = $Label3D
# 是否可以用 gizmo 选中
var be_selected_by_gizmo: bool = false
# 初速度大小、方向
@export var vel: float = 2.0
@export var vel_dir: Vector3 = Vector3(1.0, 0.0, 0.0)
# 质量
@export var mass: float = 1.0
# 电荷量
@export var charge: float = 0.0
# 获取物理场的信息
var fields = null
# 当前加速度
var current_acceleration: Vector3 = Vector3.ZERO
# 0=完全非弹性, 1=完全弹性
@export var restitution: float = 1.0

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
			is_fixed()
			return
	# 变量赋值
	delta_time = delta * Engine.time_scale
	mass = get_mass()
	# 从全局场管理器获取当前位置场信息
	fields = FieldManager.get_field_at(global_position)

	gravity_movement()
	electric_movement()
	magnetic_movement()
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

# 电场下的运动
func electric_movement():
	# 电场力 F = qE
	var e = fields["electric"]
	if e["value"] > 0.0:
		var e_dir = Vector3(e["dir"][0], e["dir"][1], e["dir"][2])
		var E = e_dir * e["value"]
		var force = E * charge
		current_acceleration += force / mass

# 磁场下的运动
func magnetic_movement():
	var b = fields["magnetic"]
	if b["value"] <= 0.0 or mass <= 0.0:
		return
	var b_dir = Vector3(b["dir"][0], b["dir"][1], b["dir"][2])
	var B = b_dir * b["value"]
	
	# Boris 算法
	var q = charge
	var m = mass
	var t = (q * delta_time / m) * B * 0.5
	# 避免 t 过大导致溢出
	if t.length() > 1e-6:
		var s = 2.0 * t / (1.0 + t.dot(t))
		var v_minus = velocity
		var v_prime = v_minus + v_minus.cross(t)
		var v_plus = v_minus + v_prime.cross(s)
		velocity = v_plus

# 自定义场下的运动
func custom_movement():
	# 外力 F = ma
	var c = fields["custom"]
	if c["value"] > 0.0:
		var c_dir = Vector3(c["dir"][0], c["dir"][1], c["dir"][2])
		current_acceleration += c_dir * c["value"]


### ===================================== 特殊的运动模式 ===============================
# 线性运动 _vel初速度大小 _dir初速度方向
func linear_move(_vel: float, _dir: Vector3) -> Vector3:
	# _dir.normalized()方向归一化得单位向量
	var v = _vel * _dir.normalized()
	return v

# 停止运动
func is_fixed():
	velocity = Vector3.ZERO

# 随机方向运动-扩散 _vel初速度大小 _dir初速度方向
func random_move(_vel: float) -> Vector3:
	var _dir: Vector3 = Vector3(randf_range(-1.0, 1.0),
								randf_range(-1.0, 1.0),
								randf_range(-1.0, 1.0))
	
	var v = _vel * _dir.normalized()
	return v

# 匀加速运动 _acc加速度大小 _dir加速度方向
func uniform_accelerated_move(_vel: Vector3, _acc: float, _dir: Vector3) -> Vector3:
	var v = _vel + _acc * _dir.normalized() * delta_time
	return v

var _new_cir_angle: float = 0.0 # 每次迭代的新角度

# 匀速圆周运动 _r半径长度 _r_dir半径的朝向 _vel初速度大小 _dir初速度方向
func uniform_circular_move(_r: float, _r_dir: Vector3, _dir: Vector3, _vel: float) -> Vector3:
	var _projection_dir = get_vertical_projection_vector(_r_dir, _dir) # 获取投影向量
	_new_cir_angle += deflection_angle_per_frame(_vel, _r) # 获取偏转角度
	var _corrected_dir = corrected_deflection_vector(_r_dir, _projection_dir, -1 * _new_cir_angle)
	var v = _vel * _corrected_dir
	
	return v

# 获得垂直投影向量  a-原向量  b-在与a垂直的平面上的投影向量的原向量
func get_vertical_projection_vector(a: Vector3, b: Vector3) -> Vector3:
	vector_interception(GlobalTools.get_current_func_name(), a, b)
	
	var c = a.cross(b) # 先取ab叉乘过后的结果c（同时垂直于a、b）
	var d = a.cross(c) # 再取ac叉乘结果d
	var e = b.project(d) # 最后算出半径方向b在d上的投影向量e
	return e.normalized() # e归一化后返回值

# 获得圆周运动每帧偏转角度
func deflection_angle_per_frame(_vel: float, _r: float) -> float:
	var theta = (_vel / _r) * (1.0 /(ProjectSettings.get_setting("physics/common/physics_ticks_per_second") / Engine.time_scale))
	return theta

# 获得圆周修正偏转向量 a:参考向量, b:待偏转向量, m:偏转角(弧度制)
func corrected_deflection_vector(a: Vector3, b: Vector3, m: float) -> Vector3:
	vector_interception(GlobalTools.get_current_func_name(), a, b)
	
	# 计算a、b平面的法向旋转轴
	var cross_ab = a.cross(b)
	var cross_len = cross_ab.length()
	# a与b平行，无旋转平面，直接返回原b
	if cross_ab == Vector3.ZERO:
		return b
	
	var axis = cross_ab / cross_len # 单位旋转轴
	
	# 绕轴旋转m弧度，得到偏转后的c
	var c = b.rotated(axis, m)
	return c

# 拦截双向量为零向量或者平行向量
func vector_interception(func_name:String, a: Vector3, b: Vector3):
	if a == Vector3.ZERO:
		printerr(func_name, ": a为零向量")
	if b == Vector3.ZERO:
		printerr(func_name, ": b为零向量")
	if a.cross(b) == Vector3.ZERO:
		printerr(func_name, ": a与b共线")
	
	if ((a != Vector3.ZERO) and 
		(b != Vector3.ZERO) and
		(a.cross(b) != Vector3.ZERO)):
		return

# 允许外部直接设置加速度
func apply_acceleration(accel: Vector3, delta: float):
	velocity += accel * delta
	move_and_slide()


### ============================== 其他一些与运动无关的函数 ================================
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

# 最低 y 坐标记录
var lowest_y: float = INF   # 初始化为正无穷
var lowest_position: Vector3 = Vector3.ZERO  # 记录最低点位置
func get_lowest_record():
	var current_y = global_position.y
	if current_y < lowest_y:
		lowest_y = current_y
		lowest_position = global_position
	print("最低 y: ", lowest_y, " 位置: ", lowest_position)


