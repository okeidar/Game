extends Node3D
## Death-penalty machinery: where Erthis falls, a remnant remains. It records
## the death location and holds the dropped ESSENCE (canon name - the
## enemy-drop currency) for recovery. Feathers are never part of the payload
## (Omer ruling 2026-09-19: feathers are not currency).

const Sim = preload("res://src/combat/combat_sim.gd")

var payload := {}   # contents.essence = the dropped currency (canon name)
var mote: MeshInstance3D
var spin := 0.0

func _ready() -> void:
	add_to_group("remnants")
	mote = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.22, 0.22)
	mote.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("6d5a7a")
	mat.emission_enabled = true
	mat.emission = Color("4a3a5a")
	# the glow names the loss: size and brightness scale with the essence held
	var held: float = payload.get("contents", {}).get("essence", 0.0)
	mat.emission_energy_multiplier = 1.4 + minf(held, 60.0) / 30.0
	mote.scale = Vector3.ONE * (1.0 + minf(held, 60.0) / 60.0)
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
			var held: float = payload.get("contents", {}).get("essence", 0.0)
			if held > 0.0:
				if p.progression != null:
					p.progression.add_essence(held)
				Sim.log_event("REMNANT RECOVERED - %d essence back" % int(held))
			else:
				Sim.log_event("REMNANT RECOVERED (it held nothing)")
			queue_free()
			return
