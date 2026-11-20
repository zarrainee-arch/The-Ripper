extends RefCounted

const DECISION_MODEL = preload("res://scripts/decision_model.gd")

# Batas probabilitas dan toleransi perhitungan.
const PROBABILITY_MIN: float = 0.0
const PROBABILITY_MAX: float = 1.0
const PROBABILITY_TOLERANCE: float = 0.000001
const COMPARISON_TOLERANCE: float = 0.000000001

# Parameter default Value Iteration.
const VALUE_ITERATION_EPSILON: float = 0.001
const VALUE_ITERATION_MAX_ITERATIONS: int = 1000

# Status hasil proses MDP.
const STATUS_CONVERGED: String = "CONVERGED"
const STATUS_MAX_ITERATIONS_REACHED: String = "MAX_ITERATIONS_REACHED"
const STATUS_INVALID_MODEL: String = "INVALID_MODEL"
const STATUS_INVALID_PARAMETER: String = "INVALID_PARAMETER"
const STATUS_PROVIDER_ERROR: String = "PROVIDER_ERROR"

# Membuat format Result yang digunakan oleh modul Stage 4.
static func _result(valid: bool, errors: Array[String] = [], data: Dictionary = {}) -> Dictionary:
	# Mengembalikan status validasi, daftar error, dan data hasil.
	return {
		"valid": valid,
		"errors": errors,
		"data": data
	}

# Memeriksa apakah nilai merupakan angka finite.
static func _is_finite_number(value: Variant) -> bool:
	# Menolak tipe non-numerik sebelum melakukan konversi ke float.
	if not (value is int or value is float):
		return false

	# Mengonversi nilai ke float untuk pemeriksaan NaN dan tak hingga.
	var number: float = float(value)

	# Memastikan nilai bukan NaN dan bukan infinity.
	return not is_nan(number) and not is_inf(number)

# Memastikan probabilitas berada dalam rentang yang diperbolehkan.
static func _validate_probability(value: Variant) -> bool:
	# Menolak jika nilai bukan angka finite.
	if not _is_finite_number(value):
		return false

	# Mengonversi nilai probabilitas ke tipe float.
	var probability: float = float(value)

	# Memastikan probabilitas berada di antara 0.0 dan 1.0.
	return (
		probability >= PROBABILITY_MIN
		and probability <= PROBABILITY_MAX
	)

# Memastikan nilai toleransi berupa angka finite dan tidak negatif.
static func _validate_tolerance(value: Variant) -> bool:
	# Memastikan nilai valid secara numerik dan lebih besar atau sama dengan nol.
	return _is_finite_number(value) and float(value) >= 0.0

# Mengambil konfigurasi model dari Dictionary.
static func _get_model_config(model: Variant) -> Dictionary:
	# Menolak jika input model bukan Dictionary.
	if not model is Dictionary:
		return {}

	# Mengembalikan model langsung jika sudah berisi key state_ids.
	if model.has("state_ids"):
		return model

	# Mengambil isi key config jika model dibungkus dalam struktur luar.
	if model.has("config") and model["config"] is Dictionary:
		return model["config"]

	return {}

# Memvalidasi konfigurasi melalui aturan DecisionModel.
static func _validate_model_config(model: Variant) -> Dictionary:
	# Mengambil konfigurasi inti dari parameter model.
	var config: Dictionary = _get_model_config(model)

	# Menolak jika konfigurasi kosong atau formatnya tidak dikenali.
	if config.is_empty():
		return _result(false, ["INVALID_MODEL"])

	# Menggunakan validasi DecisionModel agar aturan tidak diduplikasi.
	var created: Dictionary = DECISION_MODEL.create_model(config)

	# Meneruskan error apabila pembuatan model gagal.
	if not created is Dictionary or not created.get("valid", false):
		if created is Dictionary:
			return _result(
				false,
				created.get("errors", ["INVALID_MODEL"]),
				created.get("data", {})
			)

		return _result(false, ["INVALID_MODEL"])

	# Mengambil bagian data dari hasil pembuatan model.
	var data: Variant = created.get("data", {})

	# Memastikan key model tersedia di dalam data.
	if not data is Dictionary or not data.has("model"):
		return _result(false, ["INVALID_MODEL"])

	# Mengambil objek model yang sudah dinormalisasi.
	var normalized_model: Variant = data["model"]

	# Memastikan model yang dihasilkan berbentuk Dictionary.
	if not normalized_model is Dictionary:
		return _result(false, ["INVALID_MODEL"])

	# Memastikan reward hanya mencakup state yang terdaftar.
	if (
		not normalized_model.has("reward_by_state")
		or not normalized_model["reward_by_state"] is Dictionary
		or normalized_model["reward_by_state"].size()
		!= normalized_model["state_ids"].size()
	):
		return _result(false, ["INVALID_MODEL"])

	# Mengembalikan model yang sudah tervalidasi dan ternormalisasi.
	return _result(true, [], {"model": normalized_model})

