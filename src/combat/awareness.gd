extends RefCounted
## Enemy awareness machinery (round 3): the deferred enemy side of sneak.
## Vision cone + hearing (consumes the sound bus) + alert states:
## calm -> suspicious -> alert, with decay back down. Machinery only - ranges,
## angles, timings, and what enemies DO at each state are all OPEN decisions.

const Sim = preload("res://src/combat/combat_sim.gd")
const T = preload("res://src/combat/tuning.gd")

var state := "calm"         # calm | suspicious | alert
var suspicion := 0.0        # 0..1
var heard_watermark := 0    # index into Sim.sounds already considered
var alert_memory := 0.0

func tick(dt: float, owner, player) -> void:
	var stimulus := 0.0
	if player != null and not player.dead:
		var to_p: Vector3 = player.global_position - owner.global_position
		to_p.y = 0.0
		var dist := to_p.length()
		var range: float = T.VISION_RANGE_SCAFFOLD * (T.SNEAK_VISION_MULT_SCAFFOLD if player.sneaking else 1.0)
		if dist > 0.01 and dist < range:
			var ang := rad_to_deg(acos(clampf(owner.facing.dot(to_p / dist), -1.0, 1.0)))
			if ang <= T.VISION_HALF_ANGLE_SCAFFOLD:
				stimulus = 1.0
		var heard := false
		while heard_watermark < Sim.sounds.size():
			var snd: Dictionary = Sim.sounds[heard_watermark]
			heard_watermark += 1
			var d: Vector3 = snd.pos - owner.global_position
			d.y = 0.0
			if d.length() <= snd.radius:
				heard = true
		if heard:
			suspicion = minf(1.0, suspicion + T.HEARING_PULSE_SCAFFOLD)  # instantaneous sounds bump, not tick
			stimulus = maxf(stimulus, T.HEARING_STIMULUS_SCAFFOLD)
	if state == "alert":
		if stimulus > 0.0:
			alert_memory = T.ALERT_MEMORY_SCAFFOLD
		else:
			alert_memory -= dt
			if alert_memory <= 0.0:
				state = "suspicious"
				suspicion = 0.5
				Sim.log_event("SUSPICIOUS %s (lost the trail)" % owner.display_name)
		return
	if stimulus > 0.0:
		suspicion = minf(1.0, suspicion + stimulus * dt / T.SUSPICION_TIME_SCAFFOLD)
	else:
		suspicion = maxf(0.0, suspicion - dt / T.ALERT_MEMORY_SCAFFOLD)
	if suspicion >= 1.0:
		state = "alert"
		alert_memory = T.ALERT_MEMORY_SCAFFOLD
		Sim.log_event("ALERT %s" % owner.display_name)
	elif suspicion >= 0.35 and state == "calm":
		state = "suspicious"
		Sim.log_event("SUSPICIOUS %s" % owner.display_name)
	elif suspicion <= 0.0 and state == "suspicious":
		state = "calm"
		Sim.log_event("CALM %s" % owner.display_name)

func alert_now(owner) -> void:
	if state != "alert":
		state = "alert"
		alert_memory = T.ALERT_MEMORY_SCAFFOLD
		Sim.log_event("ALERT %s (provoked)" % owner.display_name)

func reset() -> void:
	state = "calm"
	suspicion = 0.0
	alert_memory = 0.0
