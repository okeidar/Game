extends Node3D
## A spent feather. Straight line, honest speed, no homing.

const Sim = preload("res://src/combat/combat_sim.gd")

var velocity := Vector3.ZERO
var damage := 8.0
var life := 1.2
var stagger := 0.15
var radius := 0.4
var shooter: Node3D = null
var target_group := "enemies"

func _ready() -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 0.02, 0.5)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f0ece0")
	mat.emission_enabled = true
	mat.emission = Color("ddd6c4")
	m.material_override = mat
	add_child(m)
	look_at(global_position + velocity.normalized(), Vector3.UP)

func _physics_process(dt: float) -> void:
	tick(dt)

func tick(dt: float) -> void:
	life -= dt
	if life <= 0.0:
		queue_free()
		return
	global_position += velocity * dt
	for e in get_tree().get_nodes_in_group(target_group):
		if e.dead:
			continue
		var d: Vector3 = e.global_position + Vector3(0, 0.9, 0) - global_position
		if d.length() < radius + e.hurt_radius:
			var r: int = e.apply_hit(damage, global_position, stagger)
			if r == e.HIT_RESULT_HIT:
				Sim.log_event("FEATHER HIT %s -%d" % [e.display_name, int(round(damage))])
			queue_free()
			return
