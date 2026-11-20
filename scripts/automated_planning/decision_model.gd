extends RefCounted
class_name DecisionModel

# Mengatur batas nilai probabilitas yang dapat diterima.
const PROBABILITY_MIN := 0.0
const PROBABILITY_MAX := 1.0
const PROBABILITY_TOLERANCE := 0.000001

# Menentukan kelas terminal yang dapat digunakan dalam model.
const TERMINAL_SUCCESS := "SUCCESS"
const TERMINAL_FAILURE := "FAILURE"

# Membuat struktur hasil agar keluaran setiap fungsi memiliki format yang sama.
static func _result(valid: bool, errors: Array[String], data: Dictionary = {}) -> Dictionary:
	# Mengembalikan status validasi, daftar error, dan data hasil.
	return {
		"valid": valid,
		"errors": errors,
		"data": data
	}

# Memeriksa apakah nilai yang diberikan merupakan angka finite.
static func _is_finite_number(value: Variant) -> bool:
	# Menolak tipe non-numerik serta nilai NaN atau tak hingga.
	return (value is int or value is float) and is_finite(float(value))

# Memeriksa apakah nilai probabilitas berada dalam rentang 0 sampai 1.
static func _validate_probability(value: Variant) -> bool:
	# Menolak nilai jika bukan angka finite.
	if not _is_finite_number(value):
		return false

	# Memastikan nilai berada di antara batas minimum dan maksimum probabilitas.
	return float(value) >= PROBABILITY_MIN and float(value) <= PROBABILITY_MAX

# Memeriksa apakah daftar berisi ID yang valid dan tidak memiliki duplikasi.
static func _validate_unique_ids(values: Variant) -> bool:
	# Menolak jika input bukan Array atau berisi daftar kosong.
	if not values is Array or values.is_empty():
		return false

	# Menyimpan ID yang sudah ditemukan untuk mendeteksi duplikasi.
	var seen: Dictionary = {}

	# Memeriksa setiap ID dalam daftar.
	for value in values:
		# Memastikan setiap elemen berupa String yang tidak kosong.
		if not value is String or value.is_empty():
			return false

		# Menolak jika ID yang sama muncul lebih dari satu kali.
		if seen.has(value):
			return false

		# Mencatat ID yang valid ke dalam daftar pemeriksaan.
		seen[value] = true

	return true

# Membandingkan dua daftar ID tanpa memperhatikan urutannya.
static func _same_id_set(first: Variant, second: Variant) -> bool:
	# Memastikan kedua input berbentuk Array.
	if not first is Array or not second is Array:
		return false

	# Menolak jika jumlah elemen kedua daftar berbeda.
	if first.size() != second.size():
		return false

	# Menyimpan himpunan ID unik dari daftar pertama.
	var first_set: Dictionary = {}

	# Memeriksa dan mencatat seluruh ID pada daftar pertama.
	for item in first:
		# Menolak jika elemen bukan String atau muncul ganda.
		if not item is String or first_set.has(item):
			return false

		first_set[item] = true

	# Memeriksa setiap ID pada daftar kedua.
	for item in second:
		# Menolak jika ID tidak valid atau tidak ditemukan pada daftar pertama.
		if not item is String or not first_set.has(item):
			return false

		# Menghapus ID agar tidak dapat digunakan kembali.
		first_set.erase(item)

	# Kedua daftar sama jika seluruh ID pada first_set sudah terhapus.
	return first_set.is_empty()

# Membandingkan daftar action untuk setiap state tanpa memperhatikan urutannya.
static func _same_actions_by_state(first: Variant, second: Variant) -> bool:
	# Memastikan kedua pemetaan berbentuk Dictionary.
	if not first is Dictionary or not second is Dictionary:
		return false

	# Menolak jika jumlah state pada kedua pemetaan berbeda.
	if first.size() != second.size():
		return false

	# Memeriksa kesamaan daftar action pada setiap state.
	for state in first:
		# Menolak jika state dari pemetaan pertama tidak ada di pemetaan kedua.
		if not second.has(state):
			return false

		# Membandingkan himpunan action pada state tersebut tanpa urutan.
		if not _same_id_set(first[state], second[state]):
			return false

	return true

