extends ColorRect

# 把你要显示隐藏的按钮拖进来
@onready var target_button: TextureButton = $ShowLeftTab_Btn
@onready var right_split: HSplitContainer = $"../../../RightSplit"
var is_dragging: bool = false
@onready var right_TabContainer: TabContainer = $"../../TabContainer"
# @onready var btn_panel: Panel = $Panel

func _ready():
	# right_TabContainer.visible = false
	# 一开始隐藏按钮
	# btn_panel.visible = false
	target_button.visible = false
	target_button.button_pressed = !right_TabContainer.visible
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)
	right_split.drag_started.connect(_is_drag_start)
	right_split.drag_ended.connect(_is_drag_end)
	target_button.pressed.connect(_show_left_tab_btn_pressed)
	

func _mouse_entered():
	if not is_dragging:
		# btn_panel.visible = true
		target_button.visible = true

func _mouse_exited():
	# 如果鼠标在按钮上，就不隐藏
	if target_button.get_global_rect().has_point(get_global_mouse_position()):
		return
	# btn_panel.visible = false
	target_button.visible = false

func _is_drag_start():
	is_dragging = true
	
func _is_drag_end():
	is_dragging = false

func _show_left_tab_btn_pressed():
	right_TabContainer.visible = !target_button.button_pressed
	# btn_panel.visible = false
	target_button.visible = false
