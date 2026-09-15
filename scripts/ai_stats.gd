extends Label


var npc


func _ready():
	npc = get_parent().get_parent().get_node("NPC")


func _process(_delta):
	if npc == null:
		return

	var algorithm = npc.get("last_algorithm")
	var heuristic = npc.get("last_heuristic")
	var path = npc.get("current_path")
	var expanded_nodes = npc.get("last_expanded_nodes")

	text = "Algorithm: " + str(algorithm) + "\n"

	if algorithm == "A*":
		text += "Heuristic: " + str(heuristic) + "\n"

	text += "Path Cost: " + str(max(0, path.size() - 1)) + "\n"
	text += "Expanded Nodes: " + str(expanded_nodes.size())
