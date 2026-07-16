extends VBoxContainer

@onready var type_option_btn: OptionButton = $"../ObjLabel/TypeBox/OptionButton"
@onready var pos_x: LineEdit = $PositionBox/xBox/LineEdit
@onready var pos_y: LineEdit = $PositionBox/yBox/LineEdit
@onready var pos_z: LineEdit = $PositionBox/zBox/LineEdit
@onready var size_x: LineEdit = $SizeBox/xBox/LineEdit
@onready var size_y: LineEdit = $SizeBox/yBox/LineEdit
@onready var size_z: LineEdit = $SizeBox/zBox/LineEdit
@onready var dir_x: LineEdit = $RotationBox/xBox/LineEdit
@onready var dir_y: LineEdit = $RotationBox/yBox/LineEdit
@onready var dir_z: LineEdit = $RotationBox/zBox/LineEdit

func _process(delta: float) -> void:
	if type_option_btn.get_item_id(type_option_btn.selected) == 4:
		size_x.editable = false
		size_y.editable = false
		size_z.editable = false
	else:
		size_x.editable = true
		size_y.editable = true
		size_z.editable = true

