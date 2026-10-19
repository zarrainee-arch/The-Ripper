extends RefCounted
class_name KnowledgeBase

# Konstanta untuk membedakan peran NPC.
const LEADER = "LEADER"
const FOLLOWER = "FOLLOWER"

# Konstanta untuk jenis aksi NPC.
const COORDINATED_ATTACK = "COORDINATED_ATTACK"
const NORMAL_ATTACK = "NORMAL_ATTACK"
const NO_ACTION = "NO_ACTION"

# Bonus damage serangan terkoordinasi (kontrak Tahap 4 Bagian 4.5).
# KB hanya menyimpan angkanya; battle yang menerapkannya pada serangan Follower.
const COORDINATION_BONUS_DAMAGE = 2

# Fakta yang terikat pada giliran; dibersihkan ketika giliran berganti.
const TURN_FACT_TYPES = [
    "current_turn",
    "attacked",
    "ally_attacked",
    "coordinated_attack",
    "coordination_used",
    "coordination_blocked"
]

# Fakta hasil inferensi; dihitung ulang dari fakta dasar setiap infer().
const DERIVED_FACT_TYPES = [
    "current_turn",
    "ally_attacked",
    "coordinated_attack",
    "coordination_blocked"
]

# Menyimpan seluruh fakta dan aturan yang digunakan.
var facts: Array[Dictionary] = []
var rules: Array[Dictionary] = []

# Menginisialisasi aturan ketika KnowledgeBase dibuat.
func _init():
    _initialize_rules()

# Mendefinisikan seluruh aturan inferensi R1–R7.
func _initialize_rules():
    rules = [
        {
            "id": "R1",
            "description": "Leader hidup dan menyerang pada giliran berjalan.",
            "reason": "Leader hidup telah menyerang pada giliran ini.",
            "stage": 1,
            "conditions": [
                {"type": "current_turn", "turn_id": "?T"},
                {"type": "role", "npc_id": "?L", "role": LEADER},
                {"type": "alive", "npc_id": "?L", "value": true},
                {"type": "attacked", "npc_id": "?L", "turn_id": "?T"}
            ],
            "assert": {"type": "ally_attacked", "npc_id": "?L", "turn_id": "?T"}
        },
        {
            "id": "R2",
            "description": "Leader menyerang, Follower hidup, dan koordinasi belum digunakan.",
            "reason": "Leader menyerang dan Follower hidup belum memakai koordinasi.",
            "stage": 1,
            "conditions": [
                {"type": "current_turn", "turn_id": "?T"},
                {"type": "ally_attacked", "npc_id": "?L", "turn_id": "?T"},
                {"type": "role", "npc_id": "?F", "role": FOLLOWER},
                {"type": "alive", "npc_id": "?F", "value": true},
                {"not": true, "type": "coordination_used", "npc_id": "?F", "turn_id": "?T"}
            ],
            "assert": {"type": "coordinated_attack", "npc_id": "?F", "turn_id": "?T"}
        },
        {
            "id": "R5",
            "description": "Leader mati atau belum menyerang pada giliran berjalan.",
            "reason": "Leader mati atau belum menyerang; koordinasi tidak dihasilkan.",
            "stage": 2,
            "conditions": [
                {"type": "current_turn", "turn_id": "?T"},
                {"type": "role", "npc_id": "?L", "role": LEADER},
                {"not": true, "type": "ally_attacked", "npc_id": "?L", "turn_id": "?T"}
            ],
            "assert": {"type": "coordination_blocked", "npc_id": "?L", "turn_id": "?T"}
        },
        {
            "id": "R6",
            "description": "Follower mati dan tidak boleh menjalankan aksi.",
            "reason": "Follower mati atau tidak memiliki fakta hidup yang valid.",
            "stage": 3,
            "priority": 1,
            "conditions": [
                {"type": "role", "npc_id": "?F", "role": FOLLOWER},
                {"not": true, "type": "alive", "npc_id": "?F", "value": true}
            ],
            "decide": {"action": NO_ACTION, "subject": "?F", "bonus_damage": 0}
        },
        {
            "id": "R4",
            "description": "Koordinasi Follower sudah digunakan pada giliran yang sama.",
            "reason": "Kesempatan koordinasi sudah digunakan pada giliran ini.",
            "stage": 3,
            "priority": 2,
            "conditions": [
                {"type": "current_turn", "turn_id": "?T"},
                {"type": "role", "npc_id": "?F", "role": FOLLOWER},
                {"type": "alive", "npc_id": "?F", "value": true},
                {"type": "coordination_used", "npc_id": "?F", "turn_id": "?T"}
            ],
            "decide": {"action": NORMAL_ATTACK, "subject": "?F", "bonus_damage": 0}
        },
        {
            "id": "R3",
            "description": "Follower memiliki kesempatan serangan terkoordinasi.",
            "reason": "Leader hidup telah menyerang dan koordinasi tersedia.",
            "stage": 3,
            "priority": 3,
            "conditions": [
                {"type": "current_turn", "turn_id": "?T"},
                {"type": "role", "npc_id": "?F", "role": FOLLOWER},
                {"type": "alive", "npc_id": "?F", "value": true},
                {"type": "coordinated_attack", "npc_id": "?F", "turn_id": "?T"},
                {"not": true, "type": "coordination_used", "npc_id": "?F", "turn_id": "?T"}
            ],
            "decide": {
                "action": COORDINATED_ATTACK,
                "subject": "?F",
                "bonus_damage": COORDINATION_BONUS_DAMAGE
            }
        },
        {
            "id": "R7",
            "description": "Tidak ada aturan koordinasi yang cocok.",
            "reason": "Tidak ada aturan koordinasi yang cocok.",
            "stage": 3,
            "priority": 4,
            # Fakta bertipe ini pada giliran yang sama dapat menjadi konteks keputusan fallback.
            # Inference engine hanya meneruskan data konteks tersebut.
            "explain_with": ["coordination_blocked"],
            "conditions": [
                {"type": "role", "npc_id": "?F", "role": FOLLOWER},
                {"type": "alive", "npc_id": "?F", "value": true}
            ],
            "decide": {"action": NORMAL_ATTACK, "subject": "?F", "bonus_damage": 0}
        }
    ]

