extends Node
## metrics_reporter.gd — deterministic performance truth for the worst scene.
## Samples frame deltas every rendered/physics frame; reports percentiles and
## live counters consumed by tests_staged/test_q06_performance_resilience.sh.

var _samples: PackedFloat64Array = PackedFloat64Array()
var _last_us := 0
var _collecting := false

func _ready() -> void:
	add_to_group("qa_state")

func start_collection() -> void:
	_samples = PackedFloat64Array()
	_last_us = Time.get_ticks_usec()
	_collecting = true

func stop_collection() -> void:
	_collecting = false

func _physics_process(_delta: float) -> void:
	if not _collecting:
		return
	var now := Time.get_ticks_usec()
	var frame_ms := float(now - _last_us) / 1000.0
	_last_us = now
	if frame_ms > 0.01 and frame_ms < 1000.0:
		_samples.append(frame_ms)

func report() -> Dictionary:
	var vals := Array(_samples)
	vals.sort()
	var p95 := 0.0
	var med := 0.0
	if vals.size() > 0:
		p95 = vals[int(clampf(vals.size() * 0.95, 0, vals.size() - 1))]
		med = vals[int(clampf(vals.size() * 0.5, 0, vals.size() - 1))]
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var objs := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	return {
		"samples": vals.size(),
		"p95_frame_ms": snappedf(p95, 0.01),
		"median_frame_ms": snappedf(med, 0.01),
		"draw_calls": int(dc),
		"active_objects": int(objs),
	}

func get_qa_dict() -> Dictionary:
	return {"perf": report()}
