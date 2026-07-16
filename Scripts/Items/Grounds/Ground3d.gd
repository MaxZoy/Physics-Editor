extends StaticBody3D

var id_code: int
var info: Dictionary = {
	"enabled": true, # 是否立刻启用
	"name": "", # 名称
	"type": 0, # 类型
	"rotation": [0.0, 0.0, 0.0], # 方向
	"position": [0.0, 0.0, 0.0], # 位置
	"size": [1.0, 1.0, 1.0], # 尺寸
	"coll_color": [1.0, 1.0, 1.0, 1.0], # 碰撞区域颜色
	"description": "" # 描述
}

@onready var coll = $CollisionShape3D
@onready var mesh = $GroundShape3D


# 修改完属性后刷新
func refresh_ground():
	# 修改 run_project_data 的数据
	GlobalData.run_project_data["grounds"][str(id_code).pad_zeros(6)] = info.duplicate(true)
	GlobalData.info_to_change_ground(self, info)