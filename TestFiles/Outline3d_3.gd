extends Node3D

@export var is_show_axis: bool = true

# 样式
@export var edge_color: Color = Color.BLACK
@export var draw_hidden_objects: bool = false
@export var mesh_types: Array[String] = ["FieldShape3D", "ObjectShape3D"]
@export var line_colors: Array[Color] = [Color(0.0, 0.0, 1.0, 0.5), Color(0.0, 0.0, 0.0, 1.0)]

# 硬边角度阈值
var hard_edge_angle_deg: float = 25.0:
	set(v):
		hard_edge_angle_deg = v
		_hard_edge_cos = cos(deg_to_rad(v))
var _hard_edge_cos: float = cos(deg_to_rad(25.0))

# 缓存
var mesh_edge_cache: Dictionary = {}
var prism_edge_cache: Dictionary = {}
var target_meshes: Array[MeshInstance3D] = []

# ImmediateMesh 相关
var _mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh

# 降频重绘（减少重建频率，可按需调整）
var frame_count: int = 0
const REDRAW_INTERVAL: int = 1
const HARD_EDGE_ANGLE_THRESHOLD: float = 25.0
const OFFSET = -0.001  # 世界单位，需根据场景尺寸调整
# 在 _rebuild_mesh 开头获取相机位置
var cam_pos # = get_viewport().get_camera_3d().global_position

