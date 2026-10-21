
extends Control

# KONFIGURASI PILIHAN PEMAIN
var selected_npc_count: int = 1
var selected_npc_composition: Array[int] = [1, 0, 0]

var selected_weapon: String = "Knife"
var selected_armor: String = "Street Clothes"
var selected_algorithm: String = "HillClimbing"
var selected_seed: int = -1

const MAX_NPC: int = 10

@onready var pages = $ContentPanel/Pages
@onready var seed_input = $ContentPanel/Pages/SeedPanel/LineEdit

# Label angka NPC sesuai Scene Tree milikmu
@onready var street_angka: Label = $ContentPanel/Pages/NPCCountPanel/StreetAngka
@onready var knife_angka: Label = $ContentPanel/Pages/NPCCountPanel/KnifeAngka
@onready var heavy_angka: Label = $ContentPanel/Pages/NPCCountPanel/HeavyAngka


# INISIALISASI MENU
func _ready() -> void:
	show_page("NPCCountPanel")
	update_npc_display()


func show_page(page_name: String) -> void:
	for page in pages.get_children():
		page.visible = page.name == page_name


# NAVIGASI SIDEBAR
func _on_npc_button_pressed() -> void:
	show_page("NPCCountPanel")

func _on_weapon_button_pressed() -> void:
	show_page("WeaponPanel")

func _on_armor_button_pressed() -> void:
	show_page("ArmorPanel")

func _on_optimization_button_pressed() -> void:
	show_page("AlgorithmPanel")

func _on_seed_button_pressed() -> void:
	show_page("SeedPanel")

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(
        "res://select_difficulty.tscn"
	)


# PILIHAN JUMLAH NPC
func update_npc_display() -> void:
	street_angka.text = str(selected_npc_composition[0])
	knife_angka.text = str(selected_npc_composition[1])
	heavy_angka.text = str(selected_npc_composition[2])


func change_npc_count(npc_index: int, amount: int) -> void:
	var current_total: int = (
		selected_npc_composition[0]
		+ selected_npc_composition[1]
		+ selected_npc_composition[2]
	)

	var current_value: int = selected_npc_composition[npc_index]

	# Tidak boleh kurang dari 0
	if amount < 0 and current_value <= 0:
		return

	# Total semua NPC tidak boleh lebih dari 10
	if amount > 0 and current_total >= MAX_NPC:
		print("Maksimal total NPC adalah 10!")
		return

	selected_npc_composition[npc_index] += amount

	selected_npc_count = (
		selected_npc_composition[0]
		+ selected_npc_composition[1]
		+ selected_npc_composition[2]
	)

	update_npc_display()

	print("Komposisi NPC: ", selected_npc_composition)
	print("Jumlah NPC: ", selected_npc_count)


# TOMBOL MINUS DAN PLUS: STREET THUG
func _on_street_minus_pressed() -> void:
	change_npc_count(0, -1)

func _on_street_plus_pressed() -> void:
	change_npc_count(0, 1)


# TOMBOL MINUS DAN PLUS: KNIFE THUG
func _on_knife_minus_pressed() -> void:
	change_npc_count(1, -1)

func _on_knife_plus_pressed() -> void:
	change_npc_count(1, 1)


# TOMBOL MINUS DAN PLUS: HEAVY ENFORCER
func _on_heavy_minus_pressed() -> void:
	change_npc_count(2, -1)

func _on_heavy_plus_pressed() -> void:
	change_npc_count(2, 1)


# PILIHAN KOMPOSISI NPC (UNTUK PEMANGGIL LAIN)
func set_npc_composition(
	street_thug: int,
	knife_thug: int,
	heavy_enforcer: int
) -> void:
	var composition: Array[int] = [
		maxi(0, street_thug),
		maxi(0, knife_thug),
		maxi(0, heavy_enforcer)
	]

	var total: int = (
		composition[0]
		+ composition[1]
		+ composition[2]
	)

	if total < 1 or total > MAX_NPC:
		print("Total NPC harus antara 1 sampai 10!")
		return

	selected_npc_composition = composition
	selected_npc_count = total
	update_npc_display()

	print("Komposisi NPC: ", selected_npc_composition)
	print("Jumlah NPC: ", selected_npc_count)


