extends "res://src/combat/combatant.gd"
## The training effigy. One attack, honestly telegraphed: it raises the club
## slow and turns yellow, then red, then the blow falls. Punishable recovery.
## Any hit staggers it out of windup. No hidden armor in 0A.

const T = preload("res://src/combat/tuning.gd")
const MeleeAttack = preload("res://src/combat/melee_attack.gd")

var state := "idle"            # idle | approach | attack | dead
var attack: MeleeAttack = null
var cooldown := 0.5
var facing := Vector3.FORWARD
var spawn_pos := Vector3.ZERO
var respawn_t := 0.0
var fresh_kill := true   # false after rising on its own timer: worth only a token until the world resets (rest or your death)
var ai_enabled := true
const Awareness = preload("res://src/combat/awareness.gd")
const Projectile = preload("res://src/combat/projectile.gd")
var awareness = Awareness.new()
var boss_data = null   # boss machinery: {name, phases:[{below, chain}]} - catalog OPEN
var boss_phase := 0
var forced_attack_data = null   # machinery: tests/future AI inject an attack dict
var attack_chain: Array = []    # machinery: follow-up links after the first swing
var chain_delay_t := 0.0
var pattern_count := 0            # deterministic swing counter for the pattern cycle
var did_chain := false            # the double swing earns a longer rest after
var winded_t := 0.0               # >0 while paying for the double: the opening is VISIBLE (slumped, dim, club down)
var hug_t := 0.0                 # seconds the target has spent inside shove range
var shoving := false             # the current attack is the shove
var shove_recovering := false    # stepping back after the shove: it pays for the space
var club_pivot: Node3D
var body_mat: StandardMaterial3D
var windup_color := Color("8a7a2a")   # sickly yellow: get ready
var active_color := Color("c22e1f")   # blood red: the blow is live

func _ready() -> void:
	display_name = "EFFIGY"
	team = "enemy"
	max_hp = T.DUMMY_HP
	hp = max_hp
	hurt_radius = T.DUMMY_HURT_RADIUS
	base_color = Color("5a6577")   # cold slate, readable through fog
	spawn_pos = position
	add_to_group("enemies")
	_build_visuals()

func _build_visuals() -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.55
	capsule.height = 1.9
	visual = MeshInstance3D.new()
	visual.mesh = capsule
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = base_color
	body_mat.roughness = 0.9
	body_mat.emission_enabled = true
	body_mat.emission = Color.BLACK
	visual.material_override = body_mat
	visual.position.y = 0.95
	add_child(visual)
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = 1.9
	col.shape = shape
	col.position.y = 0.95
	add_child(col)
	club_pivot = Node3D.new()
	club_pivot.position = Vector3(0.0, 1.7, 0.0)
	add_child(club_pivot)
	var club := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.22, 0.22, 1.7)
	club.mesh = cb
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color("6e6455")
	cm.roughness = 0.85
	club.material_override = cm
	club.position = Vector3(0.5, 0.2, 0.85)
	club_pivot.add_child(club)

func apply_hit(damage: float, from_pos: Vector3, stagger: float, flags := {}) -> int:
	var r: int = super.apply_hit(damage, from_pos, stagger, flags)
	if r != HIT_RESULT_MISS:
		awareness.alert_now(self)
	if r == HIT_RESULT_HIT and boss_data != null:
		var frac: float = hp / max_hp
		var phases: Array = boss_data.get("phases", [])
		if boss_phase < phases.size() and frac <= phases[boss_phase].get("below", 0.0):
			boss_phase += 1
			if phases[boss_phase - 1].has("chain"):
				attack_chain = phases[boss_phase - 1].chain.duplicate()
			Sim.log_event("BOSS %s ENTERS PHASE %d (scaffold)" % [boss_data.get("name", display_name), boss_phase + 1])
	if r == HIT_RESULT_HIT:
		if attack != null:
			Sim.log_event("%s STAGGERED OUT OF SWING" % display_name)
		attack = null
		state = "idle"
		cooldown = 0.4
	return r

