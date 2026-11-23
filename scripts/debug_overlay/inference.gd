extends Control

func _ready():
	var inference_vbox = $MarginContainer/InferenceVBox

	inference_vbox.add_theme_constant_override("separation", 10)

	var labels = [
		$MarginContainer/InferenceVBox/FactsLabel,
		$MarginContainer/InferenceVBox/RulesLabel,
		$MarginContainer/InferenceVBox/ConclusionLabel
	]

	var section_titles = [
	$MarginContainer/InferenceVBox/FactsTitleLabel,
	$MarginContainer/InferenceVBox/RulesTitleLabel,
	$MarginContainer/InferenceVBox/ConclusionTitleLabel
]

	for title in section_titles:
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", Color("#FFFFFF"))
		for label in labels:
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color("#D6D6D6"))

	## Heading utama
	#$MarginContainer/InferenceVBox/TitleLabel.add_theme_font_size_override("font_size", 14)
	#$MarginContainer/InferenceVBox/TitleLabel.add_theme_color_override(
		#"font_color", Color("#FFFFFF")
	#)
