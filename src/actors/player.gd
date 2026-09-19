extends "res://src/combat/combatant.gd"

signal npc_spoke(npc)
## The winged one, in greybox form. Stamina pays for body actions (sprint, roll,
## swing). Feathers are a second economy: the coat you wear and the shot you fire.

const T = preload("res://src/combat/tuning.gd")
const MeleeAttack = preload("res://src/combat/melee_attack.gd")
const Projectile = preload("res://src/combat/projectile.gd")

var stamina := T.STAMINA_MAX
var since_spend := 99.0
var feathers := T.FEATHERS_MAX
var state := "free"            # free | roll | attack | volley
var attack: MeleeAttack = null
var roll_t := 0.0
var roll_dir := Vector3.FORWARD
var volley_t := 0.0
var facing := Vector3.FORWARD
var camera_yaw := 0.0
var block_t := 0.0
var heal_charges := T.HEAL_CHARGES_SCAFFOLD
var heal_t := 0.0
const Inventory = preload("res://src/combat/inventory.gd")
var inventory = Inventory.new()
var sneaking := false
var step_acc := 0.0   # sound machinery: distance accumulated toward the next footstep
var item_t := 0.0
const Moveset = preload("res://src/combat/moveset.gd")
const Attributes = preload("res://src/combat/attributes.gd")
const Equipment = preload("res://src/combat/equipment.gd")
const Audio = preload("res://src/combat/audio_bus.gd")
const Gestures = preload("res://src/combat/gestures.gd")
var gestures = Gestures.new()   # gesture scaffolding: catalog OPEN
var moveset: Dictionary
var attrs = Attributes.new()         # stat scaffolding: catalog/curves OPEN
var equipment = Equipment.new()      # equipment scaffolding: slots/rules OPEN
var chain_index := 0
var cur_slot := ""
var last_attack_hit := false
var chain_window_t := 0.0
var roll_end_t := 99.0  # seconds since a roll ended; feeds the rolling-attack slot
var fall_v := 0.0       # deepest downward velocity of the current fall
var cam: Node3D = null         # camera rig, set by game; null in tests
var lock_target: Node3D = null
var buffered := ""
var buffer_left := 0.0
var sprinting := false
var deaths := 0
var input_source: RefCounted = null
var sword_pivot: Node3D
var wing_l: MeshInstance3D
var wing_r: MeshInstance3D
var feather_motes: Array[MeshInstance3D] = []

func _ready() -> void:
	moveset = Moveset.scaffold_moveset()
	equipment.slots.weapon = moveset
	recalculate_derived()
	display_name = "PLAYER"
	team = "player"
	max_hp = T.PLAYER_HP
	hp = max_hp
	hurt_radius = T.PLAYER_HURT_RADIUS
	base_color = Color("c9bfb0")   # pale ash
	add_to_group("player")
	_build_visuals()

## Derived-value hook (round 4): registered scalings reshape stats here.
## No scalings registered by default - fallbacks keep current behavior.
func recalculate_derived() -> void:
	var hp_frac: float = (hp / max_hp) if max_hp > 0.0 else 1.0
	max_hp = attrs.derived("max_hp", T.PLAYER_HP)
	hp = max_hp * hp_frac

func _build_visuals() -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	visual = MeshInstance3D.new()
	visual.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.85
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.material_override = mat
	visual.position.y = 0.9
	add_child(visual)
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	add_child(col)
	# sword: telegraph + sweep, its pose is a pure function of attack phase
	sword_pivot = Node3D.new()
	sword_pivot.position = Vector3(0.0, 1.1, 0.0)
	add_child(sword_pivot)
	var sword := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.07, 0.07, 1.5)
	sword.mesh = sb
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("8b93a1")
	sm.roughness = 0.35
	sm.metallic = 0.6
	sword.material_override = sm
	sword.position = Vector3(0.4, 0.0, 0.75)
	sword_pivot.add_child(sword)
	# wings: the fiction, two dark planes on the back
	wing_l = _wing(-1.0)
	wing_r = _wing(1.0)
	add_child(wing_l)
	add_child(wing_r)
	# the coat: one mote per 5 feathers, visible armor you spend
	for i in 6:
		var m := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.09, 0.26, 0.02)
		m.mesh = fm
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color("e8e4da")
		mm.emission_enabled = true
		mm.emission = Color("cfc9bb")
		m.material_override = mm
		add_child(m)
		feather_motes.append(m)
	_update_coat()

