extends StaticBody2D


func _ready():
	# Pastikan Obstacle benar-benar menjadi collider solid
	collision_layer = 1
	collision_mask = 0

	print("========== OBSTACLE CHECK ==========")
	print("Obstacle type: ", get_class())
	print("Collision Layer: ", collision_layer)
	print("Jumlah CollisionPolygon2D: ", get_child_count())

	for child in get_children():
		if child is CollisionPolygon2D:
			child.disabled = false
			child.one_way_collision = false
			child.build_mode = CollisionPolygon2D.BUILD_SOLIDS

			print(
				child.name,
				" | points = ",
				child.polygon.size(),
				" | disabled = ",
				child.disabled,
				" | build_mode = SOLIDS"
			)

	print("====================================")