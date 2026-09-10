extends Node2D

const CELL_SIZE = 40
const GRID_WIDTH = 20
const GRID_HEIGHT = 12

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

func _draw():
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell = Vector2i(x, y)
			var position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			
			# Gambar background cell
			draw_rect(
				Rect2(position, Vector2(CELL_SIZE, CELL_SIZE)),
				Color(0.15, 0.15, 0.15)
			)
			
			# Gambar garis grid
			draw_rect(
				Rect2(position, Vector2(CELL_SIZE, CELL_SIZE)),
				Color(0.3, 0.3, 0.3),
				false,
				1.0
			)
			
			# Jika cell adalah obstacle
			if cell in obstacles:
				draw_rect(
					Rect2(position, Vector2(CELL_SIZE, CELL_SIZE)),
					Color(0.7, 0.2, 0.2)
				)
			