func _wing(side: float) -> MeshInstance3D:
	var w := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.09, 1.1, 0.55)
	w.mesh = wm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2a2d33")
	mat.roughness = 0.95
	w.material_override = mat
	w.position = Vector3(side * 0.52, 1.25, -0.18)
	w.rotation.z = side * 0.5
	w.rotation.y = side * 0.35
	return w

func _update_coat() -> void:
	var shown := int(ceil(feathers / 5.0))
	for i in feather_motes.size():
		var m := feather_motes[i]
		m.visible = i < shown
		var a := TAU * float(i) / 6.0
		m.position = Vector3(sin(a) * 0.62, 1.32 + 0.05 * sin(a * 2.0), cos(a) * 0.62)
		m.rotation.y = a

func feather_resist() -> float:
	return T.RESIST_AT_FULL * clampf(feathers / T.FEATHERS_MAX, 0.0, 1.0)

func damage_after_defense(damage: float) -> float:
	return damage * (1.0 - feather_resist())

func is_invulnerable() -> bool:
	return state == "roll" and roll_t >= T.ROLL_IFRAME_START and roll_t <= T.ROLL_IFRAME_END

func apply_hit(damage: float, from_pos: Vector3, stagger: float, flags := {}) -> int:
	if dead:
		return HIT_RESULT_MISS
	if is_invulnerable():
		if roll_t <= T.PERFECT_DODGE_WINDOW:
			# acknowledged only: payoff pending Omer's call (no invented rewards)
			Sim.log_event("PERFECT DODGE")
		else:
			Sim.log_event("PLAYER DODGED THROUGH")
		return HIT_RESULT_DODGED
	if state == "block" and not flags.get("unblockable", false):
		if block_t <= T.PARRY_WINDOW:
			Sim.hitstop(T.HITSTOP_DEALT)
			Sim.log_event("PARRY - DEFLECTED")
			Sim.stat("parry")
			return HIT_RESULT_PARRIED
		var chip := damage * T.BLOCK_STAMINA_PER_DAMAGE
		if stamina - chip <= 0.0:
			stamina = 0.0
			state = "free"
			var rg: int = super.apply_hit(damage, from_pos, T.GUARD_BREAK_STAGGER)
			Sim.hitstop(T.HITSTOP_TAKEN)
			Sim.log_event("GUARD BREAK - full hit -%d" % int(round(damage_after_defense(damage))))
			return rg
		stamina -= chip
		since_spend = 0.0
		var rb: int = super.apply_hit(damage * (1.0 - T.BLOCK_DAMAGE_CUT), from_pos, minf(stagger, 0.15))
		Sim.hitstop(T.HITSTOP_TAKEN * 0.5)
		Sim.log_event("BLOCKED -%d" % int(round(damage_after_defense(damage) * (1.0 - T.BLOCK_DAMAGE_CUT))))
		Sim.stat("block", {"dmg": int(round(damage_after_defense(damage) * (1.0 - T.BLOCK_DAMAGE_CUT)))})
		return rb
	var r: int = super.apply_hit(damage, from_pos, stagger)
	if r == HIT_RESULT_HIT:
		attack = null
		state = "free"
		buffered = ""
		Sim.hitstop(T.HITSTOP_TAKEN)
		Sim.log_event("PLAYER HIT -%d" % int(round(damage_after_defense(damage))))
		Sim.stat("player_hurt", {"dmg": int(round(damage_after_defense(damage))), "hp": hp})
	return r

