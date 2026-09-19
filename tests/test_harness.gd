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
	var cur := {"move": Vector2.ZERO, "sprint": false, "dodge": false, "attack": false, "heavy": false, "volley": false, "lock": false, "block": false, "heal": false, "interact": false, "sneak": false, "use_item": false, "jump": false, "weapon_swap": false}
	func at(f: int, set: Dictionary) -> void:
		plan.append({"f": f, "set": set})
	func begin_frame(f: int) -> void:
		cur.dodge = false
		cur.attack = false
		cur.heavy = false
		cur.volley = false
		cur.lock = false
		cur.heal = false
		cur.interact = false
		cur.use_item = false
		cur.jump = false
		cur.weapon_swap = false
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
		if f == 10: check(absf(p.stamina - 84.0) < 0.01, "roll costs 16 (100->84), got %.2f" % p.stamina)
		if f == 59: st59 = p.stamina
		if f == 66: check(st59 - p.stamina >= 18.0 and st59 - p.stamina <= 20.5, "swing costs ~20 (45/s regen overlaps the window), delta %.2f" % (st59 - p.stamina))
		if f == 150: check(p.stamina > 60.0, "stamina regenerates after delay, got %.2f" % p.stamina)
		if f == 170: st170 = p.stamina
		if f == 215:
			st215 = p.stamina
			var per_sec := (st170 - st215) * 60.0 / 45.0
			check(absf(per_sec - 14.0) < 0.6, "sprint drains ~14/s, measured %.2f/s" % per_sec)
		return f >= 240

class ScenarioCommitment extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	var interrupted := false
	var roll_frame := -1
	func setup() -> void:
		name = "attack_commitment"
		h.make_world()
		h.input.at(15, {"attack": true})   # grounded: f<10 attacks land as airborne jump-attacks (spawn drop)
		h.input.at(20, {"dodge": true})
		h.input.at(45, {"dodge": true})
	func step(f: int) -> bool:
		var p = h.player
		# blade light 1: windup f15-32, active f32-40, committed recovery f40-55 (60%); cancel opens f55
		if f >= 16 and f <= 54 and p.state != "attack":
			interrupted = true
		if roll_frame < 0 and p.state == "roll":
			roll_frame = f
		if f == 100:
			check(not interrupted, "windup, active, and the committed 60% of recovery never interrupt")
			check(roll_frame >= 54 and roll_frame <= 58, "dodge cancel fires at the cancel point (~f55), got f%d" % roll_frame)
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
		h.effigies[0].facing = Vector3(0, 0, 1)
		h.input.at(15, {"attack": true})   # grounded (spawn drop makes earlier attacks jump-attacks)
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
		h.effigies[0].facing = Vector3(0, 0, 1)  # faces the player: run 3 crits come from the parry window, not backstab
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
			check(absf(p.hp - 85.0) < 0.01, "standing player takes full 15 (iter4 balance proposal), hp=%.2f" % p.hp)
			_start_run(1)
			return false
		if run == 1:
			check(absf(p.hp - 100.0) < 0.01, "roll timed into the blow takes zero (i-frames), hp=%.2f" % p.hp)
			check(Sim.events.has("PLAYER DODGED THROUGH"), "dodge-through is acknowledged")
			_start_run(2)
			return false
		check(absf(p.hp - 85.0) < 0.01, "roll that ends before the blow still gets hit, hp=%.2f" % p.hp)
		return true


class ScenarioDefense extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	var run := 0
	var lf := -2
	func setup() -> void:
		name = "defense_verbs"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -2.2)
		h.effigies[0].facing = Vector3(0, 0, 1)  # faces the player: run 3 crits come from the parry window, not backstab
	func step(f: int) -> bool:
		var p = h.player
		var e = h.effigies[0]
		if lf < 0:
			lf += 1
			return false
		if lf == 0:
			if run <= 1:
				p.feathers = 0.0; p.stamina = 100.0
			elif run == 2:
				p.feathers = 0.0; p.stamina = 3.0  # block regen (9/s) climbs ~8 by impact; 3 stays under the 13.5 chip
			else:
				p.feathers = 10.0
		if lf == 5: e._try_attack()
		if run == 0:
			h.input.cur.block = true
		if run == 1 and lf == 49:
			h.input.cur.block = true
		if run == 2:
			h.input.cur.block = true
		if run == 3 and lf == 49:
			h.input.cur.dodge = true; h.input.cur.move = Vector2(0, -1)
		if run == 3 and lf == 50:
			h.input.cur.move = Vector2.ZERO
		if run == 4 and lf == 40:
			h.input.cur.dodge = true; h.input.cur.move = Vector2(0, -1)
		if run == 4 and lf == 41:
			h.input.cur.move = Vector2.ZERO
		lf += 1
		if lf < 100:
			return false
		if run == 0:
			check(absf(p.hp - 95.5) < 0.01, "held block chips 30 percent of 15 through, hp=%.2f" % p.hp)
			check(p.stamina >= 86.4 and p.stamina <= 87.5, "blocked hit drains stamina ~13.5 (trickle regen after), stamina=%.2f" % p.stamina)
			var blk := false
			for ev in Sim.events:
				if ev.begins_with("BLOCKED"): blk = true
			check(blk, "block is acknowledged in the log")
			_start_run(1)
			return false
		if run == 1:
			check(absf(p.hp - 100.0) < 0.01, "tight block press deflects: zero damage, hp=%.2f" % p.hp)
			check(absf(p.stamina - 100.0) < 0.5, "parry costs no stamina, stamina=%.2f" % p.stamina)
			check(Sim.events.has("PARRY - DEFLECTED"), "parry is acknowledged")
			check(e.attack == null and e.stagger_t > 0.5, "deflected effigy reels (punish window), stagger=%.2f" % e.stagger_t)
			_start_run(2)
			return false
		if run == 2:
			check(absf(p.hp - 85.0) < 0.01, "guard break lets the full 15 through, hp=%.2f" % p.hp)
			var broke := false
			for ev in Sim.events:
				if ev.begins_with("GUARD BREAK"): broke = true
			check(broke, "guard break is acknowledged")
			check(p.state == "free", "guard break knocks the guard open, state=%s" % p.state)
			_start_run(3)
			return false
		if run == 3:
			check(absf(p.hp - 100.0) < 0.01, "perfect dodge takes zero, hp=%.2f" % p.hp)
			check(absf(p.feathers - 10.0) < 0.01, "perfect dodge pays nothing yet (no invented rewards, Omer rule), feathers=%.2f" % p.feathers)
			var perf := false
			for ev in Sim.events:
				if ev == "PERFECT DODGE": perf = true
			check(perf, "perfect dodge is acknowledged")
			_start_run(4)
			return false
		check(absf(p.hp - 100.0) < 0.01, "early roll still dodges through, hp=%.2f" % p.hp)
		check(absf(p.feathers - 10.0) < 0.01, "early roll earns no feathers, feathers=%.2f" % p.feathers)
		check(Sim.events.has("PLAYER DODGED THROUGH"), "plain dodge-through is acknowledged")
		return true


class ScenarioRooms extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	var run := 0
	var lf := -2
	func setup() -> void:
		name = "training_dummy_vs_real_enemy"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()  # harness world: effigy starts ai_enabled = false (training dummy)
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -2.2)
		h.effigies[0].facing = Vector3(0, 0, 1)  # faces the player so vision can engage
	func step(f: int) -> bool:
		var e = h.effigies[0]
		if lf < 0:
			lf += 1
			return false
		lf += 1
		if run == 0:
			if lf >= 400:
				var raised := false
				for ev in Sim.events:
					if ev.contains("RAISES"): raised = true
				check(not raised, "training dummy never strikes back across 400 frames in range")
				check(e.attack == null, "training dummy never enters a swing")
				e.ai_enabled = true
				lf = 0
				run = 1
			return false
		if lf >= 300:
			var raised2 := false
			for ev in Sim.events:
				if ev.contains("RAISES"): raised2 = true
			check(raised2, "the one real enemy engages on its own within 300 frames")
			return true
		return false


class ScenarioMachinery extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const Checkpoint = preload("res://src/world/checkpoint.gd")
	const DeathPenalty = preload("res://src/combat/death_penalty.gd")
	const Progression = preload("res://src/combat/progression.gd")
	var run := 0
	var lf := -2
	func setup() -> void:
		name = "machinery_scaffolds"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -2.2)
		h.effigies[0].facing = Vector3(0, 0, 1)  # faces the player: run 3 crits come from the parry window, not backstab
	func step(f: int) -> bool:
		var p = h.player
		var e = h.effigies[0]
		if lf < 0:
			lf += 1
			return false
		match run:
			0:  # heal machinery
				if lf == 0: p.hp = 50.0
				if lf == 5: h.input.cur.heal = true
				if lf == 70:
					check(absf(p.hp - 90.0) < 0.01, "heal machinery: +40 scaffold after the commit, hp=%.2f" % p.hp)
					check(p.heal_charges == 2, "a charge was spent (3->2), charges=%d" % p.heal_charges)
					var healed := false
					for ev in Sim.events:
						if ev.begins_with("HEALED"): healed = true
					check(healed, "heal completion is acknowledged")
					p.heal_charges = 0
					h.input.cur.heal = true
				if lf == 80:
					check(Sim.events.has("HEAL DENIED charges"), "heal is denied with no charges")
					_start_run(1)
					return false
			1:  # checkpoint machinery
				if lf == 0:
					var cp = Checkpoint.new()
					cp.position = p.position
					h.sim_root.add_child(cp)
				if lf == 5: h.input.cur.interact = true
				if lf == 20:
					check(Sim.events.has("CHECKPOINT REGISTERED"), "checkpoint registers on interact")
					check(Sim.events.has("CHECKPOINT OPENED (no shell wired)"), "interact asks for the rest menu (menu itself is covered by checkpoint_rest)")
					check(Sim.active_checkpoint != null, "the checkpoint is registered as active")
					_start_run(2)
					return false
			2:  # death remnant: the drop takes the essence, walking back returns it - the coat is untouched
				if lf == 0:
					p.feathers = 10.0
					p.progression.essence = 40.0
					DeathPenalty.drop(p, h.sim_root)
					check(absf(p.progression.essence) < 0.01, "death drops every essence where they fell, essence=%.0f" % p.progression.essence)
					check(absf(p.feathers - 10.0) < 0.01, "death does NOT touch the coat (Omer ruling 2026-09-19), feathers=%.0f" % p.feathers)
				if lf == 20:
					var rec := false
					for ev in Sim.events:
						if ev.begins_with("REMNANT RECOVERED"): rec = true
					check(rec, "walking over the remnant recovers it")
					check(absf(p.progression.essence - 40.0) < 0.01, "the recovery returns every essence, essence=%.0f" % p.progression.essence)
					check(absf(p.feathers - 10.0) < 0.01, "the coat was never part of the drop, feathers=%.0f" % p.feathers)
					_start_run(3)
					return false
			3:  # riposte machinery: parry opens the crit window, next hit crits
				if lf == 5: e._try_attack()
				if lf == 49: h.input.cur.block = true
				if lf == 69: h.input.cur.block = false
				if lf == 70:
					check(e.crit_open_t > 0.0, "parry reel opens the crit window, t=%.2f" % e.crit_open_t)
					h.input.cur.attack = true
				if lf == 110:
					check(absf(e.hp - 20.0) < 0.01, "riposte machinery: 20 x 2.0 scaffold = 40 damage, hp=%.2f" % e.hp)
					var rip := false
					for ev in Sim.events:
						if ev.begins_with("RIPOSTE"): rip = true
					check(rip, "riposte is acknowledged")
					_start_run(4)
					return false
			4:  # unblockable flag machinery: block does not hold
				if lf == 0:
					p.feathers = 0.0
					e.forced_attack_data = {"damage": 25.0, "windup": 0.85, "active": 0.12, "recovery": 1.05, "reach": 2.6, "arc_deg": 90.0, "unblockable": true}
				if lf == 5: e._try_attack()
				if lf == 6: h.input.cur.block = true
				if lf == 90:
					check(absf(p.hp - 75.0) < 0.01, "unblockable blow goes through the guard at full 25, hp=%.2f" % p.hp)
					var blk2 := false
					for ev in Sim.events:
						if ev.begins_with("BLOCKED") or ev.begins_with("PARRY"): blk2 = true
					check(not blk2, "unblockable is never blocked or parried")
					_start_run(5)
					return false
			5:  # attack chain machinery: two linked swings land in order
				if lf == 0:
					p.feathers = 0.0
					var link := {"damage": 25.0, "windup": 0.4, "active": 0.12, "recovery": 0.5, "reach": 2.6, "arc_deg": 90.0, "delay": 0.2}
					e.attack_chain = [link]
				if lf == 5: e._try_attack()
				if lf == 200:
					check(Sim.events.has("EFFIGY CHAINS AGAIN"), "the chain follow-up fires")
					check(absf(p.hp - 60.0) < 0.01, "both linked swings land (15 + 25), hp=%.2f" % p.hp)
					_start_run(6)
					return false
			6:  # progression machinery: essence add/spend path, upgrade hook - feathers never involved
				if lf == 5:
					var prog = Progression.new()
					p.feathers = 20.0
					prog.add_essence(20.0)
					check(prog.spend({"essence": 6.0}, p), "spend path accepts an affordable cost")
					check(absf(prog.essence - 14.0) < 0.01, "spend deducts essence (20->14), essence=%.2f" % prog.essence)
					check(absf(p.feathers - 20.0) < 0.01, "an essence spend never touches the coat (ruling 2026-09-19), feathers=%.0f" % p.feathers)
					check(not prog.spend({"essence": 99.0}, p), "spend path refuses an unaffordable cost")
					check(prog.apply_upgrade("test_upgrade", p) and prog.applied_upgrades.has("test_upgrade"), "upgrade hook records the application")
					return true
		lf += 1
		return false


