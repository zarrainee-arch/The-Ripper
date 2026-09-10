extends CharacterBody2D

const SPEED = 100.0

func _ready():
	position = Vector2(100, 400)
	queue_redraw()

func _physics_process(_delta):
	# Untuk sementara NPC belum menggunakan AI.
	# Nanti bagian ini akan digantikan oleh UCS / A*.
	pass

func _draw():
	draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.7, 0.2))
