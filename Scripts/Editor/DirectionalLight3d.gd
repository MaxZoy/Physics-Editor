extends DirectionalLight3D

func _ready():
	# 单场景唯一性检查
	if (get_tree().current_scene.name == "Editor3D" or 
		get_tree().current_scene.name == "MainUI"):
		if get_parent().name == "Root3d_test":
			self.queue_free()
			return