class ScenarioMachinery2 extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const T2 = preload("res://src/combat/tuning.gd")
	var run := 0
	var lf := -2
	var start_x := 0.0
	func setup() -> void:
		name = "sneak_status_items"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
		h.effigies[0].position = Vector3(0, 0.05, 60.0)  # out of the walk path
	func _sounds_with(tag: String) -> int:
		var n := 0
		for ev in Sim.events:
			if ev.begins_with("SOUND") and ev.contains(tag): n += 1
		return n
	func step(f: int) -> bool:
		var p = h.player
		if lf < 0:
			lf += 1
			return false
		match run:
			0:  # sneak = slow walk; movement emits sound events (machinery only)
				if lf == 0:
					h.input.cur.move = Vector2(0, -1)
					h.input.cur.sneak = true
					start_x = p.position.x
				if lf == 60:
					var spd: float = Vector2(p.velocity.x, p.velocity.z).length()
					check(spd < T2.WALK_SPEED * 0.6 and spd > 0.5, "sneak walk is slow (%.2f vs walk %.2f)" % [spd, T2.WALK_SPEED])
					check(_sounds_with("r=2.5") > 0, "sneak footsteps emit quiet sound events")
					h.input.cur.sneak = false
					h.input.cur.move = Vector2(0, -1)
					Sim.events.clear()
				if lf == 120:
					check(_sounds_with("r=6.0") > 0, "normal footsteps emit medium sound events")
					check(_sounds_with("r=2.5") == 0, "no sneak-radius sound once sneak is released")
					h.input.cur.sprint = true
					Sim.events.clear()
				if lf == 170:
					check(_sounds_with("r=10.0") > 0, "sprint footsteps emit loud sound events")
					h.input.cur.sprint = false
					h.input.cur.move = Vector2.ZERO
					h.input.cur.dodge = true
				if lf == 190:
					check(_sounds_with("r=8.0") > 0, "rolling emits a sound event")
					_start_run(1)
					return false
			1:  # status machinery: build-up, trigger, tick, expiry, decay
				if lf == 0:
					p.statuses.register_status("test_bleed", {"threshold": 30.0, "duration": 1.0, "tick_interval": 0.5})
					p.statuses.add_buildup("test_bleed", 20.0, p.display_name)
				if lf == 5:
					check(not p.statuses.is_active("test_bleed"), "buildup below threshold has not triggered")
					p.statuses.add_buildup("test_bleed", 15.0, p.display_name)
				if lf == 10:
					check(p.statuses.is_active("test_bleed"), "crossing the threshold triggers the status")
				if lf == 45:  # ~0.58s after trigger at lf7-ish: at least one tick
					var ticks := 0
					for ev in Sim.events:
						if ev.begins_with("STATUS TICK test_bleed"): ticks += 1
					check(ticks >= 1, "active status ticks, ticks=%d" % ticks)
				if lf == 90:
					var expired := false
					for ev in Sim.events:
						if ev.begins_with("STATUS EXPIRED test_bleed"): expired = true
					check(expired, "status expires after its duration")
					p.statuses.add_buildup("test_bleed", 10.0, p.display_name)
				if lf == 150:
					check(p.statuses.meters.get("test_bleed", 0.0) < 10.0, "untriggered buildup decays, meter=%.1f" % p.statuses.meters.get("test_bleed", 0.0))
					_start_run(2)
					return false
			2:  # consumable machinery: slots, quantity, commit-gated use, effect hook
				if lf == 0:
					p.hp = 50.0
					p.inventory.register_item_def("test_draught", func(u): u.hp += 5.0)
					p.inventory.add_item("test_draught", 2)
				if lf == 5: h.input.cur.use_item = true
				if lf == 20:
					check(absf(p.hp - 50.0) < 0.01, "item has not fired yet mid-commit, hp=%.1f" % p.hp)
				if lf == 60:  # 0.8s commit = 48 frames after lf5
					check(absf(p.hp - 55.0) < 0.01, "item effect hook applied after the commit, hp=%.1f" % p.hp)
					var used := false
					for ev in Sim.events:
						if ev.begins_with("ITEM USED test_draught"): used = true
					check(used, "item use is acknowledged")
					check(p.inventory.slots[0].qty == 1, "quantity tracked (2->1)")
					h.input.cur.use_item = true
				if lf == 115:
					check(absf(p.hp - 60.0) < 0.01, "second use applies again, hp=%.1f" % p.hp)
					check(p.inventory.slots.size() == 0, "slot empties at zero quantity")
					h.input.cur.use_item = true
				if lf == 130:
					check(Sim.events.has("ITEM DENIED empty slot"), "using an empty slot is denied")
					return true
		lf += 1
		return false


class ScenarioMachinery3 extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	var run := 0
	var lf := -2
	func setup() -> void:
		name = "moveset_jump"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
		h.effigies[0].position = Vector3(0, 0.05, 60.0)
	func _slots() -> Array:
		var out := []
		for ev in Sim.events:
			if ev.begins_with("ATTACK SLOT "): out.append(ev.trim_prefix("ATTACK SLOT "))
		return out
	func step(f: int) -> bool:
		var p = h.player
		if lf < 0:
			lf += 1
			return false
		match run:
			0:  # moveset machinery: light chain advances and resets
				if lf == 5: h.input.cur.attack = true
				if lf == 60: h.input.cur.attack = true   # inside the chain window
				if lf == 200: h.input.cur.attack = true  # window expired: back to link 0
				if lf == 260:
					var sl := _slots()
					check(sl.size() == 3, "three attacks ran through the moveset table, got %d" % sl.size())
					check(sl[0] == "light_chain[0]", "first light is chain link 0, got %s" % sl[0])
					check(sl[1] == "light_chain[1]", "second light inside the window is link 1, got %s" % sl[1])
					check(sl[2] == "light_chain[0]", "after the window lapses the chain resets, got %s" % sl[2])
					_start_run(1)
					return false
			1:  # running and rolling attack slots
				if lf == 0:
					h.input.cur.move = Vector2(0, -1)
					h.input.cur.sprint = true
				if lf == 30:
					h.input.cur.attack = true
				if lf == 31:
					h.input.cur.sprint = false
					h.input.cur.move = Vector2.ZERO
				if lf == 90: h.input.cur.dodge = true
				if lf == 140: h.input.cur.attack = true  # roll ends ~lf132, window 0.4s
				if lf == 200:
					var sl := _slots()
					check(sl.size() == 2, "two situational attacks ran, got %d" % sl.size())
					check(sl[0] == "running_attack", "attack while sprinting uses the running slot, got %s" % sl[0])
					check(sl[1] == "rolling_attack", "attack right after a roll uses the rolling slot, got %s" % sl[1])
					_start_run(2)
					return false
			2:  # jump verb + jump-attack hook
				if lf == 5: h.input.cur.jump = true
				if lf == 20:
					check(p.position.y > 0.25, "jump leaves the floor, y=%.2f" % p.position.y)
				if lf == 60:
					check(p.is_on_floor(), "jump lands back on the floor")
					h.input.cur.jump = true
				if lf == 70: h.input.cur.attack = true  # airborne
				if lf == 130:
					var sl := _slots()
					check(sl.size() == 1 and sl[0] == "jump_attack", "attacking airborne uses the jump-attack slot, got %s" % (sl[0] if sl.size() > 0 else "none"))
					return true
		lf += 1
		return false


class ScenarioMachinery4 extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const Checkpoint = preload("res://src/world/checkpoint.gd")
	var run := 0
	var lf := -2
	func setup() -> void:
		name = "awareness_ranged_fall"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
	func step(f: int) -> bool:
		var p = h.player
		var e = h.effigies[0]
		if lf < 0:
			lf += 1
			return false
		match run:
			0:  # vision: standing in the cone alerts; sneaking halves the range
				if lf == 0:
					e.ai_enabled = true
					e.position = Vector3(0, 0.05, -8.0)
					e.facing = Vector3(0, 0, 1)   # faces the player at origin
					p.position = Vector3(0, 0.05, 0.0)
					h.input.cur.sneak = true
				if lf == 120:
					check(e.awareness.state == "calm", "sneaking at 8m stays unseen (range halved to 6), state=%s" % e.awareness.state)
					h.input.cur.sneak = false
				if lf == 240:
					check(e.awareness.state == "alert", "standing in the cone at 8m alerts, state=%s" % e.awareness.state)
					var alerted := false
					for ev in Sim.events:
						if ev.begins_with("ALERT EFFIGY"): alerted = true
					check(alerted, "alert transition is acknowledged")
					_start_run(1)
					return false
			1:  # hearing: loud footsteps behind it pull awareness without sight
				if lf == 0:
					e.ai_enabled = true
					e.position = Vector3(5.0, 0.05, -6.0)  # beside the strafe path: footsteps stay in radius
					e.facing = Vector3(0, 0, -1)  # back turned to the player
					p.position = Vector3(0, 0.05, 0.0)
					h.input.cur.move = Vector2(1, 0)   # strafe in place range, loud
					h.input.cur.sprint = true
				if lf == 200:
					check(e.awareness.state == "alert", "loud footsteps within radius alert from behind, state=%s" % e.awareness.state)
					h.input.cur.sprint = false
					h.input.cur.move = Vector2.ZERO
					_start_run(2)
					return false
			2:  # enemy projectile machinery
				if lf == 0:
					p.position = Vector3(0, 0.05, 0.0)
					p.feathers = 0.0
					e.position = Vector3(0, 0.05, -5.0)
					e.forced_attack_data = {"windup": 0.3, "active": 0.1, "recovery": 0.5, "reach": 0.0, "arc_deg": 0.0, "damage": 0.0, "projectile": {"speed": 12.0, "damage": 10.0, "life": 1.5, "log_prefix": "SHOT HIT"}}
				if lf == 5: e._try_attack()
				if lf == 90:
					var shot := false
					for ev in Sim.events:
						if ev.begins_with("SHOT HIT PLAYER"): shot = true
					check(shot, "enemy projectile flies and lands (machinery)")
					check(absf(p.hp - 90.0) < 0.01, "projectile deals its scaffold 10, hp=%.2f" % p.hp)
					_start_run(3)
					return false
			3:  # checkpoint respawn linkage
				if lf == 0:
					var cp = Checkpoint.new()
					cp.position = Vector3(5.0, 0.05, 5.0)
					h.sim_root.add_child(cp)
					cp.activate(p)
				if lf == 5:
					var rsp: Vector3 = Checkpoint.respawn_position(Vector3(-99, 0, -99))
					check(rsp.distance_to(Vector3(5.0, 0.15, 5.0)) < 0.2, "respawn resolves to the registered checkpoint")
					Sim.active_checkpoint = null
					check(Checkpoint.respawn_position(Vector3(-99, 0, -99)).x < -90.0, "without a checkpoint respawn falls back to spawn")
					_start_run(4)
					return false
			4:  # fall damage machinery
				if lf == 0:
					p.position = Vector3(0, 3.0, 0.0)   # low hop: v ~ 10.4 < 12 safe
				if lf == 80:
					check(absf(p.hp - 100.0) < 0.01, "a safe fall hurts nothing, hp=%.2f" % p.hp)
					p.position = Vector3(0, 15.0, 0.0)  # long drop: v ~ 23 > 12
				if lf == 200:
					var fell := false
					for ev in Sim.events:
						if ev.begins_with("FALL DAMAGE"): fell = true
					check(fell, "a long fall deals fall damage (scaffold)")
					check(p.hp < 100.0, "hp dropped from the fall, hp=%.2f" % p.hp)
					return true
		lf += 1
		return false