# PILIHAN WEAPON
func _on_knife_button_pressed() -> void:
	select_weapon("Knife")

func _on_club_button_pressed() -> void:
	select_weapon("Club")

func _on_cleaver_button_pressed() -> void:
	select_weapon("Cleaver")

# Nama alternatif jika sinyal sudah terhubung dengan nama ini
func _on_knife_pressed() -> void:
	select_weapon("Knife")

func _on_club_pressed() -> void:
	select_weapon("Club")

func _on_clever_pressed() -> void:
	select_weapon("Cleaver")


func select_weapon(weapon_name: String) -> void:
	selected_weapon = weapon_name
	print("Weapon dipilih: ", selected_weapon)


# PILIHAN ARMOR
func _on_street_clothes_pressed() -> void:
	select_armor("Street Clothes")

func _on_leather_vest_pressed() -> void:
	select_armor("Leather Vest")

func _on_reinforced_coat_pressed() -> void:
	select_armor("Reinforced Coat")


func select_armor(armor_name: String) -> void:
	selected_armor = armor_name
	print("Armor dipilih: ", selected_armor)


# PILIHAN ALGORITMA LOCAL SEARCH
func _on_hill_climbing_pressed() -> void:
	select_algorithm("HillClimbing")

func _on_random_restart_pressed() -> void:
	select_algorithm("RandomRestart")

func _on_simulated_annealing_pressed() -> void:
	select_algorithm("SimulatedAnnealing")


func select_algorithm(algorithm_name: String) -> void:
	selected_algorithm = algorithm_name
	print("Algoritma dipilih: ", selected_algorithm)


# PILIHAN SEED
func get_selected_seed() -> int:
	var input_text: String = seed_input.text.strip_edges()

	if input_text.is_empty():
		selected_seed = -1
	elif input_text.is_valid_int():
		selected_seed = int(input_text)
	else:
		print("Seed harus berupa bilangan bulat!")
		return -1

	print("Seed dipilih: ", selected_seed)
	return selected_seed


# RINGKASAN KONFIGURASI
func print_configuration() -> void:
	print("===== KONFIGURASI PEMAIN =====")
	print("Jumlah NPC: ", selected_npc_count)
	print("Komposisi NPC: ", selected_npc_composition)
	print("Weapon: ", selected_weapon)
	print("Armor: ", selected_armor)
	print("Algoritma: ", selected_algorithm)
	print("Seed: ", get_selected_seed())
	print("==============================")


# MENJALANKAN LOCAL SEARCH DAN MEMBUKA RESULT
func run_optimization() -> void:
	var local_search := LocalSearch.new()

	# Buat konfigurasi awal dari pilihan pemain.
	var initial_configuration := LocalSearch.NPCConfiguration.new(
		selected_npc_composition,
		selected_weapon,
		selected_armor
	)

	# Validasi sebelum menjalankan algoritma.
	if not local_search.validate_configuration(initial_configuration):
		push_error("Konfigurasi NPC tidak valid!")
		return

	# Ambil target dari pilihan difficulty sebelumnya.
	var target: float = float(Global.target_difficulty)

	print("Target Difficulty: ", target)
	
	# Ambil seed dari input. -1 berarti acak.
	var seed_value: int = get_selected_seed()

	if seed_value == -1:
		seed_value = -1

	# Jalankan algoritma temanmu.
	var optimizer := Optimizer.new()
	var optimization_result: OptimizationResult = optimizer.run(
		initial_configuration,
		target,
		selected_algorithm,
		{},
		seed_value
	)

	# Kirim hasil ke scene Result.
	get_tree().root.set_meta(
		"optimization_result",
		optimization_result
	)
	# Kirim konfigurasi awal untuk ditampilkan di RESULT.
	get_tree().root.set_meta(
		"initial_configuration",
		initial_configuration
	)
	
	get_tree().root.set_meta(
	"selected_algorithm",
	selected_algorithm
)

	get_tree().root.set_meta(
		"selected_weapon",
		selected_weapon
)

	get_tree().root.set_meta(
	"selected_armor",
	selected_armor
)
	get_tree().change_scene_to_file("res://result.tscn")

func _on_optimasi_button_pressed() -> void:
	run_optimization()
