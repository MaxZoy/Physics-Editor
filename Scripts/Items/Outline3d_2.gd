extends Control

@export var is_show_outline: bool = true

# ========== 样式参数 ==========
@export var edge_color: Color = Color.BLACK
@export var line_thickness: float = 2.0
var line_thickness_finer: float = 0.8 # 更细的线条
var line_thickness_bolder: float = 1.2 # 更粗的线条
@export var draw_hidden_objects: bool = false

const HARD_EDGE_ANGLE_THRESHOLD: float = 25.0
# 硬边角度阈值（单位：度）
var hard_edge_angle_deg: float = 25.0:
	set(value):
		hard_edge_angle_deg = value
		_hard_edge_cos = cos(deg_to_rad(value))
var _hard_edge_cos: float = 0.0

# mesh 类型与描边颜色映射
@export var mesh_types: Array[String] = ["FieldShape3D", "ObjectShape3D"]
@export var line_colors: Array[Color] = [Color(0.0, 0.0, 1.0, 0.047), Color(0.0, 0.0, 0.0, 1.0)]

# 按Mesh资源缓存局部边数据
var mesh_edge_cache: Dictionary = {}
var target_meshes: Array[MeshInstance3D] = []
# 三棱柱外棱缓存（key: Mesh对象，value: 外棱顶点索引对）
var prism_edge_cache: Dictionary = {}

# 降频重绘计数
var frame_count: float = 0.0
const REDRAW_INTERVAL: float = 1.0

# 边缘斜线参数
# 边缘斜线参数
var hatch_length: float = 12.0	# 斜线长度（像素）
var hatch_spacing: float = 20.0   # 斜线沿边的间距（像素）
var hatch_direction: Vector2 = Vector2(0.4, 1.0)  # 统一朝向：x正=向右，y正=屏幕向下；调整xy可改倾斜角度

var camera: Camera3D

func _ready():

	# 单场景唯一性检查
	if (get_tree().current_scene.name == "Editor3D" or 
		get_tree().current_scene.name == "MainUI"):
		var parent = self.get_parent().get_parent()
		if parent.name == "Root3d_test":
			parent.queue_free()
			return
			
	_hard_edge_cos = cos(deg_to_rad(hard_edge_angle_deg))
	_refresh_target_list()
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	
	camera = get_viewport().get_camera_3d()

# ====================== 描边渲染 - 目标Mesh列表管理模块 ======================
# 作用：全局维护所有需要参与描边绘制的 MeshInstance3D 集合，同步增减、缓存网格边界数据
# target_meshes：数组，存储所有待描边的 MeshInstance3D 节点引用
# mesh_edge_cache：字典缓存，key=网格资源唯一ID，value=该网格预计算好的描边边界数据

# 刷新全部目标Mesh列表（全量扫描重建，用于初始化/场景重载后重置列表）
func _refresh_target_list():
	# 清空现有列表与缓存，防止旧节点残留
	target_meshes.clear()
	mesh_edge_cache.clear()
	
	# 从游戏根节点 /root 全局递归查找所有 MeshInstance3D
	# 参数说明 find_children(匹配名称, 节点类型, 递归查找子节点, 是否包含内部隐藏节点)
	var all_nodes = get_tree().root.find_children("*", "MeshInstance3D", true, false)
	
	# 遍历所有找到的网格物体，加入描边目标数组
	for node in all_nodes:
		target_meshes.append(node)

# 节点新增信号回调：场景里动态生成Mesh时自动加入描边列表
func _on_node_added(node: Node):
	# 判断新增节点类型为网格实例3D
	if node is MeshInstance3D:
		# 将新Mesh加入描边目标集合，后续渲染时会绘制描边
		target_meshes.append(node)

