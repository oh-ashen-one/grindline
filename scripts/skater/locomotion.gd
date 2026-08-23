extends CharacterBody3D
## locomotion.gd — push, steer and friction for the grounded skater.
## Constants are BRIEF.md feel values; they consolidate into config.gd at the
## vertical-slice capstone.

const PUSH_ACCEL := 6.5          # brief: m/s^2 while pushing
const MAX_PUSH_SPEED := 11.0     # brief: m/s
const STEER_RATE := 3.5          # brief: rad/s at speed
const FRICTION_DECEL := 4.0      # brief: m/s^2 when idle on flat ground
const GRAVITY := 18.0            # brief: arcade gravity

var speed := 0.0
var heading := 0.0               # radians, CCW around +Y

func _ready() -> void:
	add_to_group("qa_state")

func _physics_process(delta: float) -> void:
	var pushing := Input.is_action_pressed("push")
	var steer := Input.get_axis("steer_right", "steer_left")  # left = +1

	if pushing:
		speed = minf(speed + PUSH_ACCEL * delta, MAX_PUSH_SPEED)
	else:
		speed = maxf(speed - FRICTION_DECEL * delta, 0.0)

	if speed > 0.1:
		heading += steer * STEER_RATE * delta * clampf(speed / 6.0, 0.4, 1.0)

	var forward := Vector3(sin(heading), 0.0, cos(heading))
	# horizontal comes from locomotion; vertical belongs to air_state/gravity.
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y <= 0.0:
		velocity.y = -0.5  # stick to floor only when not launching
	# rising velocities pass through untouched (ollie impulse lives here)
	move_and_slide()

func get_qa_dict() -> Dictionary:
	return {
		"skater": {
			"speed": snappedf(speed, 0.01),
			"grounded": is_on_floor(),
			"height": global_position.y,
			"heading_deg": rad_to_deg(heading),
			"world_y": snappedf(global_position.y, 0.01),
			"floor_flag": is_on_floor(),
		}
	}
