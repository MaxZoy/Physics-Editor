extends Control

# # 引用右键菜单节点
# @onready var right_menu: PopupMenu = $RightClickMenu

# func _ready():
# 	# 连接菜单点击信号
# 	if right_menu != null:
# 		right_menu.hide_on_checkable_item_selection = true
# 		right_menu.id_pressed.connect(_on_menu_clicked)

# 	mouse_filter = MOUSE_FILTER_PASS


# # ========== 检测右键，弹出菜单 ==========
# func _gui_input(event: InputEvent) -> void:
# 	if event is InputEventMouseButton:
# 		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
# 			# 窗口客户区鼠标坐标，和Popup坐标系完全一致
# 			var mouse_pos = Vector2(DisplayServer.mouse_get_position())
# 			# 直接赋值，Popup的position本身就是视口坐标，无需换算
# 			right_menu.position = mouse_pos
# 			# 必须用无参popup()，才会严格按position定位
# 			right_menu.popup()

# # ========== 处理菜单项点击 ==========
# func _on_menu_clicked(item_id: int) -> void:
# 	right_menu.toggle_item_checked(right_menu.get_item_index(item_id))
	
# 	match item_id:
# 		0:
# 			print("菜单-新建物理场")
# 		1:
# 			print("菜单-新建研究对象")
# 		3:
# 			print("菜单-吸附网格")

