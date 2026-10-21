
extends RefCounted
class_name LocalSearch

# ============================================================
# BLOK 1 — KONSTANTA MASALAH DAN NAMA ALGORITMA
# ============================================================

const NPC_COUNT_MIN: int = 1
const NPC_COUNT_MAX: int = 10
const MAX_FITNESS: float = 100.0
const TOLERANCE: float = 2.0
const RAW_MAX: float = 312.0

const ALGORITHM_HILL_CLIMBING: String = "HillClimbing"
const ALGORITHM_RANDOM_RESTART: String = "RandomRestart"
const ALGORITHM_SIMULATED_ANNEALING: String = "SimulatedAnnealing"

const NPC_TYPES: Array[String] = [
	"Street Thug",
	"Knife Thug",
	"Heavy Enforcer"
]

const BASE_POWER: Array[int] = [10, 15, 20]

const WEAPONS: Array[String] = [
	"Knife",
	"Club",
	"Cleaver"
]

const WEAPON_FACTORS: Array[float] = [
	1.00,
	1.10,
	1.20
]

const ARMORS: Array[String] = [
	"Street Clothes",
	"Leather Vest",
	"Reinforced Coat"
]

const ARMOR_FACTORS: Array[float] = [
	1.00,
	1.15,
	1.30
]


# ============================================================
# BLOK 2 — NPC CONFIGURATION
# ============================================================

class NPCConfiguration:
	var composition: Array[int]
	var npc_count: int
	var weapon: String
	var armor: String

	func _init(
		composition_value: Array[int] = [1, 0, 0],
		weapon_value: String = "Knife",
		armor_value: String = "Street Clothes"
	) -> void:
		composition = composition_value.duplicate()
		weapon = weapon_value
		armor = armor_value
		npc_count = 0

		for count in composition:
			npc_count += count

	func duplicate_config() -> NPCConfiguration:
		return NPCConfiguration.new(
			composition,
			weapon,
			armor
		)

	func is_valid() -> bool:
		if composition.size() != 3:
			return false

		var total: int = 0

		for count in composition:
			if count < 0:
				return false
			total += count

		if total < LocalSearch.NPC_COUNT_MIN:
			return false

		if total > LocalSearch.NPC_COUNT_MAX:
			return false

		if total != npc_count:
			return false

		if not LocalSearch.WEAPONS.has(weapon):
			return false

		if not LocalSearch.ARMORS.has(armor):
			return false

		return true

	func to_key() -> String:
		return "%d,%d,%d|%s|%s" % [
			composition[0],
			composition[1],
			composition[2],
			weapon,
			armor
		]


# ============================================================
# BLOK 3 — VALIDASI DAN OPERASI KONFIGURASI
# ============================================================

func validate_configuration(
	configuration: NPCConfiguration
) -> bool:
	if configuration == null:
		return false

	return configuration.is_valid()


func copy_configuration(
	configuration: NPCConfiguration
) -> NPCConfiguration:
	if configuration == null:
		return null

	return configuration.duplicate_config()


# ============================================================
# BLOK 4 — DIFFICULTY DAN FITNESS
# ============================================================

func calculate_difficulty(
	configuration: NPCConfiguration
) -> float:
	if not validate_configuration(configuration):
		return -1.0

	var base_total: int = 0

	for i in range(3):
		base_total += (
			configuration.composition[i]
			* BASE_POWER[i]
		)

	var weapon_index: int = WEAPONS.find(
		configuration.weapon
	)
	var armor_index: int = ARMORS.find(
		configuration.armor
	)

	var raw_power: float = (
		float(base_total)
		* WEAPON_FACTORS[weapon_index]
		* ARMOR_FACTORS[armor_index]
	)

	return 100.0 * raw_power / RAW_MAX


func calculate_fitness(
	configuration: NPCConfiguration,
	target_difficulty: float
) -> float:
	if not validate_configuration(configuration):
		return -1.0

	if target_difficulty < 0.0 or target_difficulty > 100.0:
		return -1.0

	var difficulty: float = calculate_difficulty(
		configuration
	)

	return MAX_FITNESS - absf(
		difficulty - target_difficulty
	)


