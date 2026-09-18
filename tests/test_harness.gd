extends Node
## Deterministic combat scenarios. Runs inside the real tree at a fixed 60Hz
## physics tick, feeding scripted inputs. Prints TEST_PASS / TEST_FAIL lines and
## exits nonzero on any failure. No RNG anywhere in the sim: same script, same
## trace, every run. Verified by the determinism scenario itself.

const Sim = preload("res://src/combat/combat_sim.gd")
const T = preload("res://src/combat/tuning.gd")
const Player = preload("res://src/actors/player.gd")
const Effigy = preload("res://src/actors/effigy.gd")

const DT := 1.0 / 60.0

class ScriptedInput extends RefCounted:
	var plan: Array = []
	var cur := {"move": Vector2.ZERO, "sprint": false, "dodge": false, "attack": false, "heavy": false, "volley": false, "lock": false}
	func at(f: int, set: Dictionary) -> void:
		plan.append({"f": f, "set": set})
	func begin_frame(f: int) -> void:
		cur.dodge = false
		cur.attack = false
		cur.heavy = false
		cur.volley = false
		cur.lock = false
		for ev in plan:
			if ev.f == f:
				for k in ev.set:
					cur[k] = ev.set[k]
	func poll() -> Dictionary:
		return cur.duplicate()

class Scenario extends RefCounted:
	var name := "base"
	var h: Node
	func setup() -> void: pass
	func step(_f: int) -> bool: return true
	func check(cond: bool, label: String) -> void:
		h.check(self, cond, label)

var sim_root: Node3D
var player: Node3D
var effigies: Array = []
var input: ScriptedInput
var scenarios: Array = []
var current := 0
var frame := 0
var settle := 0
var det_trace_a: Array = []
var failures: Array[String] = []
var saw_pause := false
var done := false

func check(sc: Scenario, cond: bool, label: String) -> void:
	if cond:
		print("  PASS [", sc.name, "] ", label)
	else:
		failures.append(sc.name + ": " + label)
		print("  FAIL [", sc.name, "] ", label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	_register()
	print("TESTSUITE start scenarios=", scenarios.size())

func make_world(player_pos := Vector3(0, 0.1, 0), effigy_positions: Array = [Vector3(0, 0.05, -6.0)]) -> void:
	if sim_root != null:
		sim_root.queue_free()
		sim_root = null
	Sim.reset()
	saw_pause = false
	sim_root = Node3D.new()
	sim_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sim_root)
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(60, 0.3, 60)
	col.shape = shape
	col.position.y = -0.15
	floor_body.add_child(col)
	sim_root.add_child(floor_body)
	player = Player.new()
	input = ScriptedInput.new()
	player.input_source = input
	player.position = player_pos
	sim_root.add_child(player)
	effigies.clear()
	for i in effigy_positions.size():
		var e := Effigy.new()
		e.ai_enabled = false
		e.position = effigy_positions[i]
		if i > 0:
			e.display_name = "EFFIGY%d" % (i + 1)
		sim_root.add_child(e)
		effigies.append(e)

func _physics_process(_dt: float) -> void:
	if done or get_tree().paused:
		return
	if settle > 0:
		settle -= 1
		return
	if current >= scenarios.size():
		_finish()
		return
	var sc: Scenario = scenarios[current]
	if frame == 0:
		print("TEST ", sc.name)
		sc.setup()
	input.begin_frame(frame)
	if sc.step(frame):
		current += 1
		frame = 0
		settle = 2
	else:
		frame += 1

func _process(delta: float) -> void:
	if Sim.hitstop_left > 0.0:
		if not get_tree().paused:
			get_tree().paused = true
			saw_pause = true
		Sim.hitstop_left -= delta
		if Sim.hitstop_left <= 0.0:
			get_tree().paused = false

func _finish() -> void:
	done = true
	print("TESTS_SUMMARY pass=", scenarios.size() - _failed_scenarios(), " fail=", _failed_scenarios(), " checks_failed=", failures.size())
	for f in failures:
		print("FAILURE ", f)
	get_tree().quit(0 if failures.is_empty() else 1)

func _failed_scenarios() -> int:
	var s := {}
	for f in failures:
		s[f.split(":")[0]] = true
	return s.size()

# ---------------------------------------------------------------- scenarios

