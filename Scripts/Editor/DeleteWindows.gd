extends Window

var root3d

# 获取UI组件
@onready var name_label: Label = $Panel/VBoxContainer/Name
@onready var yes_btn: Button = $Panel/VBoxContainer/ConfirmBox/Yes
@onready var no_btn: Button = $Panel/VBoxContainer/ConfirmBox/No

# 获取被删除对象的基本属性
var del_id_code: int # run_project_data 中删除
var del_item_panel = null # item 在左侧栏中的面板删除
var del_item_obj = null # item 实体删除
var parent_window = null # 将删除窗口召唤出来的窗口

func _ready() -> void:
	
	refresh_name_label("obj")
	# 连接按钮的 pressed 信号
	yes_btn.pressed.connect(delete_item)
	no_btn.pressed.connect(close_window)

# 删除对象
func delete_item():
	if root3d != null:
		root3d.element_reset()

	if del_item_obj != null and del_item_panel != null:
		if del_item_obj.info.has("property"):
			GlobalData.run_project_data["objects"].erase(str(del_id_code).pad_zeros(6))
		elif del_item_obj.info.has("rotation"):
			GlobalData.run_project_data["grounds"].erase(str(del_id_code).pad_zeros(6))
		else:
			GlobalData.run_project_data["fields"].erase(str(del_id_code).pad_zeros(6))
		GlobalData.run_project_data["id_code"].erase(del_id_code)
		del_item_obj.queue_free()
		del_item_panel.queue_free()
		ConsoleLog.print_log("删除对象：" + name_label.text, Color(1.0, 0.196, 0.196, 1.0))
	else:
		ConsoleLog.print_log("未找到对象：" + name_label.text, Color(1.0, 0.196, 0.196, 1.0))

	if (parent_window == WindowsManager.get_window_by_name("SetPhysicsField") or 
		parent_window == WindowsManager.get_window_by_name("SetObjects") ):
		parent_window.close_window()

	close_window()


func close_window():
	# 关闭当前 Window
	# queue_free()
	refresh_name_label("obj")
	WindowsManager.close_window(self.name)

func refresh_name_label(name):
	name_label.text = "“" + name + "”"
