extends Label

# Menyimpan referensi ke node NPC
var npc

func _ready():
	# Mengambil node NPC dari parent dan parent di atasnya
	npc = get_parent().get_parent().get_node("NPC")

func _process(_delta):
	if npc == null:
		return

	# Mengambil algoritma pencarian terakhir yang digunakan NPC
	var algorithm = npc.get("last_algorithm")
	# Mengambil heuristic yang digunakan jika algoritmanya A*
	var heuristic = npc.get("last_heuristic")
	# Mengambil path yang dihasilkan oleh algoritma
	var path = npc.get("current_path")
	# Mengambil  daftar node yang sudah di expand
	var expanded_nodes = npc.get("last_expanded_nodes")

	text = "Algorithm: " + str(algorithm) + "\n"

	if algorithm == "A*":
		text += "Heuristic: " + str(heuristic) + "\n"

	# Menghitung path cost
	text += "Path Cost: " + str(max(0, path.size() - 1)) + "\n"
	# Menampilkan jumlah node yang sudah diexpand
	text += "Expanded Nodes: " + str(expanded_nodes.size())
