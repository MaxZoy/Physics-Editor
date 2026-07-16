@tool
extends EditorPlugin

var status_label: Label = null
var poll_timer: Timer = null

func _enter_tree():
	status_label = Label.new()
	status_label.text = "统计节点数: 0"
	status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	add_control_to_bottom_panel(status_label, "节点统计")

	poll_timer = Timer.new()
	poll_timer.wait_time = 2
	poll_timer.one_shot = false
	poll_timer.timeout.connect(_poll_update)
	add_child(poll_timer)
	poll_timer.start()

	await get_tree().process_frame
	_poll_update()

func _exit_tree():
	if status_label:
		remove_control_from_bottom_panel(status_label)
		status_label.free()
		status_label = null

	if poll_timer:
		poll_timer.stop()
		poll_timer.free()
		poll_timer = null

func _poll_update():
	if not status_label:
		return

	var current_scene = EditorInterface.get_edited_scene_root()
	if not current_scene or not is_instance_valid(current_scene):
		status_label.text = "统计节点数: 0 (无场景)"
		return

	var count = _count_nodes(current_scene)

	var scene_name = "未命名"
	var path = current_scene.scene_file_path
	if path != null and path != "":
		scene_name = path.get_file()

	var instance_count = _count_instanced_scenes(current_scene)

	status_label.text = "统计 %s : %d 个节点 (含 %d 个子场景实例)" % [scene_name, count, instance_count]

func _count_nodes(node: Node) -> int:
	var count = 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

func _count_instanced_scenes(node: Node) -> int:
	var count = 0
	# 安全获取路径
	var node_path = node.scene_file_path
	var owner_path = node.owner.scene_file_path if node.owner else ""
	
	if node_path != null and node_path != "" and node_path != owner_path:
		count += 1
	
	for child in node.get_children():
		count += _count_instanced_scenes(child)
	return count