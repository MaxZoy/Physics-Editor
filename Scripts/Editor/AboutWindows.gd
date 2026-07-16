extends Window

@onready var version_label: Label = $Panel/VBoxContainer/VBoxContainer/Version

func _ready():
	version_label.text = "版本：" + ProjectSettings.get_setting("application/config/version")