func add_feathers(n: float) -> void:
	feathers = clampf(feathers + n, 0.0, T.FEATHERS_MAX)
	_update_coat()

func _spend_stamina(n: float) -> void:
	stamina -= n
	since_spend = 0.0

func _physics_process(dt: float) -> void:
	tick(dt)

func tick(dt: float) -> void:
	tick_common(dt)
	if dead:
		return
	_tick_stamina(dt)
	if cam != null:
		camera_yaw = cam.yaw
	var inp := _poll()
	_tick_lock(inp)
	if stagger_t > 0.0:
		if state == "attack" or state == "volley" or state == "heal" or state == "item":
			state = "free"
			attack = null
		velocity = velocity.move_toward(Vector3.ZERO, 18.0 * dt)
		move_and_slide()
		_update_visual(dt)
		return
	if chain_window_t > 0.0:
		chain_window_t -= dt
	else:
		chain_index = 0
	roll_end_t += dt
	if not is_on_floor():
		fall_v = minf(fall_v, velocity.y)
	elif fall_v < 0.0:
		var impact: float = -fall_v
		fall_v = 0.0
		if impact > T.FALL_SAFE_SPEED_SCAFFOLD and not dead:
			var fdmg: float = (impact - T.FALL_SAFE_SPEED_SCAFFOLD) * T.FALL_DAMAGE_SCALE_SCAFFOLD
			apply_hit(fdmg, global_position + facing, 0.2)
			Sim.log_event("FALL DAMAGE -%d (scaffold)" % int(round(fdmg)))
	match state:
		"free": _tick_free(dt, inp)
		"roll": _tick_roll(dt, inp)
		"attack": _tick_attack(dt, inp)
		"volley": _tick_volley(dt, inp)
		"block": _tick_block(dt, inp)
		"heal": _tick_heal(dt, inp)
		"item": _tick_item(dt, inp)
	if buffer_left > 0.0:
		buffer_left -= dt
		if buffer_left <= 0.0:
			buffered = ""
	_update_visual(dt)

func _poll() -> Dictionary:
	if input_source != null:
		return input_source.poll()
	return {
		"move": Input.get_vector("move_left", "move_right", "move_forward", "move_back"),
		"sprint": Input.is_action_pressed("sprint"),
		"dodge": Input.is_action_just_pressed("dodge"),
		"attack": Input.is_action_just_pressed("attack"),
		"heavy": Input.is_action_just_pressed("heavy"),
		"volley": Input.is_action_just_pressed("volley"),
		"lock": Input.is_action_just_pressed("lock_on"),
		"block": Input.is_action_pressed("block"),
		"heal": Input.is_action_just_pressed("heal"),
		"interact": Input.is_action_just_pressed("interact"),
		"sneak": Input.is_action_pressed("sneak"),
		"use_item": Input.is_action_just_pressed("use_item"),
		"jump": Input.is_action_just_pressed("jump"),
	}

func _move_world(m: Vector2) -> Vector3:
	return Vector3(m.x, 0.0, m.y).rotated(Vector3.UP, camera_yaw)