# Memeriksa konfigurasi sebelum model keputusan dibuat.
static func _validate_config(config: Variant) -> Array[String]:
	# Menampung daftar kode error yang ditemukan selama pemeriksaan.
	var errors: Array[String] = []

	# Memastikan konfigurasi berbentuk Dictionary.
	if not config is Dictionary:
		errors.append("INVALID_MODEL")
		return errors

	# Memastikan seluruh komponen model tersedia.
	var required_keys := [
		"initial_states",
		"state_ids",
		"actions_by_state",
		"terminal_states",
		"terminal_classes",
		"reward_by_state",
		"discount_factor"
	]

	# Memeriksa keberadaan setiap kunci wajib dalam konfigurasi.
	for key in required_keys:
		if not config.has(key):
			errors.append("INVALID_MODEL")
			return errors

	# Mengambil setiap komponen konfigurasi untuk diperiksa.
	var state_ids: Variant = config["state_ids"]
	var initial_states: Variant = config["initial_states"]
	var terminal_states: Variant = config["terminal_states"]
	var actions_by_state: Variant = config["actions_by_state"]
	var terminal_classes: Variant = config["terminal_classes"]
	var reward_by_state: Variant = config["reward_by_state"]
	var discount_factor: Variant = config["discount_factor"]

	# Memastikan daftar state memiliki ID unik dan tidak kosong.
	if not _validate_unique_ids(state_ids):
		errors.append("INVALID_MODEL")
		return errors

	# Memastikan daftar initial state memiliki ID unik dan tidak kosong.
	if not _validate_unique_ids(initial_states):
		errors.append("INVALID_MODEL")
		return errors

	# Memastikan terminal_states berbentuk Array.
	if not terminal_states is Array:
		errors.append("INVALID_MODEL")
		return errors

	# Memastikan actions_by_state berbentuk Dictionary.
	if not actions_by_state is Dictionary:
		errors.append("INVALID_MODEL")
		return errors

	# Memastikan terminal_classes berbentuk Dictionary.
	if not terminal_classes is Dictionary:
		errors.append("INVALID_MODEL")
		return errors

	# Memastikan reward_by_state berbentuk Dictionary.
	if not reward_by_state is Dictionary:
		errors.append("INVALID_MODEL")
		return errors

	# Memastikan setiap initial state terdaftar dalam state_ids.
	for state in initial_states:
		if not state_ids.has(state):
			errors.append("INVALID_MODEL")
			return errors

	# Menyimpan terminal state yang valid untuk pemeriksaan duplikasi.
	var terminal_seen: Dictionary = {}

	# Memastikan terminal state terdaftar dan tidak memiliki duplikasi.
	for state in terminal_states:
		# Memastikan terminal state berupa String dan terdaftar di state_ids.
		if not state is String or not state_ids.has(state):
			errors.append("INVALID_MODEL")
			return errors

		# Menolak jika terminal state didefinisikan lebih dari sekali.
		if terminal_seen.has(state):
			errors.append("INVALID_MODEL")
			return errors

		# Menandai state sebagai terminal state yang sah.
		terminal_seen[state] = true

	# Memeriksa daftar action pada setiap state.
	for state in state_ids:
		# Memastikan setiap state memiliki entri di actions_by_state.
		if not actions_by_state.has(state):
			errors.append("INVALID_MODEL")
			return errors

		var actions: Variant = actions_by_state[state]

		# Memastikan daftar action memiliki tipe data yang sesuai.
		if not actions is Array:
			errors.append("INVALID_MODEL")
			return errors

		# Menyimpan action yang sudah diperiksa pada state aktif.
		var action_seen: Dictionary = {}

		# Memastikan setiap action memiliki ID unik.
		for action in actions:
			# Memastikan ID action berupa String dan tidak kosong.
			if not action is String or action.is_empty():
				errors.append("INVALID_MODEL")
				return errors

			# Menolak jika action yang sama muncul ganda pada satu state.
			if action_seen.has(action):
				errors.append("INVALID_MODEL")
				return errors

			# Mencatat action yang valid pada state tersebut.
			action_seen[action] = true

		# Terminal state tidak boleh memiliki action.
		if terminal_seen.has(state) and not actions.is_empty():
			errors.append("TERMINAL_HAS_ACTION")
			return errors

		# Non-terminal state harus memiliki minimal satu action.
		if not terminal_seen.has(state) and actions.is_empty():
			errors.append("EMPTY_ACTIONS")
			return errors

	# Memastikan setiap terminal state memiliki kelas terminal yang valid.
	for state in terminal_states:
		# Menolak jika terminal state belum dipetakan ke terminal_classes.
		if not terminal_classes.has(state):
			errors.append("MISSING_TERMINAL_CLASS")
			return errors

		var terminal_class: Variant = terminal_classes[state]

		# Memastikan nilai kelas hanya SUCCESS atau FAILURE.
		if terminal_class != TERMINAL_SUCCESS and terminal_class != TERMINAL_FAILURE:
			errors.append("INVALID_MODEL")
			return errors

	# Memastikan reward tersedia untuk seluruh state dan nilainya finite.
	for state in state_ids:
		# Menolak jika state tidak memiliki entri reward.
		if not reward_by_state.has(state):
			errors.append("INVALID_MODEL")
			return errors

		# Menolak jika nilai reward bukan angka finite.
		if not _is_finite_number(reward_by_state[state]):
			errors.append("INVALID_MODEL")
			return errors

	# Memastikan discount factor berupa angka finite.
	if not _is_finite_number(discount_factor):
		errors.append("INVALID_PARAMETER")
		return errors

	# Memastikan discount factor berada dalam rentang 0 sampai kurang dari 1.
	if float(discount_factor) < 0.0 or float(discount_factor) >= 1.0:
		errors.append("INVALID_PARAMETER")
		return errors

	return errors

