# FieldArea3d.gd
extends Area3D

# 物理场的基本信息
var id_code: int
@export var info: Dictionary = {
	"enabled": true, # 是否立刻启用
	"name": "g1", # 名称
	"type": 2, # 类型
	"value": 10.0, # 数值
	"direction": [0.0, -1.0, 0.0], # 方向
	"can_extense": false,
	"extense_mode": "a", # 默认全伸展
	"position": [0.0, 0.0, 0.0], # 位置
	"size": [5.0, 5.0, 5.0], # 尺寸
	"is_show_coll": true, # 是否显示碰撞区域
	"coll_color": [120.0, 90.0, 255.0, 32.0], # 碰撞区域颜色
	"description": "" # 描述
}

# 碰撞范围
@onready var coll: CollisionShape3D = $CollisionShape3D
# 碰撞范围的模型
@onready var shape: MeshInstance3D = $FieldShape3D

func _ready() -> void:
	# print(info)
	FieldManager.initialize(self)
	pass

# 修改完属性后刷新
func refresh_field():
	# 修改 run_project_data 的数据
	GlobalData.run_project_data["fields"][str(id_code).pad_zeros(6)] = info.duplicate(true)
	GlobalData.info_to_change_field(self, info)
	FieldManager.force_rebuild()   # 直接重建，不重新初始化

func get_field_info() -> Dictionary:
	return info
