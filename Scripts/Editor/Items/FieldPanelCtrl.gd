# FieldPanelCtrl.gd
extends PanelContainer

# 物理场的基本属性
var id_code: int
var info: Dictionary = {
	"enabled": true, # 是否立刻启用
	"name": "", # 名称
	"type": 0, # 类型
	"value": 0.0, # 数值
	"direction": [0.0, -1.0, 0.0], # 方向
	"can_extense": true,
	"extense_mode": "a", # 默认全伸展
	"position": [0.0, 0.0, 0.0], # 位置
	"size": [1.0, 1.0, 1.0], # 尺寸
	"is_show_coll": true, # 是否显示碰撞区域
	"coll_color": [120.0, 90.0, 255.0, 32.0], # 碰撞区域颜色
	"description": "" # 描述
}

@onready var id_code_label: Label = $HBoxContainer/SplitContainer/Info/ID_code
@onready var name_label: Label = $HBoxContainer/SplitContainer/Info/Name
@onready var value_spinbox: SpinBox = $HBoxContainer/SplitContainer/VBoxContainer/Value/Num
@onready var unit_label: Label = $HBoxContainer/SplitContainer/VBoxContainer/Value/Unit
@onready var x_line_edit: LineEdit = $HBoxContainer/SplitContainer/VBoxContainer/DirectionBox/xBox/LineEdit
@onready var y_line_edit: LineEdit = $HBoxContainer/SplitContainer/VBoxContainer/DirectionBox/yBox/LineEdit
@onready var z_line_edit: LineEdit = $HBoxContainer/SplitContainer/VBoxContainer/DirectionBox/zBox/LineEdit
@onready var setting_btn: TextureButton = $HBoxContainer/VBoxContainer/SettingButton
# 引用右键菜单节点
@onready var right_menu: PopupMenu = $SceneClickMenu
# 所对应的物理场
var field_area = null
# 更新标志
var _is_updating: bool = false

func _ready() -> void:
	id_code_label.text = "*" + str(id_code).pad_zeros(6)
	name_label.text = info["name"]
	value_spinbox.value = info["value"]
	unit_label.text = GlobalTools.field_type_select_to_unit(info["type"])
	x_line_edit.text = str(info["direction"][0])
	y_line_edit.text = str(info["direction"][1])
	z_line_edit.text = str(info["direction"][2])

	setting_btn.pressed.connect(create_window)
	# 数值输入框：数值变化时自动同步
	value_spinbox.value_changed.connect(_on_value_changed)
	# 三个方向输入框：提交（回车/失焦）时同步
	x_line_edit.text_submitted.connect(_on_dir_submitted)
	y_line_edit.text_submitted.connect(_on_dir_submitted)
	z_line_edit.text_submitted.connect(_on_dir_submitted)

	set_popup_menu()

func create_window():
	# 打开设置窗口
	WindowsManager.open_window("SetPhysicsField")
	var win = WindowsManager.get_window_by_name("SetPhysicsField")
	win.id_code = id_code
	win.id_code_text.text = "*" + str(win.id_code).pad_zeros(6)
	win.info = info
	win.reset_value_for_window(info.duplicate(true))
	win.set_field_panel = self
	win.set_field_area = field_area


# SpinBox 数值变化回调
func _on_value_changed(_new_value: float):
	if _is_updating:
		return  # 如果是程序化更新，跳过
	info_changed()

# 方向输入框提交回调
func _on_dir_submitted(_new_text: String):
	if _is_updating:
		return  # 如果是程序化更新，跳过
	info_changed()

# 当数据被修改后，对应面板的 text 也要被修改
func info_refreshed():
	_is_updating = true  # 开始更新，禁止信号触发
	
	name_label.text = info["name"]
	value_spinbox.value = info["value"]
	unit_label.text = GlobalTools.field_type_select_to_unit(info["type"])
	x_line_edit.text = str(info["direction"][0])
	y_line_edit.text = str(info["direction"][1])
	z_line_edit.text = str(info["direction"][2])
	self.tooltip_text = info["description"]
	# 刷新物理场区域
	field_area.id_code = id_code
	field_area.info = info
	# GlobalTools.print_dict(field_area.info)
	field_area.refresh_field()
	_is_updating = false  # 更新完成，恢复信号响应


# 当面板的数据被修改后，自身的 info 也要修改
func info_changed():
	# 防止在 info_changed 执行期间再次触发
	if _is_updating:
		return
		
	_is_updating = true
	# 同步数值输入框的值到 info 的 value 字段
	info["value"] = value_spinbox.value
	
	# 同步方向三个输入框的值到 direction 数组
	info["direction"][0] = x_line_edit.text.to_float()
	info["direction"][1] = y_line_edit.text.to_float()
	info["direction"][2] = z_line_edit.text.to_float()
	FieldManager.force_rebuild()

	GlobalData.run_project_data["fields"][str(id_code).pad_zeros(6)] = info.duplicate(true)

	_is_updating = false

# 设置弹出菜单
func set_popup_menu():
	# 连接菜单点击信号
	if right_menu != null:
		right_menu.hide_on_checkable_item_selection = true
		right_menu.id_pressed.connect(_on_menu_clicked)

	mouse_filter = MOUSE_FILTER_PASS

# 检测右键，弹出菜单
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 窗口客户区鼠标坐标，和Popup坐标系完全一致
			var mouse_pos = Vector2(DisplayServer.mouse_get_position())
			# 直接赋值，Popup的position本身就是视口坐标，无需换算
			right_menu.position = mouse_pos
			# 必须用无参popup()，才会严格按position定位
			right_menu.popup()

# 处理菜单项点击
func _on_menu_clicked(item_id: int) -> void:
	right_menu.toggle_item_checked(right_menu.get_item_index(item_id))
	
	match item_id:
		0:
			print("菜单-禁用")
		4:
			print("菜单-删除")
			open_delete_window()
		5:
			print("菜单-设置")
			create_window()
		6:
			print("菜单-打印")
			print_data()

func print_data():
	# print(field_area.name, "运行数据：")
	GlobalTools.print_dict(info)


func open_delete_window():
	WindowsManager.open_window("DeleteWindows")
	var win = WindowsManager.get_window_by_name("DeleteWindows")
	win.refresh_name_label(info["name"])
	win.del_id_code = id_code
	win.del_item_panel = self
	win.del_item_obj = field_area


func _make_custom_tooltip(for_text: String) -> Control:
	return TooltipBase.create_tooltip(for_text)
	