class ScenarioComboCancel extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	var run := 0
	var lf := -2
	func setup() -> void:
		name = "combo_cancel"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -2.0)
		h.effigies[0].facing = Vector3(0, 0, 1)  # faces the player: no backstab crits
	func step(f: int) -> bool:
		var p = h.player
		if lf < 0:
			lf += 1
			return false
		if run == 0:  # buffered chain cancel: the second hit lands early
			if lf == 5: h.input.cur.attack = true
			if lf == 20: h.input.cur.attack = true  # buffered mid-swing
			if lf == 95:
				var hits: Array = []
				for st in Sim.stats:
					if st.get("k") == "hit": hits.append(st)
				check(hits.size() >= 2, "the buffered chain lands two hits, got %d" % hits.size())
				if hits.size() >= 2:
					var gap: int = int(hits[1].t) - int(hits[0].t)
					check(gap < 750, "chain cancel flows: hit gap %dms beats the uncanceled 840ms" % gap)
				_start_run(1)
				return false
		else:  # dodge cancel: roll out of late recovery before the swing would end
			if lf == 5: h.input.cur.attack = true
			if lf == 20:
				h.input.cur.dodge = true
				h.input.cur.move = Vector2(0, 1)
			if lf == 30:
				h.input.cur.move = Vector2.ZERO
			if lf == 51:
				check(p.state == "roll", "dodge cancel fires inside late recovery, state=%s" % p.state)
				return true
		lf += 1
		return false

class ScenarioCheckpointRest extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const Shell = preload("res://src/ui/shell.gd")
	const Progression = preload("res://src/combat/progression.gd")
	var shell
	func setup() -> void:
		name = "checkpoint_rest"
		h.make_world()
		shell = Shell.new()
		shell.player = h.player
		shell.checkpoint_ctx = {"progression": Progression.new(), "effigies": h.effigies}
		h.add_child(shell)
	func step(f: int) -> bool:
		var p = h.player
		var e = h.effigies[0]
		if f == 2:
			p.heal_charges = 1
			p.hp = 40.0
			e.apply_hit(999.0, p.global_position, 1.0)
			shell.open("checkpoint", false)
		if f == 4:
			check(shell.menu_items.size() == 4, "checkpoint menu offers rest, two upgrades, leave - got %d" % shell.menu_items.size())
			check(e.dead, "the effigy is felled before the rest")
			shell.activate()  # REST
		if f == 6:
			check(p.heal_charges == p.max_heal_charges and absf(p.hp - p.max_hp) < 0.01, "rest refills heals and hp, charges=%d hp=%.0f" % [p.heal_charges, p.hp])
			check(not e.dead and e.position.distance_to(e.spawn_pos) < 0.01, "the fallen rise again at their post")
			check(shell.state == "hidden", "rest closes the menu")
		if f == 8:
			p.feathers = 25.0
			shell.checkpoint_ctx.progression.essence = 25.0
			shell.open("checkpoint", false)
			shell.nav(1)
			shell.activate()  # HARDEN
		if f == 10:
			check(absf(p.max_hp - 110.0) < 0.01 and absf(shell.checkpoint_ctx.progression.essence - 5.0) < 0.01, "harden spends 20 essence for +10 max hp, max_hp=%.0f essence=%.0f" % [p.max_hp, shell.checkpoint_ctx.progression.essence])
			check(absf(p.feathers - 25.0) < 0.01, "the spend never touches the coat (ruling 2026-09-19), feathers=%.0f" % p.feathers)
		if f == 12:
			shell.nav(1)
			shell.activate()  # MEND with only 5 essence
		if f == 14:
			check(p.max_heal_charges == 3, "mend is denied when poor, capacity=%d" % p.max_heal_charges)
			shell.checkpoint_ctx.progression.essence = 35.0
			shell.activate()  # still on MEND
		if f == 16:
			check(p.max_heal_charges == 4 and absf(shell.checkpoint_ctx.progression.essence - 5.0) < 0.01, "mend spends 30 for +1 charge capacity, capacity=%d essence=%.0f" % [p.max_heal_charges, shell.checkpoint_ctx.progression.essence])
			return true
		return false

class ScenarioPatternCycle extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const T3 = preload("res://src/combat/tuning.gd")
	var run := 0
	var lf := -2
	func setup() -> void:
		name = "pattern_cycle"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world(Vector3(0, 0.1, 0), [Vector3(0, 0.05, -2.0)])
	func step(f: int) -> bool:
		var _unused = f
		var p = h.player
		var e = h.effigies[0]
		match run:
			0:  # the cycle: swings 1-2 never chain, swing 3 chains, double lands 15+10, longer rest after
				if lf == 0:
					p.feathers = 0.0
				if lf == 2:
					e._try_attack()
					check(e.attack_chain.is_empty(), "swing 1 of the cycle never chains")
					e.attack = null
					e.state = "idle"
				if lf == 4:
					e._try_attack()
					check(e.attack_chain.is_empty(), "swing 2 of the cycle never chains")
					e.attack = null
					e.state = "idle"
				if lf == 6:
					e._try_attack()
					check(e.attack_chain.size() == 1, "every third swing chains the follow-up")
				if lf == 260:
					check(Sim.events.has("EFFIGY CHAINS AGAIN"), "the pattern follow-up fires after the third swing")
					check(absf(p.hp - 75.0) < 0.01, "the double lands honestly: 15 then 10, hp=%.2f" % p.hp)
					check(e.cooldown > 1.5, "the double is paid for with a longer rest (punish window), cooldown=%.2f" % e.cooldown)
					check(e.winded_t > 0.0, "the opening is VISIBLE - winded after the double, winded=%.2f" % e.winded_t)
					check(Sim.events.has("EFFIGY WINDED - the opening"), "the opening is announced")
					_start_run(1)
					return false
			1:  # world reset: death/rise clears chain, pattern count, aggro, hp, position
				if lf == 2:
					e.attack_chain = [T3.DUMMY_ATTACK_FOLLOWUP.duplicate()]
					e.awareness.alert_now(e)
					e.hp = 25.0
					e.position.x = 3.0
					e.pattern_count = 2
					e.did_chain = true
					e.reset_run(e.spawn_pos)
				if lf == 4:
					check(absf(e.hp - e.max_hp) < 0.01, "the world reset restores full hp, hp=%.0f" % e.hp)
					check(e.position.distance_to(e.spawn_pos) < 0.01, "the world reset returns it to its post")
					check(e.attack_chain.is_empty() and e.pattern_count == 0 and not e.did_chain, "the world reset clears chain and pattern memory")
					check(e.awareness.state == "calm" and e.awareness.suspicion == 0.0, "the world reset calms its awareness")
					_start_run(2)
					return false
			2:  # the overhead: every 6th swing is unblockable - block fails, full damage lands
				if lf == 0:
					p.feathers = 0.0
				if lf == 2:
					e._try_attack()
					check(e.attack_chain.is_empty(), "swing 1 of the rhythm stays plain")
					e.attack = null
					e.attack_chain.clear()
					e.state = "idle"
				if lf == 4:
					e._try_attack()
					check(e.attack_chain.is_empty(), "swing 2 of the rhythm stays plain")
					e.attack = null
					e.attack_chain.clear()
					e.state = "idle"
				if lf == 6:
					e._try_attack()
					check(e.attack_chain.size() == 1, "swing 3 chains the follow-up")
					e.attack = null
					e.attack_chain.clear()
					e.state = "idle"
				if lf == 8:
					e._try_attack()
					check(e.attack_chain.is_empty(), "swing 4 of the rhythm stays plain")
					e.attack = null
					e.attack_chain.clear()
					e.state = "idle"
				if lf == 10:
					e._try_attack()
					check(e.attack_chain.is_empty(), "swing 5 of the rhythm stays plain")
					e.attack = null
					e.attack_chain.clear()
					e.state = "idle"
				if lf == 12:
					e._try_attack()
					check(e.attack.data.get("unblockable", false), "every 6th swing is the unblockable overhead")
					check(absf(e.attack.data.damage - 25.0) < 0.01, "the overhead is the heavy 25, dmg=%.0f" % e.attack.data.damage)
					h.input.cur.block = true
				if lf == 190:
					var heaved := false
					for ev in Sim.events:
						if ev.begins_with("EFFIGY HEAVES ITS CLUB OVERHEAD"): heaved = true
					check(heaved, "the overhead is announced distinctly")
					check(absf(p.hp - 75.0) < 0.01, "the overhead goes through the guard at full 25, hp=%.2f" % p.hp)
					return true
		lf += 1
		return false

class ScenarioRemnantPenalty extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const DeathPenalty = preload("res://src/combat/death_penalty.gd")
	var run := 0
	var lf := -2
	func setup() -> void:
		name = "remnant_penalty"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
	func step(f: int) -> bool:
		var _unused = f
		var p = h.player
		match run:
			0:  # a second death before recovery: the first remnant's essence is gone for good
				if lf == 0:
					p.feathers = 10.0
					p.progression.essence = 40.0
					DeathPenalty.drop(p, h.sim_root)
					check(absf(p.progression.essence) < 0.01, "the first death drops all 40 essence, essence=%.0f" % p.progression.essence)
					check(absf(p.feathers - 10.0) < 0.01, "the coat is untouched (ruling 2026-09-19), feathers=%.0f" % p.feathers)
					p.position = Vector3(12, 0.1, 12)  # walk away so it is not recovered
				if lf == 4:
					p.progression.essence = 15.0
					DeathPenalty.drop(p, h.sim_root)
					p.position = Vector3(24, 0.1, 24)  # away from the second drop too
				if lf == 8:
					var faded := false
					for ev in Sim.events:
						if ev == "THE FIRST REMNANT FADES - 40 essence gone for good": faded = true
					check(faded, "the second death spends the first remnant - 40 gone for good")
					var left := h.get_tree().get_nodes_in_group("remnants")
					check(left.size() == 1, "only the latest death leaves a mark, remnants=%d" % left.size())
					if left.size() == 1:
						check(absf(left[0].payload.contents.essence - 15.0) < 0.01, "the new remnant holds only the 15 from the second death")
					check(absf(p.feathers - 10.0) < 0.01, "two deaths later the coat is still whole, feathers=%.0f" % p.feathers)
					_start_run(1)
					return false
			1:  # recovery returns what the remnant holds
				if lf == 0:
					p.progression.essence = 40.0
					DeathPenalty.drop(p, h.sim_root)
				if lf == 20:
					check(Sim.events.has("REMNANT RECOVERED - 40 essence back"), "the recovery names what it returned")
					check(absf(p.progression.essence - 40.0) < 0.01, "every essence is back, essence=%.0f" % p.progression.essence)
					return true
		lf += 1
		return false

class ScenarioHealCommit extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	var run := 0
	var lf := -2
	func setup() -> void:
		name = "heal_commit"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		if r == 0:
			h.make_world()
		else:
			h.make_world(Vector3(0, 0.1, 0), [Vector3(0, 0.05, -2.0)])
	func step(f: int) -> bool:
		var _unused = f
		var p = h.player
		var e = h.effigies[0]
		match run:
			0:  # the charge is committed at the sip; an uninterrupted heal completes
				if lf == 0:
					p.hp = 40.0
					p.heal_charges = 3
				if lf == 2:
					h.input.cur.heal = true
				if lf == 4:
					check(p.heal_charges == 2, "the charge is committed at the sip (3->2 immediately), charges=%d" % p.heal_charges)
					check(absf(p.hp - 40.0) < 0.01, "the hp has not landed yet - the sip takes time")
				if lf == 80:
					check(absf(p.hp - 80.0) < 0.01, "the completed heal restores +40, hp=%.2f" % p.hp)
					check(p.heal_charges == 2, "completion spends nothing extra, charges=%d" % p.heal_charges)
					_start_run(1)
					return false
			1:  # hit mid-heal: the charge is spent and the heal is lost
				if lf == 0:
					p.hp = 60.0
					p.heal_charges = 3
					p.feathers = 0.0
				if lf == 2:
					h.input.cur.heal = true
				if lf == 4:
					e.forced_attack_data = {"damage": 10.0, "windup": 0.15, "active": 0.1, "recovery": 0.3, "reach": 2.6, "arc_deg": 90.0}
					e._try_attack()
				if lf == 45:
					check(Sim.events.has("HEAL INTERRUPTED - the charge is spent"), "the interruption is acknowledged")
					check(p.heal_charges == 2, "the interrupted sip still spent the charge, charges=%d" % p.heal_charges)
					check(absf(p.hp - 50.0) < 0.01, "no heal landed - only the hit did (60-10), hp=%.2f" % p.hp)
					var healed := false
					for ev in Sim.events:
						if ev.begins_with("HEALED"): healed = true
					check(not healed, "an interrupted heal never restores")
					return true
		lf += 1
		return false

