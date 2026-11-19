extends Control

func _ready():
	var overview_vbox = get_node("MarginContainer/OverviewVBox")

	# Spacing antar elemen
	overview_vbox.add_theme_constant_override("separation", 10)

	# Styling label
	var labels = [
		get_node("MarginContainer/OverviewVBox/BattleStatusLabel"),
		get_node("MarginContainer/OverviewVBox/RoundLabel"),
		get_node("MarginContainer/OverviewVBox/PlayerHPLabel"),
		get_node("MarginContainer/OverviewVBox/NPCStatusLabel"),
		get_node("MarginContainer/OverviewVBox/NPCSummaryLabel")
	]

	for label in labels:
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("#D6D6D6"))

	# Heading Battle Status
	var battle_label = get_node("MarginContainer/OverviewVBox/BattleStatusLabel")
	battle_label.add_theme_font_size_override("font_size", 14)
	battle_label.add_theme_color_override("font_color", Color("#FFFFFF"))

	# Heading NPC Status
	var npc_label = get_node("MarginContainer/OverviewVBox/NPCStatusLabel")
	npc_label.add_theme_font_size_override("font_size", 14)
	npc_label.add_theme_color_override("font_color", Color("#FFFFFF"))