# 节点移除信号回调：物体销毁/删除时清理列表与网格缓存
func _on_node_removed(node: Node):
	# 仅处理MeshInstance3D类型节点
	if node is MeshInstance3D:
		# 从描边目标数组中移除该物体，不再渲染描边
		target_meshes.erase(node)
		
		# 安全判断：节点存在网格资源 且 缓存中存在该网格的边界数据
		if node.mesh and mesh_edge_cache.has(node.mesh.get_instance_id()):
			# 根据网格资源唯一ID，删除对应预计算描边缓存，释放内存
			mesh_edge_cache.erase(node.mesh.get_instance_id())

# ==================== 主循环 ====================
func _process(_delta: float):
	if get_tree().current_scene.name != "Root3d_test":
		is_show_outline = GlobalData.debug_is_show_outline
	
	visible = is_show_outline
	if not visible:
		return

	frame_count += 1.0
	if frame_count >= REDRAW_INTERVAL:
		queue_redraw()
		frame_count -= REDRAW_INTERVAL

# ==================== 核心绘制 ====================
func _draw():
	
	if not camera:
		return	
		
	# 预取相机全局位置，全帧复用，避免循环内重复取值
	# var cam_pos = camera.global_position
	
	for mesh_instance in target_meshes:
		# 可见性过滤
		if not draw_hidden_objects and not GlobalTools.is_fully_visible(mesh_instance):
			continue
		
		var mesh = mesh_instance.mesh
		if not mesh:
			continue
		
		var current_color = _get_mesh_color(mesh_instance.name)
		# ========== 立方体专属极速优化 ==========
		if mesh is BoxMesh:
			_draw_box_outline(camera, mesh_instance, mesh, current_color)
			# _draw_box_outline_t(camera, depth_texture, mesh, mesh.mesh, Color(1,0,0), 2.0)
			continue
		
		# ========== 球体专属极速优化 ==========
		# 直接用数学投影画外轮廓，边数从上千条降到32条，性能提升几十倍
		if mesh is SphereMesh:
			_draw_sphere_outline(camera, mesh_instance, mesh, current_color)
			continue
		
		# ========== 圆柱体专属极速优化 ==========
		if mesh is CylinderMesh:
			_draw_cylinder_outline(camera, mesh_instance, mesh, current_color)
			continue

		# ========== 胶囊体专属极速优化 ==========
		if mesh is CapsuleMesh:
			_draw_capsule_outline(camera, mesh_instance, mesh, current_color)
			continue
		
		# ========== 四边形面片专属极速优化 ==========
		if mesh is QuadMesh:
			_draw_quad_outline(camera, mesh_instance, mesh, current_color)
			continue

		# ========== 三棱柱专属极速优化（自动对齐实体+去内部对角线） ==========
		if mesh is PrismMesh:
			_draw_prism_outline(camera, mesh_instance, mesh, current_color)
			continue

		# ========== ArrayMesh硬边优化 ==========
		if mesh is ArrayMesh:
			_draw_arraymesh_hard_edges(camera, mesh_instance, mesh, current_color)
			continue
		
		# ========== 通用网格绘制（原有逻辑优化版） ==========
		var mesh_id = mesh.get_instance_id()
		var local_edges: Array
		if mesh_edge_cache.has(mesh_id):
			local_edges = mesh_edge_cache[mesh_id]
		else:
			local_edges = _extract_local_edges(mesh)
			mesh_edge_cache[mesh_id] = local_edges
		
		var global_xform = mesh_instance.global_transform
		var basis_inv_trans = global_xform.basis.inverse().transposed()
		
		for edge in local_edges:
			var edge_points = edge["points"]
			var edge_normals = edge["normals"]
			
			var world_start = global_xform * edge_points[0]
			var world_end = global_xform * edge_points[1]
			
			# 世界空间短边过滤
			if world_start.distance_to(world_end) < 0.001:
				continue
			
			# 两点都在相机后方跳过
			if camera.is_position_behind(world_start) and camera.is_position_behind(world_end):
				continue
			
			# 法线变换（不归一化，只需要符号判断，省开方运算）
			var n0 = basis_inv_trans * edge_normals[0]
			var n1 = n0
			if edge_normals.size() > 1:
				n1 = basis_inv_trans * edge_normals[1]
			
			# 判定1：边界边
			var is_boundary = edge_normals.size() == 1
			
			# 判定2：硬边（预计算余弦值，省掉反余弦运算）
			var dot_normal = clamp(n0.dot(n1), -1.0, 1.0)
			var is_hard_edge = dot_normal < _hard_edge_cos
			
			# 判定3：轮廓边（不归一化视线，只判断符号，省开方运算）
			var mid_point = (world_start + world_end) * 0.5
			var view_dir = camera.global_position - mid_point
			var dot0 = n0.dot(view_dir)
			var dot1 = n1.dot(view_dir)
			var is_silhouette = dot0 * dot1 < 0.0
			
			if is_boundary or is_hard_edge or is_silhouette:
				var screen_start = camera.unproject_position(world_start)
				var screen_end = camera.unproject_position(world_end)
				
				# 修复黑点：屏幕空间短边过滤，投影后小于1.5像素直接跳过
				if screen_start.distance_to(screen_end) < 1.5:
					continue
				
				draw_line(screen_start, screen_end, current_color, line_thickness)

