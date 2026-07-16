extends Button


func _ready() -> void:
	# 确保添加按钮一直在vbox最下面
	if get_parent():
		get_parent().move_child.call_deferred(self, -1)
	
	pressed.connect(create_window)


# 打开添加研究对象窗口
func create_window():
	# 实例化弹窗场景，生成窗口节点对象
	WindowsManager.open_window("AddObjects")
	var win = WindowsManager.get_window_by_name("AddObjects")
	var id_code = GlobalTools.get_id_code()
	win.id_code = id_code
	win.id_code_text.text = "*" + str(win.id_code).pad_zeros(6)
	var obj_arr = GlobalData.select_obj_type(win.type_option_btn.selected)
	GlobalData.object = obj_arr[0]
	GlobalData.obj_property = obj_arr[1]
	win.refresh_property()


