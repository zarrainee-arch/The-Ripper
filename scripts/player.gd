extends CharacterBody2D


const SPEED = 160.0


func _ready():
	# Collision Player
	collision_layer = 1
	collision_mask = 1
	
	print("PLAYER READY")
	print("Position: ", global_position)
	print("Collision Layer: ", collision_layer)
	print("Collision Mask: ", collision_mask)


func _physics_process(_delta):
	var direction = Vector2.ZERO


	# =========================
	# INPUT WASD
	# =========================

	if Input.is_key_pressed(KEY_W):
		direction.y -= 1

	if Input.is_key_pressed(KEY_S):
		direction.y += 1

	if Input.is_key_pressed(KEY_A):
		direction.x -= 1

	if Input.is_key_pressed(KEY_D):
		direction.x += 1


	# =========================
	# NORMALIZE
	# =========================

	if direction != Vector2.ZERO:
		direction = direction.normalized()


	# =========================
	# MOVEMENT
	# =========================

	velocity = direction * SPEED

	move_and_slide()


	# =========================
	# DEBUG COLLISION
	# =========================

	if get_slide_collision_count() > 0:

		print(
			"PLAYER MENABRAK: ",
			get_slide_collision_count(),
			" object"
		)

		for i in range(get_slide_collision_count()):

			var collision = get_slide_collision(i)

			print(
				"  → Collider: ",
				collision.get_collider().name
			)