# Membuat model keputusan berdasarkan konfigurasi yang diberikan.
static func create_model(config: Variant) -> Dictionary:
	# Memvalidasi seluruh struktur dan parameter konfigurasi input.
	var errors := _validate_config(config)

	# Mengembalikan error jika konfigurasi tidak memenuhi ketentuan model.
	if not errors.is_empty():
		var status := "INVALID_MODEL"

		# Menggunakan status khusus jika kesalahan berasal dari parameter.
		if errors.has("INVALID_PARAMETER"):
			status = "INVALID_PARAMETER"

		return _result(false, errors, {
			"status": status
		})

	# Menyalin konfigurasi agar perubahan dari luar tidak mengubah model.
	var model := {
		"initial_states": config["initial_states"].duplicate(true),
		"state_ids": config["state_ids"].duplicate(true),
		"actions_by_state": config["actions_by_state"].duplicate(true),
		"terminal_states": config["terminal_states"].duplicate(true),
		"terminal_classes": config["terminal_classes"].duplicate(true),
		"reward_by_state": config["reward_by_state"].duplicate(true),
		"discount_factor": float(config["discount_factor"])
	}

	# Mengembalikan model keputusan yang sudah tervalidasi.
	return _result(true, [], {
		"model": model
	})

# Memeriksa nilai tolerance yang digunakan dalam validasi probabilitas.
static func _validate_tolerance(tolerance: Variant) -> bool:
	# Memastikan tolerance berupa angka finite dan tidak bernilai negatif.
	return _is_finite_number(tolerance) and float(tolerance) >= 0.0

