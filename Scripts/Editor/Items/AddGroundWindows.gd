extends Window

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


func _ready() -> void:
	type_option_btn.item_selected.connect(_on_option_selected)
	yes_btn.disabled = true
	# 连接按钮的 pressed 信号
	yes_btn.pressed.connect(create_ground)
	no_btn.pressed.connect(close_window)
	# reset_value_for_window()
	

func _process(delta: float) -> void:
	
	# 如果没有输入名称，则“确定”按钮不可用
	if name_edit.text == "":
		yes_btn.disabled = true
	else:
		yes_btn.disabled = false
	

func create_ground():
	await get_tree().process_frame

	# 生成新的物理场面板
	var ground_panel_fold = get_tree().root.get_node(
		GlobalData.editor_node_path + 
		"/HBoxContainer/RightSplit/TabContainer/ScenePack/SceneScroll/ObjContainer/Ground/VBoxContainer")
	# 此处不明原因出错，用另一种方式替代。第二次尝试又好了，不知道为什么？？？
	var new_ground_panel = null
	new_ground_panel = GlobalData.ground_panel.instantiate()
	# 动态加载场景，不依赖GlobalData存储PackedScene
	# var scene = load("res://Scenes/Grounds/GroundPanel.tscn")
	# var new_ground_panel = scene.instantiate()
	assign_value_to_ground(new_ground_panel)
	# 延迟添加子节点
	ground_panel_fold.call_deferred("add_child", new_ground_panel)
	# 延迟置顶，必须等add_child执行完才会生效
	ground_panel_fold.call_deferred("move_child", new_ground_panel, 0)
	new_ground_panel.call_deferred("info_refreshed")

	# 生成物理场
	var new_ground_area = null
	var ground_area_fold = get_tree().root.get_node(
		GlobalData.root3d_node_path + "/AllGrounds")
	
	new_ground_area = GlobalData.ground.instantiate()
	# 传输数据
	new_ground_area.info = new_ground_panel.info.duplicate(true)
	ground_area_fold.add_child(new_ground_area)
	new_ground_panel.ground = new_ground_area
		
	# 关闭当前 Window
	# queue_free()
	close_window()


# 赋值给新生成的场
func assign_value_to_ground(ground):
	print("新建物理场id_code：", str(id_code).pad_zeros(6))
	# 赋值场的信息
	info["enabled"] = enabled_btn.button_pressed
	info["name"] = name_edit.text
	info["type"] = type_option_btn.selected
	var rot_vec = Vector3(float(rot_x.text), float(rot_y.text), float(rot_z.text))
	info["rotation"] = [rot_vec.x, rot_vec.y, rot_vec.z]
	var pos_vec = Vector3(float(pos_x.text), float(pos_y.text), float(pos_z.text))
	info["position"] = [pos_vec.x, pos_vec.y, pos_vec.z]
	var size_vec = Vector3(float(size_x.text), float(size_y.text), float(size_z.text))
	info["size"] = [size_vec.x, size_vec.y, size_vec.z]
	# 存入coll_color时处理
	var col = color_select.color
	info["coll_color"] = [col.r, col.g, col.b, col.a]
	info["description"] = description_text.text

	ground.id_code = id_code
	ground.info = info
	# id_code全集添加新编号
	GlobalData.run_project_data["id_code"].append(id_code)
	GlobalData.add_ground_dict(ground.id_code, ground.info)
	# print(ground.id_code)


func close_window():
	# 关闭当前 Window
	# queue_free()
	info = GlobalData.init_ground_info.duplicate(true)
	# GlobalTools.print_dict(info)
	reset_value_for_window()
	WindowsManager.close_window(self.name)

func reset_value_for_window():
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

# 返回选择项的 id
func _on_option_selected(index: int):
	var id = type_option_btn.get_item_id(index)
	GlobalData.ground = GlobalData.select_ground_type(id)
	print("选择类型：", type_option_btn.get_item_text(index))