# Memvalidasi discount factor secara terpisah.
static func _validate_discount_factor(model: Variant) -> Dictionary:
	# Mengambil konfigurasi model yang menyimpan discount_factor.
	var config: Dictionary = _get_model_config(model)

	# Menolak jika kunci discount_factor tidak ditemukan.
	if not config.has("discount_factor"):
		return _result(
			false,
			["INVALID_PARAMETER"],
			{"status": STATUS_INVALID_PARAMETER}
		)

	# Mengambil nilai discount_factor untuk diperiksa.
	var gamma: Variant = config["discount_factor"]

	# Menolak jika discount_factor bukan angka finite.
	if not _is_finite_number(gamma):
		return _result(
			false,
			["INVALID_PARAMETER"],
			{"status": STATUS_INVALID_PARAMETER}
		)

	# Discount factor harus memenuhi 0 <= gamma < 1.
	if float(gamma) < 0.0 or float(gamma) >= 1.0:
		return _result(
			false,
			["INVALID_PARAMETER"],
			{"status": STATUS_INVALID_PARAMETER}
		)

	# Mengembalikan discount_factor yang valid dalam tipe float.
	return _result(
		true,
		[],
		{"discount_factor": float(gamma)}
	)

# Memvalidasi model dan provider sebelum perhitungan MDP.
static func _prepare_model(model: Variant, provider: Variant, probability_tolerance: float) -> Dictionary:
	# Memastikan nilai toleransi probabilitas valid.
	if not _validate_tolerance(probability_tolerance):
		return _result(false, ["INVALID_TOLERANCE"])

	# Validasi konfigurasi dan normalisasi model.
	var model_check: Dictionary = _validate_model_config(model)

	# Menghentikan persiapan jika konfigurasi model tidak valid.
	if not model_check["valid"]:
		return model_check

	# Mengambil model yang telah dinormalisasi.
	var normalized_model: Dictionary = model_check["data"]["model"]

	# Memastikan discount factor model valid.
	var gamma_check: Dictionary = _validate_discount_factor(normalized_model)

	# Menghentikan persiapan jika discount factor di luar batas.
	if not gamma_check["valid"]:
		return gamma_check

	# Memeriksa kecocokan metadata provider dan seluruh transisi.
	var provider_check: Dictionary = DECISION_MODEL.validate_model(normalized_model, provider, probability_tolerance)

	# Menolak jika hasil validasi provider bukan Dictionary.
	if not provider_check is Dictionary:
		return _result(false, ["PROVIDER_ERROR"])

	# Meneruskan error apabila metadata atau transisi provider bermasalah.
	if not provider_check.get("valid", false):
		return _result(
			false,
			provider_check.get("errors", ["PROVIDER_ERROR"]),
			provider_check.get("data", {})
		)

	# Mengembalikan model yang siap digunakan oleh solver.
	return _result(
		true,
		[],
		{"model": normalized_model}
	)

