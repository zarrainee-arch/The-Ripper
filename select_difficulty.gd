extends Control

const CONFIGURATION_MENU = "res://configuration_menu.tscn"

@onready var easy_button: TextureButton = $easyButton
@onready var medium_button: TextureButton = $mediumButton
@onready var difficult_button: TextureButton = $difficultButton

# Masukkan gambar Selected melalui Inspector
@export var easy_selected: Texture2D
@export var medium_selected: Texture2D
@export var difficult_selected: Texture2D

var button_textures = {}

func _ready():
	# Simpan tekstur normal dan hover
	for button in [easy_button, medium_button, difficult_button]:
		button_textures[button] = {
			"normal": button.texture_normal,
			"hover": button.texture_hover
		}

	# Pulihkan pilihan sebelumnya
	match Global.target_difficulty:
		25:
			update_selected(25)
		50:
			update_selected(50)
		75:
			update_selected(75)
		_:
			reset_buttons()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://path_finding.tscn")


func _on_easy_button_pressed() -> void:
	open_configuration(25)


func _on_medium_button_pressed() -> void:
	open_configuration(50)


func _on_difficult_button_pressed() -> void:
	open_configuration(75)


func open_configuration(target_difficulty: int) -> void:
	Global.target_difficulty = target_difficulty
	get_tree().change_scene_to_file(CONFIGURATION_MENU)


func update_selected(selected: int) -> void:
	reset_buttons()

	match selected:
		25:
			easy_button.texture_normal = easy_selected
			easy_button.texture_hover = easy_selected
		50:
			medium_button.texture_normal = medium_selected
			medium_button.texture_hover = medium_selected
		75:
			difficult_button.texture_normal = difficult_selected
			difficult_button.texture_hover = difficult_selected


func reset_buttons() -> void:
	for button in button_textures:
		button.texture_normal = button_textures[button]["normal"]
		button.texture_hover = button_textures[button]["hover"]