class ScenarioEssenceScarcity extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	func setup() -> void:
		name = "essence_scarcity"
		h.make_world()
	func step(f: int) -> bool:
		var e = h.effigies[0]
		if f == 2:
			check(absf(e.kill_reward() - 6.0) < 0.01, "a fresh effigy is worth the full 6 essence")
			e.apply_hit(999.0, h.player.global_position, 1.0)
		if f == 4:
			check(e.dead, "the effigy is felled")
		if f == 250:
			check(not e.dead, "it rose again on its own timer")
			check(absf(e.kill_reward() - 1.0) < 0.01, "risen on its own timer it is worth only a token 1, reward=%.0f" % e.kill_reward())
			e.reset_run(e.spawn_pos, true)   # what REST and the world reset call
			check(absf(e.kill_reward() - 6.0) < 0.01, "after the world resets it is worth the full 6 again")
			return true
		return false

class ScenarioFullLoop extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const Shell = preload("res://src/ui/shell.gd")
	const Progression = preload("res://src/combat/progression.gd")
	const DeathPenalty = preload("res://src/combat/death_penalty.gd")
	var shell
	var lf := -2
	func setup() -> void:
		name = "full_loop"
		h.make_world()
		shell = Shell.new()
		shell.player = h.player
		shell.checkpoint_ctx = {"progression": Progression.new(), "effigies": h.effigies}
		h.add_child(shell)
	func step(f: int) -> bool:
		var _unused = f
		var p = h.player
		var e = h.effigies[0]
		if lf == 0:
			p.hp = 50.0
			p.heal_charges = 1
			p.feathers = 0.0
		if lf == 2:
			e.apply_hit(999.0, p.global_position, 1.0)
			p.progression.add_essence(e.kill_reward())
		if lf == 4:
			check(absf(p.progression.essence - 6.0) < 0.01, "the kill pays 6 essence, essence=%.0f" % p.progression.essence)
			check(absf(p.feathers) < 0.01, "the kill pays NO feathers (ruling 2026-09-19), feathers=%.0f" % p.feathers)
		if lf == 6:
			DeathPenalty.drop(p, h.sim_root)
			check(absf(p.progression.essence) < 0.01, "death drops the essence where they fell")
			check(absf(p.feathers) < 0.01, "death never touches the coat (ruling), feathers=%.0f" % p.feathers)
			var r = h.get_tree().get_nodes_in_group("remnants")[0]
			check(r.mote.scale.x > 1.05, "the mote's glow names the stash it holds, scale=%.2f" % r.mote.scale.x)
			p.reset_run(Vector3(0, 0.1, 6.0))  # respawn at the checkpoint, away from the drop
			check(absf(p.progression.essence) < 0.01, "respawn does NOT refund the drop - the essence waits where they fell, essence=%.0f" % p.progression.essence)
			check(absf(p.hp - p.max_hp) < 0.01 and p.heal_charges == p.max_heal_charges, "respawn still restores hp and heals")
		if lf == 10:
			p.position = Vector3(0, 0.1, 0.4)  # walk back onto the remnant
		if lf == 16:
			check(Sim.events.has("REMNANT RECOVERED - 6 essence back"), "the recovery walk pays the essence back")
			check(absf(p.progression.essence - 6.0) < 0.01, "the purse is whole again, essence=%.0f" % p.progression.essence)
		if lf == 18:
			shell.open("checkpoint", false)
			shell.activate()  # REST
		if lf == 20:
			check(not e.dead and e.position.distance_to(e.spawn_pos) < 0.01, "rest brings the felled back at their post")
			check(absf(e.kill_reward() - 6.0) < 0.01, "the world reset makes the kill worth the full 6 essence again")
		if lf == 22:
			p.feathers = 25.0
			shell.checkpoint_ctx.progression.essence = 25.0
			shell.open("checkpoint", false)
			shell.nav(1)
			shell.activate()  # HARDEN
		if lf == 24:
			check(absf(p.max_hp - 110.0) < 0.01 and absf(shell.checkpoint_ctx.progression.essence - 5.0) < 0.01, "the loop ends with a real spend: harden 20 essence for +10 max hp")
			check(absf(p.feathers - 25.0) < 0.01, "the spend never touched the coat (ruling), feathers=%.0f" % p.feathers)
			return true
		lf += 1
		return false

class ScenarioStaminaClamp extends Scenario:
	func setup() -> void:
		name = "stamina_clamp"
		h.make_world()
	func step(f: int) -> bool:
		var p = h.player
		if f == 2:
			p.stamina = 5.0
		if f == 5:
			h.input.cur.dodge = true
		if f == 7:
			check(p.stamina == 0.0, "roll from 5 stamina clamps at 0, never negative, st=%.2f" % p.stamina)
		if f == 90:
			check(p.stamina > 0.0, "stamina regenerates from a clamped zero, st=%.2f" % p.stamina)
			return true
		return false

class ScenarioShell extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const Shell = preload("res://src/ui/shell.gd")
	const SaveGame = preload("res://src/combat/save_game.gd")
	var run := 0
	var lf := -2
	var shell
	var fired := ""
	func setup() -> void:
		name = "shell_layer"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
		h.effigies[0].position = Vector3(0, 0.05, 60.0)
		shell = Shell.new()
		shell.player = h.player
		h.add_child(shell)
	func step(f: int) -> bool:
		var p = h.player
		if lf < 0:
			lf += 1
			return false
		match run:
			0:  # attributes machinery: register, raise, scaling hook feeds derived
				if lf == 5:
					p.attrs.register_attribute("vit", 10)
					p.attrs.register_scaling("max_hp", func(a): return 100.0 + a.vit * 2.0)
					p.recalculate_derived()
					check(absf(p.max_hp - 120.0) < 0.01, "registered scaling feeds max_hp (100 + 10x2), got %.1f" % p.max_hp)
					p.attrs.raise("vit", 5)
					p.recalculate_derived()
					check(absf(p.max_hp - 130.0) < 0.01, "raising the attribute moves the derived value, got %.1f" % p.max_hp)
					check(absf(p.attrs.derived("defense", 7.0) - 7.0) < 0.01, "unregistered derived keys fall back (no invented scaling)")
					_start_run(1)
					return false
			1:  # equipment machinery: swapping the weapon slot swaps the moveset
				if lf == 5:
					var T2 = preload("res://src/combat/tuning.gd")
					var fake := {"id": "test_3chain", "light_chain": [T2.PLAYER_ATTACK, T2.PLAYER_ATTACK, T2.PLAYER_ATTACK], "heavy": T2.HEAVY_ATTACK, "running_attack": T2.PLAYER_ATTACK, "rolling_attack": T2.PLAYER_ATTACK, "jump_attack": T2.PLAYER_ATTACK}
					p.equipment.equip("weapon", fake, p)
					check(p.moveset.get("id") == "test_3chain", "equipping swaps the player moveset table")
				if lf == 10: h.input.cur.attack = true
				if lf == 60: h.input.cur.attack = true
				if lf == 115: h.input.cur.attack = true
				if lf == 170:
					var n0 := 0
					var n2 := 0
					for ev in Sim.events:
						if ev == "ATTACK SLOT light_chain[0]": n0 += 1
						if ev == "ATTACK SLOT light_chain[2]": n2 += 1
					check(n2 == 1, "the equipped 3-link chain reaches link 2")
					check(n0 == 1, "and wraps back to link 0")
					_start_run(2)
					return false
			2:  # save/load machinery
				if lf == 5:
					p.position = Vector3(3.0, 0.05, -7.0)
					p.hp = 42.0
					p.feathers = 17.0
					p.heal_charges = 1
					p.attrs.register_attribute("str", 12)
					p.inventory.add_item("test_draught", 2)
					check(SaveGame.save_to_file(p, 4), "save writes to file")
					p.position = Vector3.ZERO
					p.hp = 100.0
					p.feathers = 0.0
					p.heal_charges = 3
					p.attrs.attrs.clear()
					p.inventory.slots.clear()
					var d: int = SaveGame.load_from_file(p)
					check(d == 4, "deaths count restores")
					check(p.position.distance_to(Vector3(3.0, 0.05, -7.0)) < 0.01, "position restores")
					check(absf(p.hp - 42.0) < 0.01 and absf(p.feathers - 17.0) < 0.01 and p.heal_charges == 1, "hp/feathers/charges restore")
					check(p.attrs.get_attr("str") == 12, "attributes restore")
					check(p.inventory.slots.size() == 1 and p.inventory.slots[0].qty == 2, "inventory restores")
					_start_run(3)
					return false
			3:  # menu machinery: nav, activate, hooks
				if lf == 5:
					shell.open("pause", false)
					check(shell.state == "pause" and shell.menu_items.size() == 3, "pause menu builds (resume/settings/title)")
					shell.nav(1)
					check(shell.sel == 1, "navigation moves the cursor")
					shell.nav(-1)
					check(shell.sel == 0, "navigation wraps")
					shell.activate()  # RESUME
					check(shell.state == "hidden", "RESUME closes the menu")
				if lf == 10:
					p.inventory.add_item("test_draught", 1)
					p.inventory.register_item_def("test_draught", func(u): u.hp += 5.0)
					p.hp = 50.0
					shell.open("inventory", false)
					check(shell.menu_items.size() == 2, "inventory lists the slot plus close, got %d" % shell.menu_items.size())
					shell.activate()  # use slot 0 through the UI
				if lf == 80:  # 0.8s commit after lf10
					check(absf(p.hp - 55.0) < 0.01, "using an item through the inventory UI applies the effect, hp=%.1f" % p.hp)
					shell.on_respawn = func(): fired = "respawn"
					shell.open("death", false)
					check(shell._death_menu.text.contains("YOU DIED"), "death screen carries the genre banner (full-screen label since iter 3)")
					shell.activate()
					check(fired == "respawn", "death screen fires the respawn hook")
					shell.on_begin = func(): fired = "begin"
					shell.open("title", false)
					shell.activate()
					check(fired == "begin", "title BEGIN hook fires")
					return true
		lf += 1
		return false


