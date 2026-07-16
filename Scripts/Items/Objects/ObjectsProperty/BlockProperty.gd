extends VBoxContainer

# 研究对象的特有性质
var property: Dictionary = {
	"as_particle": true,
	"mass": 1.0, # 质量大小
	"mass_e": 0,  # 质量大小的指数
	"scale": [1.0, 1.0, 1.0], # 缩放
	"shape": 0, # 形状
	"color": [1.0, 1.0, 1.0, 1.0] # 填充颜色
}

@onready var as_particle_btn: CheckBox = $Mass/Mark/AsParticle/CheckButton
@onready var mass_value: LineEdit = $Mass/Value/MassValue/LineEdit
@onready var mass_e: SpinBox = $Mass/Value/MassValue/Index
@onready var x_line_edit: LineEdit = $ScaleBox/xBox/LineEdit
@onready var y_line_edit: LineEdit = $ScaleBox/yBox/LineEdit
@onready var z_line_edit: LineEdit = $ScaleBox/zBox/LineEdit
@onready var shape_btn: OptionButton = $ShowShape/Shape/ShapeTypes/OptionButton
@onready var color_select: ColorPickerButton = $ShowShape/ColorSelect/ColorPickerButton

