
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

# WEAPON BUTTONS
@onready var knife_button: TextureButton = $ContentPanel/Pages/WeaponPanel/Knife
@onready var club_button: TextureButton = $ContentPanel/Pages/WeaponPanel/Club
@onready var cleaver_button: TextureButton = $ContentPanel/Pages/WeaponPanel/Clever

# ARMOR BUTTONS
@onready var street_button: TextureButton = $ContentPanel/Pages/ArmorPanel/Street
@onready var leather_button: TextureButton = $ContentPanel/Pages/ArmorPanel/Leather
@onready var reinforced_button: TextureButton = $ContentPanel/Pages/ArmorPanel/Reinforced

# ALGORITHM BUTTONS
@onready var hill_button: TextureButton = $ContentPanel/Pages/AlgorithmPanel/HillClimbing
@onready var restart_button: TextureButton = $ContentPanel/Pages/AlgorithmPanel/RandomRestart
@onready var annealing_button: TextureButton = $ContentPanel/Pages/AlgorithmPanel/SimulatedAnnealing

# SELECTED TEXTURES - WEAPON
@export var knife_selected: Texture2D
@export var club_selected: Texture2D
@export var cleaver_selected: Texture2D

# SELECTED TEXTURES - ARMOR
@export var street_selected: Texture2D
@export var leather_selected: Texture2D
@export var reinforced_selected: Texture2D

# SELECTED TEXTURES - ALGORITHM
@export var hill_selected: Texture2D
@export var restart_selected: Texture2D
@export var annealing_selected: Texture2D

# Menyimpan tekstur Normal dan Hover asli
var original_textures: Dictionary = {}

# INISIALISASI MENU
func _ready() -> void:
	show_page("NPCCountPanel")
	update_npc_display()
	setup_selection_buttons()


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
	update_weapon_display()
	print("Weapon dipilih: ", selected_weapon)


# PILIHAN ARMOR
func _on_street_pressed() -> void:
	select_armor("Street Clothes")

func _on_leather_pressed() -> void:
	select_armor("Leather Vest")

func _on_reinforced_pressed() -> void:
	select_armor("Reinforced Coat")


func select_armor(armor_name: String) -> void:
	print("TOMBOL ARMOR DIKLIK: ", armor_name)
	selected_armor = armor_name
	update_armor_display()
	print("ARMOR TERPILIH: ", selected_armor)


# PILIHAN ALGORITMA LOCAL SEARCH
func _on_hill_climbing_pressed() -> void:
	select_algorithm("HillClimbing")

func _on_random_restart_pressed() -> void:
	select_algorithm("RandomRestart")

func _on_simulated_annealing_pressed() -> void:
	select_algorithm("SimulatedAnnealing")


func select_algorithm(algorithm_name: String) -> void:
	selected_algorithm = algorithm_name
	update_algorithm_display()
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
	
	
func setup_selection_buttons() -> void:
	var all_buttons = [
		knife_button, club_button, cleaver_button,
		street_button, leather_button, reinforced_button,
		hill_button, restart_button, annealing_button
	]

	for button in all_buttons:
		original_textures[button] = {
			"normal": button.texture_normal,
			"hover": button.texture_hover
		}

	update_weapon_display()
	update_armor_display()
	update_algorithm_display()


func apply_selected(
	buttons: Array,
	selected_button: TextureButton,
	selected_texture: Texture2D
) -> void:
	for button in buttons:
		button.texture_normal = original_textures[button]["normal"]
		button.texture_hover = original_textures[button]["hover"]

	selected_button.texture_normal = selected_texture
	selected_button.texture_hover = selected_texture


func update_weapon_display() -> void:
	var buttons = [knife_button, club_button, cleaver_button]
	var selected_button: TextureButton
	var selected_texture: Texture2D

	match selected_weapon:
		"Knife":
			selected_button = knife_button
			selected_texture = knife_selected
		"Club":
			selected_button = club_button
			selected_texture = club_selected
		"Cleaver":
			selected_button = cleaver_button
			selected_texture = cleaver_selected

	apply_selected(buttons, selected_button, selected_texture)


func update_armor_display() -> void:
	var buttons = [street_button, leather_button, reinforced_button]
	var selected_button: TextureButton
	var selected_texture: Texture2D

	match selected_armor:
		"Street Clothes":
			selected_button = street_button
			selected_texture = street_selected
		"Leather Vest":
			selected_button = leather_button
			selected_texture = leather_selected
		"Reinforced Coat":
			selected_button = reinforced_button
			selected_texture = reinforced_selected

	apply_selected(buttons, selected_button, selected_texture)

func update_algorithm_display() -> void:
	var buttons = [hill_button, restart_button, annealing_button]
	var selected_button: TextureButton
	var selected_texture: Texture2D

	match selected_algorithm:
		"HillClimbing":
			selected_button = hill_button
			selected_texture = hill_selected
		"RandomRestart":
			selected_button = restart_button
			selected_texture = restart_selected
		"SimulatedAnnealing":
			selected_button = annealing_button
			selected_texture = annealing_selected

	apply_selected(buttons, selected_button, selected_texture)
