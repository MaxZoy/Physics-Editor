# BlueprintLink.gd
class_name BlueprintLink
extends Resource

@export var id: int = 0
@export var from_node_id: int = 0
@export var from_port: int = 0
@export var to_node_id: int = 0
@export var to_port: int = 0

func serialize() -> Dictionary:
    return {
        "id": id,
        "from": from_node_id,
        "from_port": from_port,
        "to": to_node_id,
        "to_port": to_port
    }

func deserialize(data: Dictionary) -> void:
    id = data["id"]
    from_node_id = data["from"]
    from_port = data["from_port"]
    to_node_id = data["to"]
    to_port = data["to_port"]

