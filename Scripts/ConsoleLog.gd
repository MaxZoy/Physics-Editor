extends Node
const CONSOLE_PATH = "/root/RunWindow/Console/Content/RichTextLabel"

# 使用方法：ConsoleLog.print_log("模型加载完成", Color(0.2, 0.9, 0.4), "模型A")
func print_log(msg: String, color: Color, tag: String = ""):
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var console = GlobalTools.find_node_from_global("Content")
		if console != null and console.has_method("log_custom"):
			console.log_custom(msg, color, tag)

# 存储所有快捷键的回调
var _shortcuts: Dictionary = {}

func _ready():
	# 连接 process_frame 信号（只需要连接一次）
	get_tree().process_frame.connect(_on_process_frame)
	
	# 注册快捷键
	register_shortcut(KEY_F3, _print_dict)

# 打印运行数据
func _print_dict():
	if GlobalData and GlobalData.run_project_data != null:
		GlobalTools.print_dict(GlobalData.run_project_data)
	else:
		print("警告: GlobalData.run_project_data 不存在")

func _on_process_frame():
	# 遍历所有注册的快捷键，检测按键
	for key in _shortcuts.keys():
		var was_pressed = _shortcuts[key].get("was_pressed", false)
		var callback = _shortcuts[key].get("callback")
		var current_pressed = Input.is_key_pressed(key)
		
		if current_pressed and not was_pressed:
			if callback != null:
				callback.call()
		
		# 更新状态
		_shortcuts[key]["was_pressed"] = current_pressed

## 注册一个快捷键
## key: 按键码，如 KEY_F1, KEY_1, KEY_SPACE
## callback: 按下时要执行的函数（Callable）
func register_shortcut(key: int, callback: Callable):
	if not _shortcuts.has(key):
		_shortcuts[key] = {
			"was_pressed": false,
			"callback": callback
		}
	else:
		# 如果已存在，覆盖回调
		_shortcuts[key]["callback"] = callback
	
	var key_name = OS.get_keycode_string(key)
	print("已注册快捷键: ", key_name)

## 注销快捷键
func unregister_shortcut(key: int):
	if _shortcuts.has(key):
		_shortcuts.erase(key)
		var key_name = OS.get_keycode_string(key)
		print("已注销快捷键: ", key_name)
## 清空所有快捷键
func clear_all_shortcuts():
	_shortcuts.clear()
	print("已清空所有快捷键")

# 调试打印系统使用方法：
# extends Node

# func _ready():
# 	# 注册 F1 键，按下时执行 _print_dict 函数
# 	ConsoleLog.register_shortcut(KEY_F1, _print_dict)
	
# 	# 注册数字键 1
# 	ConsoleLog.register_shortcut(KEY_1, _on_key_1_pressed)
	
# 	# 注册空格键
# 	ConsoleLog.register_shortcut(KEY_SPACE, _on_space_pressed)

# func _print_dict():
# 	print("========== 打印字典 ==========")
# 	GlobalTools.print_dict(GlobalData.run_project_data)
# 	print("================================")

# func _on_key_1_pressed():
# 	print("按了数字键 1")

# func _on_space_pressed():
#	print("按了空格键")
# 检测 Ctrl + F1
# func _on_process_frame():
#	 for key in _shortcuts.keys():
#		 var was_pressed = _shortcuts[key].get("was_pressed", false)
#		 var callback = _shortcuts[key].get("callback")
#		 var require_ctrl = _shortcuts[key].get("require_ctrl", false)
		
#		 var current_pressed = Input.is_key_pressed(key)
#		 if require_ctrl:
#			 current_pressed = current_pressed and Input.is_key_pressed(KEY_CTRL)
		
#		 if current_pressed and not was_pressed:
#			 if callback != null:
#				 callback.call()
		
#		 _shortcuts[key]["was_pressed"] = current_pressed

# # 使用时
# ConsoleLog.register_shortcut(KEY_F1, _print_dict, true)  # true 表示需要 Ctrl

