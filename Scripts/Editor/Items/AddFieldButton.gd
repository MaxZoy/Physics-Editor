extends Button


func _ready() -> void:
	# 确保添加按钮一直在vbox最下面
	if get_parent():
		get_parent().move_child.call_deferred(self, -1)
	pressed.connect(create_window)

# 打开添加物理场窗口
func create_window():
	# # 判断弹窗实例是否存在且有效（未被销毁）
	# if add_field_window == null:
	# 实例化弹窗场景，生成窗口节点对象
	WindowsManager.open_window("AddPhysicsField")
	var win = WindowsManager.get_window_by_name("AddPhysicsField")
	var id_code = GlobalTools.get_id_code()
	win.id_code = id_code
	win.id_code_text.text = "*" + str(win.id_code).pad_zeros(6)
