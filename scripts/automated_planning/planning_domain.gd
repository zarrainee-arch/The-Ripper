
extends RefCounted
class_name PlanningDomain

# Konstanta jenis aksi yang dapat dilakukan NPC.
const ACTION_NORMAL := "NORMAL_ATTACK"
const ACTION_COORDINATED := "COORDINATED_ATTACK"
const ACTION_WAIT := "WAIT"

# Konstanta untuk membedakan peran NPC sebagai Leader dan Follower.
const ROLE_LEADER := "LEADER"
const ROLE_FOLLOWER := "FOLLOWER"

# Biaya setiap aksi yang digunakan untuk menghitung total cost dalam planner.
const COST_NORMAL := 2
const COST_COORDINATED := 1
const COST_WAIT := 3

# Membentuk state awal berdasarkan kondisi NPC dan target yang diperoleh dari battle.
static func create_initial_state(npcs: Array, target_alive: bool, wait_supported: bool = false, wait_advised_ids: Array = []) -> Dictionary:
    var state := {
        "alive": [], # Menyimpan ID seluruh NPC yang masih hidup.
        "roles": {}, # Menyimpan peran masing-masing NPC.
        "resolved": [], # Menyimpan NPC yang sudah menyelesaikan aksinya pada ronde ini.
        "coord_used": [], # Menyimpan Follower yang sudah menggunakan aksi koordinasi.
        "leader_attacked": false, # Menandakan apakah Leader sudah berhasil menjalankan serangan.
        "target_alive": target_alive, # Menyimpan kondisi hidup atau matinya target.
        "wait_supported": wait_supported, # Menandakan apakah battle mendukung aksi WAIT.
        "wait_advised": [], # Menyimpan NPC yang mendapat anjuran WAIT dari inference engine.
        "blocked": [] # Menyimpan aksi yang diblokir agar tidak dipilih kembali oleh planner.
    }

    # Memeriksa seluruh NPC untuk membentuk kondisi state awal.
    for npc in npcs:
        if int(npc.get("hp", 0)) <= 0:
            continue # NPC yang sudah mati tidak dimasukkan ke dalam state.

        var npc_id: String = str(npc.get("npc_id", ""))

        if npc_id.is_empty():
            continue # NPC tanpa ID tidak dapat diproses oleh planner.

        state["alive"].append(npc_id)
        state["roles"][npc_id] = str(npc.get("role", ROLE_FOLLOWER))

        # NPC hanya mendapat batasan WAIT jika battle mendukung WAIT dan ID-nya terdapat dalam hasil inferensi.
        if wait_supported and wait_advised_ids.has(npc_id):
            state["wait_advised"].append(npc_id)

    # Mengurutkan ID NPC secara numerik agar urutan pemrosesan selalu konsisten.
    state["alive"].sort_custom(_compare_npc_id)
    state["wait_advised"].sort_custom(_compare_npc_id)

    return state # Mengembalikan state awal untuk digunakan oleh planner.

# Memeriksa apakah masih terdapat Leader yang hidup di dalam state.
static func has_alive_leader(state: Dictionary) -> bool:
    for npc_id in state["alive"]:
        if state["roles"].get(npc_id, ROLE_FOLLOWER) == ROLE_LEADER:
            return true # Mengembalikan true jika ditemukan Leader yang masih hidup.
    return false # Mengembalikan false jika tidak ada Leader yang hidup.

# Membentuk identitas unik suatu aksi berdasarkan jenis aksi dan ID NPC.
static func make_action_key(action_type: String, npc_id: String) -> String:
    return "%s|%s" % [action_type, npc_id]

# Memeriksa apakah seluruh NPC yang masih hidup sudah menyelesaikan aksinya.
static func is_goal(state: Dictionary) -> bool:
    for npc_id in state["alive"]:
        if not state["resolved"].has(npc_id):
            return false # Goal belum tercapai jika masih ada NPC hidup yang belum menyelesaikan aksinya.
    return true # Goal tercapai jika seluruh NPC hidup sudah resolved.

