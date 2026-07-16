extends Camera3D

# 灵敏度参数
@export var rotate_speed: float = 1.0       # 右键旋转灵敏度
@export var pan_speed: float = 1.2        # 左键平移灵敏度
@export var zoom_speed: float = 1.0         # 滚轮缩放速度

# 限制参数
var min_pitch: float = -90.0        # 最低仰角（防止万向锁，不要设为-90）
var max_pitch: float = 90.0         # 最高仰角
var min_zoom: float = 5.0           # 最小缩放（最大放大）
var max_zoom: float = 50.0         # 最大缩放（最小放大）
var original_size: float

# 自由轨道相机核心状态
var yaw: float = 0.0                # 水平旋转角度（绕Y轴）
var pitch: float = 0.0              # 垂直旋转角度（绕X轴）
var distance: float = 1000.0          # 相机到旋转中心的距离
var orbit_center: Vector3 = Vector3.ZERO  # 当前旋转中心（相机正前方的焦点）
var direction: Vector3 = Vector3.ZERO

var is_rotating: bool = false
var is_panning: bool = false

# ---------- 四元数旋转累积 ----------
# 该四元数表示相机的绝对旋转（不含位置）
# 初始为单位四元数（无旋转），其 forward 方向为 -Z
var rotation_quat: Quaternion = Quaternion.IDENTITY

func _ready():
	# 单场景相机唯一性检查
	if (get_tree().current_scene.name == "Editor3D" or 
		get_tree().current_scene.name == "MainUI"):
		if get_parent().name == "Root3d_test":
			self.queue_free()
			return
	
	original_size = self.size
	distance = get_position().z
	
	# 从当前相机状态自动初始化所有轨道参数
	var forward = -global_transform.basis.z
	orbit_center = global_position + forward * distance
	
	# 从初始位置和中心计算角度
	var initial_dir = (global_position - orbit_center).normalized()
	pitch = asin(initial_dir.y)
	yaw = atan2(initial_dir.x, initial_dir.z)
	
	# 使用 yaw/pitch 构建初始四元数
	var q_yaw = Quaternion(Vector3.UP, yaw)
	var q_pitch = Quaternion(Vector3.RIGHT, pitch)
	rotation_quat = q_yaw * q_pitch   # 先水平（全局），再垂直（局部）
	
	# 强制更新一次相机位置和朝向
	_update_orbit_camera()