class ScenarioRound5A extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const Audio = preload("res://src/combat/audio_bus.gd")
	const Settings = preload("res://src/combat/settings.gd")
	const NGPlus = preload("res://src/combat/ngplus.gd")
	const Shell = preload("res://src/ui/shell.gd")
	const Checkpoint = preload("res://src/world/checkpoint.gd")
	var run := 0
	var lf := -2
	var shell
	func setup() -> void:
		name = "meta_scaffolds"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
		h.effigies[0].position = Vector3(0, 0.05, 60.0)
		shell = Shell.new()
		shell.player = h.player
		h.add_child(shell)
	func step(f: int) -> bool:
		var p = h.player
		if lf < 0:
			lf += 1
			return false
		match run:
			0:  # audio bus: game events emit semantic audio hooks
				if lf == 5: h.input.cur.attack = true
				if lf == 30:
					var swung := false
					for id in Audio.sfx_log:
						if id == "swing": swung = true
					check(swung, "attacking emits a swing sfx hook")
					var cp = Checkpoint.new()
					cp.position = p.position
					h.sim_root.add_child(cp)
					cp.activate(p)
					check(Audio.sfx_log.has("rest"), "checkpoint rest emits an sfx hook")
					_start_run(1)
					return false
			1:  # toast feed: player-facing messages flow to the feed
				if lf == 5:
					p.inventory.add_item("test_draught", 2)
				if lf == 15:
					var found := false
					for t in Sim.toasts:
						if str(t.get("m", "")).contains("test_draught"): found = true
					check(found, "gaining an item lands on the toast feed")
					check(Sim.toasts.size() <= 12, "the feed is bounded")
					_start_run(2)
					return false
			2:  # settings machinery: register, adjust, clamp, hook
				if lf == 5:
					var st = Settings.new()
					var seen := {"v": -1.0}
					st.register_setting("fov", {"label": "camera fov", "min": 60.0, "max": 70.0, "step": 5.0, "value": 65.0, "on_change": func(v): seen.v = v})
					st.adjust("fov", 1)
					check(absf(seen.v - 70.0) < 0.01, "adjusting fires the change hook with the new value")
					st.adjust("fov", 1)
					check(absf(seen.v - 70.0) < 0.01, "adjustment clamps at the bound")
					check(st.label_for("fov").contains("70"), "settings render for the menu")
					_start_run(3)
					return false
			3:  # gestures machinery: registry + perform through the shell menu
				if lf == 5:
					var did := {"g": false}
					p.gestures.register_gesture("point", func(_pl): did.g = true)
					shell.open("gestures", false)
					check(shell.menu_items.size() == 2, "gesture menu lists the registered gesture plus close")
					shell.activate()
					check(did.g, "performing a gesture fires its hook")
					_start_run(4)
					return false
			4:  # NG+ machinery: cycle counter + scaling hooks
				if lf == 5:
					NGPlus.reset()
					check(absf(NGPlus.scaled("enemy_hp", 60.0) - 60.0) < 0.01, "cycle 0 with no scaling is identity")
					NGPlus.register_scaling("enemy_hp", func(c): return 1.0 + 0.5 * c)
					NGPlus.next_cycle()
					check(NGPlus.cycle == 1, "the cycle counter advances")
					check(absf(NGPlus.scaled("enemy_hp", 60.0) - 90.0) < 0.01, "a registered scaling reshapes values at cycle 1")
					NGPlus.reset()
					return true
		lf += 1
		return false


class ScenarioRound5B extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const Npc = preload("res://src/world/npc.gd")
	const MapData = preload("res://src/combat/map_data.gd")
	const Tutorial = preload("res://src/combat/tutorial.gd")
	const Effigy = preload("res://src/actors/effigy.gd")
	const Shell = preload("res://src/ui/shell.gd")
	var run := 0
	var lf := -2
	var spoke := false
	func setup() -> void:
		name = "world_scaffolds"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		spoke = false
		h.make_world()
		h.effigies[0].position = Vector3(0, 0.05, 60.0)
	func step(f: int) -> bool:
		var p = h.player
		var e = h.effigies[0]
		if lf < 0:
			lf += 1
			return false
		match run:
			0:  # NPC + dialogue machinery
				if lf == 5:
					var npc = Npc.new()
					npc.position = p.position
					npc.dialogue_tree = {"entry": {"text": "line one", "choices": [{"label": "ask", "next": "two"}, {"label": "leave", "next": ""}]}, "two": {"text": "line two", "choices": []}}
					h.sim_root.add_child(npc)
					p.npc_spoke.connect(func(_n): spoke = true)
					h.input.cur.interact = true
				if lf == 15:
					check(spoke, "interacting with an NPC emits the spoke signal")
					var npc2 = null
					for n in h.sim_root.get_children():
						if n is Npc: npc2 = n
					var d = npc2.start_dialogue()
					check(d.node().text == "line one", "dialogue opens at the entry node")
					d.choose(0)
					check(d.current == "two" and not d.ended, "choices advance the tree")
					check(d.choices().is_empty(), "a terminal node offers no choices (the shell shows LEAVE)")
					var d2 = npc2.start_dialogue()
					d2.choose(1)  # "leave"
					check(d2.ended, "a choice with an empty next ends the dialogue")
					_start_run(1)
					return false
			1:  # map machinery: regions, links, discovery
				if lf == 5:
					var m = MapData.new()
					m.register_region("MOVE")
					m.link("MOVE", "STRIKE")
					check(not m.is_visited("MOVE"), "unvisited until entered")
					m.set_current("MOVE")
					check(m.is_visited("MOVE") and m.current == "MOVE", "entering marks discovery")
					check(m.regions["STRIKE"].links.has("MOVE"), "links are bidirectional")
					var sh = Shell.new()
					sh.map_data = m
					h.add_child(sh)
					sh.open("map", false)
					check(sh.menu_items.size() == 3, "map menu lists regions plus close")
					_start_run(2)
					return false
			2:  # boss machinery: hp-threshold phases swap behavior
				if lf == 5:
					e.boss_data = {"name": "TESTBOSS", "phases": [{"below": 0.5, "chain": [{"damage": 25.0, "windup": 0.4, "active": 0.12, "recovery": 0.5, "reach": 2.6, "arc_deg": 90.0}]}]}
					e.apply_hit(31.0, p.global_position, 0.0)  # 60 -> 29, below 50%
				if lf == 15:
					check(e.boss_phase == 1, "crossing the threshold advances the phase")
					check(e.attack_chain.size() == 1, "the phase swapped the attack chain")
					var ph := false
					for ev in Sim.events:
						if ev.begins_with("BOSS TESTBOSS ENTERS PHASE 2"): ph = true
					check(ph, "phase change is acknowledged")
					_start_run(3)
					return false
			3:  # tutorial hooks: once-only contextual hints
				if lf == 5:
					var tut = Tutorial.new()
					tut.ctx = {"player": p}
					tut.register_rule("low_stam", func(c): return c.player.stamina < 20.0, "hint text (scaffold)")
					p.stamina = 10.0
					tut.tick()
					var hints := 0
					for t2 in Sim.toasts:
						if str(t2.get("m", "")).contains("hint text"): hints += 1
					check(hints == 1, "the hint fires when its condition holds")
					tut.tick()
					hints = 0
					for t2 in Sim.toasts:
						if str(t2.get("m", "")).contains("hint text"): hints += 1
					check(hints == 1, "and never fires twice")
					_start_run(4)
					return false
			4:  # aggro linking: one alerted enemy wakes nearby ones
				if lf == 5:
					var e2 = Effigy.new()
					e2.position = Vector3(3.0, 0.05, 0.0)
					e2.ai_enabled = true
					e2.display_name = "SENTRY"
					h.sim_root.add_child(e2)
					h.effigies.append(e2)
					e.position = Vector3(-3.0, 0.05, 0.0)
					e.ai_enabled = true
					e.awareness.alert_now(e)
				if lf == 30:
					check(h.effigies[1].awareness.state == "alert", "a nearby enemy alerts through the link, state=%s" % h.effigies[1].awareness.state)
					return true
		lf += 1
		return false

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
		h.effigies[0].facing = Vector3(0, 0, 1)
		h.input.at(15, {"attack": true})   # grounded
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
			check(absf(p.feathers - 24.0) < 0.01, "volley spent 6 feathers (30->24, collection-only), got %.2f" % p.feathers)
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


class ScenarioCameraRelative extends Scenario:
	func setup() -> void:
		name = "camera_relative_movement"
		h.make_world()
		h.effigies[0].position = Vector3(60.0, 0.05, 60.0)  # clear the lane: no collision bleed
		h.player.camera_yaw = PI / 2.0  # tests set yaw directly; live play syncs from the rig
		h.input.at(5, {"move": Vector2(0, -1)})
	func step(f: int) -> bool:
		var p = h.player
		if f == 65:
			check(p.position.x < -1.0, "forward input with a quarter-turned camera moves along camera forward (-x), x=%.2f" % p.position.x)
			check(absf(p.position.z) < 0.35, "no world-axis bleed on z, z=%.2f" % p.position.z)
			p.position = Vector3.ZERO
			h.input.at(66, {"move": Vector2(1, 0)})
		if f == 126:
			check(p.position.z < -1.0, "strafe-right with the same camera moves along camera right (-z), z=%.2f" % p.position.z)
			check(absf(p.position.x) < 0.35, "no world-axis bleed on x, x=%.2f" % p.position.x)
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
			check(absf(h.player.feathers - 10.0) < 0.01, "the coat never regrows on a timer (collection only, Omer directive), got %.2f" % h.player.feathers)
		return f >= 100


class ScenarioSprintOutcome extends Scenario:
	# Outcome test for Omer's playtest catch (2026-09-19): "you said shift to
	# sprint but it is actually slow". Root cause: sneak + sprint were both bound
	# to SHIFT in project.godot (machinery pass 2), so SHIFT always engaged sneak
	# and sprinting never turned on. State-level tests passed while REAL velocity
	# never rose. These measure actual displacement over frames, and the binding
	# overlap check fails the moment two movement gaits share a key again.
	const T2 = preload("res://src/combat/tuning.gd")
	var p0 := Vector3.ZERO
	func setup() -> void:
		name = "sprint_outcome"
		h.make_world()
		h.effigies[0].position = Vector3(60.0, 0.05, 60.0)
		h.player.camera_yaw = 0.0
		var sprint_keys := []
		for ev in InputMap.action_get_events("sprint"):
			if ev is InputEventKey:
				sprint_keys.append(ev.physical_keycode)
		var sneak_keys := []
		for ev in InputMap.action_get_events("sneak"):
			if ev is InputEventKey:
				sneak_keys.append(ev.physical_keycode)
		var overlap := false
		for k in sneak_keys:
			if k in sprint_keys:
				overlap = true
		check(not overlap, "sprint and sneak never share a key (sprint=%s sneak=%s)" % [str(sprint_keys), str(sneak_keys)])
		check(4194325 in sprint_keys, "sprint is bound to SHIFT, got %s" % str(sprint_keys))
		check(4194326 in sneak_keys, "sneak is bound to CTRL, got %s" % str(sneak_keys))
		h.input.at(2, {"move": Vector2(0, -1), "sprint": true})
	func _speed_between(a: Vector3, b: Vector3, frames: int) -> float:
		var d := Vector2(b.x - a.x, b.z - a.z).length()
		return d * Engine.physics_ticks_per_second / frames
	func step(f: int) -> bool:
		var p = h.player
		if f == 10:
			p0 = p.global_position
			check(p.sprinting, "sprint state engages under sprint input")
		if f == 70:
			var spd := _speed_between(p0, p.global_position, 60)
			check(spd > T2.WALK_SPEED * 1.4, "REAL sprint velocity beats walk by 40%%+, measured %.2f m/s (walk %.2f)" % [spd, T2.WALK_SPEED])
			check(spd > T2.SPRINT_SPEED * 0.9 and spd < T2.SPRINT_SPEED * 1.05, "REAL sprint velocity matches SPRINT_SPEED %.2f, measured %.2f m/s" % [T2.SPRINT_SPEED, spd])
			p0 = p.global_position
			h.input.at(72, {"sprint": false, "sneak": true})
		if f == 80:
			p0 = p.global_position
		if f == 140:
			var spd := _speed_between(p0, p.global_position, 60)
			check(spd < T2.WALK_SPEED * 0.6, "REAL sneak velocity is meaningfully slower than walk, measured %.2f m/s" % spd)
			h.input.at(142, {"sneak": false})
		if f == 150:
			p0 = p.global_position
		if f == 210:
			var spd := _speed_between(p0, p.global_position, 60)
			check(spd > T2.WALK_SPEED * 0.95 and spd < T2.WALK_SPEED * 1.05, "REAL walk velocity matches WALK_SPEED %.2f, measured %.2f m/s" % [T2.WALK_SPEED, spd])
		return f >= 215