# Menambahkan fakta atau memperbarui fakta dengan identitas yang sama.
func set_fact(fact_type: String, data: Dictionary) -> void:
    var fact = {"type": fact_type}
    for key in data:
        fact[key] = data[key]

    # Memperbarui fakta jika identitasnya sudah ada.
    for i in range(facts.size()):
        if _same_fact_identity(facts[i], fact):
            facts[i] = fact
            return

    # Menambahkan fakta baru jika belum ditemukan.
    facts.append(fact)

# Menghapus fakta berdasarkan tipe dan atribut yang diberikan.
func remove_fact(fact_type: String, data: Dictionary = {}) -> void:
    # Iterasi mundur agar penghapusan tidak menggeser indeks berikutnya.
    for i in range(facts.size() - 1, -1, -1):
        if facts[i].get("type", "") != fact_type:
            continue

        var matched = true
        # Memastikan semua atribut yang diminta cocok.
        for key in data:
            if not facts[i].has(key) or facts[i][key] != data[key]:
                matched = false
                break

        # Menghapus fakta jika seluruh atribut cocok.
        if matched:
            facts.remove_at(i)

# Memeriksa keberadaan fakta berdasarkan tipe dan atributnya.
func has_fact(fact_type: String, data: Dictionary = {}) -> bool:
    for fact in facts:
        if fact.get("type", "") != fact_type:
            continue

        var matched = true
        # Memeriksa setiap atribut fakta.
        for key in data:
            if not fact.has(key) or fact[key] != data[key]:
                matched = false
                break

        # Mengembalikan true jika semua atribut cocok.
        if matched:
            return true

    return false

# Mengembalikan salinan fakta agar data internal tidak diubah pemanggil.
func get_facts() -> Array[Dictionary]:
    return facts.duplicate(true)

# Mengembalikan salinan aturan yang tersedia.
func get_rules() -> Array[Dictionary]:
    return rules.duplicate(true)

# Menghapus seluruh fakta saat battle dimulai ulang.
func clear_facts() -> void:
    facts.clear()

# Menghapus fakta kejadian dari giliran sebelumnya.
func clear_old_turn_facts(current_turn_id: int) -> void:
    # Memeriksa fakta dari indeks terakhir ke awal.
    for i in range(facts.size() - 1, -1, -1):
        if facts[i].get("type", "") in TURN_FACT_TYPES:
            # Menghapus fakta yang bukan milik giliran aktif.
            if facts[i].get("turn_id", -1) != current_turn_id:
                facts.remove_at(i)

# Menghapus fakta hasil inferensi agar dihitung ulang dari fakta dasar.
# Mencegah kesimpulan lama bertahan ketika fakta dasarnya berubah.
func clear_derived_facts() -> void:
    # Memeriksa fakta turunan dari indeks terakhir ke awal.
    for i in range(facts.size() - 1, -1, -1):
        if facts[i].get("type", "") in DERIVED_FACT_TYPES:
            facts.remove_at(i)

# Membandingkan identitas fakta untuk mencegah duplikasi.
func _same_fact_identity(first: Dictionary, second: Dictionary) -> bool:
    # Fakta dengan tipe berbeda tidak dianggap memiliki identitas sama.
    if first.get("type", "") != second.get("type", ""):
        return false

    # Membandingkan ID NPC dan giliran jika atribut tersebut tersedia.
    for field in ["npc_id", "turn_id"]:
        if first.has(field) or second.has(field):
            if first.get(field) != second.get(field):
                return false

    return true