extends Node3D

@export var is_show_axis: bool = false
@export var axis_always_on_top: bool = true
@export var axis_length: float = 10000.0  # 坐标轴总长度，足够覆盖场景

var mesh: ArrayMesh
var mat_x: StandardMaterial3D
var mat_y: StandardMaterial3D
var mat_z: StandardMaterial3D
var mi: MeshInstance3D

func _ready():
	mesh = ArrayMesh.new()
	mi = MeshInstance3D.new()
	
	# 初始化材质
	mat_x = StandardMaterial3D.new()
	mat_y = StandardMaterial3D.new()
	mat_z = StandardMaterial3D.new()
	
	for mat in [mat_x, mat_y, mat_z]:
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.render_priority = 127  # 最高渲染优先级
		if axis_always_on_top:
			mat.depth_enabled = false  # 关闭深度测试，永远置顶
	
	mat_x.albedo_color = Color.RED
	mat_y.albedo_color = Color.GREEN
	mat_z.albedo_color = Color.BLUE
	
	# 一次性生成坐标轴网格，后续不需要每帧重建
	_build_axis_mesh()
	
	mi.mesh = mesh
	add_child(mi)
	
	mi.custom_aabb = AABB(Vector3(-axis_length, -axis_length, -axis_length), Vector3(axis_length*2, axis_length*2, axis_length*2))
	mi.extra_cull_margin = axis_length
	mi.ignore_occlusion_culling = true

func _process(delta):
	if get_tree().current_scene.name != "Root3d_test":
		is_show_axis = GlobalData.debug_is_show_axis
	
	mi.visible = is_show_axis
	# mi.visible = false
	
	if not visible:
		return
	
# 一次性构建坐标轴网格，性能远高于每帧重建
func _build_axis_mesh():
	var half_len = axis_length / 2.0
	
	# X轴
	var x_vertices = PackedVector3Array()
	x_vertices.append(Vector3(-half_len, 0, 0))
	x_vertices.append(Vector3(half_len, 0, 0))
	_add_surface(x_vertices, mat_x)
	
	# Y轴
	var y_vertices = PackedVector3Array()
	y_vertices.append(Vector3(0, -half_len, 0))
	y_vertices.append(Vector3(0, half_len, 0))
	_add_surface(y_vertices, mat_y)
	
	# Z轴
	var z_vertices = PackedVector3Array()
	z_vertices.append(Vector3(0, 0, -half_len))
	z_vertices.append(Vector3(0, 0, half_len))
	_add_surface(z_vertices, mat_z)

func _add_surface(vertices: PackedVector3Array, material: Material):
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