# Memeriksa struktur transisi dan memastikan total probabilitasnya sesuai.
static func _validate_transitions(transitions: Variant, state_ids: Array,tolerance: float) -> Array[String]:
	# Menampung daftar kode error yang ditemukan selama pemeriksaan transisi.
	var errors: Array[String] = []

	# Memastikan daftar transisi tidak kosong.
	if not transitions is Array or transitions.is_empty():
		errors.append("INVALID_TRANSITION")
		return errors

	# Menyimpan akumulasi probabilitas dan ID cabang yang sudah diperiksa.
	var total_probability := 0.0
	var branch_ids: Dictionary = {}

	# Memeriksa setiap cabang transisi.
	for transition in transitions:
		# Memastikan setiap elemen transisi berbentuk Dictionary.
		if not transition is Dictionary:
			errors.append("INVALID_TRANSITION")
			return errors

		# Memastikan atribut wajib transisi tersedia lengkap.
		if not transition.has("branch_id") or not transition.has("next_state") or not transition.has("probability"):
			errors.append("INVALID_TRANSITION")
			return errors

		# Mengambil atribut utama dari cabang transisi.
		var branch_id: Variant = transition["branch_id"]
		var next_state: Variant = transition["next_state"]
		var probability: Variant = transition["probability"]

		# Memastikan setiap cabang memiliki ID yang valid dan unik.
		if not branch_id is String or branch_id.is_empty():
			errors.append("INVALID_TRANSITION")
			return errors

		# Menolak jika branch_id muncul lebih dari sekali.
		if branch_ids.has(branch_id):
			errors.append("INVALID_TRANSITION")
			return errors

		# Mencatat branch_id yang sudah valid.
		branch_ids[branch_id] = true

		# Memastikan state tujuan terdaftar dalam model.
		if not next_state is String or not state_ids.has(next_state):
			errors.append("INVALID_TRANSITION")
			return errors

		# Memastikan probabilitas setiap cabang memiliki nilai yang valid.
		if not _validate_probability(probability):
			errors.append("INVALID_PROBABILITY")
			return errors

		# Menjumlahkan probabilitas setiap cabang, termasuk tujuan yang sama.
		total_probability += float(probability)

	# Total probabilitas seluruh cabang harus mendekati 1.
	if abs(total_probability - 1.0) > tolerance:
		errors.append("INVALID_PROBABILITY_SUM")

	return errors

# Memeriksa kesesuaian metadata transition provider dengan model keputusan.
static func _validate_provider_metadata(model: Dictionary, provider: Dictionary) -> Array[String]:
	# Menampung daftar kode error yang ditemukan selama pemeriksaan metadata.
	var errors: Array[String] = []

	# Memastikan seluruh informasi yang dibutuhkan provider tersedia.
	var required_keys := [
		"get_transitions",
		"actions_by_state",
		"terminal_states",
		"state_ids",
		"initial_states"
	]

	# Memeriksa keberadaan setiap kunci wajib pada provider.
	for key in required_keys:
		if not provider.has(key):
			errors.append("PROVIDER_ERROR")
			return errors

	# Memastikan fungsi pengambilan transisi bertipe Callable.
	if not provider["get_transitions"] is Callable:
		errors.append("PROVIDER_ERROR")
		return errors

	# Memastikan fungsi pengambilan transisi masih valid untuk dipanggil.
	if not provider["get_transitions"].is_valid():
		errors.append("PROVIDER_ERROR")
		return errors

	# Membandingkan daftar state tanpa memperhatikan urutannya.
	if not _same_id_set(provider["state_ids"], model["state_ids"]):
		errors.append("INVALID_MODEL")
		return errors

	# Membandingkan initial state tanpa memperhatikan urutannya.
	if not _same_id_set(provider["initial_states"], model["initial_states"]):
		errors.append("INVALID_MODEL")
		return errors

	# Membandingkan terminal state tanpa memperhatikan urutannya.
	if not _same_id_set(provider["terminal_states"], model["terminal_states"]):
		errors.append("INVALID_MODEL")
		return errors

	# Memastikan daftar action pada setiap state sesuai dengan model.
	if not _same_actions_by_state(provider["actions_by_state"], model["actions_by_state"]):
		errors.append("INVALID_MODEL")
		return errors

	return errors

