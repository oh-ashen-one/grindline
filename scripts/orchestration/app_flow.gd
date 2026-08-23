extends Node
## app_flow.gd — top-level application phase machine.
## Phases: title -> menu -> run -> results (slots fill in as phases land).
## QA: exposes get_qa_dict() consumed by game/sim/sim_bridge.gd.

var phase := "boot"

func _ready() -> void:
	add_to_group("qa_state")
	# brief: boot reaches title within 3 s real time; here it is immediate
	# once the scene tree is live.
	phase = "title"

func get_qa_dict() -> Dictionary:
	return {"app": {"phase": phase}}

func _unhandled_input(event: InputEvent) -> void:
	if phase == "title" and _is_press(event):
		# menu arrives with the product-shell story; flag the transition target
		phase = "title_awaiting_menu"
	elif phase == "title_awaiting_menu":
		phase = "title"

func _is_press(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventJoypadButton and event.pressed:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	return false
