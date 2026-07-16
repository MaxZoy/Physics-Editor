extends Window

# 每个新建的元素都有唯一且对应的id_code
var id_code: int
var info: Dictionary = {
	"enabled": true, # 是否立刻启用
	"name": "", # 名称
	"type": 0, # 类型
	"rotation": [0.0, 0.0, 0.0], # 方向
	"position": [0.0, 0.0, 0.0], # 位置
	"size": [1.0, 1.0, 1.0], # 尺寸
	"coll_color": [1.0, 1.0, 1.0, 1.0], # 碰撞区域颜色
	"description": "" # 描述
}

# 获取窗口中的重要组件
@onready var enabled_btn: CheckButton = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/IDCodeBox/CheckButton
@onready var name_edit: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/ObjLabel/NameBox/LineEdit
@onready var id_code_text: Label = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/IDCodeBox/Code
@onready var type_option_btn: OptionButton = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/ObjLabel/TypeBox/OptionButton
@onready var pos_x: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/b1/PositionBox/xBox/LineEdit
@onready var pos_y: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/b1/PositionBox/yBox/LineEdit
@onready var pos_z: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/b1/PositionBox/zBox/LineEdit
@onready var size_x: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/b1/SizeBox/xBox/LineEdit
@onready var size_y: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/b1/SizeBox/yBox/LineEdit
@onready var size_z: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/b1/SizeBox/zBox/LineEdit
@onready var rot_x: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/b1/RotationBox/xBox/LineEdit
@onready var rot_y: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/b1/RotationBox/yBox/LineEdit
@onready var rot_z: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/b1/RotationBox/zBox/LineEdit
@onready var color_select: ColorPickerButton = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/b1/ColorSelect/ColorPickerButton
# 其他
@onready var description_text: TextEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/Description/TextEdit
@onready var yes_btn: Button = $Panel/VBoxContainer/ConfirmBox/Yes
@onready var no_btn: Button = $Panel/VBoxContainer/ConfirmBox/No
@onready var del_btn: Button = $Panel/VBoxContainer/ConfirmBox/Delete

# 对应修改数据面板
var set_ground_panel: PanelContainer = null
var set_ground = null

func _ready() -> void:
	reset_value_for_window(GlobalData.init_ground_info)
	yes_btn.disabled = true
	# 连接按钮的 pressed 信号
	yes_btn.pressed.connect(reset_ground)
	no_btn.pressed.connect(close_window)
	del_btn.pressed.connect(open_delete_window)

func _process(delta: float) -> void:
	
	# 如果没有输入名称，则“确定”按钮不可用
	if name_edit.text == "":
		yes_btn.disabled = true
	else:
		yes_btn.disabled = false
	

# 设置窗口确认键按下后 将新的值赋值给物理场
func reset_ground():
	# 新的赋值
	info["enabled"] = enabled_btn.button_pressed
	info["name"] = name_edit.text
	info["type"] = type_option_btn.selected
	var rot_vec = Vector3(float(rot_x.text), float(rot_y.text), float(rot_z.text))
	info["rotation"] = [rot_vec.x, rot_vec.y, rot_vec.z]
	var pos_vec = Vector3(float(pos_x.text), float(pos_y.text), float(pos_z.text))
	info["position"] = [pos_vec.x, pos_vec.y, pos_vec.z]
	var size_vec = Vector3(float(size_x.text), float(size_y.text), float(size_z.text))
	info["size"] = [size_vec.x, size_vec.y, size_vec.z]
	var col = color_select.color
	info["coll_color"] = [col.r, col.g, col.b, col.a]
	info["description"] = description_text.text


	# 传输数据
	if set_ground_panel != null:
		set_ground_panel.info = info
		set_ground_panel.info_refreshed()
		pass
	else:
		printerr("尝试修改数据失败")

	# 修改 run_project_data 的数据
	GlobalData.run_project_data["grounds"][str(id_code).pad_zeros(6)] = info.duplicate(true)
	if GlobalData.ground == null:
		GlobalData.ground = GlobalData.select_ground_type(type_option_btn.selected)
	set_ground = GlobalData.ground.instantiate()

	# 关闭当前 Window
	# queue_free()
	close_window()

func close_window():
	# 关闭当前 Window
	# queue_free()
	info = GlobalData.init_ground_info.duplicate(true)
	reset_value_for_window(GlobalData.init_ground_info)
	WindowsManager.close_window(self.name)

func reset_value_for_window(ground_info):
	info = ground_info
	# 将info数据赋值给窗口UI组件
	enabled_btn.button_pressed = info["enabled"]
	name_edit.text = info["name"]
	type_option_btn.selected = info["type"]

	# rotation三维数组赋值给xyz输入框
	var rot_arr = info["rotation"]
	rot_x.text = str(rot_arr[0])
	rot_y.text = str(rot_arr[1])
	rot_z.text = str(rot_arr[2])

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

	# 四维数组转Color
	var col_arr = info["coll_color"]
	color_select.color = Color(col_arr[0], col_arr[1], col_arr[2], col_arr[3])

	description_text.text = info["description"]

func open_delete_window():
	WindowsManager.open_window("DeleteWindows")
	var win = WindowsManager.get_window_by_name("DeleteWindows")
	win.refresh_name_label(info["name"])
	win.del_id_code = id_code
	win.del_item_panel = set_ground_panel
	win.del_item_obj = set_ground
	win.parent_window = self


