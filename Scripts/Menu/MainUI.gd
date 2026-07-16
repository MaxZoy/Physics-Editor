# 主菜单的设置
extends VBoxContainer

# 场景加载容器 绑定MainContent节点
@onready var main_content: Control = $BackGround/MainArea/MainPanel/MainContent
@onready var file_menu: MenuButton = $TopBar/MenuBarContainer/File
@onready var edit_menu: MenuButton = $TopBar/MenuBarContainer/Edit
@onready var option_menu: MenuButton = $TopBar/MenuBarContainer/Option
@onready var debug_menu: MenuButton = $TopBar/MenuBarContainer/Debug
@onready var help_menu: MenuButton = $TopBar/MenuBarContainer/Help
@onready var bottom_panel: PanelContainer = $BackGround/MainArea/BottomPanel
# 当前加载的场景实例
var current_scene: Control = null


func _ready():
	get_window().title = "Physics Editor" 
	set_popup_menu()
	# 启动时默认加载Start场景
	# load_scene(START_SCENE)
	load_scene(GlobalData.EDITOR_SCENE)

func set_popup_menu():
	# 从MenuButton获取PopupMenu，再连接信号
	# File
	var file_popup = file_menu.get_popup()
	file_popup.shrink_width = false
	file_popup.min_size.x = 256
	# 添加快捷方式
	file_popup.set_item_accelerator(file_popup.get_item_index(0), KEY_MASK_CTRL | KEY_N) # 新建快捷键
	file_popup.set_item_accelerator(file_popup.get_item_index(1), KEY_MASK_CTRL | KEY_O) # 打开快捷键
	file_popup.set_item_accelerator(file_popup.get_item_index(5), KEY_MASK_CTRL | KEY_S) # 保存快捷键
	file_popup.set_item_accelerator(file_popup.get_item_index(3), KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_S) # 另存为快捷键
	file_popup.id_pressed.connect(_on_file_menu_id_pressed)  
	
	var edit_popup = edit_menu.get_popup()
	edit_popup.shrink_width = false
	edit_popup.min_size.x = 256
	
	var option_popup = option_menu.get_popup()
	option_popup.shrink_width = false
	option_popup.min_size.x = 256
	
	var debug_popup = debug_menu.get_popup()
	debug_popup.shrink_width = false
	debug_popup.min_size.x = 256
	
	var help_popup = help_menu.get_popup()
	help_popup.shrink_width = false
	help_popup.min_size.x = 256
	

# 通用场景加载函数 + 自动适配父容器大小
func load_scene(scene: PackedScene):
	# 1. 销毁旧场景
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.queue_free()
		current_scene = null

	# 2. 实例化新场景
	current_scene = scene.instantiate()
	main_content.add_child(current_scene)

	# 让场景铺满父容器（自动适配大小）
	current_scene.anchor_left = 0.0
	current_scene.anchor_top = 0.0
	current_scene.anchor_right = 1.0
	current_scene.anchor_bottom = 1.0
	
	# 禁止固定大小，强制自适应
	current_scene.custom_minimum_size = Vector2(0, 0)
	current_scene.size_flags_horizontal = Control.SIZE_FILL
	current_scene.size_flags_vertical = Control.SIZE_FILL

# File菜单事件处理
func _on_file_menu_id_pressed(id: int):
	match id:
		0: # 新建项目
			if GlobalData.check_data_equal():
				_create_new_project()
			else:
				WindowsManager.open_window("CheckSaveFile")
				WindowsManager.get_window_by_name("CheckSaveFile").main_ui = self
				WindowsManager.get_window_by_name("CheckSaveFile").file_mode = 0
		1: # 打开项目
			if GlobalData.check_data_equal():
				_open_existing_project()
			else:
				WindowsManager.open_window("CheckSaveFile")
				WindowsManager.get_window_by_name("CheckSaveFile").main_ui = self
				WindowsManager.get_window_by_name("CheckSaveFile").file_mode = 1
		2: # 退出程序
			# get_tree().quit()
			GlobalData.check_data_before_quit()
		5: # 保存项目
			print("保存项目")
			GlobalData.save_data()
			if not GlobalData.current_project_read_file:
				_save_new_project()
			else:
				# 写入文件
				GlobalTools.write_json_file(GlobalData.current_project_file_path, GlobalData.init_project_data)


# 统一创建文件对话框
func _create_file_dialog(dialog_mode, title: String, default_file: String = "") -> FileDialog:
	var dialog = FileDialog.new()
	# 访问权限：完整文件系统
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	# 对话框模式
	dialog.file_mode = dialog_mode
	# 弹窗标题
	dialog.title = title
	# 默认文件名
	if default_file != "":
		dialog.current_file = default_file
	# 文件过滤器：只显示 .physe 项目文件
	dialog.filters = ["物理模拟项目 (*.physe);*.physe", "所有文件;*.*"]
	# 保存模式下开启覆盖确认
	if dialog_mode == FileDialog.FILE_MODE_SAVE_FILE:
		dialog.overwrite_warning_enabled = true
	# 应用自定义窗口样式
	dialog_window_form(dialog)
	# 点取消/关闭窗口时自动销毁
	dialog.canceled.connect(dialog.queue_free)
	return dialog

