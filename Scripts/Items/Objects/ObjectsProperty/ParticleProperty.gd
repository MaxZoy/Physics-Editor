extends VBoxContainer

# 研究对象的特有性质
var property: Dictionary = {
	"mass": 1.0, # 质量大小
	"mass_e": 0  # 质量大小的指数
}

@onready var mass_value: LineEdit = $Mass/Value/MassValue/LineEdit
@onready var mass_e: SpinBox = $Mass/Value/MassValue/Index

