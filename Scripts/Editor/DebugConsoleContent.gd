extends RichTextLabel

# 正确：继承自 Logger 类
class CustomLogger extends Logger:
	var log_label: RichTextLabel

	func _log_message(msg: String, is_error: bool):
		# 必须用 call_deferred 安全更新 UI（解决线程安全问题）
		log_label.call_deferred("_append_system_log", msg, is_error)

func _ready():
	self.get_window().min_size = Vector2i(256, 128)
	
	text = ""
	bbcode_enabled = true  # 必须开启 BBCode 才能显示颜色
	
	ready_info()
	
	var logger = CustomLogger.new()
	logger.log_label = self
	OS.add_logger(logger)
	

func ready_info():
	append_text("PE Debug Console\t")
	var info = ("ver:" + ProjectSettings.get_setting("application/config/version"))
	append_text("%s\n" % [info])
	

# 专门用来更新 UI 的函数（主线程安全）
func _append_system_log(msg: String, is_error: bool):
	append_text(Time.get_time_string_from_system() + " ")
	var color = Color(1.0, 1.0, 1.0, 1.0)
	if is_error:
		color = Color(1.0, 0.196, 0.196, 1.0)
	
	append_text("[color=%s]%s[/color]" % [color.to_html(true), msg])
	# 自动滚动到底部
	scroll_to_line(get_line_count() - 1)

