extends RefCounted
## Shared combat-bus: event log (HUD + tests read the same feed) and hitstop clock.

static var log_lines: Array[String] = []
static var events: Array[String] = []   # machine-checkable feed for tests
static var hitstop_left := 0.0
static var active_checkpoint = null
static var sounds: Array = []   # sound bus: awareness reads new entries via a watermark
static var toasts: Array = []   # player-facing message feed (toast UI machinery)
static var alert_pulses: Array = []   # aggro-link bus: alerted enemies broadcast position

static func reset() -> void:
	log_lines.clear()
	events.clear()
	hitstop_left = 0.0
	active_checkpoint = null
	sounds.clear()
	toasts.clear()
	alert_pulses.clear()
	stats.clear()

static func toast(msg: String) -> void:
	# Player-facing message machinery: separate from the debug log feed.
	# [overnight proposal - awaiting Omer review] each toast carries a
	# timestamp; the HUD fades them after T.TOAST_LIFETIME_MS instead of
	# stacking stale messages forever. The record itself keeps everything.
	toasts.append({"m": msg, "t": Time.get_ticks_msec()})
	if toasts.size() > 12:
		toasts.pop_front()
	log_event("TOAST %s" % msg)

static var stats: Array = []

## Structured stats feed (overnight mandate 2026-09-19): machine-readable
## gameplay events for the playtest bot + stats analysis. Prints STAT <json>
## to the console (harvested live) and keeps a copy for tests.
static func stat(kind: String, fields: Dictionary = {}) -> void:
	fields["k"] = kind
	fields["t"] = Time.get_ticks_msec()
	stats.append(fields)
	print("STAT " + JSON.stringify(fields))

static func log_event(msg: String) -> void:
	log_lines.append(msg)
	events.append(msg)
	if log_lines.size() > 8:
		log_lines.pop_front()
	print("[combat] ", msg)

static func emit_sound(source_name: String, pos: Vector3, radius: float, loudness: float) -> void:
	# Sound machinery: instantaneous events on a bus; awareness consumes them.
	sounds.append({"pos": pos, "radius": radius, "loudness": loudness, "source": source_name})
	if sounds.size() > 200:
		sounds.pop_front()
	# [overnight proposal - awaiting Omer review] feet stay OFF the visible feed:
	# log_lines (the HUD) is for combat signal; events/console keep full fidelity.
	var msg := "SOUND %s at (%.1f, %.1f) r=%.1f loud=%.1f" % [source_name, pos.x, pos.z, radius, loudness]
	events.append(msg)
	print("[combat] ", msg)

static func hitstop(d: float) -> void:
	hitstop_left = maxf(hitstop_left, d)

## Sector hit test in the XZ plane. Facing need not be normalized.
static func in_sector(from: Vector3, facing: Vector3, to: Vector3, target_radius: float, reach: float, arc_deg: float) -> bool:
	var d := to - from
	d.y = 0.0
	var dist := d.length()
	if dist - target_radius > reach:
		return false
	if dist < 0.05:
		return true
	var f := facing
	f.y = 0.0
	if f.length_squared() < 0.0001:
		return true
	f = f.normalized()
	var ang := rad_to_deg(acos(clampf(f.dot(d / dist), -1.0, 1.0)))
	var slack := rad_to_deg(asin(clampf(target_radius / dist, 0.0, 1.0)))
	return ang <= arc_deg * 0.5 + slack
