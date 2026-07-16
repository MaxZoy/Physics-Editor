extends ColorRect

# 把你要显示隐藏的按钮拖进来
@onready var target_panel: TextureRect = $Rotation_Btn
@onready var subviewport: SubViewport = $"../RunWindow/SimulationViewport"

func _ready():
	
	target_panel.visible = false
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)
	

func _mouse_entered():
	target_panel.visible = true

func _mouse_exited():
	# 如果鼠标在按钮上，就不隐藏
	if target_panel.get_global_rect().has_point(get_global_mouse_position()) or GlobalData.view_is_rotate:
		return
		
	target_panel.visible = false


func _show_left_tab_btn_pressed():
	target_panel.visible = false
