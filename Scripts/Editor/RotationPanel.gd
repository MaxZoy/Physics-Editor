extends TextureRect

var press_inside: bool = false

# 背面暗球引用
@onready var x_b: TextureRect = $x_back
@onready var y_b: TextureRect = $y_back
@onready var z_b: TextureRect = $z_back

var m_length: float = 24.0
@export var m_thickness: float = 2.0

# 正面轴线条
@onready var x_m: ColorRect = $X
@onready var y_m: ColorRect = $Y
@onready var z_m: ColorRect = $Z
@onready var c_point: ColorRect = $Center

# 正面带字标签球
@onready var x_l: TextureRect = $x_label
@onready var y_l: TextureRect = $y_label
@onready var z_l: TextureRect = $z_label

func _ready():
	mouse_filter = MOUSE_FILTER_PASS
	setup_pivot_center()

func setup_pivot_center() -> void:
	var all_ctrl = [x_m, y_m, z_m, x_b, y_b, z_b, x_l, y_l, z_l, c_point]
	for ctrl in all_ctrl:
		ctrl.pivot_offset_ratio = Vector2(0.5, 0.5)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_inside = get_global_rect().has_point(event.global_position)
			GlobalData.view_is_rotate = press_inside
			# 启用鼠标捕获，实现无限拖拽
			if press_inside:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			press_inside = false
			GlobalData.view_is_rotate = false
			GlobalData.mouse_rotate_delta = Vector2.ZERO
			# 释放鼠标捕获
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseMotion and press_inside:
		GlobalData.mouse_rotate_delta = event.relative

func is_mouse_hold_inside() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		and press_inside

func _process(delta: float) -> void:
	update_view_axis()
	GlobalData.view_is_rotate = press_inside

func project_axis(world_vec: Vector3, yaw: float, pitch: float) -> Vector3:
	var q_yaw = Quaternion(Vector3.UP, yaw)
	var q_pitch = Quaternion(Vector3.RIGHT, pitch)
	var q = q_yaw * q_pitch
	var local = q.inverse() * world_vec
	return Vector3(local.x, -local.y, local.z)

func update_view_axis() -> void:
	var yaw = -GlobalData.camera_yaw
	var pitch = GlobalData.camera_pitch
	var center = size / 2.0
	
	# 判断是否接近极点（俯仰角 > 85° 或 < -85°）
	var is_near_pole = abs(pitch) > deg_to_rad(85.0)
	
	c_point.position = center - c_point.size / 2.0
	c_point.z_index = 100

	var vec_x = project_axis(Vector3.RIGHT, yaw, pitch)
	var vec_y = project_axis(Vector3.DOWN, yaw, pitch)
	var vec_z = project_axis(Vector3.FORWARD, yaw, pitch)

	update_single_axis(x_m, x_b, x_l, vec_x, center, is_near_pole)
	update_single_axis(y_m, y_b, y_l, vec_y, center, is_near_pole)
	update_single_axis(z_m, z_b, z_l, vec_z, center, is_near_pole)

func update_single_axis(front_line: ColorRect, back_ball: TextureRect, front_label: TextureRect, vec: Vector3, center: Vector2, force_alpha_full: bool) -> void:
	var dir_2d = Vector2(vec.x, -vec.y)
	var angle = dir_2d.angle()
	var proj_len = dir_2d.length()

	var line_z = int((-vec.z + 1.0) * 24)
	var back_ball_z = 50 + int((vec.z + 1.0) * 24)
	var front_ball_z = 150 + int((-vec.z + 1.0) * 24)

	front_line.z_index = line_z
	back_ball.z_index = back_ball_z
	front_label.z_index = front_ball_z

	front_line.visible = true
	front_line.size = Vector2(m_length * 2 * proj_len, m_thickness)
	front_line.rotation = angle
	front_line.position = center - front_line.size / 2.0

	var dir_norm = dir_2d.normalized()
	var end_pos_front = center + dir_norm * m_length * proj_len
	var end_pos_back = center - dir_norm * m_length * proj_len

	# ===== 透明度控制 =====
	if force_alpha_full:
		# 极点附近：所有球全亮（消除闪烁）
		front_label.modulate.a = 1.0
		back_ball.modulate.a = 1.0
	else:
		# 正常情况：根据深度区分前后
		front_label.modulate.a = 1.0 if vec.z <= 0.0 else 0.4
		back_ball.modulate.a = 1.0 if vec.z >= 0.0 else 0.4

	front_label.visible = proj_len > 0.01
	front_label.position = end_pos_front - front_label.size / 2.0

	back_ball.visible = proj_len > 0.01
	back_ball.position = end_pos_back - back_ball.size / 2.0