func _physics_process(dt: float) -> void:
	tick(dt)

func tick(dt: float) -> void:
	tick_common(dt)
	winded_t = maxf(0.0, winded_t - dt)
	if dead:
		respawn_t -= dt
		if respawn_t <= 0.0:
			reset_run(spawn_pos, false)
			Sim.log_event("%s RISES AGAIN" % display_name)
		return
	if not ai_enabled:
		_tick_attack(dt)
		_update_visual(dt)
		return
	if stagger_t > 0.0:
		velocity = Vector3.ZERO
		_update_visual(dt)
		return
	cooldown = maxf(0.0, cooldown - dt)
	var target := _get_target()
	# hug pressure accumulates in any state: face-tanking through a swing still earns the shove
	if target != null and not target.dead and _dist_to(target) <= T.DUMMY_SHOVE_RANGE:
		hug_t += dt
	else:
		hug_t = 0.0
	awareness.tick(dt, self, target)   # enemy side of sneak: vision + hearing
	# the shove's price plays out above state: step back, then fight on
	if shove_recovering:
		velocity.x = -facing.x * T.DUMMY_SHOVE_RETREAT
		velocity.z = -facing.z * T.DUMMY_SHOVE_RETREAT
		move_and_slide()
		if cooldown <= T.DUMMY_CHAIN_COOLDOWN - T.DUMMY_SHOVE.recovery - 0.2:
			shove_recovering = false
			velocity = Vector3.ZERO
		_update_visual(dt)
		return
	match state:
		"idle":
			if target != null and awareness.state == "alert" and _dist_to(target) < T.DUMMY_AGGRO_RANGE * 3.0:
				state = "approach"
		"approach":
			if target == null or target.dead or awareness.state == "calm":
				state = "idle"
			else:
				var d := _dist_to(target)
				var to: Vector3 = (target.global_position - global_position)
				to.y = 0.0
				to = to.normalized()
				if d > T.DUMMY_ATTACK_RANGE:
					facing = to
					velocity.x = to.x * T.DUMMY_APPROACH_SPEED
					velocity.z = to.z * T.DUMMY_APPROACH_SPEED
					move_and_slide()
				else:
					velocity = Vector3.ZERO
					facing = to
					if hug_t >= T.DUMMY_SHOVE_DWELL:
						hug_t = 0.0
						_try_shove()   # the hug answer bypasses cooldown - pressure must be answered
					elif cooldown <= 0.0 and stagger_t <= 0.0:
						_try_attack()
		"attack":
			_tick_attack(dt)
	_update_visual(dt)

func _get_target() -> Node3D:
	var ps := get_tree().get_nodes_in_group("player")
	if ps.is_empty():
		return null
	return ps[0]

func _dist_to(n: Node3D) -> float:
	var d: Vector3 = n.global_position - global_position
	d.y = 0.0
	return d.length()

func _in_range(target: Node3D) -> bool:
	return _dist_to(target) <= T.DUMMY_ATTACK_RANGE + 0.3

func _try_attack() -> bool:
	var target := _get_target()
	if target == null:
		return false
	# pattern cycle, deterministic: every DUMMY_OVERHEAD_PERIOD-th honest
	# swing is the unblockable overhead; every DUMMY_PATTERN_PERIOD-th other
	# swing chains the quick follow-up. Skipped when machinery already owns
	# the chain (boss phase, test injection) or a forced attack is rehearsed.
	var overhead := false
	if forced_attack_data == null and boss_data == null and attack_chain.is_empty():
		pattern_count += 1
		if pattern_count % T.DUMMY_OVERHEAD_PERIOD == 0:
			overhead = true
		elif pattern_count % T.DUMMY_PATTERN_PERIOD == 0:
			attack_chain = [T.DUMMY_ATTACK_FOLLOWUP.duplicate()]
	var data: Dictionary = forced_attack_data if forced_attack_data != null else (T.DUMMY_ATTACK_OVERHEAD if overhead else T.DUMMY_ATTACK)
	attack = MeleeAttack.new(data, target.global_position - global_position)
	facing = attack.direction
	state = "attack"
	if overhead:
		Sim.log_event("%s HEAVES ITS CLUB OVERHEAD" % display_name)
	else:
		Sim.log_event("%s RAISES ITS CLUB" % display_name)
	return true

