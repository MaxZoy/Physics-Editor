extends Control

var camera: Camera3D
@export var is_show_axis: bool = false

var axis_length: float = 1000.0      # 坐标轴在3D空间中的长度
var line_thickness: float = 1.6    # 线条粗细
var draw_negative: bool = true     # 是否绘制负方向轴
var axis_origin: Vector3 = Vector3.ZERO  # 坐标轴3D原点位置
@export var alpha: float = 0.8
var r_color: Color = Color(1.0, 0.196, 0.196, 1.0)
var b_color: Color = Color(0.196, 0.588, 1.0, 1.0)
var g_color: Color = Color(0.196, 1.0, 0.196, 1.0)

func _ready() -> void:
	if get_tree().current_scene.name != "Root3d_test":
		if get_parent().get_parent().name == "Root3d_test":
			self.queue_free()
		
	else:
		is_show_axis = true
	
	camera = get_viewport().get_camera_3d()

func _process(delta: float) -> void:
	
	# GlobalData.debug_is_show_axis = true
	
	
	# 每帧重绘，同步相机的所有变换
	queue_redraw()


func _draw() -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	r_color.a = alpha
	b_color.a = alpha
	g_color.a = alpha
	
	# 计算6个轴端点的3D坐标
	var x_pos = axis_origin + Vector3.RIGHT * axis_length
	var x_neg = axis_origin + Vector3.LEFT * axis_length
	var y_pos = axis_origin + Vector3.UP * axis_length
	var y_neg = axis_origin + Vector3.DOWN * axis_length
	var z_pos = axis_origin + Vector3.FORWARD * axis_length
	var z_neg = axis_origin + Vector3.BACK * axis_length

	# 将3D坐标投影为2D屏幕像素坐标（左上角为原点）
	var origin_2d = camera.unproject_position(axis_origin)
	var x_pos_2d = camera.unproject_position(x_pos)
	var x_neg_2d = camera.unproject_position(x_neg)
	var y_pos_2d = camera.unproject_position(y_pos)
	var y_neg_2d = camera.unproject_position(y_neg)
	var z_pos_2d = camera.unproject_position(z_pos)
	var z_neg_2d = camera.unproject_position(z_neg)
	
	if is_show_axis:
		# 绘制X轴（红色）
		draw_line(origin_2d, x_pos_2d, r_color, line_thickness)
		if draw_negative:
			draw_line(origin_2d, x_neg_2d, r_color, line_thickness)

		# 绘制Y轴（绿色）
		draw_line(origin_2d, y_pos_2d, g_color, line_thickness)
		if draw_negative:
			draw_line(origin_2d, y_neg_2d, g_color, line_thickness)

		# 绘制Z轴（蓝色）
		draw_line(origin_2d, z_pos_2d, b_color, line_thickness)
		if draw_negative:
			draw_line(origin_2d, z_neg_2d, b_color, line_thickness)
	