# Memeriksa struktur model dan seluruh kemungkinan transisi yang disediakan provider.
static func validate_model(model: Variant, provider: Variant, probability_tolerance: float = PROBABILITY_TOLERANCE) -> Dictionary:
	# Memastikan tolerance memiliki nilai yang valid.
	if not _validate_tolerance(probability_tolerance):
		return _result(false, ["INVALID_TOLERANCE"], {
			"status": "INVALID_PARAMETER"
		})

	# Memeriksa konfigurasi model sebelum memeriksa transisinya.
	var config_errors := _validate_config(model)

	# Mengembalikan error jika konfigurasi model tidak valid.
	if not config_errors.is_empty():
		var config_status := "INVALID_MODEL"

		# Menyesuaikan status jika kesalahan berasal dari parameter.
		if config_errors.has("INVALID_PARAMETER"):
			config_status = "INVALID_PARAMETER"

		return _result(false, config_errors, {
			"status": config_status
		})

	# Memastikan provider memiliki struktur yang sesuai.
	if not provider is Dictionary:
		return _result(false, ["PROVIDER_ERROR"], {
			"status": "PROVIDER_ERROR"
		})

	# Memeriksa kecocokan metadata provider terhadap model.
	var metadata_errors := _validate_provider_metadata(model, provider)

	# Mengembalikan error jika metadata provider tidak sesuai.
	if not metadata_errors.is_empty():
		var metadata_status := "INVALID_MODEL"

		# Menyesuaikan status jika kesalahan berasal dari struktur provider.
		if metadata_errors.has("PROVIDER_ERROR"):
			metadata_status = "PROVIDER_ERROR"

		return _result(false, metadata_errors, {
			"status": metadata_status
		})

	# Mengambil fungsi transisi dan daftar state dari model.
	var get_transitions: Callable = provider["get_transitions"]
	var state_ids: Array = model["state_ids"]

	# Memeriksa transisi untuk setiap action pada setiap non-terminal state.
	for state in state_ids:
		# Melewati terminal state karena tidak memiliki transisi lanjutan.
		if model["terminal_states"].has(state):
			continue

		for action in model["actions_by_state"][state]:
			# Meminta daftar cabang transisi untuk pasangan state dan action.
			var transition_result: Variant = get_transitions.call(state, action)

			# Memastikan provider mengembalikan struktur Result.
			if not transition_result is Dictionary:
				return _result(false, ["PROVIDER_ERROR"], {
					"status": "PROVIDER_ERROR"
				})

			# Memastikan hasil provider memiliki kunci standar Result.
			if not transition_result.has("valid") or not transition_result.has("errors") or not transition_result.has("data"):
				return _result(false, ["PROVIDER_ERROR"], {
					"status": "PROVIDER_ERROR"
				})

			# Menolak jika provider melaporkan kegagalan saat mengambil transisi.
			if not transition_result["valid"]:
				return _result(false, ["PROVIDER_ERROR"], {
					"status": "PROVIDER_ERROR"
				})

			# Memastikan hasil provider memiliki daftar transisi.
			if not transition_result["data"] is Dictionary or not transition_result["data"].has("transitions"):
				return _result(false, ["PROVIDER_ERROR"], {
					"status": "PROVIDER_ERROR"
				})

			var transitions: Variant = transition_result["data"]["transitions"]

			# Memeriksa probabilitas dan state tujuan setiap cabang.
			var transition_errors := _validate_transitions(
				transitions,
				state_ids,
				probability_tolerance
			)

			# Mengembalikan error jika ditemukan transisi yang tidak valid.
			if not transition_errors.is_empty():
				return _result(false, transition_errors, {
					"status": "INVALID_MODEL"
				})

	# Mengembalikan status VALID jika seluruh komponen dan transisi lolos uji.
	return _result(true, [], {
		"status": "VALID"
	})

# Mengambil reward berdasarkan state yang diberikan.
static func get_reward(model: Variant, state: Variant) -> Dictionary:
	# Memastikan model memiliki pemetaan reward_by_state.
	if not model is Dictionary or not model.has("reward_by_state"):
		return _result(false, ["INVALID_MODEL"])

	# Memastikan state tersedia dalam model.
	if not state is String or not model["reward_by_state"].has(state):
		return _result(false, ["INVALID_STATE"])

	var reward: Variant = model["reward_by_state"][state]

	# Memastikan reward merupakan angka finite.
	if not _is_finite_number(reward):
		return _result(false, ["INVALID_MODEL"])

	# Mengembalikan state beserta nilai reward dalam tipe float.
	return _result(true, [], {
		"state": state,
		"reward": float(reward)
	})