# ==================== 立方体专属轮廓绘制（彻底消除面内斜线） ====================
func _draw_box_outline(camera: Camera3D, mesh_inst: MeshInstance3D, box_mesh: BoxMesh, color: Color):
	var xform = mesh_inst.global_transform
	var half_size = box_mesh.size * 0.5
	
	# 立方体8个顶点的局部坐标
	var local_verts = [
		Vector3(-half_size.x, -half_size.y, -half_size.z),
		Vector3( half_size.x, -half_size.y, -half_size.z),
		Vector3( half_size.x, -half_size.y,  half_size.z),
		Vector3(-half_size.x, -half_size.y,  half_size.z),
		Vector3(-half_size.x,  half_size.y, -half_size.z),
		Vector3( half_size.x,  half_size.y, -half_size.z),
		Vector3( half_size.x,  half_size.y,  half_size.z),
		Vector3(-half_size.x,  half_size.y,  half_size.z),
	]
	
	# 转换为世界坐标
	var world_verts = PackedVector3Array()
	for v in local_verts:
		world_verts.append(xform * v)
	
	# 立方体12条棱的顶点索引（标准立方体框线，无面内对角线）
	var edge_indices = [
		[0, 1], [1, 2], [2, 3], [3, 0], # 底面4条
		[4, 5], [5, 6], [6, 7], [7, 4], # 顶面4条
		[0, 4], [1, 5], [2, 6], [3, 7], # 侧面4条竖边
	]
	
	# 逐条棱投影绘制
	for edge in edge_indices:
		var ws_p0 = world_verts[edge[0]]
		var ws_p1 = world_verts[edge[1]]
		
		# 两点都在相机后方则跳过
		if camera.is_position_behind(ws_p0) and camera.is_position_behind(ws_p1):
			continue
		
		var screen_p0 = camera.unproject_position(ws_p0)
		var screen_p1 = camera.unproject_position(ws_p1)
		draw_line(screen_p0, screen_p1, color, line_thickness)

# ==================== 球体专属轮廓绘制 ====================
func _draw_sphere_outline(camera: Camera3D, mesh_inst: MeshInstance3D, sphere_mesh: SphereMesh, color: Color):
	var world_center = mesh_inst.global_position
	# 修复：从全局变换矩阵中提取缩放值，兼容所有Godot4版本
	var global_scale = mesh_inst.global_transform.basis.get_scale()
	var radius = sphere_mesh.radius * global_scale.x

	# 相机坐标系的右、上方向，构建垂直于视线的轮廓平面
	var cam_basis = camera.global_transform.basis
	var right = cam_basis.x.normalized()
	var up = cam_basis.y.normalized()

	# 32个采样点，平滑度足够
	const SAMPLE_COUNT = 16
	var points = PackedVector2Array()
	points.resize(SAMPLE_COUNT + 1)

	for i in range(SAMPLE_COUNT):
		var angle = TAU * float(i) / float(SAMPLE_COUNT)
		var world_point = world_center + right * cos(angle) * radius + up * sin(angle) * radius
		
		if not camera.is_position_behind(world_point):
			points[i] = camera.unproject_position(world_point)
		else:
			# 点在相机后方时用球心投影兜底，避免异常
			points[i] = camera.unproject_position(world_center)
	
	# 闭合轮廓
	points[SAMPLE_COUNT] = points[0]
	
	# 绘制平滑轮廓
	draw_polyline(points, color, line_thickness * line_thickness_finer, true)

