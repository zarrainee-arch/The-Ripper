extends Node2D


const CELL_SIZE = 40
const GRID_WIDTH = 32
const GRID_HEIGHT = 18


var obstacles = [
	Vector2i(5, 2),
	Vector2i(6, 2),
	Vector2i(7, 2),
	Vector2i(5, 3),
	Vector2i(7, 3),
	Vector2i(5, 4),
	Vector2i(7, 4),
	Vector2i(5, 5),
	Vector2i(6, 5),
	Vector2i(7, 5)
]


func _ready():
	queue_redraw()


# Mengecek apakah cell masih berada di dalam grid
func is_inside_grid(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < GRID_WIDTH
		and cell.y >= 0
		and cell.y < GRID_HEIGHT
	)


# Mengecek apakah cell bisa dilewati
func is_walkable(cell: Vector2i) -> bool:
	return is_inside_grid(cell) and cell not in obstacles


# Mendapatkan tetangga yang bisa dilewati
func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []

	var directions = [
		Vector2i(0, -1),  # Up
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0),  # Left
		Vector2i(1, 0)    # Right
	]

	for direction in directions:
		var neighbor = cell + direction

		if is_walkable(neighbor):
			neighbors.append(neighbor)

	return neighbors


# Mengubah koordinat grid menjadi posisi pixel
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * CELL_SIZE + CELL_SIZE / 2,
		cell.y * CELL_SIZE + CELL_SIZE / 2
	)


# Mengubah posisi pixel menjadi koordinat grid
func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floor(world_position.x / CELL_SIZE),
		floor(world_position.y / CELL_SIZE)
	)


func _draw():
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell = Vector2i(x, y)

			var cell_position = Vector2(
				x * CELL_SIZE,
				y * CELL_SIZE
			)

			# Background cell
			draw_rect(
				Rect2(
					cell_position,
					Vector2(CELL_SIZE, CELL_SIZE)
				),
				Color(0.15, 0.15, 0.15)
			)

			# Garis grid
			draw_rect(
				Rect2(
					cell_position,
					Vector2(CELL_SIZE, CELL_SIZE)
				),
				Color(0.3, 0.3, 0.3),
				false,
				1.0
			)

			# Obstacle
			if cell in obstacles:
				draw_rect(
					Rect2(
						cell_position,
						Vector2(CELL_SIZE, CELL_SIZE)
					),
					Color(0.7, 0.2, 0.2)
				)