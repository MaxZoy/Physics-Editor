extends Window

# 研究对象的基本属性
var id_code: int = 000000
var info: Dictionary = {
	"enabled": true, # 是否立刻启用
	"name": "", # 名称
	"mark": "", # 标记
	"type": 0, # 类型
	"position": [0.0, 0.0, 0.0], # 位置
	"vel_value": 0.0, # 初速度大小
	"vel_dir": [1.0, 0.0, 0.0], # 初速度方向
	"description": "", # 描述
	"property": {}
}


# 获取窗口中的重要组件
@onready var enabled_btn: CheckButton = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/IDCodeBox/CheckButton
@onready var name_edit: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/ObjLabel/NameBox/LineEdit
@onready var label_edit: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/ObjLabel/NameBox/Mark/LineEdit
@onready var id_code_text: Label = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/IDCodeBox/Code
@onready var type_option_btn: OptionButton = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/ObjLabel/TypeBox/OptionButton
@onready var pos_x: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/PositionBox/xBox/LineEdit
@onready var pos_y: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/PositionBox/yBox/LineEdit
@onready var pos_z: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/PositionBox/zBox/LineEdit
@onready var vel_value_edit: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/VelocityBox/VBoxContainer/VelValueBox/LineEdit
@onready var vel_x: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/VelocityBox/VBoxContainer/VelDirectionBox/xBox/LineEdit
@onready var vel_y: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/VelocityBox/VBoxContainer/VelDirectionBox/yBox/LineEdit
@onready var vel_z: LineEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/VelocityBox/VBoxContainer/VelDirectionBox/zBox/LineEdit
@onready var property_fold: FoldableContainer = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/Property
# 其他
@onready var description_text: TextEdit = $Panel/VBoxContainer/ScrollContainer/VBoxContainer/Description/TextEdit
@onready var yes_btn: Button = $Panel/VBoxContainer/ConfirmBox/Yes
@onready var no_btn: Button = $Panel/VBoxContainer/ConfirmBox/No

# fold_container 下的子节点
var new_property = null


func _ready() -> void:
	type_option_btn.item_selected.connect(_on_option_selected)
	yes_btn.disabled = true
	# 连接按钮的 pressed 信号
	yes_btn.pressed.connect(create_object)
	no_btn.pressed.connect(close_window)
	reset_value_for_window()


func _process(delta: float) -> void:
	# 如果没有输入名称，则“确定”按钮不可用
	if name_edit.text == "":
		yes_btn.disabled = true
	else:
		yes_btn.disabled = false

func create_object():
	await get_tree().process_frame

	# print("按下新建按钮，生成研究对象面板")
	# 生成新的研究对象面板
	var object_panel_fold = get_tree().root.get_node(
		GlobalData.editor_node_path + 
		"/HBoxContainer/RightSplit/TabContainer/ScenePack/SceneScroll/ObjContainer/Object/VBoxContainer")
	# 动态加载场景，不依赖GlobalData存储PackedScene
	# var scene = load("res://Scenes/Objects/ObjPanel.tscn")
	# var new_object_panel = scene.instantiate()
	var new_object_panel = null
	new_object_panel = GlobalData.object_panel.instantiate()
	assign_value_to_object(new_object_panel)
	# 延迟添加子节点
	object_panel_fold.call_deferred("add_child", new_object_panel)
	# 延迟置顶，必须等add_child执行完才会生效
	object_panel_fold.call_deferred("move_child", new_object_panel, 0)
	new_object_panel.call_deferred("info_refreshed")

	# 生成研究对象
	var new_object = null
	var object_area_fold = get_tree().root.get_node(
		GlobalData.root3d_node_path + "/AllObjects")

	new_object = GlobalData.object.instantiate()
	# 传输数据
	new_object.info = new_object_panel.info.duplicate(true)
	object_area_fold.add_child(new_object)
	new_object_panel.object = new_object


	# 关闭当前 Window
	close_window()

