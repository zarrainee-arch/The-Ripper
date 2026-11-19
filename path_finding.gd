
extends Control

const DIFFICULTY_SCENE = "res://select_difficulty.tscn"

@onready var button_ucs: TextureButton = $ucs_button
@onready var button_manhattan: TextureButton = $manhattan_button
@onready var button_euclidean: TextureButton = $euclidean_button

@export var ucs_selected: Texture2D
@export var manhattan_selected: Texture2D
@export var euclidean_selected: Texture2D

var button_textures: Dictionary = {}


func _ready() -> void:
	# Menyimpan texture normal dan hover
	for button in [button_ucs, button_manhattan, button_euclidean]:
		button_textures[button] = {
			"normal": button.texture_normal,
			"hover": button.texture_hover
		}

	# Menghubungkan tombol
	button_ucs.pressed.connect(_on_ucs_pressed)
	button_manhattan.pressed.connect(_on_manhattan_pressed)
	button_euclidean.pressed.connect(_on_euclidean_pressed)

	# Menampilkan pilihan sebelumnya jika kembali ke scene ini
	update_selected(Global.selected_pathfinding)


func _on_ucs_pressed() -> void:
	select_algorithm("ucs")


func _on_manhattan_pressed() -> void:
	select_algorithm("astar_manhattan")


func _on_euclidean_pressed() -> void:
	select_algorithm("astar_euclidean")


func select_algorithm(algorithm: String) -> void:
	Global.selected_pathfinding = algorithm
	get_tree().change_scene_to_file(DIFFICULTY_SCENE)


func update_selected(selected: String) -> void:
	# Reset seluruh tombol
	for button in button_textures:
		button.texture_normal = button_textures[button]["normal"]
		button.texture_hover = button_textures[button]["hover"]

	# Tampilkan pilihan yang sudah tersimpan
	match selected:
		"ucs":
			button_ucs.texture_normal = ucs_selected
			button_ucs.texture_hover = ucs_selected

		"astar_manhattan":
			button_manhattan.texture_normal = manhattan_selected
			button_manhattan.texture_hover = manhattan_selected

		"astar_euclidean":
			button_euclidean.texture_normal = euclidean_selected
			button_euclidean.texture_hover = euclidean_selected