func _tick_free(dt: float, inp: Dictionary) -> void:
	var wish: Vector2 = inp.move
	var dir := _move_world(wish)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	sneaking = inp.get("sneak", false)
	sprinting = inp.sprint and not sneaking and stamina > 0.0 and wish.length_squared() > 0.01
	var speed := T.SPRINT_SPEED if sprinting else T.WALK_SPEED
	if sneaking:
		speed *= T.SNEAK_SPEED_MULT_SCAFFOLD  # SCAFFOLD - sneak speed undecided
	if sprinting:
		_spend_stamina(T.SPRINT_DRAIN_PER_SEC * dt)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_gravity(dt)
	move_and_slide()
	# sound machinery: movement emits footstep sound events (enemy hearing deferred)
	if wish.length_squared() > 0.01:
		step_acc += Vector2(velocity.x, velocity.z).length() * dt
		if step_acc >= T.SOUND_STEP_DISTANCE:
			step_acc = 0.0
			var r: float = T.SOUND_RADIUS_SPRINT_SCAFFOLD if sprinting else (T.SOUND_RADIUS_SNEAK_SCAFFOLD if sneaking else T.SOUND_RADIUS_WALK_SCAFFOLD)
			Sim.emit_sound("footstep", global_position, r, r)
	if _lock_valid():
		facing = (lock_target.global_position - global_position)
		facing.y = 0.0
		facing = facing.normalized()
	elif dir.length_squared() > 0.01:
		facing = dir.normalized()
	if inp.get("block", false) and stamina > 0.0:
		state = "block"
		block_t = 0.0
		Sim.log_event("BLOCK UP")
	elif inp.dodge:
		_try_roll(dir)
	elif inp.attack:
		_try_attack()
	elif inp.heavy:
		_try_heavy()
	elif inp.volley:
		_try_volley()
	elif inp.get("heal", false):
		_try_heal()
	elif inp.get("interact", false):
		_try_interact()
	elif inp.get("use_item", false):
		_try_use_item()
	elif inp.get("jump", false):
		_try_jump()

func _try_jump() -> bool:
	if not is_on_floor():
		return false
	velocity.y = T.JUMP_VELOCITY_SCAFFOLD  # SCAFFOLD - height/feel/air control undecided
	Sim.log_event("JUMP")
	return true

func _try_use_item() -> bool:
	if not inventory.can_use(0):
		Sim.log_event("ITEM DENIED empty slot")
		return false
	state = "item"
	item_t = 0.0
	Sim.log_event("ITEM USE START")
	return true

func _tick_item(dt: float, _inp: Dictionary) -> void:
	item_t += dt
	velocity = Vector3.ZERO
	_gravity(dt)
	move_and_slide()
	if item_t >= T.ITEM_USE_COMMIT_SCAFFOLD:
		inventory.use(0, self)
		state = "free"

func _try_roll(dir: Vector3) -> bool:
	if stamina <= 0.0:
		Sim.log_event("ROLL DENIED stamina")
		return false
	_spend_stamina(T.ROLL_COST)
	state = "roll"
	roll_t = 0.0
	Sim.emit_sound("roll", global_position, T.SOUND_RADIUS_ROLL_SCAFFOLD, T.SOUND_RADIUS_ROLL_SCAFFOLD)
	roll_dir = dir.normalized() if dir.length_squared() > 0.01 else -facing
	facing = roll_dir
	Sim.log_event("ROLL")
	Sim.stat("roll")
	return true

func _tick_roll(dt: float, inp: Dictionary) -> void:
	roll_t += dt
	var speed := T.ROLL_SPEED * (1.0 - 0.45 * (roll_t / T.ROLL_DURATION))
	velocity.x = roll_dir.x * speed
	velocity.z = roll_dir.z * speed
	_gravity(dt)
	move_and_slide()
	if inp.dodge:
		_buffer("dodge")
	elif inp.attack:
		_buffer("attack")
	elif inp.heavy:
		_buffer("heavy")
	elif inp.volley:
		_buffer("volley")
	if roll_t >= T.ROLL_DURATION:
		state = "free"
		roll_end_t = 0.0
		_fire_buffered()

