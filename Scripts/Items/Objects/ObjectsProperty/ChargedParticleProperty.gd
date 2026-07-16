extends VBoxContainer

# 研究对象的特有性质
var property: Dictionary = {
	"mass": 1.0, # 质量大小
	"mass_e": 0,  # 质量大小的指数
	"as_charge_point": true, # 是否视为点电荷
	"charge_type": 0, # 带电种类：0正电性 1负电性 2电中性
	"charge": 1, # 带电量大小
	"charge_e": 0, # 带电量大小的指数
	# "total_charge": 1.0, # 总电荷大小
	# "total_charge_e": 0, # 总电荷大小的指数
	# "net_charge": 1.0, # 净电荷大小
	# "net_charge_e": 0 # 净电荷大小的指数
}

@onready var mass_value: LineEdit = $Mass/Value/MassValue/LineEdit
@onready var mass_e: SpinBox = $Mass/Value/MassValue/Index
@onready var as_charge_point: CheckBox = $ChargePoint/ChargePointBtn/CheckBox
@onready var charge_type: OptionButton = $ChargePoint/ChargeTypes/OptionButton
@onready var charge_value: LineEdit = $Charge/Value/Value/LineEdit
@onready var charge_e: SpinBox = $Charge/Value/Value/Index
# @onready var total_charge_value : LineEdit = $Charge/TotalValue/Value/LineEdit
# @onready var total_charge_e : SpinBox = $Charge/TotalValue/Value/Index
# @onready var net_charge_value : LineEdit = $Charge/NetValue/Value/LineEdit
# @onready var net_charge_e : SpinBox = $Charge/NetValue/Value/Index

