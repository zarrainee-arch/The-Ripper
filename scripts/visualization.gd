extends Node2D


var npc


func _ready():
	npc = get_parent().get_node("NPC")
	queue_redraw()


func _process(_delta):
	queue_redraw()


func _draw():
	if npc == null:
		return

	# =========================
	# Expanded Nodes
	# =========================

	for cell in npc.last_expanded_nodes:
		var position = Vector2(
			cell.x * 40,
			cell.y * 40
		)

		draw_rect(
			Rect2(
				position + Vector2(5, 5),
				Vector2(30, 30)
			),
			Color(1.0, 0.9, 0.2, 0.35)
		)


	# =========================
	# Final Path
	# =========================

	for cell in npc.current_path:
		var position = Vector2(
			cell.x * 40,
			cell.y * 40
		)

		draw_rect(
			Rect2(
				position + Vector2(12, 12),
				Vector2(16, 16)
			),
			Color(0.2, 1.0, 0.3, 0.8)
		)
