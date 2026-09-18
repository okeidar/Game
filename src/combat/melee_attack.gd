extends RefCounted
## A committed melee swing: windup -> active -> recovery.
## No cancel during windup/active. The phase clock is the single source of truth
## for both hit resolution and the sword animation, so they cannot drift apart.

var data: Dictionary
var t := 0.0
var phase := "windup"
var direction := Vector3.FORWARD
var resolved := false

func _init(attack_data: Dictionary, dir: Vector3) -> void:
	data = attack_data
	direction = dir
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()

func total() -> float:
	return data.windup + data.active + data.recovery

func active_start() -> float:
	return data.windup

func advance(dt: float) -> void:
	t += dt
	if t >= total():
		phase = "done"
	elif t >= data.windup + data.active:
		phase = "recovery"
	elif t >= data.windup:
		phase = "active"
	else:
		phase = "windup"

func just_entered_active(prev: String) -> bool:
	return prev != "active" and phase == "active"
