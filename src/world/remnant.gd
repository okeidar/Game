extends Node3D
## Death-penalty machinery: where Erthis falls, a remnant remains. It records
## the death location and holds a payload for recovery. WHAT is dropped and
## the recovery rules are UNDECIDED - the payload is empty scaffolding.

const Sim = preload("res://src/combat/combat_sim.gd")

var payload := {}   # UNDECIDED contents - empty until Omer decides the rules
var mote: MeshInstance3D
var spin := 0.0

func _ready() -> void:
	mote = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.22, 0.22)
	mote.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("6d5a7a")
	mat.emission_enabled = true
	mat.emission = Color("4a3a5a")
	mat.emission_energy_multiplier = 1.4
	mote.material_override = mat
	mote.position.y = 0.6
	add_child(mote)

func _physics_process(dt: float) -> void:
	spin += dt
	if mote != null:
		mote.rotation.y = spin * 1.2
		mote.position.y = 0.6 + 0.1 * sin(spin * 1.8)
	for p in get_tree().get_nodes_in_group("player"):
		if p.dead:
			continue
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() < 1.0:
			# Recovery rules UNDECIDED: payload is applied here when decided.
			Sim.log_event("REMNANT RECOVERED (payload empty - rules undecided)")
			queue_free()
			return
