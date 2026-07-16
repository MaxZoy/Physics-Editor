# AddPhysicsFieldWindows.gd
extends Window

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
# 其他
@onready var description_text: TextEdit = $Panel/VBoxContainer/VBoxContainer/TextEdit
@onready var yes_btn: Button = $Panel/VBoxContainer/ConfirmBox/Yes
@onready var no_btn: Button = $Panel/VBoxContainer/ConfirmBox/No


func _ready() -> void:
	yes_btn.disabled = true
	# 连接按钮的 pressed 信号
	yes_btn.pressed.connect(create_field)
	no_btn.pressed.connect(close_window)
	reset_value_for_window()
	

func _process(delta: float) -> void:
	# 选择的物理场类型不一样，数值单位也不一样
	value_unit.text = GlobalTools.field_type_select_to_unit(type_option_btn.selected)
	
	# 如果没有输入名称，则“确定”按钮不可用
	if name_edit.text == "":
		yes_btn.disabled = true
	else:
		yes_btn.disabled = false
	

func create_field():
	await get_tree().process_frame

	# 生成新的物理场面板
	var field_panel_fold = get_tree().root.get_node(
		GlobalData.editor_node_path + 
		"/HBoxContainer/RightSplit/TabContainer/ScenePack/SceneScroll/ObjContainer/Field/VBoxContainer")
	# 此处不明原因出错，用另一种方式替代。第二次尝试又好了，不知道为什么？？？
	var new_field_panel = null
	new_field_panel = GlobalData.field_panel.instantiate()
	# 动态加载场景，不依赖GlobalData存储PackedScene
	# var scene = load("res://Scenes/Fields/FieldPanel.tscn")
	# var new_field_panel = scene.instantiate()
	assign_value_to_field(new_field_panel)
	# 延迟添加子节点
	field_panel_fold.call_deferred("add_child", new_field_panel)
	# 延迟置顶，必须等add_child执行完才会生效
	field_panel_fold.call_deferred("move_child", new_field_panel, 0)
	new_field_panel.call_deferred("info_refreshed")

	# 生成物理场
	var new_field_area = null
	var field_area_fold = get_tree().root.get_node(
		GlobalData.root3d_node_path + "/AllFields")
	new_field_area = GlobalData.field_area.instantiate()
	# 传输数据
	new_field_area.info = new_field_panel.info.duplicate(true)
	field_area_fold.add_child(new_field_area)
	new_field_panel.field_area = new_field_area
		
	# 关闭当前 Window
	# queue_free()
	close_window()


# 赋值给新生成的场
func assign_value_to_field(field):
	print("新建物理场id_code：", str(id_code).pad_zeros(6))
	# 赋值场的信息
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
	# 存入coll_color时处理
	var col = coll_color_select.color
	info["coll_color"] = [
		round(col.r * 255 * 10) / 10.0,
		round(col.g * 255 * 10) / 10.0,
		round(col.b * 255 * 10) / 10.0,
		round(col.a * 255 * 10) / 10.0
	]
	info["description"] = description_text.text

	field.id_code = id_code
	field.info = info
	# id_code全集添加新编号
	# print(field.id_code)
	GlobalData.run_project_data["id_code"].append(id_code)
	GlobalData.add_field_dict(field.id_code, field.info)


func close_window():
	# 关闭当前 Window
	# queue_free()
	info = GlobalData.init_field_info.duplicate(true)
	# GlobalTools.print_dict(info)
	reset_value_for_window()
	WindowsManager.close_window(self.name)

func reset_value_for_window():
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