func _try_attack() -> bool:
	var slot := ""
	var data: Dictionary
	if not is_on_floor():
		slot = "jump_attack"
		data = moveset.jump_attack
	elif roll_end_t < T.ROLL_ATTACK_WINDOW_SCAFFOLD:
		slot = "rolling_attack"
		data = moveset.rolling_attack
	elif sprinting:
		slot = "running_attack"
		data = moveset.running_attack
	else:
		slot = "light_chain[%d]" % chain_index
		data = moveset.light_chain[chain_index]
		chain_index = (chain_index + 1) % moveset.light_chain.size()
		chain_window_t = data.windup + data.active + data.recovery + T.CHAIN_WINDOW_SCAFFOLD
	return _start_attack(data, T.ATTACK_COST * moveset.get("cost_mult", 1.0), "ATTACK", slot)

func _try_heavy() -> bool:
	return _start_attack(moveset.heavy, T.HEAVY_COST * moveset.get("cost_mult", 1.0), "HEAVY", "heavy")

func _start_attack(data: Dictionary, cost: float, label: String, slot := "") -> bool:
	if stamina <= 0.0:
		Sim.log_event("%s DENIED stamina" % label)
		return false
	_spend_stamina(cost)
	var dir := facing
	if _lock_valid():
		dir = lock_target.global_position - global_position
	attack = MeleeAttack.new(data, dir)
	facing = attack.direction
	rotation.y = atan2(facing.x, facing.z)
	state = "attack"
	Audio.sfx("swing")
	Sim.log_event("%s START" % label)
	cur_slot = slot if slot != "" else label
	last_attack_hit = false
	Sim.stat("attack", {"slot": cur_slot, "weapon": moveset.get("id", "?"), "dmg": data.damage, "windup": data.windup})
	if slot != "":
		Sim.log_event("ATTACK SLOT %s" % slot)
	return true

func _tick_attack(dt: float, inp: Dictionary) -> void:
	var prev: String = attack.phase
	attack.advance(dt)
	var drift := 0.0
	if attack.phase == "windup" or attack.phase == "active":
		drift = T.ATTACK_STEP_SPEED
	velocity.x = attack.direction.x * drift
	velocity.z = attack.direction.z * drift
	_gravity(dt)
	move_and_slide()
	if attack.just_entered_active(prev) and not attack.resolved:
		attack.resolved = true
		_resolve_attack_hit()
	if inp.dodge:
		_buffer("dodge")
	elif inp.attack:
		_buffer("attack")
	elif inp.heavy:
		_buffer("heavy")
	elif inp.volley:
		_buffer("volley")
	if attack.phase == "done":
		if not last_attack_hit:
			Sim.stat("whiff", {"slot": cur_slot})
		attack = null
		state = "free"
		_fire_buffered()

func _resolve_attack_hit() -> void:
	var d: Dictionary = attack.data
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		if Sim.in_sector(global_position, attack.direction, e.global_position, e.hurt_radius, d.reach, d.arc_deg):
			var to_e: Vector3 = (e.global_position - global_position).normalized()
			var behind: bool = to_e.dot(e.facing) > cos(deg_to_rad(T.BACKSTAB_HALF_ANGLE_SCAFFOLD))
			var crit: bool = e.crit_open_t > 0.0 or behind
			var dmg: float = d.damage * (T.CRIT_MULTIPLIER_SCAFFOLD if crit else 1.0)
			var r: int = e.apply_hit(dmg, global_position, d.get("stagger", T.DUMMY_STAGGER))
			if r == HIT_RESULT_HIT:
				Sim.hitstop(T.HITSTOP_DEALT)
				last_attack_hit = true
				Sim.stat("hit", {"target": e.display_name, "dmg": int(round(dmg)), "crit": crit, "slot": cur_slot, "weapon": moveset.get("id", "?")})
				if crit:
					Sim.log_event("RIPOSTE %s -%d (scaffold x%.1f)" % [e.display_name, int(round(dmg)), T.CRIT_MULTIPLIER_SCAFFOLD])
				else:
					Sim.log_event("HIT %s -%d" % [e.display_name, int(round(dmg))])