# ==================== 圆柱体专属轮廓绘制 ====================
func _draw_cylinder_outline(camera: Camera3D, mesh_inst: MeshInstance3D, cyl_mesh: CylinderMesh, color: Color):
	var xform = mesh_inst.global_transform
	var world_center = xform.origin
	var world_up = xform.basis.y.normalized()
	var scale = xform.basis.get_scale()
	
	var top_r = cyl_mesh.top_radius * scale.x
	var bottom_r = cyl_mesh.bottom_radius * scale.x
	var half_h = cyl_mesh.height * 0.5 * scale.y
	
	var top_center = world_center + world_up * half_h
	var bottom_center = world_center - world_up * half_h
	
	# 计算侧面轮廓方向（垂直于视线与轴向）
	var view_dir = camera.global_position - world_center
	var right_dir = view_dir.cross(world_up).normalized()
	
	# 侧面两条轮廓母线（对应原软边轮廓逻辑）
	var top_left = top_center - right_dir * top_r
	var top_right = top_center + right_dir * top_r
	var bottom_left = bottom_center - right_dir * bottom_r
	var bottom_right = bottom_center + right_dir * bottom_r
	
	draw_line(camera.unproject_position(top_left), camera.unproject_position(bottom_left), color, line_thickness)
	draw_line(camera.unproject_position(top_right), camera.unproject_position(bottom_right), color, line_thickness)
	
	# 上下端面硬边圆环（对应原硬边逻辑）
	const CIRCLE_SEGMENTS = 16
	var top_points = PackedVector2Array()
	var bottom_points = PackedVector2Array()
	top_points.resize(CIRCLE_SEGMENTS + 1)
	bottom_points.resize(CIRCLE_SEGMENTS + 1)
	
	var rot_step = TAU / CIRCLE_SEGMENTS
	var initial_right = right_dir
	
	for i in range(CIRCLE_SEGMENTS + 1):
		var angle = rot_step * float(i)
		var rotated = Basis(world_up, angle) * initial_right
		
		var top_world = top_center + rotated * top_r
		var bottom_world = bottom_center + rotated * bottom_r
		
		if not camera.is_position_behind(top_world):
			top_points[i] = camera.unproject_position(top_world)
		else:
			top_points[i] = camera.unproject_position(top_center)
			
		if not camera.is_position_behind(bottom_world):
			bottom_points[i] = camera.unproject_position(bottom_world)
		else:
			bottom_points[i] = camera.unproject_position(bottom_center)
	
	draw_polyline(top_points, color, line_thickness * line_thickness_finer, true)
	draw_polyline(bottom_points, color, line_thickness * line_thickness_finer, true)