func _try_shove() -> bool:
	var target := _get_target()
	if target == null:
		return false
	attack = MeleeAttack.new(T.DUMMY_SHOVE, target.global_position - global_position)
	facing = attack.direction
	shoving = true
	state = "attack"
	Sim.log_event("%s SHOVES YOU OFF" % display_name)
	return true

func _tick_attack(dt: float) -> void:
	if attack == null:
		if attack_chain.size() > 0 and state == "attack":
			chain_delay_t -= dt
			if chain_delay_t <= 0.0:
				var link: Dictionary = attack_chain.pop_front()
				var t2 := _get_target()
				if t2 != null:
					attack = MeleeAttack.new(link, t2.global_position - global_position)
					facing = attack.direction
					did_chain = true
					Sim.log_event("%s CHAINS AGAIN" % display_name)
				else:
					attack_chain.clear()
					state = "idle"
					cooldown = T.DUMMY_CHAIN_COOLDOWN if did_chain else T.DUMMY_COOLDOWN
					did_chain = false
		return
	var target := _get_target()
	# track early, commit late: strafing behind it beats the swing
	if attack.phase == "windup" and target != null and not target.dead \
			and attack.t < attack.data.windup * T.DUMMY_TRACK_FRACTION:
		var want: Vector3 = target.global_position - global_position
		want.y = 0.0
		want = want.normalized()
		var cur_a := atan2(attack.direction.x, attack.direction.z)
		var want_a := atan2(want.x, want.z)
		var na := move_toward(cur_a, want_a, T.DUMMY_TRACK_RATE * dt)
		attack.direction = Vector3(sin(na), 0.0, cos(na))
		facing = attack.direction
	var prev: String = attack.phase
	attack.advance(dt)
	if attack.just_entered_active(prev) and not attack.resolved:
		attack.resolved = true
		var d2: Dictionary = attack.data
		if d2.has("projectile"):
			var pd: Dictionary = d2.projectile
			var pr := Projectile.new()
			pr.velocity = attack.direction * pd.get("speed", 12.0)
			pr.damage = pd.get("damage", 10.0)
			pr.life = pd.get("life", 1.5)
			pr.log_prefix = pd.get("log_prefix", "SHOT HIT")
			pr.shooter = self
			pr.target_group = "player"
			pr.position = global_position + Vector3(0, 1.2, 0) + attack.direction * 0.7
			get_parent().add_child(pr)
			Sim.log_event("%s LOOSES A SHOT (scaffold)" % display_name)
		elif target != null and _in_range_any(target):
			var d: Dictionary = attack.data
			if Sim.in_sector(global_position, attack.direction, target.global_position, target.hurt_radius, d.reach, d.arc_deg):
				var res: int = target.apply_hit(d.damage, global_position, T.PLAYER_STAGGER, {"unblockable": d.get("unblockable", false)})
				if res == HIT_RESULT_PARRIED:
					attack = null
					attack_chain.clear()
					state = "idle"
					stagger_t = T.PARRY_STAGGER
					crit_open_t = T.CRIT_WINDOW_SCAFFOLD  # riposte machinery: reel opens the crit window
					cooldown = T.DUMMY_COOLDOWN
					did_chain = false
					Sim.log_event("%s DEFLECTED - REELING" % display_name)
	if attack != null and attack.phase == "done":
		attack = null
		if attack_chain.size() > 0:
			chain_delay_t = attack_chain[0].get("delay", 0.0)  # SCAFFOLD hook: per-link delay
		else:
			state = "idle"
			cooldown = T.DUMMY_CHAIN_COOLDOWN if did_chain else T.DUMMY_COOLDOWN
			if shoving:
				cooldown = T.DUMMY_CHAIN_COOLDOWN   # the shove pays the double's price: the long rest
				shove_recovering = true
			if did_chain:
				winded_t = T.DUMMY_CHAIN_COOLDOWN
				Sim.log_event("%s WINDED - the opening" % display_name)
			did_chain = false
			shoving = false