# Memeriksa apakah suatu aksi memenuhi seluruh precondition dalam planning domain.
static func is_action_valid(state: Dictionary, action: Dictionary) -> bool:
    var npc_id: String = str(action.get("npc", ""))
    var action_type: String = str(action.get("type", ""))

    # Memastikan aksi memiliki ID NPC dan jenis aksi yang valid.
    if npc_id.is_empty() or action_type.is_empty():
        return false

    # NPC harus masih hidup agar dapat melakukan aksi.
    if not state["alive"].has(npc_id):
        return false

    # NPC yang sudah menyelesaikan aksinya tidak boleh bertindak kembali.
    if state["resolved"].has(npc_id):
        return false

    # Aksi tidak dapat dilakukan jika target sudah mati.
    if not state["target_alive"]:
        return false

    # Menolak aksi yang sebelumnya sudah diblokir oleh controller.
    if state["blocked"].has(make_action_key(action_type, npc_id)):
        return false

    var role: String = state["roles"].get(npc_id, ROLE_FOLLOWER)

    # NPC yang mendapat wait_advised hanya diperbolehkan melakukan WAIT.
    if state["wait_advised"].has(npc_id):
        return action_type == ACTION_WAIT and state["wait_supported"]

    # Memeriksa precondition berdasarkan jenis aksi yang akan dilakukan.
    match action_type:
        ACTION_NORMAL:
            return true # NORMAL_ATTACK dapat dilakukan oleh NPC hidup yang belum resolved dan memiliki target hidup.

        ACTION_COORDINATED:
            return(
                role == ROLE_FOLLOWER and
                state["leader_attacked"] and
                has_alive_leader(state) and
                not state["coord_used"].has(npc_id)
            ) # COORDINATED_ATTACK hanya dapat dilakukan Follower setelah Leader menyerang dan selama Leader masih hidup.

        ACTION_WAIT:
            return false # WAIT tidak diperbolehkan jika NPC tidak mendapat anjuran WAIT.

    return false # Menolak jenis aksi yang tidak dikenal oleh domain.

# Menghasilkan seluruh aksi yang memenuhi precondition untuk setiap NPC yang masih hidup.
static func get_available_actions(state: Dictionary) -> Array:
    var actions: Array = []

    # Tidak menghasilkan aksi jika target sudah mati.
    if not state["target_alive"]:
        return actions

    # Memeriksa seluruh NPC yang masih hidup untuk mencari aksi yang dapat dilakukan.
    for npc_id in state["alive"]:
        if state["resolved"].has(npc_id):
            continue # NPC yang sudah menyelesaikan aksinya tidak perlu diperiksa kembali.

        var candidates: Array = []

        # NPC yang mendapat anjuran WAIT hanya memiliki satu kandidat aksi, yaitu WAIT.
        if state["wait_advised"].has(npc_id):
            candidates.append({
                "type": ACTION_WAIT,
                "npc": npc_id,
                "cost": COST_WAIT
            })
        else:
            # NPC biasa dapat dipertimbangkan untuk melakukan NORMAL_ATTACK.
            candidates.append({
                "type": ACTION_NORMAL,
                "npc": npc_id,
                "cost": COST_NORMAL
            })

            # COORDINATED_ATTACK akan diterima hanya jika seluruh precondition terpenuhi.
            candidates.append({
                "type": ACTION_COORDINATED,
                "npc": npc_id,
                "cost": COST_COORDINATED
            })

        # Memasukkan kandidat aksi yang sudah lolos pemeriksaan validasi.
        for candidate in candidates:
            if is_action_valid(state, candidate):
                actions.append(candidate)

    # Mengurutkan aksi berdasarkan ID NPC dan jenis aksi untuk menjaga urutan deterministik.
    actions.sort_custom(_compare_actions)
    return actions

