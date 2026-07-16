# 主菜单栏按钮设置脚本
extends MenuButton

# 帮助菜单下"关于"选项的唯一ID标识
const ABOUT_MENU_ID = 1

# 当前菜单按钮节点名称，用于区分菜单类型
var current_name: String
# 关于窗口单例缓存，复用窗口实例，避免重复创建
var about_window: Window = null

func _ready():
	# 记录当前按钮节点名称，用于后续判断菜单归属
	current_name = name
	# 获取按钮内置下拉弹窗控件
	var popup: PopupMenu = get_popup()
	# 绑定弹窗条目点击信号，点击任意菜单条目触发回调
	popup.id_pressed.connect(_on_menu_item_clicked)

# 下拉菜单条目点击回调函数
# menu_id：被点击条目的唯一ID
func _on_menu_item_clicked(menu_id: int):
	# 判断当前是Help帮助菜单，且点击的是关于条目
	if current_name == "Help" && menu_id == ABOUT_MENU_ID:
		# 打开关于窗口
		open_about_window()

# 打开/唤醒关于窗口逻辑
func open_about_window():
	WindowsManager.open_window("AboutWindows")

