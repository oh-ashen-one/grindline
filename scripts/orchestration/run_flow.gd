extends Node
## run_flow.gd — orchestrates the run lifecycle inside the product shell.
## Title/menu chrome lives in main.tscn; this node owns the run scene slot:
## start_run -> cell instance -> results -> restart_run (fresh instance).

const CELL_SCENE := "res://game/scenes/skater_cell.tscn"

var run_phase := "idle"  # idle | running | results

func _ready() -> void:
	add_to_group("qa_state")

func start_run() -> void:
	_mount_cell()
	run_phase = "running"

func restart_run() -> void:
	_mount_cell()  # fresh instance == fresh RunState (score 0, full clock)
	run_phase = "running"

func _mount_cell() -> void:
	for child in get_children():
		child.queue_free()
	var packed: PackedScene = load(CELL_SCENE)
	if packed == null:
		push_error("RunFlow: cannot load %s" % CELL_SCENE)
		return
	var inst := packed.instantiate()
	inst.name = "RunInstance"
	add_child(inst)

func _physics_process(_delta: float) -> void:
	if run_phase == "running":
		var rs := _find_run_state()
		if rs != null and rs.phase == "results":
			run_phase = "results"

func _find_run_state() -> Node:
	var inst := get_node_or_null("RunInstance")
	return inst.get_node_or_null("RunState") if inst else null

func get_qa_dict() -> Dictionary:
	return {"flow": {"run_phase": run_phase}}