# 清洗文件名并强制补全 .physe 后缀
func _fix_physe_file_path(full_path: String) -> String:
	# 分离目录与文件名
	var dir = full_path.get_base_dir()
	var filename = full_path.get_file()
	# 清洗文件名：按分隔符截取纯名称部分
	if " : " in filename:
		filename = filename.split(" : ")[0]
	# 补全后缀
	if not filename.ends_with(".physe"):
		filename += ".physe"
	# 拼接回完整路径
	return dir.path_join(filename)

# 新建项目逻辑
func _create_new_project():
	var dialog = _create_file_dialog(
		FileDialog.FILE_MODE_SAVE_FILE,
		"新建项目",
		"未命名项目.physe"
	)
	
	dialog.file_selected.connect(func(path: String):
		# 修正文件名与后缀
		var full_path = _fix_physe_file_path(path)
		GlobalData.current_project_file_path = full_path
		# 生成空白项目数据
		GlobalData.current_project_read_file = true
		var project_data = GlobalData._get_default_empty_save(full_path)
		# 写入文件
		GlobalTools.write_json_file(full_path, project_data)
		
		print("项目创建成功：", full_path)
		# 赋值全局状态
		GlobalData.init_project_data = project_data.duplicate(true)
		GlobalData.run_project_data = GlobalData.init_project_data.duplicate(true)
	)
	
	add_child(dialog)
	dialog.popup_centered()

# 打开项目逻辑
func _open_existing_project():
	var dialog = _create_file_dialog(
		FileDialog.FILE_MODE_OPEN_FILE,
		"打开项目"
	)
	
	dialog.file_selected.connect(func(path: String):
		var full_path = _fix_physe_file_path(path)
		
		# 校验文件是否存在
		if not FileAccess.file_exists(full_path):
			print("项目文件不存在")
			return
		
		# 读取解析项目数据
		var project_data = GlobalTools.read_json_file(full_path)
		
		# 校验文件核心字段
		if (not project_data.has("project_info")
			or not project_data.has("project_settings")
			or not project_data.has("simulation_settings")):
			print("无效的项目文件格式")
			return
		
		print("项目加载成功：", full_path)
		# 赋值全局状态
		GlobalData.current_project_read_file = true
		GlobalData.current_project_file_path = full_path
		GlobalData.init_project_data = project_data.duplicate(true)
		GlobalData.run_project_data = GlobalData.init_project_data.duplicate(true)
		# 切换到编辑器场景
		load_scene(GlobalData.EDITOR_SCENE)
	)
	
	add_child(dialog)
	dialog.popup_centered()

# 另存为项目逻辑
func _save_new_project():
	var dialog = _create_file_dialog(
		FileDialog.FILE_MODE_SAVE_FILE,
		"保存项目",
		GlobalData.current_project_file_path.get_file() if GlobalData.current_project_file_path != "" else "未命名项目.physe"
	)
	
	dialog.file_selected.connect(func(path: String):
		# 修正文件名与后缀
		var full_path = _fix_physe_file_path(path)
		# 取当前初始项目数据保存
		var project_data = GlobalData.init_project_data
		# 写入文件
		GlobalTools.write_json_file(full_path, project_data)
		
		print("项目保存成功：", full_path)
		# 更新全局状态
		GlobalData.current_project_read_file = true
		GlobalData.current_project_file_path = full_path
		GlobalData.save_data()
		# 跳转编辑器场景
		load_scene(GlobalData.EDITOR_SCENE)
	)
	
	add_child(dialog)
	dialog.popup_centered()


# 新建/打开窗口的格式
func dialog_window_form(dialog: FileDialog):
	# 给对话框绑定预设窗口主题
	dialog.theme = GlobalData.DIALOG_WINDOWS_THEME
	# 设置文件列表展示模式为列表模式，而非缩略图模式
	dialog.display_mode = FileDialog.DISPLAY_LIST
	# 隐藏布局切换按钮，禁止用户切换列表/缩略图显示布局
	dialog.layout_toggle_enabled = false
	# 开启文件删除功能，允许用户在弹窗内删除已有文件
	dialog.deleting_enabled = true
	# 隐藏隐藏文件切换按钮，不展示系统隐藏文件
	dialog.hidden_files_toggle_enabled = false
	# 隐藏文件过滤器开关，不提供自定义过滤功能
	dialog.file_filter_toggle_enabled = false
	# 隐藏文件排序选项，禁用手动排序切换
	dialog.file_sort_options_enabled = false
	# 关闭收藏目录功能，不显示收藏栏
	dialog.favorites_enabled = false
	# dialog.use_native_dialog = true
	# 文件过滤器，仅显示后缀为.physe的项目文件
	dialog.filters = ["*.physe"]

