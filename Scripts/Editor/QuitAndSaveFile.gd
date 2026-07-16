extends Window

@onready var yes_btn: Button = $Panel/VBoxContainer/ConfirmBox/Yes
@onready var no_btn: Button = $Panel/VBoxContainer/ConfirmBox/No
@onready var cancel_btn: Button = $Panel/VBoxContainer/ConfirmBox/Cancel

func _ready() -> void:
	yes_btn.pressed.connect(yes_window)
	no_btn.pressed.connect(no_window)
	cancel_btn.pressed.connect(cancel_window)

# 执行保存文件的函数
func yes_window():
	# 关闭当前 Window
	# queue_free()
	print("保存项目")
	GlobalData.save_data()
	WindowsManager.close_window(self.name)
	# 执行完逻辑后，真正关闭程序
	get_tree().quit()

# 取消保存文件
func no_window():
	# 关闭当前 Window
	# queue_free()
	WindowsManager.close_window(self.name)
	# 执行完逻辑后，真正关闭程序
	get_tree().quit()

# 返回
func cancel_window():
	# 关闭当前 Window
	# queue_free()
	WindowsManager.close_window(self.name)
