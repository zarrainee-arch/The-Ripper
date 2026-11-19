
extends Control

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://path_finding.tscn")
	
func _on_quit_button_pressed() -> void:
	get_tree().quit()