class ScenarioStamina extends Scenario:
	var st59 := 0.0
	var st170 := 0.0
	var st215 := 0.0
	func setup() -> void:
		name = "stamina_costs"
		h.make_world()
		h.player.stamina = 100.0
		h.input.at(5, {"dodge": true})
		h.input.at(60, {"attack": true})
		h.input.at(160, {"sprint": true, "move": Vector2(0, -1)})
		h.input.at(220, {"sprint": false, "move": Vector2.ZERO})
	func step(f: int) -> bool:
		var p = h.player
		if f == 10: check(absf(p.stamina - 75.0) < 0.01, "roll costs 25 (100->75), got %.2f" % p.stamina)
		if f == 59: st59 = p.stamina
		if f == 66: check(st59 - p.stamina >= 19.0 and st59 - p.stamina <= 20.5, "swing costs ~20 (regen overlaps the window), delta %.2f" % (st59 - p.stamina))
		if f == 150: check(p.stamina > 60.0, "stamina regenerates after delay, got %.2f" % p.stamina)
		if f == 170: st170 = p.stamina
		if f == 215:
			st215 = p.stamina
			var per_sec := (st170 - st215) * 60.0 / 45.0
			check(absf(per_sec - 12.0) < 0.6, "sprint drains ~12/s, measured %.2f/s" % per_sec)
		return f >= 240

class ScenarioCommitment extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	var interrupted := false
	var done_frame := -1
	var saw_roll := false
	func setup() -> void:
		name = "attack_commitment"
		h.make_world()
		h.input.at(5, {"attack": true})
		h.input.at(10, {"dodge": true})
		h.input.at(30, {"dodge": true})
	func step(f: int) -> bool:
		var p = h.player
		if f > 5 and done_frame < 0 and p.state == "free":
			done_frame = f
		if f >= 6 and f <= 55 and p.state != "attack":
			interrupted = true
		if f > 55 and p.state == "roll":
			saw_roll = true
		if f == 100:
			check(not interrupted, "dodge input during windup/active never interrupts the swing")
			check(done_frame > 0, "swing completes")
			check(saw_roll, "buffered dodge fires when the swing ends")
			var rolls := 0
			for e in Sim.events:
				if e == "ROLL": rolls += 1
			check(rolls == 1, "exactly one buffered roll fires, got %d" % rolls)
		return f >= 100

class ScenarioHitWindow extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	func setup() -> void:
		name = "hit_window"
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -2.0)
		h.input.at(5, {"attack": true})
		h.input.at(65, {"attack": true})
		h.input.at(115, {"attack": true})
	func hits() -> int:
		var n := 0
		for e in Sim.events:
			if e.begins_with("HIT EFFIGY"): n += 1
		return n
	func step(f: int) -> bool:
		var e = h.effigies[0]
		if f == 40:
			check(absf(e.hp - 40.0) < 0.01, "in-reach swing deals exactly 20 once, hp=%.2f" % e.hp)
			check(hits() == 1, "exactly one hit event")
		if f == 60: e.position = Vector3(0, 0.05, -5.0)
		if f == 100:
			check(absf(e.hp - 40.0) < 0.01, "out-of-reach swing whiffs, hp=%.2f" % e.hp)
			e.position = Vector3(2.0, 0.05, 0.0)
		if f == 150:
			check(absf(e.hp - 40.0) < 0.01, "target outside the swing arc whiffs, hp=%.2f" % e.hp)
			check(hits() == 1, "still exactly one hit event, got %d" % hits())
		return f >= 150

class ScenarioIFrames extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const T = preload("res://src/combat/tuning.gd")
	var run := 0
	var lf := 0
	func setup() -> void:
		name = "dodge_iframes"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
		h.player.feathers = 0.0
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -2.2)
	func step(f: int) -> bool:
		var p = h.player
		var e = h.effigies[0]
		p.feathers = 0.0
		if lf < 0:
			lf += 1
			return false
		if lf == 5: e._try_attack()
		if run == 1 and lf == 45: h.input.cur.dodge = true; h.input.cur.move = Vector2(0, -1)
		if run == 1 and lf == 46: h.input.cur.move = Vector2.ZERO
		if run == 2 and lf == 5: h.input.cur.dodge = true; h.input.cur.move = Vector2(0, -1)
		if run == 2 and lf == 6: h.input.cur.move = Vector2.ZERO
		lf += 1
		if lf < 95:
			return false
		if run == 0:
			check(absf(p.hp - 75.0) < 0.01, "standing player takes full 25, hp=%.2f" % p.hp)
			_start_run(1)
			return false
		if run == 1:
			check(absf(p.hp - 100.0) < 0.01, "roll timed into the blow takes zero (i-frames), hp=%.2f" % p.hp)
			check(Sim.events.has("PLAYER DODGED THROUGH"), "dodge-through is acknowledged")
			_start_run(2)
			return false
		check(absf(p.hp - 75.0) < 0.01, "roll that ends before the blow still gets hit, hp=%.2f" % p.hp)
		return true

