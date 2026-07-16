extends PanelContainer

@onready var axisshow_btn = $HBoxContainer/LeftContainer/AxisShow

@onready var time_select = $HBoxContainer/RightContainer/TimeSelect
@onready var launch_btn = $HBoxContainer/RightContainer/Launch
@onready var pause_btn = $HBoxContainer/RightContainer/Pause
@onready var stop_btn = $HBoxContainer/RightContainer/Stop

@onready var subviewport_obj: SubViewport = $"../RunPanel/RunWindow/SimulationViewport"
@onready var axis_grid = $"../RunPanel/RunWindow/SimulationViewport/AxisGrid3D"

# 模拟场景根节点
var sim_root: Node3D = null

func _ready() -> void:
	axisshow_btn.toggle_mode = true
	
	launch_btn.toggle_mode = true
	pause_btn.disabled = false
	pause_btn.toggle_mode = true
	stop_btn.disabled = true
	stop_btn.toggle_mode = false

	# 绑定按钮信号
	axisshow_btn.pressed.connect(_on_axis_show_pressed)
	
	time_select.item_selected.connect(select_time_ctrl)
	launch_btn.pressed.connect(_on_start_sim)
	pause_btn.pressed.connect(_on_pause_sim)
	stop_btn.pressed.connect(_on_stop_reset_sim)
	
	print("编辑器加载成功")
	
	# 实例化新场景
	sim_root = GlobalData.SIMULATION_SCENE.instantiate()
	subviewport_obj.add_child(sim_root)


func _process(delta: float) -> void:
	
	# 当按下启动按钮时，停止按钮被激活
	stop_btn.disabled = !launch_btn.button_pressed

# 加载/重置模拟场景（初始冻结）
func load_reset_simulation():
	# print("重置模拟场景")
	set_sim_paused(true)
	GlobalData.refresh_all_items_by_data(GlobalData.run_project_data)

	# 重置按钮状态
	launch_btn.button_pressed = false
	launch_btn.disabled = false
	pause_btn.button_pressed = false
	pause_btn.disabled = true
	stop_btn.disabled = true

# 暂停模拟
func set_sim_paused(paused: bool):
	if not sim_root:
		return
	# print("模拟是否暂停：", paused)
	GlobalData.is_paused = paused

# 开始模拟按钮
func _on_start_sim():
	
	if launch_btn.button_pressed:
		GlobalData.can_clear_console_content = true
		set_sim_paused(false)  # 启动物理
		# print("time_scale = ", Engine.time_scale)
		launch_btn.disabled = true
		pause_btn.disabled = false
		stop_btn.disabled = false

# 暂停模拟按钮
func _on_pause_sim():
	# get_tree().paused = true
	if pause_btn.button_pressed:
		set_sim_paused(true)
	else:
		set_sim_paused(false)

# 停止模拟按钮
func _on_stop_reset_sim():
	load_reset_simulation()  # 重新加载场景 + 自动冻结

# 选择模拟时间
func select_time_ctrl(sel: int):
	var id = time_select.get_item_id(sel)

	match id:
		0:
			Engine.time_scale = 0.1
		1:
			Engine.time_scale = 0.2
		2:
			Engine.time_scale = 0.3
		3:
			Engine.time_scale = 0.5
		4:
			Engine.time_scale = 0.75
		5:
			Engine.time_scale = 1.0
		6:
			Engine.time_scale = 1.25
		7:
			Engine.time_scale = 1.50
		8:
			Engine.time_scale = 1.75
		9:
			Engine.time_scale = 2.0


# 显示坐标轴按钮
func _on_axis_show_pressed() -> void:
	# 是否显示坐标系按钮
	if axis_grid.is_show_axis:
		print("隐藏坐标轴")
	if not axis_grid.is_show_axis:
		print("显示坐标轴")
	GlobalData.debug_is_show_axis = axisshow_btn.button_pressed