class ScenarioWeapons extends Scenario:
	# Iteration 2 (overnight): REAL weapon catalog outcomes via the stats feed -
	# no frame-exact guesses (they break whenever content timings change by
	# design). Asserts on Sim.stats: per-weapon hit damage sets and real
	# attack->hit delays (the commitment each weapon actually carries).
	const T2 = preload("res://src/combat/tuning.gd")
	const Moveset2 = preload("res://src/combat/moveset.gd")
	func setup() -> void:
		name = "weapons"
		h.make_world()
		h.effigies[0].position = Vector3(0.0, 0.05, -1.8)  # in reach of every weapon
		h.effigies[0].facing = Vector3(0, 0, 1)          # facing the player: no accidental backstab crits
		h.effigies[0].max_hp = 500.0
		h.effigies[0].hp = 500.0                          # survive the whole exercise
		h.player.camera_yaw = 0.0
		check(Moveset2.catalog().size() == 3, "catalog offers three weapons")
		h.player.equipment.equip("weapon", Moveset2.fangs(), h.player)
		h.input.at(12, {"attack": true})   # grounded (spawn drop)
		h.input.at(37, {"attack": true})
		h.input.at(62, {"attack": true})
		h.input.at(87, {"attack": true})
	func _hits(weapon: String) -> Array:
		var out := []
		for st in Sim.stats:
			if st.get("k") == "hit" and st.get("weapon") == weapon:
				out.append(st)
		return out
	func _attack_t(weapon: String) -> int:
		for st in Sim.stats:
			if st.get("k") == "attack" and st.get("weapon") == weapon:
				return st.t
		return -1
	func step(f: int) -> bool:
		var p = h.player
		if f == 160:   # fangs chain fully resolved (buffering makes links land late)
			var fh := _hits("fangs")
			var dmgs := []
			for hh in fh:
				dmgs.append(hh.dmg)
			dmgs.sort()
			check(fh.size() == 4 and dmgs == [9, 9, 11, 15], "fangs 4-hit chain lands exactly 9/9/11/15, got %s" % str(dmgs))
			var delay: float = ((fh[0].t - _attack_t("fangs")) / 1000.0) if fh.size() > 0 else 99.0
			check(delay < 0.35, "fangs first hit is fast (windup 0.16s), measured %.2fs" % delay)
			p.equipment.equip("weapon", Moveset2.maul(), p)
			check(p.moveset.id == "maul" and p.chain_index == 0, "equip swaps the live moveset and resets the chain")
			h.input.at(163, {"attack": true})
		if f == 230:
			var mh := _hits("maul")
			check(mh.size() == 1 and mh[0].dmg == 34, "maul light 1 lands exactly 34, got %s" % str(mh.map(func(x): return x.dmg)))
			var mdelay: float = ((mh[0].t - _attack_t("maul")) / 1000.0) if mh.size() > 0 else 0.0
			check(mdelay >= 0.5, "maul carries real commitment (windup 0.52s), measured %.2fs" % mdelay)
			p.equipment.equip("weapon", Moveset2.blade(), p)
			h.input.at(233, {"attack": true})
		if f == 290:
			var bh := _hits("blade")
			check(bh.size() == 1 and bh[0].dmg == 20, "blade light 1 lands exactly 20, got %s" % str(bh.map(func(x): return x.dmg)))
			check(p.moveset.id == "blade", "blade equipped")
		return f >= 295


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
		h.effigies[0].facing = Vector3(0, 0, 1)
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
			check(absf(p.stamina - 73.0) < 0.01, "heavy costs 27 stamina, got %.2f" % p.stamina)
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

class ScenarioWeaponSwap extends Scenario:
	const Sim2 = preload("res://src/combat/combat_sim.gd")
	func setup() -> void:
		name = "weapon_swap"
		h.make_world()
		h.input.at(20, {"weapon_swap": true})   # blade -> fangs
		h.input.at(30, {"weapon_swap": true})   # inside the 0.45s lockout (27f) - denied
		h.input.at(80, {"weapon_swap": true})   # fangs -> maul
		h.input.at(140, {"weapon_swap": true})  # maul -> blade (wrap)
	func step(f: int) -> bool:
		var p = h.player
		if f == 22: check(p.moveset.get("id") == "fangs", "G swaps blade -> fangs, got %s" % p.moveset.get("id"))
		if f == 32: check(p.moveset.get("id") == "fangs", "swap inside the exposure lockout is denied, still %s" % p.moveset.get("id"))
		if f == 82: check(p.moveset.get("id") == "maul", "second swap lands fangs -> maul, got %s" % p.moveset.get("id"))
		if f == 142:
			check(p.moveset.get("id") == "blade", "cycle wraps maul -> blade, got %s" % p.moveset.get("id"))
			var n := 0
			for e in Sim2.events:
				if e.begins_with("WEAPON SWAP"): n += 1
			check(n == 3, "exactly three swap events (one denied), got %d" % n)
		return f >= 150

class ScenarioFinisher extends Scenario:
	const Sim2 = preload("res://src/combat/combat_sim.gd")
	func setup() -> void:
		name = "blade_finisher"
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -2.0)
		h.effigies[0].facing = Vector3(0, 0, 1)
		# chain window per link ~= full swing + 0.8s (98-102f), so f15/f70/f140 stay chained
		h.input.at(15, {"attack": true})    # link 0: 20 dmg
		h.input.at(70, {"attack": true})    # link 1: 22 dmg
		h.input.at(140, {"attack": true})   # link 2 FINISHER: 31 dmg
	func step(f: int) -> bool:
		var e = h.effigies[0]
		if f == 60: check(absf(e.hp - 40.0) < 0.01, "link 0 deals 20, hp=%.2f" % e.hp)
		if f == 120: check(absf(e.hp - 18.0) < 0.01, "link 1 deals 22, hp=%.2f" % e.hp)
		if f == 200:
			check(e.hp <= 0.0 or absf(e.hp - (60.0 - 73.0)) < 0.01, "finisher deals 31 (total 73), hp=%.2f" % e.hp)
			var saw_fin := false
			var saw_denied_or_ok := false
			for ev in Sim2.events:
				if ev.begins_with("FINISHER"): saw_fin = true
				if ev == "ATTACK SLOT light_chain[2]": saw_denied_or_ok = true
			check(saw_denied_or_ok, "third chained attack runs slot light_chain[2]")
			check(saw_fin, "FINISHER event fires on the third link")
		return f >= 210


class ScenarioInventorySlots extends Scenario:
	const Sim2 = preload("res://src/combat/combat_sim.gd")
	func setup() -> void:
		name = "inventory_slot_routing"
		h.make_world()
		# two items; using slot 1 must consume slot 1, not slot 0
		h.player.inventory.add_item("alpha", 1)
		h.player.inventory.add_item("beta", 1)
		h.player.inventory.register_item_desc("beta", "the second thing")
	func step(f: int) -> bool:
		var p = h.player
		if f == 10:
			p._try_use_item(1)
		if f == 20:
			check(p.state == "item", "item commit runs, state=%s" % p.state)
		if f == 80:   # commit is 0.8s = 48f, so the use has landed
			check(p.inventory.slots.size() == 1, "exactly one item remains, got %d" % p.inventory.slots.size())
			if p.inventory.slots.size() == 1:
				check(p.inventory.slots[0].id == "alpha", "slot 0 survives; the PICKED slot was consumed, remaining=%s" % p.inventory.slots[0].id)
			var used_beta := false
			for e in Sim2.events:
				if e == "ITEM USED beta (effect hook - catalog undecided)": used_beta = true
			check(used_beta, "ITEM USED event names beta, not alpha")
			check(p.inventory.describe("beta") == "the second thing", "describe() returns the registered line")
			check(p.inventory.describe("mystery") == "an unwritten thing (scaffold)", "describe() falls back honestly")
		return f >= 90

class ScenarioEquipmentHonest extends Scenario:
	const Shell2 = preload("res://src/ui/shell.gd")
	var shell
	func setup() -> void:
		name = "equipment_menu_honest"
		h.make_world()
		shell = Shell2.new()
		shell.player = h.player
		h.add_child(shell)
		shell.open("equipment", false)
	func step(f: int) -> bool:
		if f == 5:
			check(shell.menu_items.size() == 4, "equipment menu is 3 weapons + CLOSE, no dead header row, got %d" % shell.menu_items.size())
			var joined := ""
			for it in shell.menu_items:
				joined += it.label + "\n"
			check(not joined.contains("weapon: blade"), "no dead weapon header eating a nav stop")
			check(joined.contains("the ruler"), "blade row carries its tradeoff prose")
			check(joined.contains("cannot stop a swing"), "fangs row names its stagger cost")
			check(joined.contains("every swing is a bet"), "maul row names its exposure cost")
			check(shell.menu_items[0].label.begins_with("* blade"), "equipped weapon is starred, got [%s]" % shell.menu_items[0].label)
			shell.sel = 1
			shell.activate()
		if f == 10:
			check(h.player.moveset.get("id") == "fangs", "activating a row equips that weapon, got %s" % h.player.moveset.get("id"))
			check(shell.menu_items[1].label.begins_with("* fangs"), "the star follows the equip, got [%s]" % shell.menu_items[1].label)
		return f >= 15

class ScenarioShove extends Scenario:
	const Sim2 = preload("res://src/combat/combat_sim.gd")
	func setup() -> void:
		name = "effigy_shove"
		h.make_world()
		h.effigies[0].ai_enabled = true
		h.effigies[0].position = Vector3(0, 0.05, -1.0)   # 1.0m: inside shove range, hugging
		h.effigies[0].facing = Vector3(0, 0, 1)
		h.player.position = Vector3(0, 0.1, 0)
	func step(f: int) -> bool:
		var e = h.effigies[0]
		var p = h.player
		if f == 90:   # aggro ramp + 0.8s dwell: the shove has fired by now
			var saw := false
			for ev in Sim2.events:
				if ev == "EFFIGY SHOVES YOU OFF": saw = true
			check(saw, "hugging past the dwell triggers the shove")
		if f == 130:
			check(p.hp < 100.0, "the shove connects for its small damage, hp=%.1f" % p.hp)
		if f == 190:   # recovery: it has stepped back and pays the long rest
			var d: float = e.global_position.distance_to(p.global_position)
			check(d > 1.15, "the effigy steps BACK after shoving (dist %.2f vs hug 1.0)" % d)
			check(e.cooldown > 0.0 or e.state == "attack", "the shove costs the effigy its long rest")
		return f >= 200

class ScenarioShoveHonest extends Scenario:
	const Sim2 = preload("res://src/combat/combat_sim.gd")
	func setup() -> void:
		name = "effigy_shove_honest_range"
		h.make_world()
		h.effigies[0].ai_enabled = true
		h.effigies[0].position = Vector3(0, 0.05, -2.0)   # 2.0m: normal spacing, NO hug
		h.effigies[0].facing = Vector3(0, 0, 1)
		h.player.position = Vector3(0, 0.1, 0)
	func step(f: int) -> bool:
		if f == 150:   # same window as the hug run: at honest range no shove may fire
			var saw := false
			for ev in Sim2.events:
				if ev == "EFFIGY SHOVES YOU OFF": saw = true
			check(not saw, "honest spacing never triggers the shove")
		return f >= 160

class ScenarioQuietFeed extends Scenario:
	const Sim2 = preload("res://src/combat/combat_sim.gd")
	func setup() -> void:
		name = "quiet_feed"
		h.make_world()
		h.input.at(5, {"move": Vector2(0, -1)})   # walk: footsteps fire
		h.input.at(40, {"move": Vector2.ZERO})
	func step(f: int) -> bool:
		if f == 60:
			var snd_in_events := 0
			var snd_in_feed := 0
			for ev in Sim2.events:
				if ev.begins_with("SOUND"): snd_in_events += 1
			for ln in Sim2.log_lines:
				if ln.begins_with("SOUND"): snd_in_feed += 1
			check(snd_in_events > 0, "sound machinery still records every footstep for tests and AI, got %d" % snd_in_events)
			check(snd_in_feed == 0, "the visible feed carries no footstep noise, got %d" % snd_in_feed)
		return f >= 70

class ScenarioStaminaPriceTick extends Scenario:
	const Hud2 = preload("res://src/ui/hud.gd")
	const M2 = preload("res://src/combat/moveset.gd")
	var hud
	func setup() -> void:
		name = "stamina_price_tick"
		h.make_world()
		hud = Hud2.new()
		hud.player = h.player
		h.add_child(hud)
	func step(f: int) -> bool:
		if f == 5:
			hud._process(0.016)
			check(absf(hud.st_tick.position.x - 76.0) < 0.5, "tick sits at one blade swing's price (x=%.1f)" % hud.st_tick.position.x)
			check(hud.st_tick.color.a < 0.9, "tick is quiet while a swing is affordable")
			h.player.stamina = 10.0
			hud._process(0.016)
			check(hud.st_tick.color.r > 0.7, "tick turns hot when a swing is unaffordable")
			h.player.equipment.equip("weapon", M2.catalog()[2], h.player)   # maul: x1.7 = 34 stamina
			hud._process(0.016)
			check(absf(hud.st_tick.position.x - (24.0 + 260.0 * 0.34)) < 0.6, "tick follows the carried weapon's price (x=%.1f)" % hud.st_tick.position.x)
		return f >= 10

