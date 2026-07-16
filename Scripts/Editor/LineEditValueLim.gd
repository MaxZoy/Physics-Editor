extends LineEdit

# ---------- 导出变量 ----------
@export var limit_min: bool = false
@export var limit_max: bool = false
@export var min_value: float = -1.0
@export var max_value: float = 1.0
@export var decimal_places: int = 1		  # 退出时保留的小数位数（0 表示整数）

# 内部值
var value: float = 0.0

# 用于文本变化时回退的合法文本缓存
var _last_valid_text: String = ""

# 预编译正则：合法浮点数格式（允许前导正负号、数字、一个小数点）
var _float_regex: RegEx

# ---------- 初始化 ----------
func _ready():
	_float_regex = RegEx.new()
	_float_regex.compile("^[+-]?\\d*\\.?\\d*$")
	
	# 连接信号（注意顺序：text_changed 在内部处理时先触发，再连接其他）
	text_changed.connect(_on_text_changed)
	text_submitted.connect(_on_text_submitted)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	
	_swap_min_max_if_needed()
	
	# 初始值设定
	var init_val
	if text == "":
		init_val = 0.0
	else:
		init_val = text.to_float()
	if limit_min and limit_max:
		value = clamp(init_val, min_value, max_value)
	elif limit_min:
		value = max(init_val, min_value)
	elif limit_max:
		value = min(init_val, max_value)
	else:
		value = init_val
	# 首次显示按格式化输出
	text = _format_number(value)
	_last_valid_text = text

# 确保 min <= max
func _swap_min_max_if_needed():
	if limit_min and limit_max and min_value > max_value:
		var tmp = min_value
		min_value = max_value
		max_value = tmp

# ---------- 格式化工具 ----------
func _format_number(num: float) -> String:
	if decimal_places == 0:
		return str(int(round(num)))  # 强制转为 int 再转 str
	else:
		var fmt = "%." + str(decimal_places) + "f"
		return fmt % num

# ---------- 焦点事件 ----------
# 进入编辑：若值为0则清空，否则化简显示（如 1.00 → 1）
func _on_focus_entered():
	var num = text.to_float()
	if is_zero_approx(num):
		text = ""
		caret_column = 0
		_last_valid_text = ""
	else:
		# 化简为最简形式（去掉末尾零和小数点）
		var simplified = _simplify_float(num)   # Godot 自动化简浮点字符串
		text = simplified
		_last_valid_text = simplified
		# 光标置于末尾
		caret_column = text.length()

# 失去焦点（点击外部或 Tab）时提交校验
func _on_focus_exited():
	# print(">> _on_focus_exited")
	_apply_and_validate()
	# print(">> after _apply_and_validate, text = '", text, "'")

# 回车提交
func _on_text_submitted(_new_text: String):
	_apply_and_validate()
	release_focus()
	get_viewport().set_input_as_handled()

# ---------- 文本变化校验（核心过滤） ----------
# 每次文本变化后检查合法性，若不合法则回退到上次合法文本
func _on_text_changed(new_text: String):
	# print(">> _on_text_changed: new_text = '", new_text, "', current text = '", text, "'")
	# 空字符串总是合法的（允许用户清空）
	if new_text == "":
		_last_valid_text = ""
		value = 0.0
		return
	
	# 检查是否符合浮点数格式
	if _float_regex.search(new_text) == null:
		# 非法输入，回退到上次合法文本
		text = _last_valid_text
		# 将光标置于末尾（因为回退后文本变了）
		caret_column = text.length()
		# 阻止信号递归
		return
	
	# 合法文本，更新缓存和内部值
	_last_valid_text = new_text
	# 更新 value（用于其他逻辑）
	value = new_text.to_float()

# ---------- 核心提交与校验 ----------
func _apply_and_validate():
	# print("=== _apply_and_validate START ===")
	# print("  current text: '", text, "'")
	# 1. 去除前导正号（用户要求退出时自动省略）
	var raw = text
	if raw.begins_with("+"):
		raw = raw.substr(1)
	
	# 2. 处理空文本或仅符号的情况
	if raw == "" or raw == "-" or raw == "." or raw == "-.":
		raw = "0"
	
	# 3. 转换为浮点数
	var num = raw.to_float()
	if is_nan(num):
		num = 0.0
	
	# 4. 修正 min/max 顺序
	_swap_min_max_if_needed()
	
	# 5. 应用范围限制
	if limit_min and limit_max:
		value = clamp(num, min_value, max_value)
	elif limit_min:
		value = max(num, min_value)
	elif limit_max:
		value = min(num, max_value)
	else:
		value = num
	
	# 6. 按小数位格式化显示
	text = _format_number(value)
	# print("  after _format_number: text = '", text, "'")
	_last_valid_text = text
	# print("=== _apply_and_validate END ===")

# ---------- 鼠标点击外部释放焦点 ----------
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and is_editing():
		var rect = get_global_rect()
		var mouse_global = get_global_mouse_position()
		if not rect.has_point(mouse_global):
			release_focus()
			get_viewport().set_input_as_handled()

func _simplify_float(num: float) -> String:
	var s = str(num)
	# 如果包含小数点，则逐步去掉末尾的 '0'
	if "." in s:
		while s.ends_with("0"):
			s = s.substr(0, s.length() - 1)
		# 若末尾只剩小数点，也去掉
		if s.ends_with("."):
			s = s.substr(0, s.length() - 1)
	return s