# ============================================================
# BLOK 5 — NEIGHBOUR / SUCCESSOR
# Urutan: ADD, REMOVE, SWAP_TYPE,
#         CHANGE_WEAPON, CHANGE_ARMOR
# ============================================================

func get_neighbours(
	configuration: NPCConfiguration
) -> Array[NPCConfiguration]:
	var neighbours: Array[NPCConfiguration] = []

	if not validate_configuration(configuration):
		return neighbours

	var seen: Dictionary = {}
	var current: NPCConfiguration = configuration

	# ADD: tambah satu NPC sesuai urutan tipe.
	for i in range(3):
		if current.npc_count >= NPC_COUNT_MAX:
			break

		var next: NPCConfiguration = copy_configuration(current)
		next.composition[i] += 1
		next.npc_count += 1
		_add_if_new(neighbours, seen, next)

	# REMOVE: kurangi satu NPC sesuai urutan tipe.
	for i in range(3):
		if current.npc_count <= NPC_COUNT_MIN:
			break

		if current.composition[i] <= 0:
			continue

		var next: NPCConfiguration = copy_configuration(current)
		next.composition[i] -= 1
		next.npc_count -= 1
		_add_if_new(neighbours, seen, next)

	# SWAP_TYPE: pindahkan satu NPC dari tipe i ke tipe j.
	for i in range(3):
		if current.composition[i] <= 0:
			continue

		for j in range(3):
			if i == j:
				continue

			var next: NPCConfiguration = copy_configuration(current)
			next.composition[i] -= 1
			next.composition[j] += 1
			_add_if_new(neighbours, seen, next)

	# CHANGE_WEAPON: urutan mengikuti daftar weapon.
	for weapon_name in WEAPONS:
		if weapon_name == current.weapon:
			continue

		var next: NPCConfiguration = copy_configuration(current)
		next.weapon = weapon_name
		_add_if_new(neighbours, seen, next)

	# CHANGE_ARMOR: urutan mengikuti daftar armor.
	for armor_name in ARMORS:
		if armor_name == current.armor:
			continue

		var next: NPCConfiguration = copy_configuration(current)
		next.armor = armor_name
		_add_if_new(neighbours, seen, next)

	return neighbours


func _add_if_new(
	neighbours: Array[NPCConfiguration],
	seen: Dictionary,
	configuration: NPCConfiguration
) -> void:
	if not validate_configuration(configuration):
		return

	var key: String = configuration.to_key()

	if seen.has(key):
		return

	seen[key] = true
	neighbours.append(configuration)


# Membuat konfigurasi valid secara acak.
func random_configuration(
	rng: RandomNumberGenerator
) -> NPCConfiguration:
	var configuration: NPCConfiguration

	while true:
		var composition: Array[int] = [0, 0, 0]
		var total: int = rng.randi_range(
			NPC_COUNT_MIN,
			NPC_COUNT_MAX
		)

		for i in range(total):
			var type_index: int = rng.randi_range(0, 2)
			composition[type_index] += 1

		var weapon: String = WEAPONS[
			rng.randi_range(0, WEAPONS.size() - 1)
		]
		var armor: String = ARMORS[
			rng.randi_range(0, ARMORS.size() - 1)
		]

		configuration = NPCConfiguration.new(
			composition,
			weapon,
			armor
		)

		if validate_configuration(configuration):
			return configuration

	return configuration


# Memilih satu neighbour secara acak seragam.
# RNG diberikan oleh pemanggil agar bisa dipakai
# bersama oleh seluruh algoritma dalam satu run.
func random_neighbour(
	configuration: NPCConfiguration,
	rng: RandomNumberGenerator
) -> NPCConfiguration:
	var neighbours: Array[NPCConfiguration] = get_neighbours(
		configuration
	)

	if neighbours.is_empty():
		return copy_configuration(configuration)

	var index: int = rng.randi_range(
		0,
		neighbours.size() - 1
	)

	return neighbours[index]