func _try_volley() -> bool:
	if feathers < T.VOLLEY_COST:
		Sim.log_event("VOLLEY DENIED feathers")
		return false
	add_feathers(-T.VOLLEY_COST)
	state = "volley"
	volley_t = 0.0
	var dir := facing
	if _lock_valid():
		dir = lock_target.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized()
	facing = dir
	rotation.y = atan2(facing.x, facing.z)
	Sim.log_event("VOLLEY -%d feathers" % int(T.VOLLEY_COST))
	_fire_volley(dir)
	return true

func _fire_volley(dir: Vector3) -> void:
	var n := T.VOLLEY_COUNT
	for i in n:
		var off := 0.0
		if n > 1:
			off = deg_to_rad(T.VOLLEY_SPREAD_DEG) * (float(i) - float(n - 1) / 2.0)
		var p := Projectile.new()
		p.velocity = dir.rotated(Vector3.UP, off) * T.VOLLEY_SPEED
		p.damage = T.VOLLEY_DAMAGE
		p.life = T.VOLLEY_LIFE
		p.stagger = T.VOLLEY_STAGGER
		p.shooter = self
		p.target_group = "enemies"
		p.position = global_position + Vector3(0, 1.3, 0) + dir * 0.7
		get_parent().add_child(p)

func _tick_volley(dt: float, _inp: Dictionary) -> void:
	volley_t += dt
	velocity = velocity.move_toward(Vector3.ZERO, 22.0 * dt)
	_gravity(dt)
	move_and_slide()
	if volley_t >= T.VOLLEY_COMMIT:
		state = "free"
		_fire_buffered()

func _buffer(action: String) -> void:
	buffered = action
	buffer_left = 99.0   # held until state ends, then grace window applies

func _fire_buffered() -> void:
	if buffered == "":
		return
	var a := buffered
	buffered = ""
	buffer_left = 0.0
	var inp := _poll()
	match a:
		"dodge": _try_roll(_move_world(inp.move))
		"attack": _try_attack()
		"heavy": _try_heavy()
		"volley": _try_volley()

func _try_heal() -> bool:
	if heal_charges <= 0:
		Sim.log_event("HEAL DENIED charges")
		return false
	if hp >= max_hp:
		Sim.log_event("HEAL DENIED full")
		return false
	state = "heal"
	heal_t = 0.0
	Sim.log_event("HEAL START")
	return true

func _tick_heal(dt: float, _inp: Dictionary) -> void:
	heal_t += dt
	velocity = Vector3.ZERO
	_gravity(dt)
	move_and_slide()
	if heal_t >= T.HEAL_COMMIT:
		heal_charges -= 1
		Sim.stat("heal", {"charges_left": heal_charges})
		var amt: float = minf(T.HEAL_AMOUNT_SCAFFOLD, max_hp - hp)
		hp += amt
		Sim.log_event("HEALED +%d (scaffold amount)" % int(round(amt)))
		state = "free"

func _try_interact() -> bool:
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.interactable_by(self):
			npc_spoke.emit(n)
			return true
	for c in get_tree().get_nodes_in_group("checkpoints"):
		var d: Vector3 = c.global_position - global_position
		d.y = 0.0
		if d.length() <= T.CHECKPOINT_RADIUS_SCAFFOLD:
			c.activate(self)
			return true
	return false

func _tick_block(dt: float, inp: Dictionary) -> void:
	block_t += dt
	var dir := _move_world(inp.move)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	velocity.x = dir.x * T.WALK_SPEED * T.BLOCK_MOVE_MULT
	velocity.z = dir.z * T.WALK_SPEED * T.BLOCK_MOVE_MULT
	_gravity(dt)
	move_and_slide()
	if inp.dodge and stamina > 0.0:
		_try_roll(dir)
		return
	if not inp.get("block", false) or stamina <= 0.0:
		state = "free"