# Mengambil daftar transisi dari provider.
static func _get_transitions(provider: Variant, state: String, action: String) -> Dictionary:
	# Memastikan provider berbentuk Dictionary.
	if not provider is Dictionary:
		return _result(false, ["PROVIDER_ERROR"])

	# Memastikan provider menyediakan key get_transitions.
	if not provider.has("get_transitions"):
		return _result(false, ["PROVIDER_ERROR"])

	# Mengambil referensi fungsi transisi dari provider.
	var transition_callable: Variant = provider["get_transitions"]

	# Memastikan get_transitions bertipe Callable.
	if not transition_callable is Callable:
		return _result(false, ["PROVIDER_ERROR"])

	# Memastikan Callable masih aktif dan dapat dipanggil.
	if not transition_callable.is_valid():
		return _result(false, ["PROVIDER_ERROR"])

	# Memanggil fungsi transisi untuk pasangan state dan action.
	var transition_result: Variant = transition_callable.call(state, action)

	# Memastikan keluaran provider berupa Dictionary.
	if not transition_result is Dictionary:
		return _result(false, ["PROVIDER_ERROR"])

	# Memastikan struktur standar Result (valid dan data) tersedia.
	if (
		not transition_result.has("valid")
		or not transition_result.has("data")
		or not transition_result["valid"] is bool
	):
		return _result(false, ["PROVIDER_ERROR"])

	# Menolak jika provider melaporkan kegagalan saat pengambilan transisi.
	if not transition_result["valid"]:
		return _result(false, ["PROVIDER_ERROR"])

	# Memastikan bagian data dari hasil provider berbentuk Dictionary.
	if not transition_result["data"] is Dictionary:
		return _result(false, ["PROVIDER_ERROR"])

	# Mengambil payload data transisi dari provider.
	var transition_data: Dictionary = transition_result["data"]

	# Memastikan key transitions tersedia di dalam payload data.
	if not transition_data.has("transitions"):
		return _result(false, ["PROVIDER_ERROR"])

	# Memastikan daftar transitions berbentuk Array.
	if not transition_data["transitions"] is Array:
		return _result(false, ["PROVIDER_ERROR"])

	# Mengembalikan daftar cabang transisi yang berhasil diambil.
	return _result(
		true,
		[],
		{"transitions": transition_data["transitions"]}
	)

# Memvalidasi setiap cabang transisi sebelum digunakan.
static func _validate_transition_list(transitions: Variant, state_ids: Array, probability_tolerance: float) -> Dictionary:
	# Memastikan daftar transisi berbentuk Array dan tidak kosong.
	if not transitions is Array or transitions.is_empty():
		return _result(false, ["INVALID_TRANSITION"])

	# Menyimpan himpunan state terdaftar untuk pencarian cepat.
	var known_states: Dictionary = {}

	# Mendaftarkan setiap ID state ke dalam lookup dictionary.
	for state in state_ids:
		known_states[state] = true

	# Menyimpan ID cabang yang sudah diperiksa dan akumulasi probabilitas.
	var branch_ids: Dictionary = {}
	var probability_sum: float = 0.0

	# Memeriksa struktur dan nilai setiap cabang transisi.
	for branch in transitions:
		# Memastikan setiap elemen cabang berbentuk Dictionary.
		if not branch is Dictionary:
			return _result(false, ["INVALID_TRANSITION"])

		# Daftar kunci wajib yang harus dimiliki setiap cabang.
		var required_keys: Array[String] = [
			"branch_id",
			"next_state",
			"probability"
		]

		# Memastikan seluruh kunci wajib cabang tersedia.
		for key in required_keys:
			if not branch.has(key):
				return _result(false, ["INVALID_TRANSITION"])

		# Mengambil atribut cabang untuk divalidasi.
		var branch_id: Variant = branch["branch_id"]
		var next_state: Variant = branch["next_state"]
		var probability: Variant = branch["probability"]

		# ID cabang harus berupa String dan tidak boleh duplikat.
		if not branch_id is String or branch_id.is_empty():
			return _result(false, ["INVALID_TRANSITION"])

		# Menolak jika branch_id sudah pernah muncul pada daftar ini.
		if branch_ids.has(branch_id):
			return _result(false, ["INVALID_TRANSITION"])

		# Mencatat branch_id yang valid.
		branch_ids[branch_id] = true

		# State tujuan harus terdaftar dalam model.
		if not next_state is String or not known_states.has(next_state):
			return _result(false, ["INVALID_TRANSITION"])

		# Memastikan probabilitas cabang berada dalam rentang [0.0, 1.0].
		if not _validate_probability(probability):
			return _result(false, ["INVALID_PROBABILITY"])

		# Menjumlahkan probabilitas cabang ke akumulasi total.
		probability_sum += float(probability)

		# Memastikan penjumlahan probabilitas tidak overflow.
		if not _is_finite_number(probability_sum):
			return _result(false, ["INVALID_PROBABILITY_SUM"])

	# Total probabilitas seluruh cabang harus mendekati 1.
	if abs(probability_sum - 1.0) > probability_tolerance:
		return _result(false, ["INVALID_PROBABILITY_SUM"])

	return _result(true)