class ScenarioFeatherDecoupling extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const DeathPenalty = preload("res://src/combat/death_penalty.gd")
	# Omer ruling 2026-09-19 (verbatim): "Feathers are not like runes. They are
	# not come from enemies and are not re collectible. They are not currency."
	# Kills pay essence, death drops essence, spends charge essence - the coat
	# (feathers, resist, volley) is never part of the economy.
	func setup() -> void:
		name = "feather_decoupling"
		h.make_world()
	func step(f: int) -> bool:
		var p = h.player
		var e = h.effigies[0]
		if f == 2:
			p.feathers = 12.0
			p.progression.essence = 0.0
			e.apply_hit(999.0, p.global_position, 1.0)
			p.progression.add_essence(e.kill_reward())
			check(absf(p.progression.essence - 6.0) < 0.01, "a fell pays essence, essence=%.0f" % p.progression.essence)
			check(absf(p.feathers - 12.0) < 0.01, "a fell pays NO feathers (ruling), feathers=%.0f" % p.feathers)
			DeathPenalty.drop(p, h.sim_root)
			check(absf(p.progression.essence) < 0.01, "death drops the essence where they fell, essence=%.0f" % p.progression.essence)
			check(absf(p.feathers - 12.0) < 0.01, "death leaves the coat untouched (ruling), feathers=%.0f" % p.feathers)
			check(p.feather_resist() > 0.0, "the coat's protection survives death")
		if f == 26:
			check(Sim.events.has("REMNANT RECOVERED - 6 essence back"), "the walk-back returns essence")
			check(absf(p.progression.essence - 6.0) < 0.01, "the essence came back, essence=%.0f" % p.progression.essence)
			check(absf(p.feathers - 12.0) < 0.01, "the coat never moved through it all, feathers=%.0f" % p.feathers)
			return true
		return false

class ScenarioToastExpiry extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const Hud3 = preload("res://src/ui/hud.gd")
	var hud
	func setup() -> void:
		name = "toast_expiry"
		h.make_world()
		hud = Hud3.new()
		hud.player = h.player
		h.add_child(hud)
	func step(f: int) -> bool:
		if f == 5:
			Sim.toast("a fresh word")
			hud._process(0.016)
			check(hud.toast_label.text.contains("a fresh word"), "a fresh toast is on the HUD")
			for t in Sim.toasts:
				t["t"] = int(t["t"]) - 30000   # age every toast 30s into the past
			hud._process(0.016)
			check(not hud.toast_label.text.contains("a fresh word"), "a stale toast fades off the HUD")
			check(Sim.events.has("TOAST a fresh word"), "the machine record keeps full fidelity")
			check(Sim.toasts.size() > 0, "the toast record itself is not erased")
		return f >= 10

class ScenarioDefenseFeedback extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const HitSpark = preload("res://src/fx/hit_spark.gd")
	var spark_base := 0
	var run := 0
	var lf := -2
	var saw_flash := false
	var saw_color := Color(0, 0, 0)
	func setup() -> void:
		name = "defense_feedback"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		saw_flash = false
		spark_base = HitSpark.spawned
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -2.2)
		h.effigies[0].facing = Vector3(0, 0, 1)   # the proven defense_verbs geometry
	func step(f: int) -> bool:
		var _unused = f
		var p = h.player
		var e = h.effigies[0]
		if p.guard_flash_t > 0.0:
			saw_flash = true
			saw_color = p.guard_flash_color
		match run:
			0:  # a held guard answers with a cold spark, not the hurt flash
				if lf == 0:
					p.feathers = 0.0
					p.stamina = 100.0
					h.input.cur.block = true
				if lf == 5: e._try_attack()
				if lf == 70:
					check(HitSpark.spawned == spark_base + 1, "a blocked hit bursts one cold spark, +%d" % (HitSpark.spawned - spark_base))
					check(saw_flash, "a blocked hit raises the guard spark")
					check(saw_color.b > 0.9 and saw_color.r < 0.9, "the spark is cold, not the hurt red")
					check(p.stamina < 88.0, "the block taxes stamina (15 x 0.9 = 13.5 chip), st=%.1f" % p.stamina)
					check(absf(p.hp - 95.5) < 0.01, "the chip still lands 30 percent of 15, hp=%.2f" % p.hp)
					_start_run(1)
					return false
			1:  # a timed guard answers with the bright deflect flash
				if lf == 0:
					p.feathers = 0.0
				if lf == 5: e._try_attack()
				if lf == 49: h.input.cur.block = true
				if lf == 70:
					check(HitSpark.spawned == spark_base + 1, "a timed deflect bursts one bright spark, +%d" % (HitSpark.spawned - spark_base))
					check(saw_flash, "a timed guard raises the deflect flash")
					check(saw_color.r > 0.95 and saw_color.g > 0.95, "the deflect flash is bright white, not the block spark")
					check(absf(p.hp - 100.0) < 0.01, "a deflect costs no hp, hp=%.2f" % p.hp)
					check(Sim.events.has("PARRY - DEFLECTED"), "the deflect is acknowledged")
					return true
		lf += 1
		return false



class ScenarioHitSpark extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const HitSpark = preload("res://src/fx/hit_spark.gd")
	var lf := -2
	var run := 0
	var base := 0
	func setup() -> void:
		name = "hit_spark"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -2.0)
		h.effigies[0].facing = Vector3(0, 0, 1)   # the proven hit_window geometry
		base = HitSpark.spawned
	func sparks_alive() -> int:
		return h.get_tree().get_nodes_in_group("hit_sparks").size()
	func step(f: int) -> bool:
		var _unused = f
		match run:
			0:  # a landed swing bursts a spark at the victim, then cleans up
				if lf == 16:
					h.input.cur.attack = true   # grounded: past the spawn-drop window (hit_window idiom)
				if lf == 45:
					check(HitSpark.spawned == base + 1, "a landed swing spawns exactly one burst, +%d" % (HitSpark.spawned - base))
					check(sparks_alive() >= 1, "the burst is alive in the world right after the hit")
				if lf == 70:
					check(sparks_alive() == 0, "the burst cleans itself up after its lifetime")
					_start_run(1)
					return false
			1:  # an effigy hit on the player bursts a spark too
				if lf == 0:
					h.player.feathers = 0.0
				if lf == 5:
					h.effigies[0]._try_attack()
				if lf == 80:
					check(HitSpark.spawned == base + 1, "an effigy hit on the player spawns one burst, +%d" % (HitSpark.spawned - base))
					return true
		lf += 1
		return false


class ScenarioScreenShake extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const Cam = preload("res://src/camera/third_person_camera.gd")
	var lf := -2
	func setup() -> void:
		name = "screenshake"
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -2.2)
		h.effigies[0].facing = Vector3(0, 0, 1)   # the proven defense_verbs geometry
	func step(f: int) -> bool:
		var _unused = f
		if lf == 0:
			h.player.feathers = 0.0
		if lf == 5:
			h.effigies[0]._try_attack()
		if lf == 80:
			check(Sim.shake_pool > 0.0, "a hit on the player requests screenshake, pool=%.2f" % Sim.shake_pool)
			var c = Cam.new()
			c.add_shake(0.4)
			check(c.trauma > 0.39 and c.trauma <= 1.0, "the camera banks the request as trauma, t=%.2f" % c.trauma)
			for i in 60:
				c.shake_tick(0.016)
			check(c.trauma == 0.0, "the shake decays back to still, t=%.2f" % c.trauma)
			c.free()
			return true
		lf += 1
		return false


class ScenarioAudioHooks extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	const Audio = preload("res://src/combat/audio_bus.gd")
	var lf := -2
	func setup() -> void:
		name = "audio_hooks"
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -2.0)
		h.effigies[0].facing = Vector3(0, 0, 1)   # the proven hit_window geometry
	func has_event(prefix: String) -> bool:
		for e in Sim.events:
			if e.begins_with(prefix):
				return true
		return false
	func step(f: int) -> bool:
		var _unused = f
		if lf == 0:
			# tests have no game.gd pool: bind one by hand, the bus plays through it
			var pool: Array = []
			for i in 2:
				var ap := AudioStreamPlayer.new()
				h.sim_root.add_child(ap)
				pool.append(ap)
			Audio.bind_pool(pool)
		if lf == 16:
			h.input.cur.attack = true   # grounded: past the spawn-drop window
		if lf == 45:
			check(has_event("AUDIO sfx:swing"), "the swing hook fires its audio event")
			check(has_event("AUDIO sfx:hit"), "a landed hit fires the hit audio event")
			check(not has_event("(hook, no assets)"), "the no-assets scaffolding tag is gone")
			Audio.sfx("block")
			var p: AudioStreamPlayer = Audio._pool[0]
			check(p.stream != null, "the bus loads a real stream for a known id, stream=%s" % [p.stream])
			return true
		lf += 1
		return false

class ScenarioJumpFeel extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	var run := 0
	var lf := -2
	var airborne_seen := false
	var land_lf := -1
	var measured_land_lf := -1
	var jump_count := 0
	var ledge = null
	func setup() -> void:
		name = "jump_feel"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		airborne_seen = false
		land_lf = -1
		jump_count = 0
		ledge = null
		h.make_world()
		h.effigies[0].position = Vector3(0, 0.05, 60.0)
		if r == 2:
			ledge = StaticBody3D.new()
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(2.0, 0.5, 2.0)
			col.shape = shape
			col.position.y = 0.75
			ledge.add_child(col)
			h.sim_root.add_child(ledge)
			h.player.position = Vector3(0, 1.05, 0)
	func _jumps() -> int:
		var n := 0
		for ev in Sim.events:
			if ev == "JUMP": n += 1
		return n
	func step(_f: int) -> bool:
		if lf < 0:
			lf += 1
			return false
		var p = h.player
		match run:
			0:  # measure: natural jump airtime in frames
				if lf == 5:
					h.input.cur.jump = true
				if lf > 5 and not p.is_on_floor():
					airborne_seen = true
				if airborne_seen and p.is_on_floor():
					land_lf = lf
					measured_land_lf = lf
					check(land_lf > 15, "natural jump stays airborne a while, landed at frame %d" % land_lf)
					_start_run(1)
					return false
				if lf > 400:
					check(false, "jump never landed")
					return true
			1:  # jump buffer: press 4 frames before landing, must fire on touchdown
				if lf == 5:
					h.input.cur.jump = true
				if lf == measured_land_lf - 4:
					h.input.cur.jump = true   # pressed while still airborne, inside the 0.12s buffer window
				if lf == measured_land_lf + 4:
					check(_jumps() == 2, "buffered press fired a second jump on landing, got %d jumps" % _jumps())
					check(p.velocity.y > 0.0, "second jump is actually rising at landing+4, vy=%.2f" % p.velocity.y)
					_start_run(2)
					return false
			2:  # coyote time: floor vanishes, press 4 frames after leaving ground, still jumps
				if lf == 12:
					check(p.is_on_floor(), "settled on the ledge before it vanishes")
					ledge.queue_free()
				if lf == 16:
					check(not p.is_on_floor(), "airborne after the ledge is gone")
					h.input.cur.jump = true
				if lf == 20:
					check(_jumps() == 1, "coyote window allowed a jump 4 frames after leaving ground, got %d" % _jumps())
					check(p.velocity.y > 0.0, "coyote jump is rising, vy=%.2f" % p.velocity.y)
					return true
				if lf > 60:
					check(false, "coyote check never ran")
					return true
		lf += 1
		return false