func _process(delta: float) -> void:
	# 应用视角仪传递的旋转位移
	if GlobalData.mouse_rotate_delta != Vector2.ZERO:
		var rel = GlobalData.mouse_rotate_delta
		# 计算旋转增量（弧度）
		var angle_yaw = -rel.x * rotate_speed * (1 / (distance * 10)) * (max_zoom - size / (max_zoom - min_zoom))
		var angle_pitch = -rel.y * rotate_speed * (1 / (distance * 10)) * (max_zoom - size / (max_zoom - min_zoom))
		
		# ---------- 俯仰角限制 ----------
		# 计算受限后的新俯仰角
		var new_pitch = pitch + angle_pitch
		new_pitch = clamp(new_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		var limited_angle_pitch = new_pitch - pitch   # 受限的垂直增量
		# 用受限增量替代原增量
		angle_pitch = limited_angle_pitch
		
		# ---------- 四元数应用旋转 ----------
		var q_yaw_delta = Quaternion(Vector3.UP, angle_yaw)
		var q_pitch_delta = Quaternion(Vector3.RIGHT, angle_pitch)
		# 顺序：先全局水平旋转，再局部垂直旋转
		rotation_quat = q_yaw_delta * rotation_quat * q_pitch_delta
		
		# 提取更新后的欧拉角（用于外部读取）
		var euler = rotation_quat.get_euler()
		yaw = euler.y
		pitch = euler.x
		
		GlobalData.camera_yaw = yaw
		GlobalData.camera_pitch = pitch
		# 更新相机位置与朝向
		_update_orbit_camera()
		# 用完清零
		GlobalData.mouse_rotate_delta = Vector2.ZERO
		
		debug_print()

func _unhandled_input(event: InputEvent):
	
	# 右键拖拽：绕当前旋转中心旋转
	if (event is InputEventMouseButton and 
		event.button_index == MOUSE_BUTTON_RIGHT and 
		get_tree().current_scene.name == "Root3d_test"):
		is_rotating = event.pressed
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)
	
	# 平移视角
	if event is InputEventMouseButton:
		# 不在Root3d 场景下
		if not get_tree().current_scene.name == "Root3d_test":
			# 用右键拖拽平移
			if event.button_index == MOUSE_BUTTON_RIGHT:
				is_panning = event.pressed
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)
		# 在 Root3d 场景下
		# else:
		# 	# 用左键拖拽平移
		# 	if event.button_index == MOUSE_BUTTON_LEFT:
		# 		is_panning = event.pressed
		# 		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)
	
	# 滚轮缩放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if projection == PROJECTION_ORTHOGONAL:
				size = clamp(size - zoom_speed, min_zoom, max_zoom)
			else:
				distance = clamp(distance - zoom_speed, min_zoom, max_zoom)
				_update_orbit_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if projection == PROJECTION_ORTHOGONAL:
				size = clamp(size + zoom_speed, min_zoom, max_zoom)
			else:
				distance = clamp(distance + zoom_speed, min_zoom, max_zoom)
				_update_orbit_camera()
	
	 # Ctrl + + / Ctrl + - 键盘缩放
	elif event is InputEventKey and event.pressed and event.ctrl_pressed:
		if event.keycode == KEY_EQUAL:
			if projection == PROJECTION_ORTHOGONAL:
				size = clamp(size - zoom_speed * 4, min_zoom, max_zoom)
			else:
				distance = clamp(distance - zoom_speed * 4, min_zoom, max_zoom)
			_update_orbit_camera()
		elif event.keycode == KEY_MINUS:
			if projection == PROJECTION_ORTHOGONAL:
				size = clamp(size + zoom_speed * 4, min_zoom, max_zoom)
			else:
				distance = clamp(distance + zoom_speed * 4, min_zoom, max_zoom)
			_update_orbit_camera()
	
	# 鼠标移动处理
	elif event is InputEventMouseMotion:
		if is_rotating:
			# 计算旋转增量（弧度）
			var angle_yaw = -event.relative.x * rotate_speed * (1 / (distance * 10)) * (max_zoom - size / (max_zoom - min_zoom))
			var angle_pitch = -event.relative.y * rotate_speed * (1 / (distance * 10)) * (max_zoom - size / (max_zoom - min_zoom))
			
			# ---------- 俯仰角限制 ----------
			var new_pitch = pitch + angle_pitch
			new_pitch = clamp(new_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
			var limited_angle_pitch = new_pitch - pitch
			angle_pitch = limited_angle_pitch
			
			# ---------- 四元数应用旋转 ----------
			var q_yaw_delta = Quaternion(Vector3.UP, angle_yaw)
			var q_pitch_delta = Quaternion(Vector3.RIGHT, angle_pitch)
			rotation_quat = q_yaw_delta * rotation_quat * q_pitch_delta
			
			# 提取更新后的欧拉角
			var euler = rotation_quat.get_euler()
			yaw = euler.y
			pitch = euler.x
			
			# 更新相机位置和朝向
			_update_orbit_camera()
		
		elif is_panning:
			# 平移：同时移动相机和旋转中心
			var right = global_transform.basis.x * event.relative.x * pan_speed * size / 1000
			var up = -global_transform.basis.y * event.relative.y * pan_speed * size / 1000
			var offset = right + up
			
			global_position -= offset
			orbit_center -= offset
	

# 核心：自由轨道相机更新函数
# 使用四元数计算方向向量，手动构建相机朝向
func _update_orbit_camera():
	var x = sin(yaw) * cos(pitch)
	var y = -sin(pitch)
	var z = cos(yaw) * cos(pitch)
	direction = Vector3(x, y, z).normalized()
	global_position = orbit_center + direction * distance
	
	# 使用 yaw 和 pitch 构建四元数（顺序：先水平再垂直）
	var q_yaw = Quaternion(Vector3.UP, yaw)
	var q_pitch = Quaternion(Vector3.RIGHT, pitch)
	var q = q_yaw * q_pitch
	global_transform.basis = Basis(q)

func get_nearest_half_pi(t: float) -> float:
	var pi = PI
	var half_pi = pi / 2.0
	var two_pi = 2.0 * pi
	
	var k_float = (t - half_pi) / two_pi
	var k = round(k_float)
	return half_pi + two_pi * k

func debug_print():
	# print("yaw: ", "%.2f" % yaw, "     ", "pitch: ", "%.2f" % pitch)
	# print("direction: ", direction)
	# print("global_position: ", global_position)
	# print("global_rotation: ", global_rotation)
	pass
