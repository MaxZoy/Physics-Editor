extends Control

const DIALOG_WINDOWS_THEME = preload("res://Themes/Dark/ChildWindows.tres")

# 创建项目完成时，传递项目路径给MainUI
signal project_created(project_path: String)

# 绑定新建项目按钮
@onready var new_project_btn: Button = $MainContent/NewProjectButton
@onready var open_project_btn: Button = $MainContent/OpenProjectButton


func _ready():
	# 找到按钮再连接信号
	if new_project_btn != null:
		new_project_btn.pressed.connect(on_new_project_clicked)
	else:
		print("错误：找不到新建项目按钮，请检查节点路径是否正确")
		
	# 连接打开项目按钮
	if open_project_btn != null:
		open_project_btn.pressed.connect(on_open_project_clicked)
	else:
		print("错误：找不到打开项目按钮")


# 点击新建项目按钮：弹出文件对话框并创建项目文件
func on_new_project_clicked():
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.theme = DIALOG_WINDOWS_THEME
	dialog.display_mode = FileDialog.DISPLAY_LIST
	dialog.layout_toggle_enabled = false
	dialog.deleting_enabled = true
	dialog.hidden_files_toggle_enabled = false
	dialog.file_filter_toggle_enabled = false
	dialog.file_sort_options_enabled = false
	dialog.favorites_enabled = false
	# dialog.use_native_dialog = true
	dialog.title = "新建项目"
	# 文件过滤器
	dialog.filters = ["*.physe"]
	
	dialog.file_selected.connect(func(_paths):
		var selected_dir = dialog.current_dir
		var raw_input = dialog.get_line_edit().text
		
		# 剥离过滤器文本
		var cleaned_filename = raw_input.split(" : ")[0]
		
		# 自动补全后缀
		if not cleaned_filename.ends_with(".physe"):
			cleaned_filename += ".physe"
		
		# 确保目录末尾有斜杠
		if not selected_dir.ends_with("/"):
			selected_dir += "/"
		
		# 拼接完整路径
		var full_path = selected_dir + cleaned_filename
		
		full_path = ProjectSettings.globalize_path(full_path)
		
		print("=== 最终验证路径 ===")
		print("拼接后的路径:", full_path)
		print("是否为绝对路径:", full_path.is_absolute_path())
		
		create_new_project(full_path)
	)
	
	
	# 添加到场景并居中弹出
	add_child(dialog)
	dialog.popup_centered()


func create_new_project(paths: String):

	print("Final project path:", paths)

	# 生成项目基础数据
	var project_data = {
		"project_info": {
			"name": paths.get_file().get_basename(),
			"version": "1.0",
			"created_at": Time.get_datetime_string_from_system(),
			"author": "Your Name"
		},
		"simulation_settings": {
			"gravity": [0, -9.81],  # 存为数组，而非Vector2对象
			"time_step": 1.0 / 60.0,
			"max_steps": 10000
		},
		"objects": []
	}

	# 写入项目文件（JSON格式）
	var file = FileAccess.open(paths, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(project_data, "\t")
		# 将字符串转为UTF-8字节数组，用store_buffer写入
		var data_buffer = json_str.to_utf8_buffer()
		file.store_buffer(data_buffer)
		file.close()
		
		print("项目创建成功，路径：", paths)
		project_created.emit(paths)
	else:
		print("错误：无法创建项目文件，请检查路径权限或磁盘空间")


# 打开项目逻辑
func on_open_project_clicked():
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.theme = DIALOG_WINDOWS_THEME
	dialog.display_mode = FileDialog.DISPLAY_LIST
	dialog.layout_toggle_enabled = false
	dialog.deleting_enabled = true
	dialog.hidden_files_toggle_enabled = false
	dialog.file_filter_toggle_enabled = false
	dialog.file_sort_options_enabled = false
	dialog.favorites_enabled = false
	# dialog.use_native_dialog = true
	dialog.title = "打开项目"
	dialog.filters = ["*.physe"]
	
	dialog.file_selected.connect(func(_paths):
		var selected_dir = dialog.current_dir
		var raw_input = dialog.get_line_edit().text
		var cleaned_filename = raw_input.split(" : ")[0]
		
		if not selected_dir.ends_with("/"):
			selected_dir += "/"
		
		var full_path = selected_dir + cleaned_filename
		full_path = ProjectSettings.globalize_path(full_path)
		
		load_existing_project(full_path)
	)
	
	add_child(dialog)
	dialog.popup_centered()


func load_existing_project(project_path: String):
	print("正在打开项目：", project_path)
	
	# 1. 检查文件是否存在
	if not FileAccess.file_exists(project_path):
		print("项目文件不存在")
		return
	
	# 读取文件内容
	var file = FileAccess.open(project_path, FileAccess.READ)
	if not file:
		print("无法打开项目文件：", FileAccess.get_open_error())
		return
	
	var json_str = file.get_as_text()
	file.close()
	
	# 解析JSON数据
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		print("JSON解析错误：", err)
		return
	
	# 验证项目数据格式
	var project_data = json.data
	if not project_data.has("project_info") or not project_data.has("simulation_settings"):
		print("无效的项目文件格式")
		return
	
	# 发出信号，切换到Editor界面
	print("项目加载成功：", project_path)
	project_created.emit(project_path)
