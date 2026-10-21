extends Control

# REFERENSI NODE
@onready var page_configuration = $Background/PageConfiguration
@onready var page_statistic = $Background/PageStatistic

# Label konfigurasi awal
@onready var street_awal: Label = $Background/PageConfiguration/streetAwal
@onready var knife_awal: Label = $Background/PageConfiguration/knifeAwal
@onready var heavy_awal: Label = $Background/PageConfiguration/heavyAwal
@onready var weapon_awal: Label = $Background/PageConfiguration/weaponAwal
@onready var armor_awal: Label = $Background/PageConfiguration/armorAwal

# Label Best Configuration
@onready var best_street: Label = $Background/PageConfiguration/bestStreet
@onready var best_knife: Label = $Background/PageConfiguration/bestKnife
@onready var best_heavy: Label = $Background/PageConfiguration/bestHeavy
@onready var best_weapon: Label = $Background/PageConfiguration/bestWeapon
@onready var best_armor: Label = $Background/PageConfiguration/bestArmor

# Label statistik hasil
@onready var best_fitness_value: Label = $Background/PageStatistic/BestVitnessValue
@onready var difficulty_score_value: Label = $Background/PageStatistic/DifficultyScoreValue
@onready var target_difficulty_value: Label = $Background/PageStatistic/TargetDifficultyValue
@onready var absolute_error_value: Label = $Background/PageStatistic/AbsoluteErrorValue

@onready var algorithm_name_value: Label = $Background/PageStatistic/AlgorithmNameValue
@onready var seed_value_label: Label = $Background/PageStatistic/SeedValue
@onready var iteration_count_value: Label = $Background/PageStatistic/IterationCountValue
@onready var evaluation_count_value: Label = $Background/PageStatistic/EvaluationCountValue
@onready var restart_count_value: Label = $Background/PageStatistic/RestartCountValue

@onready var elapsed_time_value: Label = $Background/PageStatistic/ElapsedTimeValue
@onready var status_value: Label = $Background/PageStatistic/StatusValue
@onready var termination_reason_value: Label = $Background/PageStatistic/TerminationReasonValue


# INISIALISASI
func _ready() -> void:
	show_configuration()
	show_initial_configuration()
	show_optimization_statistics()

# NAVIGASI HALAMAN
func show_configuration() -> void:
	page_configuration.visible = true
	page_statistic.visible = false

func show_statistic() -> void:
	page_configuration.visible = false
	page_statistic.visible = true

func _on_statistic_button_pressed() -> void:
	show_statistic()

func _on_back_menu_pressed() -> void:
	show_configuration()

# KONFIGURASI AWAL
func show_initial_configuration() -> void:
	if not get_tree().root.has_meta("initial_configuration"):
		push_warning("Konfigurasi awal tidak ditemukan.")
		return

	var config = get_tree().root.get_meta("initial_configuration")

	street_awal.text = str(config.composition[0])
	knife_awal.text = str(config.composition[1])
	heavy_awal.text = str(config.composition[2])
	weapon_awal.text = str(config.weapon)
	armor_awal.text = str(config.armor)

# STATISTIK HASIL OPTIMASI
func show_optimization_statistics() -> void:
	if not get_tree().root.has_meta("optimization_result"):
		push_warning("Hasil optimasi tidak ditemukan.")
		return

	var result = get_tree().root.get_meta("optimization_result")

	if result == null:
		push_warning("Objek hasil optimasi kosong.")
		return
	var best = result.best_configuration

	best_street.text = str(best.composition[0])
	best_knife.text = str(best.composition[1])
	best_heavy.text = str(best.composition[2])
	best_weapon.text = str(best.weapon)
	best_armor.text = str(best.armor)

	best_fitness_value.text = str(result.best_fitness)
	difficulty_score_value.text = str(result.best_difficulty_score)
	target_difficulty_value.text = str(result.target_difficulty)

	absolute_error_value.text = str(
		absf(result.best_difficulty_score - result.target_difficulty)
	)

	algorithm_name_value.text = str(result.algorithm_name)
	seed_value_label.text = str(result.seed_used)
	iteration_count_value.text = str(result.iteration_count)
	evaluation_count_value.text = str(result.evaluation_count)
	restart_count_value.text = str(result.restart_count)

	elapsed_time_value.text = "%.2f ms" % result.elapsed_ms

	status_value.text = "Berhasil" if result.success else "Tidak Berhasil"
	termination_reason_value.text = str(result.termination_reason)

func _on_restart_button_pressed() -> void:
	print("Restart diklik!")

	get_tree().root.remove_meta("optimization_result")
	get_tree().root.remove_meta("initial_configuration")

	var error := get_tree().change_scene_to_file(
		"res://select_difficulty.tscn"
	)

	if error != OK:
		push_error("Gagal membuka Select Difficulty. Error: " + str(error))


func _on_mulai_battle_pressed() -> void:
	var root = get_tree().root

	if not root.has_meta("optimization_result"):
		push_error("Hasil optimasi tidak ditemukan!")
		return

	var result = root.get_meta("optimization_result")

	if result == null or result.best_configuration == null:
		push_error("Best Configuration tidak ditemukan!")
		return

	# Simpan konfigurasi terbaik agar bisa dibaca di main.tscn.
	root.set_meta("battle_configuration", result.best_configuration)

	var error := get_tree().change_scene_to_file("res://main.tscn")

	if error != OK:
		push_error("Gagal membuka Main scene. Error: " + str(error))
