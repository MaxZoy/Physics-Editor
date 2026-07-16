extends PanelContainer

# 物理场的基本属性
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

@onready var id_code_label: Label = $HBoxContainer/SplitContainer/Info/ID_code
@onready var name_label: Label = $HBoxContainer/SplitContainer/Info/Name
@onready var x_line_edit: LineEdit = $HBoxContainer/SplitContainer/VBoxContainer/PositionBox/xBox/LineEdit
@onready var y_line_edit: LineEdit = $HBoxContainer/SplitContainer/VBoxContainer/PositionBox/yBox/LineEdit
@onready var z_line_edit: LineEdit = $HBoxContainer/SplitContainer/VBoxContainer/PositionBox/zBox/LineEdit
@onready var setting_btn: TextureButton = $HBoxContainer/VBoxContainer/SettingButton
# 引用右键菜单节点
@onready var right_menu: PopupMenu = $SceneClickMenu
# 所对应的研究对象
var ground = null
# 更新标志
var _is_updating: bool = false


func _ready() -> void:
	id_code_label.text = "*" + str(id_code).pad_zeros(6)
	name_label.text = info["name"]
	x_line_edit.text = str(info["position"][0])
	y_line_edit.text = str(info["position"][1])
	z_line_edit.text = str(info["position"][2])

	setting_btn.pressed.connect(create_window)
	# 三个方向输入框：提交（回车/失焦）时同步
	x_line_edit.text_submitted.connect(_on_pos_submitted)
	y_line_edit.text_submitted.connect(_on_pos_submitted)
	z_line_edit.text_submitted.connect(_on_pos_submitted)

	set_popup_menu()

func create_window():
	# 打开设置窗口
	WindowsManager.open_window("SetGround")
	var win = WindowsManager.get_window_by_name("SetGround")
	# 先赋值基础数据
	win.id_code = id_code
	win.id_code_text.text = "*" + str(win.id_code).pad_zeros(6)
	win.info = info.duplicate(true) # 深度拷贝，避免外部字典被窗口篡改
	win.type_option_btn.selected = info["type"]
	win.set_ground_panel = self
	win.set_ground = ground
	
	# 根据当前实体类型获取属性模板，同步到全局
	GlobalData.ground = GlobalData.select_ground_type(info["type"])
	# print(GlobalData.obj_property)

	# 统一刷新UI面板+回显数据
	win.reset_value_for_window(win.info)



# 位置输入框提交回调
func _on_pos_submitted(_new_text: String):
	if _is_updating:
		return  # 如果是程序化更新，跳过
	info_changed()

# 当数据被修改后，对应面板的 text 也要被修改
func info_refreshed():
	_is_updating = true  # 开始更新，禁止信号触发
	
	name_label.text = info["name"]
	x_line_edit.text = str(info["position"][0])
	y_line_edit.text = str(info["position"][1])
	z_line_edit.text = str(info["position"][2])
	self.tooltip_text = info["description"]
	# 刷新物理场区域
	# print(ground.id_code)
	ground.id_code = id_code
	ground.info = info
	ground.refresh_ground()
	_is_updating = false  # 更新完成，恢复信号响应


# 当面板的数据被修改后，自身的 info 也要修改
func info_changed():
	# 防止在 info_changed 执行期间再次触发
	if _is_updating:
		return
		
	_is_updating = true
	
	# 同步方向三个输入框的值到 direction 数组
	info["position"][0] = x_line_edit.text.to_float()
	info["position"][1] = y_line_edit.text.to_float()
	info["position"][2] = z_line_edit.text.to_float()

	GlobalData.info_to_change_ground(ground, info)
	GlobalData.run_project_data["grounds"][str(id_code).pad_zeros(6)] = info.duplicate(true)

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
			print("菜单-复制")
		1:
			print("菜单-粘贴")
		2:
			print("菜单-剪切")
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
	# print(ground.name, "运行数据：")
	GlobalTools.print_dict(info)

func open_delete_window():
	WindowsManager.open_window("DeleteWindows")
	var win = WindowsManager.get_window_by_name("DeleteWindows")
	win.refresh_name_label(info["name"])
	win.del_id_code = id_code
	win.del_item_panel = self
	win.del_item_obj = ground


func _make_custom_tooltip(for_text: String) -> Control:
	return TooltipBase.create_tooltip(for_text)


