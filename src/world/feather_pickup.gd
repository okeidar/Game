extends Node3D
## A loose feather, pale and lit. Walk over it to take it into the coat.

const T = preload("res://src/combat/tuning.gd")
const Sim = preload("res://src/combat/combat_sim.gd")

var value := T.PICKUP_VALUE
var alive := true
var respawn_t := 0.0
var spin := 0.0
var mote: MeshInstance3D

func _ready() -> void:
	mote = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.5, 0.03)
	mote.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("efeade")
	mat.emission_enabled = true
	mat.emission = Color("cfc8b8")
	mat.emission_energy_multiplier = 1.6
	mote.material_override = mat
	mote.position.y = 0.7
	add_child(mote)

func _physics_process(dt: float) -> void:
	tick(dt)

func tick(dt: float) -> void:
	spin += dt
	if mote != null:
		mote.rotation.y = spin * 1.7
		mote.position.y = 0.7 + 0.12 * sin(spin * 2.2)
	if not alive:
		respawn_t -= dt
		if respawn_t <= 0.0:
			alive = true
			visible = true
		return
	for p in get_tree().get_nodes_in_group("player"):
		if p.dead:
			continue
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() < T.PICKUP_RADIUS:
			alive = false
			visible = false
			respawn_t = T.PICKUP_RESPAWN
			p.add_feathers(value)
			Sim.log_event("+%d FEATHERS" % int(value))
			return
