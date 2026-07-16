extends VBoxContainer

# 此脚本用于控制UI控件是否启用
# 例：“新建物理场”设置启用“无限延伸”，那么场的尺寸则无法设置
var is_ex: bool
@onready var can_ex: CheckBox = $InfiniteExtension/CanExtenseBtn/CheckBox
@onready var ex_mode: OptionButton = $InfiniteExtension/ExtenseMode/OptionButton
@onready var p_x: LineEdit = $PositionBox/xBox/LineEdit
@onready var p_y: LineEdit = $PositionBox/yBox/LineEdit
@onready var p_z: LineEdit = $PositionBox/zBox/LineEdit
@onready var s_x: LineEdit = $SizeBox/xBox/LineEdit
@onready var s_y: LineEdit = $SizeBox/yBox/LineEdit
@onready var s_z: LineEdit = $SizeBox/zBox/LineEdit
@onready var coll_check: CheckBox = $ShowCollBox/ShowCollBtn/CheckBox
@onready var color_sel: ColorPickerButton = $ShowCollBox/ColorSelect/ColorPickerButton

func _process(delta: float) -> void:
	is_ex = can_ex.button_pressed
	color_sel.edit_intensity = false

	# 颜色拾取器的预设
	var col_pick = color_sel.get_picker()
	col_pick.picker_shape = ColorPicker.SHAPE_HSV_RECTANGLE
	col_pick.can_add_swatches = false
	col_pick.sampler_visible = false
	col_pick.color_modes_visible = false
	col_pick.presets_visible = false
	
	if is_ex:
		ex_mode.disabled = false
		p_x.editable = false
		p_y.editable = false
		p_z.editable = false
		s_x.editable = false
		s_y.editable = false
		s_z.editable = false
		# coll_check.disabled = true
		# color_sel.disabled = true
	else:
		ex_mode.disabled = true
		p_x.editable = true
		p_y.editable = true
		p_z.editable = true
		s_x.editable = true
		s_y.editable = true
		s_z.editable = true
		# coll_check.disabled = false
		# color_sel.disabled = false