class ScenarioLockOn extends Scenario:
	func setup() -> void:
		name = "lock_on"
		h.make_world(Vector3(0, 0.1, 0), [Vector3(5, 0.05, -4), Vector3(0, 0.05, -6)])
		h.player.facing = Vector3(0, 0, -1)
		h.input.at(5, {"lock": true})
		h.input.at(30, {"lock": true})
	func step(f: int) -> bool:
		var p = h.player
		if f == 10: check(p.lock_target == h.effigies[1], "lock takes the enemy nearest camera-forward")
		if f == 15: h.effigies[1].position = Vector3(0, 0.05, 30)
		if f == 25: check(p.lock_target == null, "lock breaks beyond break range")
		if f == 40: check(p.lock_target == h.effigies[0], "re-lock takes the remaining enemy in the cone")
		if f == 45:
			h.effigies[0].hp = 1.0
			h.effigies[0].apply_hit(10.0, Vector3.ZERO, 0.1)
		if f == 55: check(p.lock_target == null, "lock drops when the target dies")
		return f >= 55

class ScenarioTelegraph extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	var start_f := -1
	var hit_f := -1
	var second_start := -1
	var prev_hp := 100.0
	var hits := 0
	var player_attacked := false
	func setup() -> void:
		name = "telegraph_readability"
		h.make_world()
		h.player.feathers = 0.0
		h.effigies[0].position = Vector3(0, 0.05, -2.0)
		h.effigies[0].ai_enabled = true
		h.player.facing = Vector3(0, 0, -1)
	func step(f: int) -> bool:
		var p = h.player
		var e = h.effigies[0]
		if e.state == "attack" and start_f < 0:
			start_f = f
		if p.hp < prev_hp - 0.001:
			hits += 1
			if hit_f < 0: hit_f = f
		prev_hp = p.hp
		var raises := 0
		for ev in Sim.events:
			if ev == "EFFIGY RAISES ITS CLUB":
				raises += 1
		if raises >= 2 and second_start < 0:
			second_start = f
		if second_start > 0 and not player_attacked:
			h.input.cur.attack = true   # keep pressing until the stagger from the first hit lets go
			if p.state == "attack":
				player_attacked = true
		if second_start > 0 and f >= second_start + 90:
			check(start_f >= 0 and hit_f > start_f, "the blow lands after the windup")
			check(hit_f - start_f >= 48, "windup gives >= 0.8s of readable telegraph, got %d frames" % (hit_f - start_f))
			check(Sim.events.has("EFFIGY STAGGERED OUT OF SWING"), "hitting the effigy mid-windup cancels its swing")
			check(hits == 1, "the interrupted second swing never lands, player hits taken=%d" % hits)
			return true
		return f >= 500

class ScenarioHitstop extends Scenario:
	func setup() -> void:
		name = "hitstop"
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -2.0)
		h.input.at(5, {"attack": true})
	func step(f: int) -> bool:
		if f == 80:
			check(h.saw_pause, "landing a hit freezes the world briefly (hitstop)")
			check(not h.get_tree().paused, "hitstop releases")
			check(absf(h.effigies[0].hp - 40.0) < 0.01, "the hit still landed")
		return f >= 80

class ScenarioFeathers extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const Pickup = preload("res://src/world/feather_pickup.gd")
	var pre_pickup := 0.0
	func setup() -> void:
		name = "feather_economy"
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -6.0)
		h.player.feathers = 30.0
		h.input.at(30, {"volley": true})
		h.input.at(100, {"volley": true})
	func count(prefix: String) -> int:
		var n := 0
		for e in Sim.events:
			if e.begins_with(prefix): n += 1
		return n
	func step(f: int) -> bool:
		var p = h.player
		var e = h.effigies[0]
		if f == 5:
			p.apply_hit(25.0, e.global_position, 0.35)
		if f == 10:
			check(absf(p.hp - 87.5) < 0.01, "full coat halves a 25 hit to 12.5, hp=%.2f" % p.hp)
			p.hp = 100.0
			p.stagger_t = 0.0
			p.feathers = 0.0
			p.apply_hit(25.0, e.global_position, 0.35)
		if f == 15:
			check(absf(p.hp - 75.0) < 0.01, "bare player takes the full 25, hp=%.2f" % p.hp)
			p.hp = 100.0
			p.stagger_t = 0.0
			p.feathers = 30.0
		if f == 80:
			check(absf(e.hp - 36.0) < 0.01, "volley lands 3 feathers x 8 = 24, effigy hp=%.2f" % e.hp)
			check(count("FEATHER HIT") == 3, "three feather hit events, got %d" % count("FEATHER HIT"))
			check(p.feathers < 25.0, "volley spent 6 feathers (30->24 + slow regrowth), got %.2f" % p.feathers)
		if f == 90:
			p.feathers = 5.0
		if f == 110:
			check(Sim.events.has("VOLLEY DENIED feathers"), "volley is denied when the coat is too thin")
			check(count("VOLLEY -") == 1, "only one paid volley fired, got %d" % count("VOLLEY -"))
			pre_pickup = p.feathers
			var pk = Pickup.new()
			pk.position = p.position
			h.sim_root.add_child(pk)
		if f == 130:
			check(p.feathers > pre_pickup + 5.0, "walking over a loose feather feeds the coat (+%.1f)" % (p.feathers - pre_pickup))
		return f >= 130

