extends Node3D

# ---------- 开关与绘制参数 ----------
@export var is_show_field_area: bool = true

@export var wireframe_color: Color = Color(0.0, 0.0, 1.0, 0.8)
@export var arrow_color: Color = Color(1.0, 0.3, 0.3, 0.8)  # 默认箭头颜色（未匹配类型时使用）

# 场类型 → 箭头颜色映射
const TYPE_COLORS = {
	"custom":   Color(1, 0, 0, 1),
	"electric": Color(0.455, 0.455, 0.275, 1),
	"magnetic": Color(0, 0, 1, 1),
	"gravity":  Color(0.557, 0.298, 0.569, 1)
}

# 降频重绘参数
var frame_count: int = 0
const REDRAW_INTERVAL: int = 1   # 每帧都重绘（可改为2+降低性能消耗）

# ---------- ImmediateMesh 相关 ----------
var _mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh

func _ready() -> void:
	
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "FieldDebugDraw"
	add_child(_mesh_instance)
	_immediate_mesh = ImmediateMesh.new()
	_mesh_instance.mesh = _immediate_mesh

	# 原本的 StandardMaterial3D 写法
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_instance.material_override = mat

func _process(_delta: float) -> void:
	if get_tree().current_scene.name == "Root3d_test":
		is_show_field_area = true
	else:
		is_show_field_area = GlobalData.debug_is_show_field_area
	visible = is_show_field_area
	if not visible:
		return

	frame_count += 1
	if frame_count >= REDRAW_INTERVAL:
		frame_count = 0
		_rebuild_mesh()

func _rebuild_mesh():
	_immediate_mesh.clear_surfaces()
	var regions = FieldManager.get_all_regions()   # 全局单例名称请确认
	if regions.is_empty():
		return

	# 所有线条绘制在一个表面里
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# 1. 绘制区域线框（半透明绿色）
	for region in regions:
		_draw_wireframe_cube(region["min"], region["max"], wireframe_color)

	# 2. 绘制场向量箭头（按类型着色）
	for region in regions:
		var center = (region["min"] + region["max"]) * 0.5
		var fields = region["fields"]
		for key in fields:
			var vec = fields[key]
			if vec.length_squared() > 0.0001:
				_add_arrow(center, vec, TYPE_COLORS.get(key, arrow_color))

	_immediate_mesh.surface_end()

# ---------- 绘制辅助函数 ----------
func _draw_wireframe_cube(min_p: Vector3, max_p: Vector3, color: Color) -> void:
	var corners = [
		Vector3(min_p.x, min_p.y, min_p.z),
		Vector3(max_p.x, min_p.y, min_p.z),
		Vector3(max_p.x, min_p.y, max_p.z),
		Vector3(min_p.x, min_p.y, max_p.z),
		Vector3(min_p.x, max_p.y, min_p.z),
		Vector3(max_p.x, max_p.y, min_p.z),
		Vector3(max_p.x, max_p.y, max_p.z),
		Vector3(min_p.x, max_p.y, max_p.z),
	]
	var edges = [
		[0,1], [1,2], [2,3], [3,0],   # 底面
		[4,5], [5,6], [6,7], [7,4],   # 顶面
		[0,4], [1,5], [2,6], [3,7]	# 侧边
	]
	for edge in edges:
		_immediate_mesh.surface_set_color(color)
		_immediate_mesh.surface_add_vertex(corners[edge[0]])
		_immediate_mesh.surface_add_vertex(corners[edge[1]])

func _add_arrow(origin: Vector3, vector: Vector3, color: Color, length: float = 0.5):
	if vector.length_squared() < 0.0001:
		return
	var dir = vector.normalized()
	var end = origin + dir * length

	# 主线
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(origin)
	_immediate_mesh.surface_add_vertex(end)

	# 箭头头部
	var head_size = length * 0.2
	var perp1 = Vector3(0, 1, 0).cross(dir)
	if perp1.length() < 0.1:
		perp1 = Vector3(1, 0, 0).cross(dir)
	perp1 = perp1.normalized()
	var perp2 = dir.cross(perp1).normalized()
	var head_base = end - dir * head_size

	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(end)
	_immediate_mesh.surface_add_vertex(head_base + perp1 * head_size * 0.5)
	_immediate_mesh.surface_add_vertex(end)
	_immediate_mesh.surface_add_vertex(head_base - perp1 * head_size * 0.5)
	_immediate_mesh.surface_add_vertex(end)
	_immediate_mesh.surface_add_vertex(head_base + perp2 * head_size * 0.5)
	_immediate_mesh.surface_add_vertex(end)
	_immediate_mesh.surface_add_vertex(head_base - perp2 * head_size * 0.5)

