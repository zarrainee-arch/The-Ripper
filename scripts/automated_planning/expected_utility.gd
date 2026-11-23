extends RefCounted

# Batas probabilitas dan toleransi perhitungan.
const PROBABILITY_MIN: float = 0.0
const PROBABILITY_MAX: float = 1.0
const PROBABILITY_TOLERANCE: float = 0.000001
const COMPARISON_TOLERANCE: float = 0.000000001

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

	# Memastikan nilai bukan NaN maupun infinity.
	return not is_nan(number) and not is_inf(number)

# Memvalidasi toleransi probabilitas dan perbandingan.
static func _validate_tolerance(value: Variant) -> bool:
	# Memastikan toleransi berupa angka finite dan tidak bernilai negatif.
	return _is_finite_number(value) and float(value) >= 0.0

# Memastikan probabilitas berada dalam rentang yang diperbolehkan.
static func _validate_probability(value: Variant) -> bool:
	# Menolak jika nilai bukan angka finite.
	if not _is_finite_number(value):
		return false

	# Mengonversi nilai probabilitas ke tipe float.
	var probability: float = float(value)

	# Memastikan probabilitas berada dalam rentang [0.0, 1.0].
	return (
		probability >= PROBABILITY_MIN
		and probability <= PROBABILITY_MAX
	)

# Memvalidasi struktur OutcomeList.
static func _validate_outcomes(outcomes: Variant, probability_tolerance: float) -> Dictionary:
	# Memastikan daftar outcome berbentuk Array dan tidak kosong.
	if not outcomes is Array or outcomes.is_empty():
		return _result(false, ["EMPTY_OUTCOMES"])

	# Menyimpan ID outcome yang sudah diperiksa dan akumulasi probabilitas.
	var outcome_ids: Dictionary = {}
	var probability_sum: float = 0.0

	# Memeriksa validitas struktur dan nilai setiap outcome.
	for outcome in outcomes:
		# Memastikan setiap elemen outcome berbentuk Dictionary.
		if not outcome is Dictionary:
			return _result(false, ["INVALID_OUTCOME"])

		# Daftar kunci wajib yang harus dimiliki setiap outcome.
		var required_keys: Array[String] = [
			"id",
			"probability",
			"utility"
		]

		# Memastikan seluruh kunci wajib outcome tersedia.
		for key in required_keys:
			if not outcome.has(key):
				return _result(false, ["INVALID_OUTCOME"])

		# Mengambil atribut ID, probabilitas, dan utility dari outcome.
		var outcome_id: Variant = outcome["id"]
		var probability: Variant = outcome["probability"]
		var utility: Variant = outcome["utility"]

		# ID outcome harus berupa String dan tidak boleh duplikat.
		if not outcome_id is String or outcome_id.is_empty():
			return _result(false, ["INVALID_OUTCOME"])

		# Menolak jika ID outcome yang sama muncul lebih dari sekali.
		if outcome_ids.has(outcome_id):
			return _result(false, ["INVALID_OUTCOME"])

		# Mencatat ID outcome yang valid ke dalam daftar pemeriksaan.
		outcome_ids[outcome_id] = true

		# Probabilitas harus berada pada rentang 0 sampai 1.
		if not _validate_probability(probability):
			return _result(false, ["INVALID_PROBABILITY"])

		# Utility harus berupa angka finite.
		if not _is_finite_number(utility):
			return _result(false, ["INVALID_UTILITY"])

		# Menjumlahkan probabilitas outcome ke akumulasi total.
		probability_sum += float(probability)

		# Memastikan akumulasi probabilitas tidak overflow.
		if not _is_finite_number(probability_sum):
			return _result(false, ["INVALID_PROBABILITY_SUM"])

	# Total probabilitas harus mendekati 1.
	if abs(probability_sum - 1.0) > probability_tolerance:
		return _result(false, ["INVALID_PROBABILITY_SUM"])

	# Mengembalikan status valid jika seluruh outcome memenuhi aturan.
	return _result(true)

# Menghitung Expected Utility dari seluruh outcome.
static func expected_utility(outcomes: Variant, probability_tolerance: float = PROBABILITY_TOLERANCE) -> Dictionary:
	# Memeriksa toleransi sebelum validasi outcome.
	if not _validate_tolerance(probability_tolerance):
		return _result(false, ["INVALID_TOLERANCE"])

	# Memvalidasi struktur dan distribusi probabilitas seluruh outcome.
	var validation: Dictionary = _validate_outcomes(
		outcomes,
		probability_tolerance
	)

	# Menghentikan perhitungan jika validasi outcome gagal.
	if not validation["valid"]:
		return validation

	# Menyiapkan akumulator total EU dan rincian setiap outcome.
	var expected_utility_value: float = 0.0
	var outcome_details: Array = []

	# Menghitung kontribusi utility setiap outcome.
	for outcome in outcomes:
		# Mengambil ID outcome dan mengonversi nilai numeriknya ke float.
		var outcome_id: String = outcome["id"]
		var probability: float = float(outcome["probability"])
		var utility: float = float(outcome["utility"])

		# EU = Σ P(outcome) * Utility(outcome).
		var contribution: float = probability * utility

		# Menolak hasil perkalian yang overflow atau tidak finite.
		if not _is_finite_number(contribution):
			return _result(false, ["INVALID_UTILITY"])

		# Menambahkan kontribusi outcome ke total Expected Utility.
		expected_utility_value += contribution

		# Memastikan hasil penjumlahan tetap finite.
		if not _is_finite_number(expected_utility_value):
			return _result(false, ["INVALID_UTILITY"])

		# Menyimpan rincian perhitungan outcome untuk audit dan evaluasi.
		outcome_details.append({
			"id": outcome_id,
			"probability": probability,
			"utility": utility,
			"contribution": contribution
		})

	# Mengembalikan nilai total Expected Utility beserta rinciannya.
	return _result(
		true,
		[],
		{
			"expected_utility": expected_utility_value,
			"outcome_details": outcome_details
		}
	)

