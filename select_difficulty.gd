extends Control

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")

const CONFIGURATION_MENU = "res://configuration_menu.tscn"

func _on_easy_button_pressed() -> void: open_configuration(25)

func _on_medium_button_pressed() -> void: open_configuration(50)

func _on_difficult_button_pressed() -> void: open_configuration(75)

func open_configuration(target_difficulty: int) -> void:
	Global.target_difficulty = target_difficulty
	get_tree().change_scene_to_file(CONFIGURATION_MENU)
