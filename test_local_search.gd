extends Node

func _ready() -> void:
	print("=== TEST LOCAL SEARCH ===")

	var problem = LocalSearch.new()
	print("LocalSearch berhasil dibuat!")

	var optimizer = Optimizer.new()
	print("Optimizer berhasil dibuat!")

	print("=== TEST SELESAI ===")
