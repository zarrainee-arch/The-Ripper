extends TabContainer

func _ready():
	add_theme_font_size_override("font_size", 12)
	add_theme_constant_override("tab_separation", 14)

	var tab_style = StyleBoxFlat.new()
	tab_style.bg_color = Color("#303030")

	tab_style.content_margin_left = 8
	tab_style.content_margin_right = 8
	tab_style.content_margin_top = 3
	tab_style.content_margin_bottom = 3

	add_theme_stylebox_override("tab_unselected", tab_style)

	var selected_style = tab_style.duplicate()
	selected_style.bg_color = Color("#454545")
	add_theme_stylebox_override("tab_selected", selected_style)