# 赋值给新生成的研究对象
func assign_value_to_object(object):
	# print("新建研究对象id_code：", str(id_code).pad_zeros(6))
	# 赋值研究对象的信息
	info["enabled"] = enabled_btn.button_pressed
	info["name"] = name_edit.text
	info["mark"] = label_edit.text
	info["type"] = type_option_btn.get_item_id(type_option_btn.selected)
	var pos_vec = Vector3(pos_x.text.to_float(), pos_y.text.to_float(), pos_z.text.to_float())
	info["position"] = [pos_vec.x, pos_vec.y, pos_vec.z]
	info["vel_value"] = vel_value_edit.text.to_float()
	var vel_vec = Vector3(vel_x.text.to_float(), vel_y.text.to_float(), vel_z.text.to_float())
	info["vel_dir"] = [vel_vec.x, vel_vec.y, vel_vec.z]
	info["description"] = description_text.text
	# 赋值特有属性
	assign_property_to_object()
	object.id_code = id_code
	object.info = info
	# id_code全集添加新编号
	GlobalData.run_project_data["id_code"].append(id_code)
	GlobalData.add_object_dict(object.id_code, object.info)

# 赋值研究对象属性
func assign_property_to_object():
	var type = type_option_btn.selected
	match  type:
		0:
			# 复制基础模板
			info["property"] = GlobalData.init_obj_particle_info.duplicate(true)
			
			# 质量与指数
			info["property"]["mass"] = new_property.mass_value.text.to_float()
			info["property"]["mass_e"] = new_property.mass_e.value
		1:
			# 复制基础模板
			info["property"] = GlobalData.init_obj_block_info.duplicate(true)
			
			# 是否作为粒子
			info["property"]["as_particle"] = new_property.as_particle_btn.button_pressed
			
			# 质量与指数
			info["property"]["mass"] = new_property.mass_value.text.to_float()
			info["property"]["mass_e"] = new_property.mass_e.value
			
			# 三维缩放数组 [x,y,z]
			var scale_x = new_property.x_line_edit.text.to_float()
			var scale_y = new_property.y_line_edit.text.to_float()
			var scale_z = new_property.z_line_edit.text.to_float()
			info["property"]["scale"] = [scale_x, scale_y, scale_z]
			
			# 形状枚举索引
			info["property"]["shape"] = new_property.shape_btn.selected
			
			# RGBA 颜色数组 [r,g,b,a]
			var pick_color = new_property.color_select.color
			info["property"]["color"] = [pick_color.r, pick_color.g, pick_color.b, pick_color.a]
		2:
			# 复制基础模板
			info["property"] = GlobalData.init_obj_charged_particle_info.duplicate(true)
			
			# 质量与指数
			info["property"]["mass"] = new_property.mass_value.text.to_float()
			info["property"]["mass_e"] = new_property.mass_e.value
			
			# 是否作为带电粒子
			info["property"]["as_charge_point"] = new_property.as_charge_point.button_pressed
			
			# 带电种类
			info["property"]["charge_type"] = new_property.charge_type.selected
			
			# 电荷量与指数
			info["property"]["charge"] = int(new_property.charge_value.text)
			info["property"]["charge_e"] = int(new_property.charge_e.value)


func close_window():
	# 关闭当前 Window
	# queue_free()
	info = GlobalData.init_object_info.duplicate(true)
	new_property = null
	reset_value_for_window()
	WindowsManager.close_window(self.name)

func reset_value_for_window():
	# 将info数据赋值给窗口UI组件
	enabled_btn.button_pressed = info["enabled"]
	name_edit.text = info["name"]
	label_edit.text = info["mark"]
	type_option_btn.selected = info["type"]
	# position三维数组赋值
	var pos_arr = info["position"]
	pos_x.text = str(pos_arr[0])
	pos_y.text = str(pos_arr[1])
	pos_z.text = str(pos_arr[2])

	description_text.text = info["description"]

# 返回选择项的 id
func _on_option_selected(index: int):
	var id = type_option_btn.get_item_id(index)
	var obj_arr = GlobalData.select_obj_type(id)
	GlobalData.object = obj_arr[0]
	GlobalData.obj_property = obj_arr[1]
	refresh_property()
	print("选择类型：", type_option_btn.get_item_text(index))

# 每次 type_option_btn 选择新项都会刷新一次
func refresh_property():
	for child in property_fold.get_children():
		child.queue_free()
	new_property = GlobalData.obj_property.instantiate()
	property_fold.add_child(new_property)