func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "EdgeDrawer"
	add_child(_mesh_instance)
	_immediate_mesh = ImmediateMesh.new()
	_mesh_instance.mesh = _immediate_mesh

	# ===== 使用自定义 ShaderMaterial（深度偏移 + 顶点颜色） =====
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode unshaded, depth_test_enabled, depth_draw_opaque, blend_mix;

	uniform float depth_bias : hint_range(0.0, 0.01) = 0.0005;

	void vertex() {
		vec4 clip_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		// 深度偏移：向相机方向微移，消除 Z-fighting
		clip_pos.z -= depth_bias * clip_pos.w;
		POSITION = clip_pos;
	}

	void fragment() {
		ALBEDO = COLOR.rgb;
		ALPHA = COLOR.a;
	}
	"""
	mat.shader = shader
	mat.set_shader_parameter("depth_bias", 0.0005)
	_mesh_instance.material_override = mat

	_refresh_target_list()
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

func _process(_delta: float) -> void:
	visible = is_show_axis
	if not visible:
		return

	frame_count += 1
	if frame_count >= REDRAW_INTERVAL:
		frame_count = 0
		_rebuild_mesh()

# ---------- 目标列表管理 ----------
func _refresh_target_list():
	target_meshes.clear()
	mesh_edge_cache.clear()
	prism_edge_cache.clear()
	var all_nodes = get_tree().root.find_children("*", "MeshInstance3D", true, false)
	for node in all_nodes:
		target_meshes.append(node)

func _on_node_added(node: Node):
	if node is MeshInstance3D:
		target_meshes.append(node)

func _on_node_removed(node: Node):
	if node is MeshInstance3D:
		target_meshes.erase(node)
		if node.mesh and mesh_edge_cache.has(node.mesh.get_instance_id()):
			mesh_edge_cache.erase(node.mesh.get_instance_id())

# ---------- 网格重建 ----------
func _rebuild_mesh():
	cam_pos = get_viewport().get_camera_3d().global_position
	_immediate_mesh.clear_surfaces()
	if target_meshes.is_empty():
		return
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	for mesh_instance in target_meshes:
		if not draw_hidden_objects and not GlobalTools.is_fully_visible(mesh_instance):
			continue
		var mesh = mesh_instance.mesh
		if not mesh:
			continue
		var color = _get_mesh_color(mesh_instance.name)

		if mesh is BoxMesh:
			_add_box_edges(mesh_instance, mesh, color)
		elif mesh is SphereMesh:
			_add_sphere_edges(mesh_instance, mesh, color)
		elif mesh is CylinderMesh:
			_add_cylinder_edges(mesh_instance, mesh, color)
		elif mesh is CapsuleMesh:
			_add_capsule_edges(mesh_instance, mesh, color)
		elif mesh is QuadMesh:
			_add_quad_edges(mesh_instance, mesh, color)
		elif mesh is PrismMesh:
			_add_prism_edges(mesh_instance, mesh, color)
		elif mesh is ArrayMesh:
			_add_arraymesh_hard_edges(mesh_instance, mesh, color)
		else:
			_add_generic_mesh_edges(mesh_instance, mesh, color)

	_immediate_mesh.surface_end()

# ---------- 颜色映射 ----------
func _get_mesh_color(mesh_name: String) -> Color:
	for i in range(mesh_types.size()):
		if mesh_name.find(mesh_types[i]) != -1 and i < line_colors.size():
			return line_colors[i]
	return edge_color

# ---------- 各形体边生成 ----------
func _add_box_edges(inst: MeshInstance3D, box: BoxMesh, color: Color):
	var xf = inst.global_transform
	var half = box.size * 0.5
	var verts = [
		Vector3(-half.x, -half.y, -half.z), Vector3( half.x, -half.y, -half.z),
		Vector3( half.x, -half.y,  half.z), Vector3(-half.x, -half.y,  half.z),
		Vector3(-half.x,  half.y, -half.z), Vector3( half.x,  half.y, -half.z),
		Vector3( half.x,  half.y,  half.z), Vector3(-half.x,  half.y,  half.z),
	]
	var edges = [
		[0,1], [1,2], [2,3], [3,0], [4,5], [5,6], [6,7], [7,4],
		[0,4], [1,5], [2,6], [3,7]
	]
	for e in edges:
		var p0 = xf * verts[e[0]]
		var p1 = xf * verts[e[1]]
		_add_line(p0, p1, color)

func _add_sphere_edges(inst: MeshInstance3D, sphere: SphereMesh, color: Color):
	var center = inst.global_position
	var radius = sphere.radius * inst.global_transform.basis.get_scale().x
	var cam_pos = get_viewport().get_camera_3d().global_position
	var view_dir = (cam_pos - center).normalized()
	# 构建面向相机的正交基
	var right: Vector3 = view_dir.cross(Vector3.UP)
	if right.length() < 0.001:
		right = view_dir.cross(Vector3.RIGHT)
	right = right.normalized()
	var up = view_dir.cross(right).normalized()
	const SEGS = 32
	var prev = center + right * radius
	for i in range(1, SEGS + 1):
		var angle = TAU * float(i) / SEGS
		var pt = center + (right * cos(angle) + up * sin(angle)) * radius
		_add_line(prev, pt, color)
		prev = pt

func _add_cylinder_edges(inst: MeshInstance3D, cyl: CylinderMesh, color: Color):
	var xf = inst.global_transform
	var center = xf.origin
	var axis = xf.basis.y.normalized()
	var scale = xf.basis.get_scale()
	var top_r = cyl.top_radius * scale.x
	var bottom_r = cyl.bottom_radius * scale.x
	var half_h = cyl.height * 0.5 * scale.y
	var top_center = center + axis * half_h
	var bottom_center = center - axis * half_h

	# 侧面两条轮廓（基于视线方向）
	var cam_pos = get_viewport().get_camera_3d().global_position
	var view_dir = cam_pos - center
	var right_dir = view_dir.cross(axis).normalized()
	_add_line(top_center + right_dir * top_r, bottom_center + right_dir * bottom_r, color)
	_add_line(top_center - right_dir * top_r, bottom_center - right_dir * bottom_r, color)

	# 上下端面圆（固定世界空间）
	_add_circle(top_center, axis, top_r, 32, color)
	_add_circle(bottom_center, axis, bottom_r, 32, color)

func _add_capsule_edges(inst: MeshInstance3D, cap: CapsuleMesh, color: Color):
	var xf = inst.global_transform
	var center = xf.origin
	var axis = xf.basis.y.normalized()
	var scale = xf.basis.get_scale()
	var radius = cap.radius * scale.x
	var half_cyl = (cap.height - radius * 2) * 0.5 * scale.y
	var top_sphere_center = center + axis * half_cyl
	var bottom_sphere_center = center - axis * half_cyl

	# 轮廓生成：使用支撑函数（基于视线方向）
	var cam_pos = get_viewport().get_camera_3d().global_position
	var view_dir = (cam_pos - center).normalized()
	var right: Vector3 = view_dir.cross(Vector3.UP)
	if right.length() < 0.001:
		right = view_dir.cross(Vector3.RIGHT)
	right = right.normalized()
	var up = view_dir.cross(right).normalized()

	const SEGS = 32
	var prev: Vector3
	for i in range(SEGS + 1):
		var angle = TAU * float(i) / SEGS
		var dir = right * cos(angle) + up * sin(angle)
		# 哪个球心在 dir 方向上更远，就用它作为基点外扩
		var dot_top = top_sphere_center.dot(dir)
		var dot_bottom = bottom_sphere_center.dot(dir)
		var base = top_sphere_center if dot_top > dot_bottom else bottom_sphere_center
		var pt = base + dir * radius
		if i > 0:
			_add_line(prev, pt, color)
		prev = pt

func _add_quad_edges(inst: MeshInstance3D, quad: QuadMesh, color: Color):
	# 简化：仅绘制四周边框，不包含 hatch（hatch 需要屏幕空间计算，暂不支持）
	var xf = inst.global_transform
	var half = quad.size * 0.5
	var verts = [
		Vector3(-half.x, -half.y, 0),
		Vector3( half.x, -half.y, 0),
		Vector3( half.x,  half.y, 0),
		Vector3(-half.x,  half.y, 0),
	]
	var edges = [[0,1], [1,2], [2,3], [3,0]]
	for e in edges:
		_add_line(xf * verts[e[0]], xf * verts[e[1]], color)

func _add_prism_edges(inst: MeshInstance3D, prism: PrismMesh, color: Color):
	if not prism_edge_cache.has(prism):
		_build_prism_edge_cache(prism)
	var edge_pairs = prism_edge_cache[prism]
	var arrays = prism.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var xf = inst.global_transform
	for pair in edge_pairs:
		_add_line(xf * vertices[pair[0]], xf * vertices[pair[1]], color)

func _add_arraymesh_hard_edges(inst: MeshInstance3D, mesh: ArrayMesh, color: Color):
	var cache_key = mesh.resource_path if not mesh.resource_path.is_empty() else str(mesh.get_instance_id())
	if not mesh_edge_cache.has(cache_key):
		mesh_edge_cache[cache_key] = _extract_hard_edges(mesh)
	var edges = mesh_edge_cache[cache_key]
	var xf = inst.global_transform
	for i in range(0, edges.size(), 2):
		_add_line(xf * edges[i], xf * edges[i+1], color)

func _add_generic_mesh_edges(inst: MeshInstance3D, mesh: Mesh, color: Color):
	var mesh_id = mesh.get_instance_id()
	var local_edges: Array
	if mesh_edge_cache.has(mesh_id):
		local_edges = mesh_edge_cache[mesh_id]
	else:
		local_edges = _extract_local_edges(mesh)
		mesh_edge_cache[mesh_id] = local_edges
	var xf = inst.global_transform
	# 为了简化，这里不做法线/硬边/轮廓判断，直接绘制所有被记录的边
	# 原版在此有复杂的轮廓/硬边筛选，因 ImmediateMesh 本身在 3D 空间，筛选逻辑可省略
	for edge in local_edges:
		var pts = edge["points"]
		_add_line(xf * pts[0], xf * pts[1], color)

# ---------- 辅助：世界空间线段与圆 ----------
func _add_line(p0: Vector3, p1: Vector3, color: Color):
	# var dir0 = (cam_pos - p0).normalized()
	# var dir1 = (cam_pos - p1).normalized()
	# p0 += dir0 * OFFSET
	# p1 += dir1 * OFFSET
	_immediate_mesh.surface_set_color(Color(0, 0, 0, 1))
	_immediate_mesh.surface_add_vertex(p0)
	_immediate_mesh.surface_add_vertex(p1)

func _add_circle(center: Vector3, normal: Vector3, radius: float, segments: int, color: Color):
	var basis = _make_basis_from_normal(normal)
	var prev = center + basis.x * radius
	for i in range(1, segments + 1):
		var angle = TAU * float(i) / segments
		var pt = center + (basis.x * cos(angle) + basis.y * sin(angle)) * radius
		_add_line(prev, pt, color)
		prev = pt

func _make_basis_from_normal(normal: Vector3) -> Basis:
	var n = normal.normalized()
	var u = Vector3(1,0,0) if abs(n.x) < 0.9 else Vector3(0,1,0)
	var v = n.cross(u).normalized()
	u = v.cross(n).normalized()
	return Basis(u, n, v)

# ---------- 硬边提取（保留原逻辑） ----------
func _build_prism_edge_cache(mesh: Mesh) -> void:
	var edge_faces: Dictionary = {}
	var arrays = mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var face_count = indices.size() / 3.0
	var face_normals: PackedVector3Array = []
	face_normals.resize(face_count)
	
	# 遍历所有三角面，计算法线并登记边的所属面
	for face_idx in range(face_count):
		var i0 = indices[face_idx * 3]
		var i1 = indices[face_idx * 3 + 1]
		var i2 = indices[face_idx * 3 + 2]
		var v0 = vertices[i0]
		var v1 = vertices[i1]
		var v2 = vertices[i2]
		
		face_normals[face_idx] = (v1 - v0).cross(v2 - v0).normalized()
		
		_register_prism_edge(edge_faces, i0, i1, face_idx)
		_register_prism_edge(edge_faces, i1, i2, face_idx)
		_register_prism_edge(edge_faces, i2, i0, face_idx)
	
	# 筛选外棱：共面的内部分割线直接剔除
	var boundary_edges: Array = []
	var cos_threshold = cos(0.05) # 约2.9度，过滤共面边
	for key in edge_faces:
		var faces = edge_faces[key]
		if faces.size() == 1:
			boundary_edges.append([key.x, key.y])
		elif faces.size() == 2:
			var dot = face_normals[faces[0]].dot(face_normals[faces[1]])
			if dot < cos_threshold:
				boundary_edges.append([key.x, key.y])
	
	prism_edge_cache[mesh] = boundary_edges

# 辅助：登记边的所属面，忽略方向
func _register_prism_edge(dict: Dictionary, a: int, b: int, face_idx: int) -> void:
	var key = Vector2i(min(a, b), max(a, b))
	if not dict.has(key):
		dict[key] = []
	dict[key].append(face_idx)

func _extract_hard_edges(mesh: ArrayMesh) -> PackedVector3Array:
	var hard_edges = PackedVector3Array()
	if mesh.get_surface_count() == 0:
		return hard_edges
	
	var mdt = MeshDataTool.new()
	var threshold_cos = cos(deg_to_rad(HARD_EDGE_ANGLE_THRESHOLD))
	
	for surf_idx in range(mesh.get_surface_count()):
		# 校验图元类型：仅处理三角形表面，非三角形类型跳过以避免参数非法报错
		if mesh.surface_get_primitive_type(surf_idx) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		
		var err = mdt.create_from_surface(mesh, surf_idx)
		if err != OK:
			continue
		
		for edge_idx in range(mdt.get_edge_count()):
			# 修复：获取共享该边的所有面索引数组
			var face_indices = mdt.get_edge_faces(edge_idx)
			var face_count = face_indices.size()
			
			if face_count == 1:
				# 边界边（仅一个面），直接保留
				var v0 = mdt.get_vertex(mdt.get_edge_vertex(edge_idx, 0))
				var v1 = mdt.get_vertex(mdt.get_edge_vertex(edge_idx, 1))
				hard_edges.append(v0)
				hard_edges.append(v1)
			elif face_count >= 2:
				# 修复：从面索引数组里取前两个面，计算法线夹角
				var f0 = face_indices[0]
				var f1 = face_indices[1]
				var n0 = mdt.get_face_normal(f0)
				var n1 = mdt.get_face_normal(f1)
				var dot = n0.dot(n1)
				
				if dot < threshold_cos:
					var v0 = mdt.get_vertex(mdt.get_edge_vertex(edge_idx, 0))
					var v1 = mdt.get_vertex(mdt.get_edge_vertex(edge_idx, 1))
					hard_edges.append(v0)
					hard_edges.append(v1)
		mdt.clear()
	
	return hard_edges

# ==================== 硬边提取函数_任意Mesh ====================
func _extract_local_edges(source_mesh: Mesh) -> Array:
	var edge_map = {}
	var surface_count = source_mesh.get_surface_count()
	
	for s in range(surface_count):
		var arrays = source_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX else null
		
		var merge_map = _build_vertex_merge_map(verts)
		var tri_count: int
		if indices != null and indices.size() > 0:
			@warning_ignore("integer_division")
			tri_count = indices.size() / 3
		else:
			@warning_ignore("integer_division")
			tri_count = verts.size() / 3
		
		for tri_idx in range(tri_count):
			var i0: int
			var i1: int
			var i2: int
			if indices != null and indices.size() > 0:
				i0 = indices[tri_idx * 3]
				i1 = indices[tri_idx * 3 + 1]
				i2 = indices[tri_idx * 3 + 2]
			else:
				i0 = tri_idx * 3
				i1 = tri_idx * 3 + 1
				i2 = tri_idx * 3 + 2
			
			var v0 = verts[i0]
			var v1 = verts[i1]
			var v2 = verts[i2]
			var normal = (v1 - v0).cross(v2 - v0).normalized()
			
			var m0 = merge_map[i0]
			var m1 = merge_map[i1]
			var m2 = merge_map[i2]
			
			_record_edge(edge_map, m0, m1, v0, v1, normal)
			_record_edge(edge_map, m1, m2, v1, v2, normal)
			_record_edge(edge_map, m2, m0, v2, v0, normal)
	
	var result = []
	for data in edge_map.values():
		result.append({
			"points": data["points"],
			"normals": data["normals"]
		})
	return result

func _record_edge(map: Dictionary, a: int, b: int, va: Vector3, vb: Vector3, normal: Vector3):
	var key = Vector2i(min(a, b), max(a, b))
	if not map.has(key):
		map[key] = {
			"points": [va, vb],
			"normals": []
		}
	map[key]["normals"].append(normal)


func _build_vertex_merge_map(verts: PackedVector3Array, threshold: float = 0.0001) -> PackedInt32Array:
	var merge_map = PackedInt32Array()
	var unique_vertices: Dictionary = {}
	var next_index: int = 0
	merge_map.resize(verts.size())
	
	for i in range(verts.size()):
		var v = verts[i]
		var key = Vector3i(
			int(round(v.x / threshold)),
			int(round(v.y / threshold)),
			int(round(v.z / threshold))
		)
		if unique_vertices.has(key):
			merge_map[i] = unique_vertices[key]
		else:
			unique_vertices[key] = next_index
			merge_map[i] = next_index
			next_index += 1
	return merge_map

