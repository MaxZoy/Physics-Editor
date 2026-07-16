# tooltip_base.gd
class_name TooltipBase
extends Control  # 注意：这个类不直接使用，仅作为功能库

# 这是一个静态函数，可以在任何控件的 _make_custom_tooltip 中调用
static func create_tooltip(for_text: String) -> Label:
	var label = Label.new()
	label.text = for_text
	label.visible = true

	# 第一步：测量不换行时的文本宽度
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size.x = 10000
	var text_width = label.get_minimum_size().x

	const MAX_WIDTH = 300

	if text_width <= MAX_WIDTH:
		label.size.x = text_width
	else:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size.x = MAX_WIDTH

	return label

# 使用方法：每一个UI脚本下加入这段代码
# func _make_custom_tooltip(for_text: String) -> Control:
# 	return TooltipBase.create_tooltip(for_text)