# ==================== 胶囊体专属轮廓绘制（全视角正确版） ====================
func _draw_capsule_outline(camera: Camera3D, mesh_inst: MeshInstance3D, cap_mesh: CapsuleMesh, color: Color):
	var xform = mesh_inst.global_transform
	var world_center = xform.origin
	var world_up = xform.basis.y.normalized()
	var scale = xform.basis.get_scale()
	
	var radius = cap_mesh.radius * scale.x
	var half_cyl_h = (cap_mesh.height - radius * 2) * 0.5 * scale.y
	
	# 上下两个球心（圆柱端面中心）
	var top_center = world_center + world_up * half_cyl_h
	var bottom_center = world_center - world_up * half_cyl_h
	
	# 相机坐标系的右、上方向，组成垂直于视线的平面
	var cam_basis = camera.global_transform.basis
	var cam_right = cam_basis.x.normalized()
	var cam_up = cam_basis.y.normalized()
	
	const SAMPLE_COUNT = 16
	var points = PackedVector2Array()
	points.resize(SAMPLE_COUNT + 1)
	
	for i in range(SAMPLE_COUNT):
		var angle = TAU * float(i) / float(SAMPLE_COUNT)
		# 世界空间中，垂直于视线的单位方向向量
		var dir = cam_right * cos(angle) + cam_up * sin(angle)
		dir = dir.normalized()
		
		# 胶囊支撑函数：该方向上投影更远的端点 + 方向外扩半径 = 最外侧点
		var dot_top = top_center.dot(dir)
		var dot_bottom = bottom_center.dot(dir)
		var base_point = top_center if dot_top > dot_bottom else bottom_center
		var world_point = base_point + dir * radius
		
		# 投影到屏幕，相机后方点用中心兜底
		if not camera.is_position_behind(world_point):
			points[i] = camera.unproject_position(world_point)
		else:
			points[i] = camera.unproject_position(world_center)
	
	# 闭合轮廓
	points[SAMPLE_COUNT] = points[0]
	draw_polyline(points, color, line_thickness * line_thickness_finer, true)

# ==================== 四边形面片专属轮廓+边缘斜线绘制（正面过滤+背面全边绘制） ====================
func _draw_quad_outline(camera: Camera3D, mesh_inst: MeshInstance3D, quad_mesh: QuadMesh, color: Color):
	var xform = mesh_inst.global_transform
	var half_size = quad_mesh.size * 0.5

	# QuadMesh 4个顶点的局部坐标
	var local_verts = [
		Vector3(-half_size.x, -half_size.y, 0.0),
		Vector3( half_size.x, -half_size.y, 0.0),
		Vector3( half_size.x,  half_size.y, 0.0),
		Vector3(-half_size.x,  half_size.y, 0.0),
	]

	# 转换为世界坐标
	var world_verts = PackedVector3Array()
	for v in local_verts:
		world_verts.append(xform * v)

	# 预计算所有顶点的屏幕坐标
	var screen_verts = []
	var all_behind = true
	for v in world_verts:
		if not camera.is_position_behind(v):
			all_behind = false
		screen_verts.append(camera.unproject_position(v))
	if all_behind:
		return

	# 计算四边形屏幕中心，用于判断边的内外侧
	var screen_center = Vector2.ZERO
	for v in screen_verts:
		screen_center += v
	screen_center /= screen_verts.size()

	# 四边形4条外棱索引
	var edge_indices = [
		[0, 1], [1, 2], [2, 3], [3, 0],
	]

	# 第一步：绘制外框
	for edge in edge_indices:
		var i0 = edge[0]
		var i1 = edge[1]
		var ws_p0 = world_verts[i0]
		var ws_p1 = world_verts[i1]
		if camera.is_position_behind(ws_p0) and camera.is_position_behind(ws_p1):
			continue
		draw_line(screen_verts[i0], screen_verts[i1], color, line_thickness)

	# 判断相机位于平面的正面还是背面
	var plane_origin = xform.origin
	var plane_normal = xform.basis.z.normalized()
	var cam_pos = camera.global_position
	var cam_side = plane_normal.dot(cam_pos - plane_origin)
	var is_front_face = cam_side > 0.0

	# 第二步：绘制统一朝向斜线
	var hatch_dir = hatch_direction.normalized()
	var hatch_offset = hatch_dir * hatch_length

	for edge in edge_indices:
		var i0 = edge[0]
		var i1 = edge[1]
		var p0 = screen_verts[i0]
		var p1 = screen_verts[i1]
		var ws_p0 = world_verts[i0]
		var ws_p1 = world_verts[i1]

		# 两点都在相机后方则跳过
		if camera.is_position_behind(ws_p0) and camera.is_position_behind(ws_p1):
			continue

		var edge_vec = p1 - p0
		var edge_len = edge_vec.length()
		if edge_len < 0.1:
			continue

		# 仅正面时执行内外侧过滤；背面时全边绘制
		if is_front_face:
			# 计算当前边的外法线（指向四边形外侧）
			var normal_a = Vector2(-edge_vec.y, edge_vec.x).normalized()
			var normal_b = -normal_a
			var edge_mid = (p0 + p1) * 0.5
			var outward_dir = edge_mid - screen_center
			var outer_normal = normal_a if normal_a.dot(outward_dir) > 0 else normal_b
			# 斜线朝内则跳过这条边
			if hatch_dir.dot(outer_normal) <= 0:
				continue

		# 计算沿边的斜线数量与步长
		var count = int(edge_len / hatch_spacing)
		var step_vec = edge_vec.normalized() * hatch_spacing

		# 沿边逐个绘制短斜线
		for i in range(count + 1):
			var start = p0 + step_vec * i
			var end = start + hatch_offset
			draw_line(start, end, color, line_thickness * line_thickness_bolder)