class ScenarioRegen extends Scenario:
	func setup() -> void:
		name = "regen"
		h.make_world()
		h.player.stamina = 50.0
		h.player.feathers = 10.0
	func step(f: int) -> bool:
		if f == 100:
			check(h.player.stamina > 60.0, "stamina climbs back when rested, got %.2f" % h.player.stamina)
			check(h.player.feathers > 10.9, "the coat slowly regrows, got %.2f" % h.player.feathers)
		return f >= 100

class ScenarioHeavy extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const T = preload("res://src/combat/tuning.gd")
	var saw_roll := false
	var done_frame := -1
	func setup() -> void:
		name = "heavy_tradeoff"
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -2.2)
		h.input.at(5, {"heavy": true})
		h.input.at(12, {"dodge": true})
	func step(f: int) -> bool:
		var p = h.player
		var e = h.effigies[0]
		if f > 5 and done_frame < 0 and p.state == "free":
			done_frame = f
		if f > 85 and p.state == "roll":
			saw_roll = true
		if f == 10:
			check(absf(p.stamina - 68.0) < 0.01, "heavy costs 32 stamina, got %.2f" % p.stamina)
		if f == 34:
			check(absf(e.hp - 60.0) < 0.01, "heavy has not hit yet at frame 34 (windup is longer than light)")
			check(p.state == "attack", "heavy cannot be canceled mid-windup")
		if f == 50:
			check(absf(e.hp - 28.0) < 0.01, "heavy deals 32 when it lands, hp=%.2f" % e.hp)
		if f == 110:
			check(T.HEAVY_ATTACK.windup > T.PLAYER_ATTACK.windup and T.HEAVY_ATTACK.damage > T.PLAYER_ATTACK.damage, "heavy trades commitment for damage in the data")
			check(Sim.events.has("HEAVY START"), "heavy is its own labeled verb")
			check(saw_roll, "the buffered dodge fires after the heavy ends")
		return f >= 110

class ScenarioDeterminismA extends Scenario:
	func setup() -> void:
		name = "determinism_run_a"
		h.det_trace_a.clear()
		_det_world()
	func _det_world() -> void:
		h.make_world(Vector3(0, 0.1, 3), [Vector3(0, 0.05, -6)])
		h.effigies[0].ai_enabled = true
		h.input.at(5, {"move": Vector2(0, -1), "sprint": true})
		h.input.at(40, {"sprint": false})
		h.input.at(60, {"move": Vector2.ZERO})
		h.input.at(70, {"dodge": true})
		h.input.at(110, {"attack": true})
		h.input.at(150, {"lock": true})
		h.input.at(170, {"heavy": true})
		h.input.at(240, {"volley": true})
		h.input.at(300, {"attack": true})
	func _snap() -> Array:
		var p = h.player
		var e = h.effigies[0]
		return [snappedf(p.hp, 0.0001), snappedf(p.stamina, 0.0001), snappedf(p.feathers, 0.0001),
			snappedf(p.position.x, 0.0001), snappedf(p.position.z, 0.0001),
			snappedf(e.hp, 0.0001), snappedf(e.position.x, 0.0001), snappedf(e.position.z, 0.0001)]
	func step(_f: int) -> bool:
		h.det_trace_a.append(_snap())
		return h.det_trace_a.size() >= 400

class ScenarioDeterminismB extends ScenarioDeterminismA:
	var mismatches := 0
	func setup() -> void:
		name = "determinism_run_b"
		_det_world()
	func step(f: int) -> bool:
		if f < h.det_trace_a.size() and _snap() != h.det_trace_a[f]:
			mismatches += 1
		if f >= 399:
			check(mismatches == 0, "two identical 400-frame scripts produce identical state traces (%d mismatches)" % mismatches)
			return true
		return false

func _register() -> void:
	scenarios = [
		ScenarioStamina.new(),
		ScenarioCommitment.new(),
		ScenarioHitWindow.new(),
		ScenarioIFrames.new(),
		ScenarioLockOn.new(),
		ScenarioTelegraph.new(),
		ScenarioHitstop.new(),
		ScenarioFeathers.new(),
		ScenarioRegen.new(),
		ScenarioHeavy.new(),
		ScenarioDeterminismA.new(),
		ScenarioDeterminismB.new(),
	]
	for sc in scenarios:
		sc.h = self
