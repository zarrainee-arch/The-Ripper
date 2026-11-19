extends Control

func _ready():
	apply_style(self)
	visible = false

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			visible = not visible

func apply_style(node):
	for child in node.get_children():

		if child is Label:
			style_label(child)

		elif child is VBoxContainer:
			child.add_theme_constant_override("separation", 8)

		apply_style(child)


func style_label(label: Label):
	var node_name = label.name

	# Heading pada tab
	if node_name.contains("TitleLabel") \
	or node_name == "BattleStatusLabel" \
	or node_name == "NPCStatusLabel":

		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("#FFFFFF"))

	else:
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("#D6D6D6"))


func _on_close_button_pressed():
	visible = false