func _in_range_any(target: Node3D) -> bool:
	return _dist_to(target) <= T.DUMMY_ATTACK.reach + target.hurt_radius + 1.0

func _update_visual(dt: float) -> void:
	# telegraph colors: slate -> yellow (windup) -> red (live) -> slate
	if attack != null and not dead:
		var d: Dictionary = attack.data
		if attack.phase == "windup":
			var f: float = clampf(attack.t / d.windup, 0.0, 1.0)
			var wc: Color = active_color if attack.data.get("unblockable", false) else windup_color
			base_color = Color("5a6577").lerp(wc, f)
			body_mat.emission = wc * f * 0.6
		elif attack.phase == "active":
			base_color = active_color
			body_mat.emission = active_color
		else:
			base_color = base_color.lerp(Color("5a6577"), 6.0 * dt)
			body_mat.emission = body_mat.emission.lerp(Color.BLACK, 6.0 * dt)
	elif winded_t > 0.0:
		# winded: visibly spent - pale slump, no glow, club dragged low
		base_color = base_color.lerp(Color("9aa4ae"), 4.0 * dt)
		body_mat.emission = body_mat.emission.lerp(Color.BLACK, 8.0 * dt)
	else:
		base_color = base_color.lerp(Color("5a6577"), 6.0 * dt)
		body_mat.emission = body_mat.emission.lerp(Color.BLACK, 6.0 * dt)
	# club pose mirrors the attack clock: raise slow, fall fast
	var pitch := 0.0
	if winded_t > 0.0 and attack == null:
		pitch = lerpf(club_pivot.rotation.x, 0.9, 6.0 * dt)   # club dragged low: the opening reads
	if attack != null:
		var d2: Dictionary = attack.data
		if attack.phase == "windup":
			var f2: float = clampf(attack.t / d2.windup, 0.0, 1.0)
			pitch = lerpf(0.0, -1.6, f2 * f2)
		elif attack.phase == "active":
			var f3: float = clampf((attack.t - d2.windup) / d2.active, 0.0, 1.0)
			pitch = lerpf(-1.6, 0.9, f3)
		else:
			var f4: float = clampf((attack.t - d2.windup - d2.active) / d2.recovery, 0.0, 1.0)
			pitch = lerpf(0.9, 0.0, f4 * 0.6)
	club_pivot.rotation.x = pitch
	rotation.y = lerp_angle(rotation.y, atan2(facing.x, facing.z), 10.0 * dt)
	# death: keel over
	if dead:
		visual.rotation.x = lerpf(visual.rotation.x, -1.4, 4.0 * dt)

func feather_reward() -> float:
	return T.KILL_FEATHERS if fresh_kill else T.KILL_FEATHERS_RISEN

func reset_run(spawn: Vector3, fresh := true) -> void:
	fresh_kill = fresh
	position = spawn
	velocity = Vector3.ZERO
	hp = max_hp
	dead = false
	stagger_t = 0.0
	attack = null
	attack_chain.clear()
	chain_delay_t = 0.0
	pattern_count = 0
	did_chain = false
	winded_t = 0.0
	hug_t = 0.0
	shoving = false
	shove_recovering = false
	awareness.suspicion = 0.0
	awareness.state = "calm"
	state = "idle"
	cooldown = 0.8
	respawn_t = 0.0
	base_color = Color("5a6577")
	visual.rotation.x = 0.0
	facing = Vector3.FORWARD
	_update_flash()

func _on_died() -> void:
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		died.connect(func() -> void:
			state = "dead"
			respawn_t = T.DUMMY_RESPAWN
			Sim.log_event("%s FELLED" % display_name)
		)
