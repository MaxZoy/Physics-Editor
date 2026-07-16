extends Node

# 关于窗口场景
const ABOUT_WINDOW_SCENE: PackedScene = preload("res://Scenes/BuildInWindows/AboutWindows.tscn")
# 添加物理场窗口场景
const ADD_PHYSICS_FIELD_SCENE: PackedScene = preload("res://Scenes/BuildInWindows/AddPhysicsField.tscn")
# 添加研究对象窗口场景
const ADD_OBJECT_SCENE: PackedScene = preload("res://Scenes/BuildInWindows/AddObjects.tscn")
# 添加接触面窗口场景
const ADD_GROUND_SCENE: PackedScene = preload("res://Scenes/BuildInWindows/AddGround.tscn")
# 设置物理场窗口场景
const SET_PHYSICS_FIELD_SCENE: PackedScene = preload("res://Scenes/BuildInWindows/SetPhysicsField.tscn")
# 设置研究对象窗口场景
const SET_OBJECT_SCENE: PackedScene = preload("res://Scenes/BuildInWindows/SetObjects.tscn")
# 添加接触面窗口场景
const SET_GROUND_SCENE: PackedScene = preload("res://Scenes/BuildInWindows/SetGround.tscn")
# 关闭前保存窗口场景
const CHECK_SAVE_WINDOW: PackedScene = preload("res://Scenes/BuildInWindows/CheckSaveFile.tscn")
# 退出前保存窗口场景
const QUIT_AND_SAVE_WINDOW: PackedScene = preload("res://Scenes/BuildInWindows/QuitAndSaveFile.tscn")
# 删除窗口场景
const DELETE_WINDOW: PackedScene = preload("res://Scenes/BuildInWindows/DeleteWindows.tscn")

# 窗口池：缓存所有预加载好的窗口实例
var window_pool: Array[Window] = []
# 窗口资源列表，存放你所有子窗口PackedScene
@onready var window_scenes: Array[PackedScene] = [
	ABOUT_WINDOW_SCENE,
	ADD_PHYSICS_FIELD_SCENE,
	ADD_OBJECT_SCENE,
	ADD_GROUND_SCENE,
	SET_PHYSICS_FIELD_SCENE,
	SET_OBJECT_SCENE,
	SET_GROUND_SCENE,
	CHECK_SAVE_WINDOW,
	QUIT_AND_SAVE_WINDOW,
	DELETE_WINDOW
]

func _ready():
	# 启动阶段一次性预生成全部窗口，分摊加载耗时，避免运行时卡顿
	for scene in window_scenes:
		var win = scene.instantiate()
		# 初始隐藏，不渲染
		win.visible = false
		# 不加入场景树，仅内存持有
		window_pool.append(win)

# 对外接口：打开指定窗口
func open_window(target_name: String):
	for win in window_pool:
		if win.name == target_name:
			if not win.is_inside_tree():
				get_tree().root.add_child(win)
			win.visible = true
			win.popup_centered()
			# 先断开，防止多次绑定重复触发
			if win.close_requested.is_connected(close_window):
				win.close_requested.disconnect(close_window)
			win.close_requested.connect(func(): close_window(win.name))
			break

# 对外接口：关闭窗口（仅隐藏，不销毁、不从树移除）
func close_window(target_name: String):
	for win in window_pool:
		if win.name == target_name:
			win.visible = false
			# 关键：不执行queue_free / remove_child，永久保留实例
			break

# 对外接口：根据场景名称查找对应的窗口
func get_window_by_name(target_name: String) -> Window:
	for win in window_pool:
		if win.name == target_name:
			return win

	return null
