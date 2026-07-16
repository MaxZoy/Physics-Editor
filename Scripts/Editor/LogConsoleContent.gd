extends RichTextLabel

# 继承自 Logger 类
class CustomLogger extends Logger:
	var log_label: RichTextLabel

	func _log_message(msg: String, is_error: bool):
		# 先校验节点是否存活，已销毁则直接跳过
		if not is_instance_valid(log_label):
			return
		# 必须用 call_deferred 安全更新 UI（解决线程安全问题）
		log_label.call_deferred("_append_system_log", msg, is_error)

func _ready():
	text = ""
	bbcode_enabled = true  # 必须开启 BBCode 才能显示颜色
	
	ready_info()
	
	var logger = CustomLogger.new()
	logger.log_label = self
	OS.add_logger(logger)
	

func _process(delta: float) -> void:
	if GlobalData.can_clear_console_content:
		_clear_log()
		GlobalData.can_clear_console_content = false
	

func ready_info():
	var info = (ProjectSettings.get_setting("application/config/name") + "  " + 
				ProjectSettings.get_setting("application/config/version"))
	append_text("[color=%s]%s[/color]\n" % ["gray", info])
	

# 专门用来更新 UI 的函数（主线程安全）
func _append_system_log(msg: String, is_error: bool):
	var stamp = Time.get_time_string_from_system() + " "
	var color = Color(1.0, 1.0, 1.0, 1.0)
	if is_error:
		color = Color(1.0, 0.196, 0.196, 1.0)
	
	var full_log = stamp + "[color=%s]%s[/color]" % [color.to_html(true), msg]
	append_text(full_log)
	# 自动滚动到底部
	scroll_to_line(get_line_count() - 1)

# 外部物体调用：传入消息、自定义颜色、可选物体标识标签
func log_custom(msg: String, color: Color, tag: String = ""):
	call_deferred("_append_custom_log", msg, color, tag)

# 内部主线程执行UI渲染，线程安全
func _append_custom_log(msg: String, color: Color, tag: String):
	var hex_color = color.to_html(true)
	var line_content = Time.get_time_string_from_system() + " "
	
	# 带标签则先输出彩色标识
	if tag != "":
		line_content += "[color=%s][%s][/color] " % [hex_color, tag]
	
	# 输出彩色消息内容
	line_content += "[color=%s]%s[/color]\n" % [hex_color, msg]
	
	append_text(line_content)
	scroll_to_line(get_line_count() - 1)

func _clear_log():
	text = ""
	ready_info()