class ScenarioLandFeel extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	var run := 0
	var lf := -2
	var was_air := false
	var baseline := 0
	var land_frame := -1
	func setup() -> void:
		name = "land_feel"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		was_air = false
		baseline = 0
		land_frame = -1
		h.make_world()
		h.effigies[0].position = Vector3(0, 0.05, 60.0)
	func _lands() -> Array:
		var out := []
		for ev in Sim.events:
			if ev.begins_with("LAND impact="): out.append(ev)
		return out
	func _impact_of(ev: String) -> float:
		return ev.trim_prefix("LAND impact=").to_float()
	func step(_f: int) -> bool:
		if lf < 0:
			lf += 1
			return false
		var p = h.player
		match run:
			0:  # normal jump landing: answers with squash + sound, no camera dip
				if lf == 6:
					baseline = _lands().size()   # spawn touchdown has logged by now; only the jump arc may add one
				if lf == 5:
					h.input.cur.jump = true
				if lf > 6 and not p.is_on_floor():
					was_air = true
				if was_air and p.is_on_floor() and land_frame < 0:
					land_frame = lf   # harness runs before the player's tick: assert next frame, after the landing tick ran
				if land_frame >= 0 and lf > land_frame:
					check(_lands().size() == baseline + 1, "jump landing logs exactly one new LAND, got %d over baseline %d" % [_lands().size(), baseline])
					var ev: String = _lands().back()
					check(_impact_of(ev) < 9.0, "jump landing is soft (impact %.1f below the shake floor)" % _impact_of(ev))
					check(p.land_squash_t > 0.0, "landing squash engaged on touchdown (t=%.3f)" % p.land_squash_t)
					check(Sim.shake_pool == 0.0, "soft landing does not dip the camera (pool=%.2f)" % Sim.shake_pool)
					var heard := false
					for snd in Sim.sounds:
						if snd.get("source") == "land": heard = true
					check(heard, "jump landing emits a land sound event")
					_start_run(1)
					return false
				if lf > 300:
					check(false, "jump landing never happened")
					return true
			1:  # high fall: harder squash and a camera dip
				if lf == 6:
					baseline = _lands().size()
				if lf == 5:
					p.position = Vector3(0, 8.0, 0)
					p.velocity = Vector3.ZERO
				if lf > 6 and not p.is_on_floor():
					was_air = true
				if was_air and p.is_on_floor() and land_frame < 0:
					land_frame = lf
				if land_frame >= 0 and lf > land_frame:
					var ev: String = _lands().back()
					var imp := _impact_of(ev)
					check(imp > 9.0, "high fall lands hard (impact %.1f over the shake floor)" % imp)
					check(p.land_squash_amp > 0.6, "hard fall squashes deep (amp=%.2f)" % p.land_squash_amp)
					check(Sim.shake_pool > 0.0, "hard landing dips the camera (pool=%.2f)" % Sim.shake_pool)
					return true
				if lf > 400:
					check(false, "high fall never landed")
					return true
		lf += 1
		return false

class ScenarioHitWeight extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	var run := 0
	var lf := -2
	var pools := {}
	func setup() -> void:
		name = "hit_weight"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		if r == 2:
			# effigy in front of the player but facing away: its back is exposed, the same light attack crits
			h.effigies[0].position = Vector3(0, 0.05, -2.2)
			h.effigies[0].facing = Vector3(0, 0, -1)
		else:
			h.effigies[0].position = Vector3(0, 0.05, -2.2)
			h.effigies[0].facing = Vector3(0, 0, 1)
	func step(_f: int) -> bool:
		if lf < 0:
			lf += 1
			return false
		match run:
			0:  # light connect
				if lf == 5: h.input.cur.attack = true
				if lf == 60:
					pools["light"] = Sim.shake_pool
					check(Sim.shake_pool > 0.0, "a light connect shakes the camera (pool=%.2f)" % Sim.shake_pool)
					_start_run(1)
					return false
			1:  # heavy connect
				if lf == 5: h.input.cur.heavy = true
				if lf == 80:
					pools["heavy"] = Sim.shake_pool
					check(Sim.shake_pool > pools["light"], "a heavy connect shakes harder than a light (%.2f > %.2f)" % [Sim.shake_pool, pools["light"]])
					_start_run(2)
					return false
			2:  # backstab crit with the same light attack
				if lf == 5: h.input.cur.attack = true
				if lf == 60:
					check(Sim.shake_pool > pools["light"], "a crit shakes harder than a plain light (%.2f > %.2f)" % [Sim.shake_pool, pools["light"]])
					return true
				if lf > 200:
					check(false, "backstab connect never resolved")
					return true
		lf += 1
		return false

class ScenarioKillFeel extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	var run := 0
	var lf := -2
	var base_pool := 0.0
	var base_span := 0.0
	func setup() -> void:
		name = "kill_feel"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -2.2)
		h.effigies[0].facing = Vector3(0, 0, 1)
		if r == 1:
			h.effigies[0].hp = 5.0   # one light hit fells it
	func step(_f: int) -> bool:
		if lf < 0:
			lf += 1
			return false
		match run:
			0:  # normal connect baseline
				if lf == 5:
					h.input.cur.attack = true
				if lf == 60:
					check(not h.effigies[0].dead, "baseline hit does not fell a full-health effigy")
					base_pool = Sim.shake_pool
					base_span = Sim.hitstop_last   # physics frames freeze during hitstop, so the bus records the request
					_start_run(1)
					return false
			1:  # killing blow: longer freeze, bigger shake
				if lf == 5:
					h.input.cur.attack = true
				if lf == 60:
					check(h.effigies[0].dead, "the low-health effigy is felled by the hit")
					check(Sim.hitstop_last > base_span + 0.04, "the felling blow freezes the world longer (%.3fs vs %.3fs)" % [Sim.hitstop_last, base_span])
					check(Sim.shake_pool > base_pool + 0.10, "the felling blow shakes harder (%.2f vs %.2f)" % [Sim.shake_pool, base_pool])
					return true
				if lf > 200:
					check(false, "killing blow never resolved")
					return true
		lf += 1
		return false

class ScenarioSwingSound extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	var run := 0
	var lf := -2
	var light_radius := 0.0
	func setup() -> void:
		name = "swing_sound"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, 60.0)
	func _swings() -> Array:
		var out := []
		for snd in Sim.sounds:
			if snd.get("source") == "swing": out.append(snd)
		return out
	func step(_f: int) -> bool:
		if lf < 0:
			lf += 1
			return false
		match run:
			0:  # light swing: one audible event on the bus
				if lf == 5: h.input.cur.attack = true
				if lf == 60:
					check(_swings().size() == 1, "one light attack emits exactly one swing sound, got %d" % _swings().size())
					if _swings().size() == 1:
						light_radius = _swings()[0].get("radius", 0.0)
						check(light_radius > 2.5, "the swing carries a few meters (r=%.1f)" % light_radius)
					_start_run(1)
					return false
			1:  # heavy swing carries farther
				if lf == 5: h.input.cur.heavy = true
				if lf == 80:
					check(_swings().size() == 1, "one heavy attack emits exactly one swing sound, got %d" % _swings().size())
					if _swings().size() == 1:
						check(_swings()[0].get("radius", 0.0) > light_radius, "the heavy swing carries farther than the light (%.1f > %.1f)" % [_swings()[0].get("radius", 0.0), light_radius])
					_start_run(2)
					return false
			2:  # hearing outcome: a light swing at 4.3m does not carry, a heavy does
				if lf == 0:
					var e = h.effigies[0]
					e.ai_enabled = true
					e.position = Vector3(3.0, 0.05, -3.1)   # 4.31m: inside the heavy radius, outside the light
					e.facing = Vector3(0.7, 0, -0.7)        # back turned: only hearing can catch this
				if lf == 5: h.input.cur.attack = true   # light: out of reach of its ears
				if lf == 150:
					check(h.effigies[0].awareness.suspicion == 0.0, "a light swing at 4.3m stays unheard (suspicion=%.2f)" % h.effigies[0].awareness.suspicion)
					h.input.cur.heavy = true   # heavy: carries to its ears
				if lf == 200:
					# one sound pulse bumps suspicion (+HEARING_PULSE) without instant-alerting - that is the hearing model
					check(h.effigies[0].awareness.suspicion > 0.0, "a heavy swing at 4.3m is heard from behind (suspicion=%.2f)" % h.effigies[0].awareness.suspicion)
					return true
				if lf > 400:
					check(false, "heavy swing never reached its ears")
					return true
		lf += 1
		return false

class ScenarioVolleyFeel extends Scenario:
	const Sim = preload("res://src/combat/combat_sim.gd")
	var run := 0
	var lf := -2
	func setup() -> void:
		name = "volley_feel"
		_start_run(0)
	func _start_run(r: int) -> void:
		run = r
		lf = -2
		h.make_world()
		h.player.facing = Vector3(0, 0, -1)
		h.effigies[0].position = Vector3(0, 0.05, -6.0)
		h.player.feathers = 30.0
		if r == 1:
			h.effigies[0].hp = 4.0   # one feather fells it
	func _sounds(src: String) -> int:
		var n := 0
		for snd in Sim.sounds:
			if snd.get("source") == src: n += 1
		return n
	func step(_f: int) -> bool:
		if lf < 0:
			lf += 1
			return false
		match run:
			0:  # the loose is quiet, the impact carries
				if lf == 5: h.input.cur.volley = true
				if lf == 90:
					check(_sounds("volley") == 1, "loosing a feather emits one quiet sound, got %d" % _sounds("volley"))
					check(_sounds("volley_hit") == 3, "each feather in the spread sounds its own impact, got %d" % _sounds("volley_hit"))
					check(h.effigies[0].hp < 50.0, "the feather still lands (hp=%.1f)" % h.effigies[0].hp)
					_start_run(1)
					return false
				if lf > 200:
					check(false, "volley never resolved")
					return true
			1:  # a felling shot gets kill-feel parity with melee
				if lf == 5: h.input.cur.volley = true
				if lf == 90:
					check(h.effigies[0].dead, "the feather fells the low-health effigy")
					check(Sim.hitstop_last > 0.10, "a felling shot freezes like a felling blow (%.3fs)" % Sim.hitstop_last)
					check(Sim.shake_pool > 0.10, "a felling shot shakes (pool=%.2f)" % Sim.shake_pool)
					return true
				if lf > 200:
					check(false, "volley kill never resolved")
					return true
		lf += 1
		return false

class ScenarioCameraFov extends Scenario:
	const Cam = preload("res://src/camera/third_person_camera.gd")
	var lf := -2
	var c = null
	func setup() -> void:
		name = "camera_fov"
		h.make_world()
		h.effigies[0].position = Vector3(0, 0.05, 60.0)
		c = Cam.new()
		h.add_child(c)
		c.player = h.player
	func step(_f: int) -> bool:
		if lf < 0:
			lf += 1
			return false
		if lf == 20:
			check(absf(c.cam.fov - 62.0) < 0.5, "at rest the fov sits at base (%.1f)" % c.cam.fov)
		if lf == 25:
			h.input.cur.move = Vector2(0, -1)
			h.input.cur.sprint = true
		if lf == 70:
			check(c.cam.fov > 63.5, "sprinting widens the fov (%.1f)" % c.cam.fov)
			h.input.cur.sprint = false
			h.input.cur.move = Vector2.ZERO
		if lf == 75:
			h.input.cur.dodge = true
		if lf == 82:
			check(c.cam.fov > 65.0, "the dodge pulses the fov wider (%.1f)" % c.cam.fov)
		if lf == 160:
			check(c.cam.fov < 63.0, "the pulse settles back toward base (%.1f)" % c.cam.fov)
			return true
		lf += 1
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
		ScenarioHitSpark.new(),
		ScenarioScreenShake.new(),
		ScenarioAudioHooks.new(),
		ScenarioFeathers.new(),
		ScenarioRegen.new(),
		ScenarioCameraRelative.new(),
		ScenarioDefense.new(),
		ScenarioRooms.new(),
		ScenarioMachinery.new(),
		ScenarioMachinery2.new(),
		ScenarioMachinery3.new(),
		ScenarioMachinery4.new(),
		ScenarioComboCancel.new(),
		ScenarioJumpFeel.new(),
		ScenarioLandFeel.new(),
		ScenarioHitWeight.new(),
		ScenarioKillFeel.new(),
		ScenarioSwingSound.new(),
		ScenarioVolleyFeel.new(),
		ScenarioCameraFov.new(),
		ScenarioCheckpointRest.new(),
		ScenarioPatternCycle.new(),
		ScenarioRemnantPenalty.new(),
		ScenarioHealCommit.new(),
		ScenarioEssenceScarcity.new(),
		ScenarioFeatherDecoupling.new(),
		ScenarioToastExpiry.new(),
		ScenarioDefenseFeedback.new(),
		ScenarioFullLoop.new(),
		ScenarioStaminaClamp.new(),
		ScenarioShell.new(),
		ScenarioRound5A.new(),
		ScenarioRound5B.new(),
		ScenarioSprintOutcome.new(),
		ScenarioWeapons.new(),
		ScenarioHeavy.new(),
		ScenarioDeterminismA.new(),
		ScenarioWeaponSwap.new(),
		ScenarioFinisher.new(),
		ScenarioInventorySlots.new(),
		ScenarioEquipmentHonest.new(),
		ScenarioShove.new(),
		ScenarioShoveHonest.new(),
		ScenarioQuietFeed.new(),
		ScenarioStaminaPriceTick.new(),
		ScenarioDeterminismB.new(),
	]
	for sc in scenarios:
		sc.h = self