# Memastikan nilai V tersedia dan finite untuk seluruh state.
# Nilai V pada terminal state harus tepat 0.0.
static func _validate_values(values: Variant, state_ids: Array, terminal_states: Array) -> Dictionary:
	# Memastikan vektor nilai V berbentuk Dictionary.
	if not values is Dictionary:
		return _result(false, ["INVALID_VALUES"])

	# Memastikan jumlah entri V sama persis dengan jumlah state model.
	if values.size() != state_ids.size():
		return _result(false, ["INVALID_VALUES"])

	# Memeriksa keberadaan dan keabsahan nilai setiap state.
	for state in state_ids:
		# Menolak jika state tidak memiliki nilai di dalam V.
		if not values.has(state):
			return _result(false, ["INVALID_VALUES"])

		# Menolak jika nilai V(s) bukan angka finite.
		if not _is_finite_number(values[state]):
			return _result(false, ["INVALID_VALUES"])

		# Terminal state tidak memiliki nilai masa depan.
		if terminal_states.has(state):
			if float(values[state]) != 0.0:
				return _result(false, ["INVALID_VALUES"])

	return _result(true)

# Memeriksa apakah state merupakan terminal state.
static func _is_terminal_state(terminal_states: Array, state: String) -> bool:
	# Mengembalikan true apabila state terdaftar di terminal_states.
	return terminal_states.has(state)

# Mengambil reward berdasarkan state tujuan.
static func _get_state_reward(reward_by_state: Dictionary, state: String) -> float:
	# Mengembalikan nilai reward state tujuan dalam tipe float.
	return float(reward_by_state[state])

# Mengurutkan aksi berdasarkan nilai Q tertinggi.
# Jika nilai Q sama persis, action ID digunakan sebagai tie-break.
static func _sort_actions_by_value(first: Dictionary, second: Dictionary) -> bool:
	# Mengambil nilai Q dari kedua aksi yang dibandingkan.
	var first_value: float = float(first["q_value"])
	var second_value: float = float(second["q_value"])

	# Mengurutkan dari nilai Q tertinggi ke terendah.
	if first_value != second_value:
		return first_value > second_value

	# Menggunakan urutan alfabetis action_id jika nilai Q identik.
	return String(first["action_id"]) < String(second["action_id"])

# Mengurutkan aksi dengan mempertimbangkan comparison tolerance.
static func _rank_actions(action_values: Array,comparison_tolerance: float) -> Array:
	# Menampung hasil akhir urutan ranking aksi.
	var ranking: Array = []

	# Mengembalikan daftar kosong jika tidak ada aksi yang dievaluasi.
	if action_values.is_empty():
		return ranking

	# Menyimpan nilai Q tertinggi absolut sebagai acuan kelompok peak.
	var maximum_q: float = -INF

	# Mencari nilai Q maksimum yang sebenarnya.
	for item in action_values:
		maximum_q = max(maximum_q, float(item["q_value"]))

	# Menyiapkan kelompok aksi puncak (tie) dan kelompok aksi lainnya.
	var peak_actions: Array = []
	var other_actions: Array = []

	# Memisahkan aksi yang dianggap tie dengan aksi lainnya.
	for item in action_values:
		var q_value: float = float(item["q_value"])

		# Memasukkan aksi ke peak_actions jika selisihnya masih dalam toleransi.
		if q_value >= maximum_q - comparison_tolerance:
			peak_actions.append(item)
		else:
			# Memasukkan aksi ke other_actions jika berada di bawah batas toleransi.
			other_actions.append(item)

	# Aksi dalam kelompok peak diurutkan berdasarkan ID.
	peak_actions.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a["action_id"]) < String(b["action_id"])
	)

	# Aksi lainnya diurutkan berdasarkan Q, lalu ID jika nilainya sama.
	other_actions.sort_custom(_sort_actions_by_value)

	# Menggabungkan kelompok peak di urutan teratas diikuti aksi lainnya.
	ranking.append_array(peak_actions)
	ranking.append_array(other_actions)

	return ranking