# Mengurutkan aksi berdasarkan Expected Utility tertinggi.
# Jika nilainya sama persis, action ID digunakan sebagai tie-break.
static func _sort_by_value(first: Dictionary, second: Dictionary) -> bool:
	# Mengambil nilai Expected Utility kedua aksi untuk dibandingkan.
	var first_value: float = float(first["expected_utility"])
	var second_value: float = float(second["expected_utility"])

	# Mengurutkan dari nilai Expected Utility tertinggi ke terendah.
	if first_value != second_value:
		return first_value > second_value

	# Menggunakan urutan alfabetis action_id jika nilai EU sama persis.
	return String(first["action_id"]) < String(second["action_id"])

# Mengurutkan kelompok aksi berdasarkan action ID.
static func _sort_by_action_id(first: Dictionary, second: Dictionary) -> bool:
	# Membandingkan ID aksi secara alfabetis menaik.
	return String(first["action_id"]) < String(second["action_id"])

# Memilih aksi dengan Expected Utility maksimum.
static func choose_meu(actions: Variant, probability_tolerance: float = PROBABILITY_TOLERANCE, comparison_tolerance: float = COMPARISON_TOLERANCE) -> Dictionary:
	# Memeriksa kedua toleransi.
	if not _validate_tolerance(probability_tolerance):
		return _result(false, ["INVALID_TOLERANCE"])

	# Memastikan toleransi perbandingan nilai EU valid.
	if not _validate_tolerance(comparison_tolerance):
		return _result(false, ["INVALID_TOLERANCE"])

	# Memastikan pemetaan actions berbentuk Dictionary dan tidak kosong.
	if not actions is Dictionary or actions.is_empty():
		return _result(false, ["EMPTY_ACTIONS"])

	# Menyimpan ID aksi yang sudah diperiksa dan hasil EU setiap aksi.
	var action_ids: Dictionary = {}
	var action_values: Array = []

	# Menghitung Expected Utility untuk setiap aksi.
	for action_id in actions:
		# Memastikan ID aksi berupa String dan tidak kosong.
		if not action_id is String or action_id.is_empty():
			return _result(false, ["INVALID_ACTION"])

		# Menolak jika ditemukan duplikasi ID aksi.
		if action_ids.has(action_id):
			return _result(false, ["INVALID_ACTION"])

		# Mencatat ID aksi yang valid.
		action_ids[action_id] = true

		# Mengambil daftar outcome untuk aksi yang sedang dievaluasi.
		var outcomes: Variant = actions[action_id]

		# Menghitung Expected Utility untuk aksi tersebut.
		var eu_result: Dictionary = expected_utility(
			outcomes,
			probability_tolerance
		)

		# Menghentikan proses jika perhitungan EU salah satu aksi gagal.
		if not eu_result["valid"]:
			return eu_result

		# Menyimpan ringkasan nilai EU dan rincian outcome milik aksi.
		action_values.append({
			"action_id": action_id,
			"expected_utility": eu_result["data"]["expected_utility"],
			"outcome_details": eu_result["data"]["outcome_details"]
		})

	# Mencari nilai EU maksimum yang sebenarnya.
	var maximum_expected_utility: float = -INF

	# Membandingkan seluruh nilai EU aksi untuk memperoleh batas puncak.
	for item in action_values:
		maximum_expected_utility = max(
			maximum_expected_utility,
			float(item["expected_utility"])
		)

	# Menyiapkan kelompok aksi puncak (tie) dan kelompok aksi lainnya.
	var peak_actions: Array = []
	var other_actions: Array = []

	# Memisahkan aksi yang berada dalam rentang tie.
	for item in action_values:
		var eu_value: float = float(item["expected_utility"])

		# Memasukkan ke peak_actions jika selisihnya dalam batas toleransi.
		if eu_value >= maximum_expected_utility - comparison_tolerance:
			peak_actions.append(item)
		else:
			# Memasukkan ke other_actions jika berada di bawah batas toleransi.
			other_actions.append(item)

	# Aksi peak diurutkan berdasarkan action ID.
	peak_actions.sort_custom(_sort_by_action_id)

	# Aksi lainnya diurutkan berdasarkan EU tertinggi.
	# Jika nilainya sama persis, action ID menjadi tie-break.
	other_actions.sort_custom(_sort_by_value)

	# Menggabungkan kelompok peak dan kelompok lainnya menjadi ranking akhir.
	var ranking: Array = []
	ranking.append_array(peak_actions)
	ranking.append_array(other_actions)

	# Memastikan daftar ranking tidak kosong sebelum mengambil aksi terbaik.
	if ranking.is_empty():
		return _result(false, ["EMPTY_ACTIONS"])

	# Aksi pertama pada ranking menjadi rekomendasi MEU.
	var best_action: String = ranking[0]["action_id"]

	# Mengembalikan aksi terbaik, nilai MEU, dan urutan lengkap seluruh aksi.
	return _result(
		true,
		[],
		{
			"best_action": best_action,
			"maximum_expected_utility": maximum_expected_utility,
			"ranking": ranking
		}
	)
