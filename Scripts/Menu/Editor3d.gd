extends Control

@onready var sim_viewport: SubViewport = $HBoxContainer/RightSplit/PanelContainer/RunContainer/RunPanel/RunWindow/SimulationViewport

func _ready():
	GlobalData.editor_node_path = self.get_path()
	# sim_viewport.world_2d = World2D.new()
	sim_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	GlobalData.is_paused = true
	# get_tree().paused = true


func _process(delta: float) -> void:
	# print("time_scale = ", Engine.time_scale)
	# get_tree().paused = GlobalData.is_paused
	pass