# Menghitung Q(s,a) tanpa mengulang validasi penuh model dan provider.
static func _compute_q_internal(model: Dictionary, state: Variant, action: Variant, provider: Variant,values: Variant, probability_tolerance: float) -> Dictionary:
	# Mengambil referensi konfigurasi model yang sudah ternormalisasi.
	var config: Dictionary = model

	# Memastikan state bertipe String dan terdaftar dalam model.
	if not state is String or not config["state_ids"].has(state):
		return _result(false, ["INVALID_STATE"])

	# Memastikan action bertipe String.
	if not action is String:
		return _result(false, ["INVALID_ACTION"])

	# Terminal state tidak memiliki aksi yang dapat dievaluasi.
	if config["terminal_states"].has(state):
		return _result(false, ["INVALID_ACTION"])

	# Mengambil daftar aksi legal milik state yang diminta.
	var actions: Array = config["actions_by_state"][state]

	# Menolak jika action tidak termasuk aksi legal pada state tersebut.
	if not actions.has(action):
		return _result(false, ["INVALID_ACTION"])

	# Memastikan toleransi probabilitas bernilai valid.
	if not _validate_tolerance(probability_tolerance):
		return _result(false, ["INVALID_TOLERANCE"])

	# Nilai V harus tersedia untuk semua state dan terminal harus nol.
	var values_check: Dictionary = _validate_values(values, config["state_ids"], config["terminal_states"])

	# Menghentikan perhitungan jika vektor nilai V tidak valid.
	if not values_check["valid"]:
		return values_check

	# Mengambil transisi untuk aksi yang sedang dievaluasi.
	var transition_result: Dictionary = _get_transitions(provider, state,action)

	# Menghentikan perhitungan jika pengambilan transisi gagal.
	if not transition_result["valid"]:
		return transition_result

	# Mengambil daftar cabang transisi dari hasil provider.
	var transitions: Array = transition_result["data"]["transitions"]

	# Memvalidasi struktur dan total probabilitas daftar cabang transisi.
	var transition_check: Dictionary = _validate_transition_list(transitions, config["state_ids"], probability_tolerance)

	# Menghentikan perhitungan jika daftar transisi tidak valid.
	if not transition_check["valid"]:
		return transition_check

	# Mengambil tabel reward dan discount factor dari model.
	var reward_by_state: Dictionary = config["reward_by_state"]
	var gamma: float = float(config["discount_factor"])

	# Menyiapkan akumulator nilai Q dan daftar rincian setiap cabang.
	var q_value: float = 0.0
	var branch_details: Array = []

	# Menghitung kontribusi Bellman untuk setiap cabang.
	for branch in transitions:
		# Mengambil state tujuan dan probabilitas cabang aktif.
		var next_state: String = branch["next_state"]
		var probability: float = float(branch["probability"])

		# Mengambil reward state tujuan dari tabel reward model.
		var reward: float = _get_state_reward(reward_by_state, next_state)

		# Mengambil nilai V(next_state) dari iterasi aktif.
		var next_value: float = float(values[next_state])

		# Q(s,a) = Σ p * (R(s') + gamma * V(s')).
		var contribution: float = probability * (reward + gamma * next_value)

		# Menolak hasil perkalian yang overflow atau tidak finite.
		if not _is_finite_number(contribution):
			return _result(false, ["INVALID_VALUES"])

		# Menjumlahkan kontribusi setiap cabang.
		q_value += contribution

		# Memastikan hasil akumulasi Q tetap finite.
		if not _is_finite_number(q_value):
			return _result(false, ["INVALID_VALUES"])

		# Menyimpan rincian perhitungan cabang untuk evaluasi dan audit.
		branch_details.append({
			"branch_id": branch["branch_id"],
			"next_state": next_state,
			"probability": probability,
			"reward": reward,
			"next_value": next_value,
			"contribution": contribution
		})

	# Mengembalikan nilai Q(s,a) beserta rincian tiap cabang.
	return _result(
		true,
		[],
		{
			"state": state,
			"action": action,
			"q_value": q_value,
			"branch_details": branch_details
		}
	)

