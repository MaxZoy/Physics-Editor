extends Window

@onready var yes_btn: Button = $Panel/VBoxContainer/ConfirmBox/Yes
@onready var no_btn: Button = $Panel/VBoxContainer/ConfirmBox/No
var main_ui = null
var file_mode: int = 100

func _ready() -> void:
	yes_btn.pressed.connect(yes_window)
	no_btn.pressed.connect(no_window)

# 执行保存文件的函数
func yes_window():
	# 关闭当前 Window
	# queue_free()
	print("保存项目")
	GlobalData.save_data()
	main_ui._save_new_project()

	file_mode = 100
	WindowsManager.close_window(self.name)

# 取消保存文件
func no_window():
	# 关闭当前 Window
	# queue_free()
	print("取消保存项目")
	GlobalData.save_data()
	match file_mode:
		0:
			main_ui._create_new_project()
		1:
			main_ui._open_existing_project()

	file_mode = 100
	WindowsManager.close_window(self.name)


