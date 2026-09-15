extends CharacterBody2D


const SPEED = 160.0

var grid


func _ready():
	position = Vector2(700, 400)
	grid = get_parent().get_node("Grid")
	queue_redraw()


func _physics_process(_delta):
	var direction = Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		direction.y -= 1

	if Input.is_key_pressed(KEY_S):
		direction.y += 1

	if Input.is_key_pressed(KEY_A):
		direction.x -= 1

	if Input.is_key_pressed(KEY_D):
		direction.x += 1

	direction = direction.normalized()
	velocity = direction * SPEED

	# Cek posisi tujuan sebelum bergerak
	var next_position = position + velocity * _delta
	var next_cell = grid.world_to_cell(next_position)

	if grid.is_walkable(next_cell):
		move_and_slide()
	else:
		velocity = Vector2.ZERO


func _draw():
	draw_circle(Vector2.ZERO, 15.0, Color(0.2, 0.5, 1.0))