# Menghitung Q(s,a) melalui API publik.
static func compute_q(model: Variant, state: Variant, action: Variant, provider: Variant, values: Variant, probability_tolerance: float = PROBABILITY_TOLERANCE) -> Dictionary:
	# Memvalidasi model dan provider secara penuh sebelum menghitung Q.
	var prepared: Dictionary = _prepare_model(model, provider, probability_tolerance)

	# Meneruskan error apabila model atau provider tidak valid.
	if not prepared["valid"]:
		return prepared

	# Mengambil model yang telah dinormalisasi.
	var normalized_model: Dictionary = prepared["data"]["model"]

	# Menghitung nilai Q menggunakan fungsi internal.
	return _compute_q_internal(
		normalized_model,
		state,
		action,
		provider,
		values,
		probability_tolerance
	)

# Mengekstrak policy berdasarkan nilai V yang sudah tersedia.
static func _extract_policy_internal(model: Dictionary, values: Variant, provider: Variant, probability_tolerance: float, comparison_tolerance: float) -> Dictionary:
	# Mengambil referensi konfigurasi model yang sudah ternormalisasi.
	var config: Dictionary = model

	# Memastikan nilai toleransi probabilitas valid.
	if not _validate_tolerance(probability_tolerance):
		return _result(false, ["INVALID_TOLERANCE"])

	# Memastikan nilai toleransi perbandingan nilai Q valid.
	if not _validate_tolerance(comparison_tolerance):
		return _result(false, ["INVALID_TOLERANCE"])

	# Memastikan nilai V valid dan terminal state bernilai nol.
	var values_check: Dictionary = _validate_values(values, config["state_ids"], config["terminal_states"])

	# Menghentikan ekstraksi jika vektor nilai V tidak valid.
	if not values_check["valid"]:
		return values_check

	# Menyiapkan struktur hasil policy, aksi terpilih, dan peringkat aksi.
	var policy: Dictionary = {}
	var selected_actions: Dictionary = {}
	var action_rankings: Dictionary = {}

	# Policy hanya dibuat untuk state nonterminal.
	for state in config["state_ids"]:
		# Melewati terminal state karena tidak membutuhkan keputusan aksi.
		if _is_terminal_state(config["terminal_states"], state):
			continue

		# Mengambil daftar aksi legal dan menyiapkan daftar nilai Q-nya.
		var actions: Array = config["actions_by_state"][state]
		var action_values: Array = []

		# Menghitung Q untuk setiap aksi legal.
		for action in actions:
			var q_result: Dictionary = _compute_q_internal(
				config,
				state,
				action,
				provider,
				values,
				probability_tolerance
			)

			# Menghentikan proses jika evaluasi salah satu aksi gagal.
			if not q_result["valid"]:
				return q_result

			# Mencatat pasangan action_id dan nilai Q hasil perhitungan.
			action_values.append({
				"action_id": action,
				"q_value": q_result["data"]["q_value"]
			})

		# Mengurutkan seluruh aksi kandidat berdasarkan nilai Q dan toleransi.
		var ranking: Array = _rank_actions(action_values,comparison_tolerance)

		# Menolak jika tidak ada aksi yang berhasil diranking.
		if ranking.is_empty():
			return _result(false, ["EMPTY_ACTIONS"])

		# Aksi peringkat pertama menjadi rekomendasi policy.
		policy[state] = ranking[0]["action_id"]
		selected_actions[state] = ranking[0]["action_id"]
		action_rankings[state] = ranking

	# Mengembalikan policy optimal beserta rincian peringkat aksinya.
	return _result(
		true,
		[],
		{
			"policy": policy,
			"selected_actions": selected_actions,
			"action_rankings": action_rankings
		}
	)

# Mengekstrak policy melalui API publik.
static func extract_policy(model: Variant, values: Variant, provider: Variant, probability_tolerance: float = PROBABILITY_TOLERANCE, comparison_tolerance: float = COMPARISON_TOLERANCE) -> Dictionary:
	# Memvalidasi model dan provider sebelum ekstraksi policy.
	var prepared: Dictionary = _prepare_model(model, provider, probability_tolerance)

	# Meneruskan error apabila model atau provider tidak valid.
	if not prepared["valid"]:
		return prepared

	# Mengambil model yang telah dinormalisasi.
	var normalized_model: Dictionary = prepared["data"]["model"]

	# Mengekstrak policy menggunakan fungsi internal.
	return _extract_policy_internal(
		normalized_model,
		values,
		provider,
		probability_tolerance,
		comparison_tolerance
	)

