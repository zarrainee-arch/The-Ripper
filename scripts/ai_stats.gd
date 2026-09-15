extends Label


var npc


func _ready():
	npc = get_parent().get_parent().get_node("NPC")


func _process(_delta):
	if npc == null:
		return

	text = "Algorithm: UCS\n"
	text += "Path Cost: " + str(max(0, npc.get("current_path").size() - 1)) + "\n"
	text += "Expanded Nodes: " + str(npc.get("last_expanded_nodes").size())
