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
# 暂停前保存的速度
var saved_velocity: Vector3 = Vector3.ZERO
# 上一帧是否处于暂停
var was_paused: bool = false
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
	debug_movement()
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
	charge = get_charge()
	box_size = get_cube_size()
	half_size = box_size * 0.5
	# 从全局场管理器获取当前位置场信息
	fields = FieldManager.get_field_at(global_position)

	gravity_movement()
	electric_movement()
	magnetic_movement()
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

# 测试运动
func debug_movement():
	# velocity = uniform_circular_move(2,Vector3(0,1,0),Vector3(1,0,0),5) # 圆周运动
	# velocity = random_move(vel) # 随机方向运动-扩散
	velocity = linear_move(vel, vel_dir) # 匀速直线运动
	# velocity = uniform_accelerated_move(velocity, 9.8, Vector3(0, -1, 0)) # 匀加速运动-自由落体
	# velocity = uniform_accelerated_move(velocity, 9.8, Vector3(0, -1, 0)) # 平抛
	# velocity = linear_move(vel, vel_dir) + random_move(vel)
	# velocity = uniform_circular_move(2,Vector3(0,1,0),Vector3(0,0,-1),5) + linear_move(vel, vel_dir) # 圆周+匀直
	pass

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

# 获取带电量
func get_charge() -> float:
	if get_tree().current_scene.name != "Root3d_test":
		var m = info["property"]["charge"]
		var e = info["property"]["charge_e"]
		return m * pow(10.0, e)
	else:
		var m = property["charge"]
		var e = property["charge_e"]
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

# 最低 y 坐标记录
var lowest_y: float = INF   # 初始化为正无穷
var lowest_position: Vector3 = Vector3.ZERO  # 记录最低点位置
func get_lowest_record():
	var current_y = global_position.y
	if current_y < lowest_y:
		lowest_y = current_y
		lowest_position = global_position
	print("最低 y: ", lowest_y, " 位置: ", lowest_position)


# 完全弹性碰撞（反射）
func get_reflection_velocity(v: Vector3, normal: Vector3) -> Vector3:
	var n = normal.normalized()
	return v - 2 * v.dot(n) * n

# 完全非弹性碰撞（贴面）
func get_sliding_velocity(v: Vector3, normal: Vector3) -> Vector3:
	var n = normal.normalized()
	return v - v.dot(n) * n

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