# Mengubah error validasi menjadi status Value Iteration.
static func _get_validation_status(validation_result: Dictionary) -> String:
	# Mengambil data tambahan dari hasil validasi jika tersedia.
	var data: Variant = validation_result.get("data", {})

	# Memeriksa apakah hasil validasi sudah membawa kode status spesifik.
	if data is Dictionary and data.has("status"):
		var status: String = str(data["status"])

		# Mengembalikan status parameter jika kesalahan berasal dari parameter.
		if status == STATUS_INVALID_PARAMETER:
			return STATUS_INVALID_PARAMETER

		# Mengembalikan status provider jika kesalahan berasal dari provider.
		if status == STATUS_PROVIDER_ERROR:
			return STATUS_PROVIDER_ERROR

	# Menggunakan STATUS_INVALID_MODEL sebagai status default kegagalan model.
	return STATUS_INVALID_MODEL

# Menjalankan Value Iteration untuk memperoleh nilai V dan policy optimal.
static func value_iteration(
	model: Variant,
	provider: Variant,
	epsilon: float = VALUE_ITERATION_EPSILON,
	max_iterations: int = VALUE_ITERATION_MAX_ITERATIONS,
	probability_tolerance: float = PROBABILITY_TOLERANCE,
	comparison_tolerance: float = COMPARISON_TOLERANCE
) -> Dictionary:
	# Memeriksa parameter iterasi sebelum memulai proses.
	if not _is_finite_number(epsilon) or epsilon <= 0.0:
		return _result(
			false,
			["INVALID_EPSILON"],
			{
				"status": STATUS_INVALID_PARAMETER,
				"iterations": 0
			}
		)

	# Memastikan max_iterations berupa bilangan bulat positif.
	if not max_iterations is int or max_iterations <= 0:
		return _result(
			false,
			["INVALID_MAX_ITERATIONS"],
			{
				"status": STATUS_INVALID_PARAMETER,
				"iterations": 0
			}
		)

	# Memastikan nilai toleransi probabilitas valid.
	if not _validate_tolerance(probability_tolerance):
		return _result(
			false,
			["INVALID_TOLERANCE"],
			{
				"status": STATUS_INVALID_PARAMETER,
				"iterations": 0
			}
		)

	# Memastikan nilai toleransi perbandingan Q valid.
	if not _validate_tolerance(comparison_tolerance):
		return _result(
			false,
			["INVALID_TOLERANCE"],
			{
				"status": STATUS_INVALID_PARAMETER,
				"iterations": 0
			}
		)

	# Validasi penuh model dan provider cukup dilakukan sekali di awal.
	var prepared: Dictionary = _prepare_model(model, provider, probability_tolerance)

	# Menghentikan proses jika model atau provider gagal validasi.
	if not prepared["valid"]:
		return _result(
			false,
			prepared["errors"],
			{
				"status": _get_validation_status(prepared),
				"iterations": 0
			}
		)

	# Mengambil konfigurasi model yang sudah ternormalisasi.
	var config: Dictionary = prepared["data"]["model"]

	# Mengambil komponen utama state, terminal, dan daftar aksi.
	var state_ids: Array = config["state_ids"]
	var terminal_states: Array = config["terminal_states"]
	var actions_by_state: Dictionary = config["actions_by_state"]

	# Nilai awal seluruh state dimulai dari nol.
	var values: Dictionary = {}

	# Menginisialisasi setiap state dengan nilai awal 0.0.
	for state in state_ids:
		values[state] = 0.0

	# Terminal state selalu memiliki nilai V sebesar nol.
	for state in terminal_states:
		values[state] = 0.0

	# Menyiapkan penghitung iterasi, perubahan maksimum (delta), dan flag konvergensi.
	var iterations: int = 0
	var delta: float = INF
	var converged: bool = false

	# Melakukan pembaruan Bellman sampai konvergen atau batas iterasi tercapai.
	while iterations < max_iterations:
		# Menyalin vektor nilai V saat ini untuk pembaruan sinkron.
		var new_values: Dictionary = values.duplicate(true)
		delta = 0.0

		# Setiap state dihitung menggunakan nilai dari iterasi sebelumnya.
		for state in state_ids:
			# Menjaga nilai terminal state tetap nol tanpa mengevaluasi aksi.
			if _is_terminal_state(terminal_states, state):
				new_values[state] = 0.0
				continue

			# Mengambil daftar aksi legal milik state yang sedang dievaluasi.
			var actions: Array = actions_by_state[state]
			var maximum_q: float = -INF

			# Mencari nilai Q tertinggi dari seluruh aksi legal.
			for action in actions:
				var q_result: Dictionary = _compute_q_internal(config, state, action, provider, values, probability_tolerance)

				# Menghentikan iterasi apabila evaluasi nilai Q mengalami error.
				if not q_result["valid"]:
					var error_status: String = STATUS_INVALID_MODEL

					# Menyesuaikan status apabila error berasal dari provider.
					if q_result["errors"].has("PROVIDER_ERROR"):
						error_status = STATUS_PROVIDER_ERROR

					return _result(
						false,
						q_result["errors"],
						{
							"status": error_status,
							"iterations": iterations
						}
					)

				# Mengambil nilai Q hasil perhitungan cabang Bellman.
				var q_value: float = float(q_result["data"]["q_value"])

				# V(s) menggunakan nilai maksimum Q yang sebenarnya.
				maximum_q = max(maximum_q, q_value)

			# Menolak jika tidak ditemukan nilai Q yang valid untuk state nonterminal.
			if maximum_q == -INF:
				return _result(
					false,
					["EMPTY_ACTIONS"],
					{
						"status": STATUS_INVALID_MODEL,
						"iterations": iterations
					}
				)

			# Menyimpan nilai V baru hasil pembaruan Bellman pada state ini.
			new_values[state] = maximum_q

			# Menghitung perubahan nilai state pada iterasi ini.
			var difference: float = abs(
				float(new_values[state]) - float(values[state])
			)

			# Menolak jika hasil selisih perubahan tidak finite.
			if not _is_finite_number(difference):
				return _result(
					false,
					["INVALID_VALUES"],
					{
						"status": STATUS_INVALID_MODEL,
						"iterations": iterations
					}
				)

			# Memperbarui selisih perubahan terbesar di seluruh state.
			delta = max(delta, difference)

		# Memastikan perubahan maksimum tetap finite.
		if not _is_finite_number(delta):
			return _result(
				false,
				["INVALID_VALUES"],
				{
					"status": STATUS_INVALID_MODEL,
					"iterations": iterations
				}
			)

		# Memperbarui seluruh nilai secara sinkron.
		values = new_values
		iterations += 1

		# Konvergen jika perubahan maksimum mencapai atau di bawah epsilon.
		if delta <= epsilon:
			converged = true
			break

	# Jika batas iterasi tercapai, policy belum boleh dikeluarkan.
	if not converged:
		return _result(
			false,
			["MAX_ITERATIONS_REACHED"],
			{
				"status": STATUS_MAX_ITERATIONS_REACHED,
				"iterations": iterations,
				"delta": delta,
				"values": values
			}
		)

	# Policy hanya diekstrak setelah Value Iteration konvergen.
	var policy_result: Dictionary = _extract_policy_internal(config, values, provider, probability_tolerance, comparison_tolerance)

	# Mengembalikan error apabila proses ekstraksi policy gagal.
	if not policy_result["valid"]:
		var policy_status: String = STATUS_INVALID_MODEL

		# Menyesuaikan status apabila kegagalan berasal dari provider.
		if policy_result["errors"].has("PROVIDER_ERROR"):
			policy_status = STATUS_PROVIDER_ERROR

		return _result(
			false,
			policy_result["errors"],
			{
				"status": policy_status,
				"iterations": iterations,
				"delta": delta,
				"values": values
			}
		)

	# Mengembalikan nilai akhir dan policy hasil Value Iteration.
	return _result(
		true,
		[],
		{
			"status": STATUS_CONVERGED,
			"iterations": iterations,
			"delta": delta,
			"values": values,
			"policy": policy_result["data"]["policy"],
			"selected_actions": policy_result["data"]["selected_actions"],
			"action_rankings": policy_result["data"]["action_rankings"]
		}
	)