# Menghasilkan state baru berdasarkan effect dari aksi yang berhasil diterapkan dalam simulasi planning.
static func apply_action(state: Dictionary, action: Dictionary) -> Dictionary:
    if not is_action_valid(state, action):
        return {} # Mengembalikan Dictionary kosong jika aksi tidak memenuhi precondition.

    var next_state: Dictionary = state.duplicate(true) # Membuat salinan state agar state sebelumnya tidak berubah.
    var npc_id: String = action["npc"]
    var action_type: String = action["type"]

    # Setiap aksi yang diterapkan membuat NPC tersebut berstatus resolved.
    next_state["resolved"].append(npc_id)
    next_state["resolved"].sort_custom(_compare_npc_id)

    # Follower yang melakukan koordinasi ditandai agar tidak dapat berkoordinasi dua kali.
    if action_type == ACTION_COORDINATED:
        next_state["coord_used"].append(npc_id)
        next_state["coord_used"].sort_custom(_compare_npc_id)

    # Jika Leader melakukan NORMAL_ATTACK, planner menandai bahwa Leader sudah menyerang.
    if(action_type == ACTION_NORMAL and state["roles"].get(npc_id, ROLE_FOLLOWER) == ROLE_LEADER):
        next_state["leader_attacked"] = true

    return next_state # Mengembalikan state hasil penerapan aksi untuk proses pencarian berikutnya.

# Menghitung estimasi biaya minimum menuju goal menggunakan fungsi heuristik A*.
static func calculate_heuristic(state: Dictionary) -> int:
    var heuristic := 0

    # Menghitung estimasi biaya untuk seluruh NPC hidup yang belum resolved.
    for npc_id in state["alive"]:
        if state["resolved"].has(npc_id):
            continue # NPC yang sudah resolved tidak menambah estimasi biaya.

        var role: String = state["roles"].get(npc_id, ROLE_FOLLOWER)

        # Leader diperkirakan membutuhkan biaya NORMAL_ATTACK sebesar 2.
        if role == ROLE_LEADER:
            heuristic += COST_NORMAL
        else:
            heuristic += COST_COORDINATED # Follower diperkirakan membutuhkan biaya COORDINATED_ATTACK sebesar 1.

    return heuristic # Mengembalikan nilai heuristik berdasarkan rumus h(n) = 2L + F.

# Membentuk identitas state untuk kebutuhan visited set pada algoritma pencarian.
static func get_state_key(state: Dictionary) -> String:
    var resolved: Array = state["resolved"].duplicate()
    resolved.sort_custom(_compare_npc_id) # Mengurutkan resolved agar state yang sama menghasilkan key yang sama.
    return "%s|%s" % [",".join(resolved), str(state["leader_attacked"])] # Membedakan state berdasarkan NPC yang resolved dan kondisi serangan Leader.

# Membandingkan dua ID NPC berdasarkan nomor numeriknya.
static func _compare_npc_id(a: String, b: String) -> bool:
    return _get_numeric_id(a) < _get_numeric_id(b)

# Mengambil nomor dari bagian akhir ID NPC untuk menghindari pengurutan secara alfabetis.
static func _get_numeric_id(npc_id: String) -> int:
    var parts := npc_id.split("-")

    if parts.size() < 2:
        return 2147483647 # Memberikan nilai besar jika ID tidak memiliki format dengan pemisah "-".

    return int(parts[parts.size() - 1]) # Mengambil angka setelah tanda "-" sebagai nomor NPC.

# Membandingkan dua kandidat aksi berdasarkan ID NPC, kemudian jenis aksinya.
static func _compare_actions(a: Dictionary, b: Dictionary) -> bool:
    var id_a := _get_numeric_id(str(a["npc"]))
    var id_b := _get_numeric_id(str(b["npc"]))

    if id_a == id_b:
        return str(a["type"]) < str (b["type"]) # Jika ID sama, mengurutkan berdasarkan nama jenis aksi.

    return id_a < id_b # Jika ID berbeda, NPC dengan nomor terkecil diprioritaskan.
