extends Node2D

const CELL_SIZE = 40
const GRID_WIDTH = 46
const GRID_HEIGHT = 18

func _ready():
	queue_redraw()

func is_inside_grid(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < GRID_WIDTH
		and cell.y >= 0
		and cell.y < GRID_HEIGHT
	)

func is_walkable(cell: Vector2i) -> bool:
	if not is_inside_grid(cell):
		return false

	var space_state = get_world_2d().direct_space_state

	var shape = CircleShape2D.new()
	shape.radius = 11.0

	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(
		0.0,
		to_global(cell_to_world(cell))
	)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var results = space_state.intersect_shape(query)

	for result in results:
		var collider = result["collider"]

		if collider == get_parent().get_node_or_null("Obstacle"):
			return false

		if collider.is_in_group("obstacles"):
			return false

	return true

func get_neighbors(cell: Vector2i) -> Array[Vector2i]:

	var neighbors: Array[Vector2i] = []

	var directions = [
		Vector2i(0, -1), # atas
		Vector2i(0, 1),  # bawah
		Vector2i(-1, 0), # kiri
		Vector2i(1, 0)   # kanan
	]

	for direction in directions:

		var next_cell = cell + direction

		if is_walkable(next_cell):
			neighbors.append(next_cell)

	return neighbors

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * CELL_SIZE + CELL_SIZE / 2,
		cell.y * CELL_SIZE + CELL_SIZE / 2
	)

func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position = to_local(world_position)
	return Vector2i(
		floori(local_position.x / CELL_SIZE),
		floori(local_position.y / CELL_SIZE)
	)


func _draw():
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var rect = Rect2(
				x * CELL_SIZE,
				y * CELL_SIZE,
				CELL_SIZE,
				CELL_SIZE
			)

			draw_rect(
				rect,
				Color(1, 1, 1, 0.05),
				false,
				1.0
			)
