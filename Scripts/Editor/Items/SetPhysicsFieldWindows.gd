# SetPhysicsFieldWindows.gd
extends Window

# 每个新建的元素都有唯一且对应的id_code
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

# 获取窗口中的重要组件
@onready var enabled_btn: CheckButton = $Panel/VBoxContainer/IDCodeBox/CheckButton
@onready var name_edit: LineEdit = $Panel/VBoxContainer/b1/NameBox/LineEdit
@onready var id_code_text: Label = $Panel/VBoxContainer/IDCodeBox/Code
@onready var type_option_btn: OptionButton = $Panel/VBoxContainer/b1/TypeBox/OptionButton
@onready var value_num: SpinBox = $Panel/VBoxContainer/b1/Value/Num/Num
@onready var value_unit: Label = $Panel/VBoxContainer/b1/Value/Num/Unit
@onready var can_ext_btn: CheckBox = $Panel/VBoxContainer/b2/InfiniteExtension/CanExtenseBtn/CheckBox
@onready var ext_mode_btn: OptionButton = $Panel/VBoxContainer/b2/InfiniteExtension/ExtenseMode/OptionButton
@onready var pos_x: LineEdit = $Panel/VBoxContainer/b2/PositionBox/xBox/LineEdit
@onready var pos_y: LineEdit = $Panel/VBoxContainer/b2/PositionBox/yBox/LineEdit
@onready var pos_z: LineEdit = $Panel/VBoxContainer/b2/PositionBox/zBox/LineEdit
@onready var size_x: LineEdit = $Panel/VBoxContainer/b2/SizeBox/xBox/LineEdit
@onready var size_y: LineEdit = $Panel/VBoxContainer/b2/SizeBox/yBox/LineEdit
@onready var size_z: LineEdit = $Panel/VBoxContainer/b2/SizeBox/zBox/LineEdit
@onready var dir_x: LineEdit = $Panel/VBoxContainer/b2/DirectionBox/xBox/LineEdit
@onready var dir_y: LineEdit = $Panel/VBoxContainer/b2/DirectionBox/yBox/LineEdit
@onready var dir_z: LineEdit = $Panel/VBoxContainer/b2/DirectionBox/zBox/LineEdit
@onready var is_show_coll_btn: CheckBox = $Panel/VBoxContainer/b2/ShowCollBox/ShowCollBtn/CheckBox
@onready var coll_color_select: ColorPickerButton = $Panel/VBoxContainer/b2/ShowCollBox/ColorSelect/ColorPickerButton
@onready var description_text: TextEdit = $Panel/VBoxContainer/VBoxContainer/TextEdit
@onready var yes_btn: Button = $Panel/VBoxContainer/ConfirmBox/Yes
@onready var no_btn: Button = $Panel/VBoxContainer/ConfirmBox/No
@onready var del_btn: Button = $Panel/VBoxContainer/ConfirmBox/Delete

# 对应修改数据面板
var set_field_panel: PanelContainer = null
var set_field_area = null

func _ready() -> void:
	reset_value_for_window(GlobalData.init_field_info)
	yes_btn.disabled = true
	# 连接按钮的 pressed 信号
	yes_btn.pressed.connect(reset_field)
	no_btn.pressed.connect(close_window)
	del_btn.pressed.connect(open_delete_window)

func _process(delta: float) -> void:
	# 选择的物理场类型不一样，数值单位也不一样
	value_unit.text = GlobalTools.field_type_select_to_unit(type_option_btn.selected)
	
	# 如果没有输入名称，则“确定”按钮不可用
	if name_edit.text == "":
		yes_btn.disabled = true
	else:
		yes_btn.disabled = false
	

# 设置窗口确认键按下后 将新的值赋值给物理场
func reset_field():
	# 新的赋值
	info["enabled"] = enabled_btn.button_pressed
	info["name"] = name_edit.text
	info["type"] = type_option_btn.get_item_id(type_option_btn.selected)
	info["unit"] = value_unit.text
	info["value"] = value_num.value
	var dir_vec = Vector3(float(dir_x.text), float(dir_y.text), float(dir_z.text))
	info["direction"] = [dir_vec.x, dir_vec.y, dir_vec.z]
	info["can_extense"] = can_ext_btn.button_pressed
	info["extense_mode"] = GlobalTools.field_ext_select_to_extense_mode(ext_mode_btn.selected)
	var pos_vec = Vector3(float(pos_x.text), float(pos_y.text), float(pos_z.text))
	info["position"] = [pos_vec.x, pos_vec.y, pos_vec.z]
	var size_vec = Vector3(float(size_x.text), float(size_y.text), float(size_z.text))
	info["size"] = [size_vec.x, size_vec.y, size_vec.z]
	info["is_show_coll"] = is_show_coll_btn.button_pressed
	var col = coll_color_select.color
	info["coll_color"] = [col.r * 255.0, col.g * 255.0, col.b * 255.0, col.a * 255.0]
	info["description"] = description_text.text


	# 传输数据
	if set_field_panel != null:
		set_field_panel.info = info
		set_field_panel.info_refreshed()
		pass
	else:
		printerr("尝试修改数据失败")

	# 修改 run_project_data 的数据
	GlobalData.run_project_data["fields"][str(id_code).pad_zeros(6)] = info.duplicate(true)
	# 关闭当前 Window
	# queue_free()
	close_window()

func close_window():
	# 关闭当前 Window
	# queue_free()
	info = GlobalData.init_field_info.duplicate(true)
	reset_value_for_window(GlobalData.init_field_info)
	WindowsManager.close_window(self.name)

func reset_value_for_window(field_info):
	info = field_info
	# 将info数据赋值给窗口UI组件
	enabled_btn.button_pressed = info["enabled"]
	name_edit.text = info["name"]
	type_option_btn.selected = info["type"]
	value_unit.text = GlobalTools.field_type_select_to_unit(type_option_btn.selected)
	value_num.value = info["value"]

	# direction三维数组赋值给xyz输入框
	var dir_arr = info["direction"]
	dir_x.text = str(dir_arr[0])
	dir_y.text = str(dir_arr[1])
	dir_z.text = str(dir_arr[2])

	can_ext_btn.button_pressed = info["can_extense"]
	ext_mode_btn.selected = GlobalTools.field_extense_mode_to_select(info["extense_mode"])

	# position三维数组赋值
	var pos_arr = info["position"]
	pos_x.text = str(pos_arr[0])
	pos_y.text = str(pos_arr[1])
	pos_z.text = str(pos_arr[2])

	# size三维数组赋值
	var size_arr = info["size"]
	size_x.text = str(size_arr[0])
	size_y.text = str(size_arr[1])
	size_z.text = str(size_arr[2])

	is_show_coll_btn.button_pressed = info["is_show_coll"]

	# coll_color四维数组转Color
	var col_arr = info["coll_color"]
	coll_color_select.color = Color(
		col_arr[0] / 255.0,
		col_arr[1] / 255.0,
		col_arr[2] / 255.0,
		col_arr[3] / 255.0
	)

	description_text.text = info["description"]

func open_delete_window():
	WindowsManager.open_window("DeleteWindows")
	var win = WindowsManager.get_window_by_name("DeleteWindows")
	win.refresh_name_label(info["name"])
	win.del_id_code = id_code
	win.del_item_panel = set_field_panel
	win.del_item_obj = set_field_area
	win.parent_window = self


