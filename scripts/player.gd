extends CharacterBody2D

const SPEED = 160.0

func _ready():
	# Collision Player
	collision_layer = 1
	collision_mask = 1
	
	# Menampilkan informasi awal Player untuk debugging
	print("PLAYER READY")
	print("Position: ", global_position)
	print("Collision Layer: ", collision_layer)
	print("Collision Mask: ", collision_mask)

func _physics_process(_delta):
	# Menyimpan arah pergerakan Player
	var direction = Vector2.ZERO

	# Pergerakan player dengan WASD
	if Input.is_key_pressed(KEY_W):
		direction.y -= 1

	if Input.is_key_pressed(KEY_S):
		direction.y += 1

	if Input.is_key_pressed(KEY_A):
		direction.x -= 1

	if Input.is_key_pressed(KEY_D):
		direction.x += 1

	# Menormalkan arah agar kecepatan diagonal tidak lebih cepat dari gerakan horizontal/vertikal
	if direction != Vector2.ZERO:
		direction = direction.normalized()

	# Menentukan kecepatan berdasarkan arah dan speed
	velocity = direction * SPEED
	# Menggerakkan player dan menangai colision
	move_and_slide()

	# Mengecek apakah player mengalami tabrakan
	if get_slide_collision_count() > 0:
		print("PLAYER MENABRAK: ", get_slide_collision_count(), " object")

		# Memeriksa setiap collision yang terjadi
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			# Menampilkan nama objek yang ditabrak Player
			print("  → Collider: ", collision.get_collider().name)
