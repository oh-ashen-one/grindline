extends Node
## app_flow.gd — application phase machine: boot -> title -> menu -> run.
## The first click is the real final gate (law 12): any key opens the menu,
## PLAY (focused, Enter/gamepad A/click) starts the run, Esc returns to menu.

var phase := "boot"

@onready var title_layer: CanvasLayer = get_node("TitleLayer")
@onready var menu_layer: CanvasLayer = get_node("MenuLayer")
@onready var run_flow: Node = get_node("RunFlow")

func _ready() -> void:
	add_to_group("qa_state")
	phase = "title"
	menu_layer.visible = false
	var play_btn: Button = menu_layer.get_node("Panel/VBox/PlayBtn")
	play_btn.pressed.connect(_on_play)
	play_btn.focus_mode = Control.FOCUS_ALL
	var quit_btn: Button = menu_layer.get_node("Panel/VBox/QuitBtn")
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	quit_btn.focus_mode = Control.FOCUS_ALL

func get_qa_dict() -> Dictionary:
	return {"app": {"phase": phase}}

func _unhandled_input(event: InputEvent) -> void:
	match phase:
		"title":
			if _is_press(event):
				_open_menu()
		"menu":
			if event.is_action_pressed("ui_cancel"):
				_to_title()
		"running":
			if event.is_action_pressed("ui_cancel"):
				_end_run_to_menu()

func _open_menu() -> void:
	phase = "menu"
	menu_layer.visible = true
	title_layer.get_node("Title/PressStart").visible = false
	var play_btn: Button = menu_layer.get_node("Panel/VBox/PlayBtn")
	play_btn.grab_focus()

func _on_play() -> void:
	if phase != "menu":
		return
	phase = "running"
	menu_layer.visible = false
	run_flow.start_run()
	var cam: Camera3D = run_flow.get_node_or_null("RunInstance/CamRig")
	if cam != null:
		cam.current = true

func _end_run_to_menu() -> void:
	phase = "menu"
	run_flow.reset_to_menu()
	menu_layer.visible = true
	title_layer.get_node("Title/PressStart").visible = false
	get_viewport().set_input_as_handled()

func _to_title() -> void:
	phase = "title"
	menu_layer.visible = false
	title_layer.get_node("Title/PressStart").visible = true

func _is_press(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventJoypadButton and event.pressed:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	return false