# Mengambil utility berdasarkan ID outcome yang diberikan.
static func get_utility(utilities: Variant, outcome_id: Variant) -> Dictionary:
	# Memastikan peta utility berbentuk Dictionary.
	if not utilities is Dictionary:
		return _result(false, ["INVALID_UTILITY"])

	# Memastikan outcome tersedia dalam UtilityMap.
	if not outcome_id is String or not utilities.has(outcome_id):
		return _result(false, ["INVALID_OUTCOME"])

	var utility: Variant = utilities[outcome_id]

	# Memastikan utility memiliki nilai numerik yang valid.
	if not _is_finite_number(utility):
		return _result(false, ["INVALID_UTILITY"])

	# Mengembalikan ID outcome beserta nilai utility dalam tipe float.
	return _result(true, [], {
		"outcome_id": outcome_id,
		"utility": float(utility)
	})

# Mengambil daftar action yang dapat dilakukan pada state tertentu.
static func get_actions(model: Variant, state: Variant) -> Dictionary:
	# Memastikan model memiliki pemetaan actions_by_state.
	if not model is Dictionary or not model.has("actions_by_state"):
		return _result(false, ["INVALID_MODEL"])

	# Memastikan state memiliki daftar action.
	if not state is String or not model["actions_by_state"].has(state):
		return _result(false, ["INVALID_STATE"])

	# Mengembalikan salinan daftar action milik state tersebut.
	return _result(true, [], {
		"state": state,
		"actions": model["actions_by_state"][state].duplicate(true)
	})

# Memeriksa apakah state yang diberikan termasuk terminal state.
static func is_terminal(model: Variant, state: Variant) -> Dictionary:
	# Memastikan model memiliki daftar state_ids dan terminal_states.
	if not model is Dictionary or not model.has("state_ids") or not model.has("terminal_states"):
		return _result(false, ["INVALID_MODEL"])

	# Memastikan state terdaftar dalam model.
	if not state is String or not model["state_ids"].has(state):
		return _result(false, ["INVALID_STATE"])

	# Mengembalikan status apakah state termasuk terminal state.
	return _result(true, [], {
		"state": state,
		"is_terminal": model["terminal_states"].has(state)
	})

# Mengambil discount factor yang digunakan dalam model keputusan.
static func get_discount(model: Variant) -> Dictionary:
	# Memastikan model memiliki atribut discount_factor.
	if not model is Dictionary or not model.has("discount_factor"):
		return _result(false, ["INVALID_MODEL"])

	var discount_factor: Variant = model["discount_factor"]

	# Memastikan discount factor memiliki nilai yang valid.
	if not _is_finite_number(discount_factor):
		return _result(false, ["INVALID_PARAMETER"])

	# Memastikan discount factor berada dalam rentang 0 sampai kurang dari 1.
	if float(discount_factor) < 0.0 or float(discount_factor) >= 1.0:
		return _result(false, ["INVALID_PARAMETER"])

	# Mengembalikan nilai discount factor dalam tipe float.
	return _result(true, [], {
		"discount_factor": float(discount_factor)
	})

# Menyediakan ringkasan konfigurasi model untuk kebutuhan pemeriksaan dan integrasi.
static func summarize_model(model: Variant) -> Dictionary:
	# Memastikan model valid sebelum membuat ringkasannya.
	var config_errors := _validate_config(model)

	# Mengembalikan error jika konfigurasi model tidak valid.
	if not config_errors.is_empty():
		return _result(false, config_errors)

	# Mengembalikan salinan konfigurasi beserta jumlah state dan terminal state.
	return _result(true, [], {
		"initial_states": model["initial_states"].duplicate(true),
		"state_ids": model["state_ids"].duplicate(true),
		"actions_by_state": model["actions_by_state"].duplicate(true),
		"terminal_states": model["terminal_states"].duplicate(true),
		"terminal_classes": model["terminal_classes"].duplicate(true),
		"reward_by_state": model["reward_by_state"].duplicate(true),
		"discount_factor": float(model["discount_factor"]),
		"total_states": model["state_ids"].size(),
		"total_terminal_states": model["terminal_states"].size()
	})