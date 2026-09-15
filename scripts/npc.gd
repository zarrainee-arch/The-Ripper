extends CharacterBody2D


const UCS = preload("res://scripts/ucs.gd")

const SPEED = 100.0
const REPLAN_INTERVAL = 0.3

var grid
var player
var ucs

var current_path: Array[Vector2i] = []
var path_index = 0
var replan_timer = 0.0

var last_path_cost = 0
var last_expanded_nodes: Array[Vector2i] = []


func _ready():
	position = Vector2(100, 400)

	grid = get_parent().get_node("Grid")
	player = get_parent().get_node("Player")

	ucs = UCS.new(grid)

	queue_redraw()


func _physics_process(delta):
	replan_timer -= delta

	# Hitung ulang path setiap 0.3 detik
	if replan_timer <= 0.0:
		replan_timer = REPLAN_INTERVAL
		update_path()

	follow_path()


func update_path():
	var start = grid.world_to_cell(position)
	var goal = grid.world_to_cell(player.position)

	if not grid.is_walkable(start):
		return

	if not grid.is_walkable(goal):
		return

	var result = ucs.find_path(start, goal)

	current_path = result["path"]
	path_index = 0

	last_path_cost = result["cost"]
	last_expanded_nodes = result["expanded_nodes"]
	var last_algorithm = "UCS"


func follow_path():
	if current_path.is_empty():
		velocity = Vector2.ZERO
		return

	# Lewati node pertama kalau itu posisi Jack sendiri
	if path_index == 0:
		path_index = 1

	if path_index >= current_path.size():
		velocity = Vector2.ZERO
		return

	var target_cell = current_path[path_index]
	var target_position = grid.cell_to_world(target_cell)

	var direction = global_position.direction_to(target_position)

	velocity = direction * SPEED
	move_and_slide()

	# Kalau sudah dekat dengan target cell, lanjut ke cell berikutnya
	if global_position.distance_to(target_position) < 5.0:
		path_index += 1


func _draw():
	draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.7, 0.2))
