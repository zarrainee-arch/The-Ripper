extends CharacterBody2D

const SPEED = 160.0

func _ready():
	position = Vector2(700, 400)
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

	move_and_slide()

func _draw():
	draw_circle(Vector2.ZERO, 15.0, Color(0.2, 0.5, 1.0))
