extends Node
## budget_governor.gd — degradation ladder (contract.performanceTiers.target).
## level 0 full fidelity; each level applies the brief's degrade order:
## 1: particle rates halve + AI skaters drop to 1
## 2: shadow atlas halves
## 3: far props cull harder (35 m)

var level := 0
var ai_count := 2
var particle_scale := 1.0

signal degraded(level: int)

func _ready() -> void:
	add_to_group("qa_state")

func apply(new_level: int) -> void:
	level = clampi(new_level, 0, 3)
	match level:
		1:
			particle_scale = 0.5
			ai_count = 1
		2:
			particle_scale = 0.5
			ai_count = 1
		3:
			particle_scale = 0.25
			ai_count = 1
	degraded.emit(level)

func get_qa_dict() -> Dictionary:
	return {"gov": {"level": level, "particle_scale": particle_scale, "ai_count": ai_count}}
