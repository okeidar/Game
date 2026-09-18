extends RefCounted
## Shared combat-bus: event log (HUD + tests read the same feed) and hitstop clock.

static var log_lines: Array[String] = []
static var events: Array[String] = []   # machine-checkable feed for tests
static var hitstop_left := 0.0
static var active_checkpoint = null
static var sounds: Array = []   # sound bus: awareness reads new entries via a watermark

static func reset() -> void:
	log_lines.clear()
	events.clear()
	hitstop_left = 0.0
	active_checkpoint = null
	sounds.clear()

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
	log_event("SOUND %s at (%.1f, %.1f) r=%.1f loud=%.1f" % [source_name, pos.x, pos.z, radius, loudness])

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