func _tick_stamina(dt: float) -> void:
	since_spend += dt
	if since_spend >= T.STAMINA_REGEN_DELAY:
		if state == "free" and not sprinting:
			stamina = minf(T.STAMINA_MAX, stamina + T.STAMINA_REGEN * dt)
		elif state == "block":
			stamina = minf(T.STAMINA_MAX, stamina + T.STAMINA_REGEN * T.BLOCK_REGEN_MULT * dt)

func _gravity(dt: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * dt
	elif velocity.y < 0.0:
		velocity.y = 0.0  # keep upward velocity so a jump survives its first frame

func _lock_valid() -> bool:
	return lock_target != null and is_instance_valid(lock_target) and not lock_target.dead

func _tick_lock(inp: Dictionary) -> void:
	if lock_target != null and (not is_instance_valid(lock_target) or lock_target.dead):
		lock_target = null
		Sim.log_event("LOCK LOST")
	if _lock_valid() and global_position.distance_to(lock_target.global_position) > T.LOCK_BREAK_RANGE:
		lock_target = null
		Sim.log_event("LOCK LOST")
	if inp.lock:
		if _lock_valid():
			lock_target = null
			Sim.log_event("LOCK OFF")
		else:
			var fwd := facing
			if cam != null and cam.has_method("cam_forward"):
				fwd = cam.cam_forward()
			lock_target = acquire_lock(fwd)

func acquire_lock(cam_forward: Vector3) -> Node3D:
	var best: Node3D = null
	var best_ang := T.LOCK_CONE_DEG
	var f := Vector3(cam_forward.x, 0.0, cam_forward.z)
	if f.length_squared() < 0.0001:
		f = facing
	f = f.normalized()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > T.LOCK_RANGE or dist < 0.05:
			continue
		var ang := rad_to_deg(acos(clampf(f.dot(to / dist), -1.0, 1.0)))
		if ang < best_ang:
			best_ang = ang
			best = e
	if best != null:
		Sim.log_event("LOCK ON %s" % best.display_name)
	return best

func _update_visual(dt: float) -> void:
	var target_yaw := atan2(facing.x, facing.z)
	if state == "attack" or state == "roll" or state == "volley":
		rotation.y = target_yaw
	else:
		rotation.y = lerp_angle(rotation.y, target_yaw, 14.0 * dt)
	# roll: tuck, and go ghost during the i-frame window so they visibly match
	var mat := visual.material_override as StandardMaterial3D
	if state == "roll":
		visual.scale = Vector3(1.0, 0.62, 1.0)
		mat.albedo_color.a = 0.45 if is_invulnerable() else 1.0
	else:
		visual.scale = Vector3.ONE
		mat.albedo_color.a = 1.0
		if state == "block":
			mat.albedo_color = Color("7f9fcf")  # guard up: cold sheen
	_update_sword()

func _update_sword() -> void:
	var a := 0.0
	if state == "attack" and attack != null:
		var d: Dictionary = attack.data
		if attack.phase == "windup":
			var f: float = clampf(attack.t / d.windup, 0.0, 1.0)
			a = lerpf(0.0, -1.9, f * f)
		elif attack.phase == "active":
			var f2: float = clampf((attack.t - d.windup) / d.active, 0.0, 1.0)
			a = lerpf(-1.9, 1.4, f2)
		else:
			var f3: float = clampf((attack.t - d.windup - d.active) / d.recovery, 0.0, 1.0)
			a = lerpf(1.4, 0.0, f3 * 0.5)
	sword_pivot.rotation.y = a

func reset_run(spawn: Vector3) -> void:
	position = spawn
	velocity = Vector3.ZERO
	hp = max_hp
	stamina = T.STAMINA_MAX
	feathers = T.FEATHERS_MAX
	heal_charges = T.HEAL_CHARGES_SCAFFOLD
	dead = false
	stagger_t = 0.0
	state = "free"
	attack = null
	buffered = ""
	lock_target = null
	facing = Vector3.FORWARD
	rotation.y = 0.0
	_update_coat()
	_update_flash()
