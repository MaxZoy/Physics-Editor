# BlueprintNode.gd
class_name BlueprintNode
extends Resource

@export var id: int = 0
@export var type_id: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var properties: Dictionary = {}

func get_input_ports() -> Array:
	var def = NodeDatabase.get_node_type(type_id)
	return def.get("inputs", [])

func get_output_ports() -> Array:
	var def = NodeDatabase.get_node_type(type_id)
	return def.get("outputs", [])

func get_exec_func() -> String:
	return NodeDatabase.get_node_type(type_id).get("exec_func", "")

func is_deletable() -> bool:
	return NodeDatabase.is_deletable(type_id)


func serialize() -> Dictionary:
	return {
		"id": id,
		"type": type_id,
		"position": [position.x, position.y],
		"properties": properties.duplicate(true)   # 深拷贝属性
	}

func deserialize(data: Dictionary) -> void:
	id = data["id"]
	type_id = data["type"]
	position = Vector2(data["position"][0], data["position"][1])
	properties = data.get("properties", {}).duplicate(true)


