extends Node3D
## Behind-the-back orbit camera. Never clips through walls: a sphere query
## pulls it in before the wall eats it. Lock-on eases it behind the target line.

var player: Node3D
var yaw := 0.0
var pitch := -0.34
var distance := 5.4
var pivot_height := 1.7
var lock_target: Node3D = null
var cam: Camera3D
var pitch_min := -1.15
var pitch_max := 0.55
var sens := 0.0026
var keys_speed := 1.9

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cam = Camera3D.new()
	cam.current = true
	cam.fov = 62.0
	add_child(cam)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens, pitch_min, pitch_max)

func cam_forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

func _physics_process(dt: float) -> void:
	if player == null:
		return
	# arrow keys always work, even where pointer lock fails (some browsers)
	yaw += (Input.get_action_strength("cam_left") - Input.get_action_strength("cam_right")) * keys_speed * dt
	pitch = clampf(pitch + (Input.get_action_strength("cam_up") - Input.get_action_strength("cam_down")) * keys_speed * 0.7 * dt, pitch_min, pitch_max)
	lock_target = player.lock_target
	if lock_target != null and is_instance_valid(lock_target) and not lock_target.dead:
		var to: Vector3 = lock_target.global_position - player.global_position
		var want_yaw := atan2(to.x, to.z) + PI
		yaw = lerp_angle(yaw, want_yaw, 4.2 * dt)
	var pivot: Vector3 = player.global_position + Vector3(0, pivot_height, 0)
	global_position = pivot
	var cp := cos(pitch)
	var off := Vector3(sin(yaw) * cp, -sin(pitch), cos(yaw) * cp)
	var want := distance
	var space := player.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.32
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), pivot + off * 0.4)
	q.motion = off * (distance - 0.4)
	q.exclude = [player.get_rid()]
	var res := space.cast_motion(q)
	if res.size() >= 2 and res[1] < 1.0:
		want = maxf(0.8, 0.4 + (distance - 0.4) * res[1] * 0.92)
	cam.position = off * want
	cam.look_at(pivot + Vector3(0, 0.1, 0), Vector3.UP)
