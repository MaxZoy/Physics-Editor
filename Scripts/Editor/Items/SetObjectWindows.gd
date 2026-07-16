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
@onready var del_btn: Button = $Panel/VBoxContainer/ConfirmBox/Delete

# 对应修改数据面板
var set_object_panel: PanelContainer = null
var set_object = null
# fold_container 下的子节点
var new_property = null

func _ready() -> void:
	reset_value_for_window(GlobalData.init_object_info)
	yes_btn.disabled = true
	# 连接按钮的 pressed 信号
	yes_btn.pressed.connect(reset_object)
	no_btn.pressed.connect(close_window)
	del_btn.pressed.connect(open_delete_window)

func _process(delta: float) -> void:
	# 如果没有输入名称，则“确定”按钮不可用
	if name_edit.text == "":
		yes_btn.disabled = true
	else:
		yes_btn.disabled = false
	

# 设置窗口确认键按下后 将新的值赋值给物理场
func reset_object():
	# 新的赋值
	info["enabled"] = enabled_btn.button_pressed
	info["name"] = name_edit.text
	info["mark"] = label_edit.text
	info["type"] = type_option_btn.selected
	var pos_vec = Vector3(pos_x.text.to_float(), pos_y.text.to_float(), pos_z.text.to_float())
	info["position"] = [pos_vec.x, pos_vec.y, pos_vec.z]
	info["vel_value"] = vel_value_edit.text.to_float()
	var vel_vec = Vector3(vel_x.text.to_float(), vel_y.text.to_float(), vel_z.text.to_float())
	info["vel_dir"] = [vel_vec.x, vel_vec.y, vel_vec.z]
	info["description"] = description_text.text
	assign_property_to_object()
	# print(info["mark"])
	# 传输数据
	if set_object_panel != null:
		set_object_panel.info = info
		set_object_panel.info_refreshed()
		pass
	else:
		printerr("尝试修改数据失败")
	
	# 修改 run_project_data 的数据
	GlobalData.run_project_data["objects"][str(id_code).pad_zeros(6)] = info.duplicate(true)
	# GlobalTools.print_dict((info))
	# 关闭当前 Window
	# queue_free()
	close_window()

func close_window():
	# 关闭当前 Window
	# queue_free()
	info = GlobalData.init_object_info.duplicate(true)
	new_property = null
	reset_value_for_window(GlobalData.init_object_info)
	WindowsManager.close_window(self.name)

func reset_value_for_window(object_info):
	info = object_info.duplicate(true)
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
	# velocity赋值
	vel_value_edit.text = str(info["vel_value"])
	var vel_arr = info["vel_dir"]
	vel_x.text = str(vel_arr[0])
	vel_y.text = str(vel_arr[1])
	vel_z.text = str(vel_arr[2])
	# 描述
	description_text.text = info["description"]
	reset_property_to_object()

# 赋值研究对象属性（反向赋值：从info["property"]读取数据填入UI组件new_property）
func reset_property_to_object():
	var type = type_option_btn.selected

	if new_property == null:
		refresh_property()
	if info["property"] == {}:
		refresh_info()
	
	match  type:
		0:
			new_property.mass_value.text = str(info["property"]["mass"])
			new_property.mass_e.value = info["property"]["mass_e"]
		1:
			# 是否作为粒子
			new_property.as_particle_btn.button_pressed = info["property"]["as_particle"]
			
			# 质量
			new_property.mass_value.text = str(info["property"]["mass"])
			# 质量指数
			new_property.mass_e.value = info["property"]["mass_e"]
			
			# 三维缩放数组 [x,y,z]
			var scale_arr = info["property"]["scale"]
			new_property.x_line_edit.text = str(scale_arr[0])
			new_property.y_line_edit.text = str(scale_arr[1])
			new_property.z_line_edit.text = str(scale_arr[2])
			
			# 形状枚举索引
			new_property.shape_btn.selected = info["property"]["shape"]
			
			# RGBA颜色处理：原存储为0~255整数 → 转0~1浮点，用clamp规避精度溢出误差
			var color_r = clamp(info["property"]["color"][0], 0.0, 1.0)
			var color_g = clamp(info["property"]["color"][1], 0.0, 1.0)
			var color_b = clamp(info["property"]["color"][2], 0.0, 1.0)
			var color_a = clamp(info["property"]["color"][3], 0.0, 1.0)
			new_property.color_select.color = Color(color_r, color_g, color_b, color_a)
		2:
			# 质量与指数
			new_property.mass_value.text = str(info["property"]["mass"])
			new_property.mass_e.value = info["property"]["mass_e"]
			
			# 是否作为带电粒子
			new_property.as_charge_point.button_pressed = info["property"]["as_charge_point"]
			
			# 带电种类
			new_property.charge_type.selected = info["property"]["charge_type"]
			
			# 电荷量与指数
			new_property.charge_value.text = str(info["property"]["charge"])
			new_property.charge_e.value = info["property"]["charge_e"]

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


func open_delete_window():
	WindowsManager.open_window("DeleteWindows")
	var win = WindowsManager.get_window_by_name("DeleteWindows")
	win.refresh_name_label(info["name"])
	win.del_id_code = id_code
	win.del_item_panel = set_object_panel
	win.del_item_obj = set_object
	win.parent_window = self


# 每次打开窗口 type_option_btn 都会刷新一次
func refresh_property():
	for child in property_fold.get_children():
		child.queue_free()
	if GlobalData.obj_property == null:
		GlobalData.obj_property = GlobalData.select_obj_type(type_option_btn.selected)[1]
	new_property = GlobalData.obj_property.instantiate()
	property_fold.add_child(new_property)
	property_fold.folded = true

func refresh_info():
	match type_option_btn.selected:
		0:
			info["property"] = GlobalData.init_obj_particle_info.duplicate(true)
		1:
			info["property"] = GlobalData.init_obj_block_info.duplicate(true)

