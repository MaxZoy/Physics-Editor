# BlueprintData.gd
class_name BlueprintData
extends Resource

var nodes: Dictionary = {}  # id -> BlueprintNode
var links: Dictionary = {}  # id -> BlueprintLink
var next_id: int = 0

func add_node(type_id: String, position: Vector2) -> BlueprintNode:
	var node = BlueprintNode.new()
	node.id = next_id
	next_id += 1  # 确保递增
	node.type_id = type_id
	node.position = position
	var def = NodeDatabase.get_node_type(type_id)
	if not def.is_empty():
		var default_props = def.get("properties", {})
		for key in default_props:
			node.properties[key] = default_props[key].get("default", null)
	nodes[node.id] = node
	return node

func add_link(from_id: int, from_port: int, to_id: int, to_port: int) -> BlueprintLink:
	var link = BlueprintLink.new()
	link.id = next_id
	link.from_node_id = from_id
	link.from_port = from_port
	link.to_node_id = to_id
	link.to_port = to_port
	links[link.id] = link
	next_id += 1
	return link

func remove_node(id: int):
	# 删除关联链接
	var to_delete = []
	for link_id in links:
		if links[link_id].from_node_id == id or links[link_id].to_node_id == id:
			to_delete.append(link_id)
	for lid in to_delete:
		links.erase(lid)
	nodes.erase(id)

func remove_link(id: int):
	links.erase(id)

func get_node(id: int) -> BlueprintNode:
	return nodes.get(id)

func get_links_from(node_id: int) -> Array:
	var result = []
	for link in links.values():
		if link.from_node_id == node_id:
			result.append(link)
	return result

# BlueprintData.gd

func serialize() -> Dictionary:
	var data = {}
	var nodes_data = {}
	for n in nodes:
		nodes_data[n] = nodes[n].serialize()
	var links_data = {}
	for l in links:
		links_data[l] = links[l].serialize()
	data["nodes"] = nodes_data
	data["links"] = links_data
	data["next_id"] = next_id
	return data

func deserialize(data: Dictionary):
	nodes.clear()
	links.clear()
	for n in data["nodes"]:
		var node = BlueprintNode.new()
		node.deserialize(data["nodes"][n])
		nodes[node.id] = node
	for l in data["links"]:
		var link = BlueprintLink.new()
		link.deserialize(data["links"][l])
		links[link.id] = link
	next_id = data.get("next_id", 0)