# ==================== 三棱柱专属轮廓绘制（完美对齐实体，无多余对角线） ====================
func _draw_prism_outline(camera: Camera3D, mesh_inst: MeshInstance3D, prism_mesh: PrismMesh, color: Color):
	var xform = mesh_inst.global_transform
	
	# 无缓存则预计算外棱，后续帧直接复用
	if not prism_edge_cache.has(prism_mesh):
		_build_prism_edge_cache(prism_mesh)
	
	var edge_pairs = prism_edge_cache[prism_mesh]
	if edge_pairs.is_empty():
		return
	
	# 读取网格原始顶点数据
	var arrays = prism_mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	
	# 逐条外棱投影绘制
	for pair in edge_pairs:
		var ws_p0 = xform * vertices[pair[0]]
		var ws_p1 = xform * vertices[pair[1]]
		
		if camera.is_position_behind(ws_p0) and camera.is_position_behind(ws_p1):
			continue
		
		var screen_p0 = camera.unproject_position(ws_p0)
		var screen_p1 = camera.unproject_position(ws_p1)
		draw_line(screen_p0, screen_p1, color, line_thickness)

# 预计算三棱柱的真实外棱，存入缓存，仅执行一次
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

# ==================== ArrayMesh硬边专属绘制 ====================
func _draw_arraymesh_hard_edges(camera: Camera3D, mesh_inst: MeshInstance3D, mesh: ArrayMesh, color: Color):
	var xform = mesh_inst.global_transform
	
	# 优先读取缓存，没有则生成并缓存
	var cache_key = mesh.resource_path
	if cache_key.is_empty():
		cache_key = str(mesh.get_instance_id())
	if not mesh_edge_cache.has(cache_key):
		mesh_edge_cache[cache_key] = _extract_hard_edges(mesh)
	var hard_edges = mesh_edge_cache[cache_key]
	
	# 逐条硬边投影绘制
	for i in range(0, hard_edges.size(), 2):
		var ws_p0 = xform * hard_edges[i]
		var ws_p1 = xform * hard_edges[i+1]
		
		# 两点都在相机后方则跳过
		if camera.is_position_behind(ws_p0) and camera.is_position_behind(ws_p1):
			continue
		
		var sp0 = camera.unproject_position(ws_p0)
		var sp1 = camera.unproject_position(ws_p1)
		draw_line(sp0, sp1, color, line_thickness)

# ==================== 辅助函数 ====================
func _get_mesh_color(mesh_name: String) -> Color:
	for i in range(mesh_types.size()):
		if mesh_name.find(mesh_types[i]) != -1:
			if i < line_colors.size():
				return line_colors[i]
	return edge_color

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

# ==================== 硬边提取函数_ArrayMesh ====================
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


