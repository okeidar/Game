extends CanvasLayer
## Pale ink on dark glass. Bars for vigor/stamina/feathers, the effigy's bar
## when it matters, a short combat log, and the death banner.

const Sim = preload("res://src/combat/combat_sim.gd")
const T = preload("res://src/combat/tuning.gd")

var player: Node3D
var effigy: Node3D
var build_id := "dev"

var hp_bar: ProgressBar
var hp_ghost_bar: ProgressBar   # damage trail: recent loss lingers pale, then drains
var hp_ghost := 100.0
var st_bar: ProgressBar
var st_fill: StyleBoxFlat
var st_tick: ColorRect   # price marker: where one swing of the carried weapon lands on the bar
var heal_pips: Array[ColorRect] = []
var fe_bar: ProgressBar
var fe_text: Label
var en_panel: VBoxContainer
var en_bar: ProgressBar
var en_ghost_bar: ProgressBar
var en_ghost := 60.0
var en_label: Label
var log_label: Label
var banner: Label
var room_label: Label
var toast_label: Label

func _bar(color: Color, w: int, pos: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 100.0
	b.value = 100.0
	b.custom_minimum_size = Vector2(w, 13)
	b.position = pos
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.05, 0.07, 0.85)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	add_child(b)
	return b

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hp_ghost_bar = _bar(Color("c9a06a"), 260, Vector2(24, 452))  # under the real bar: the pale trail of what was just lost
	hp_bar = _bar(Color("7e2b26"), 260, Vector2(24, 452))
	st_bar = _bar(Color("5e6e4a"), 260, Vector2(24, 470))
	st_fill = st_bar.get_theme_stylebox("fill") as StyleBoxFlat
	st_tick = ColorRect.new()   # [overnight proposal] the tradeoff, on the bar: one swing's price
	st_tick.custom_minimum_size = Vector2(2, 13)
	st_tick.size = Vector2(2, 13)
	st_tick.color = Color(1.0, 1.0, 1.0, 0.45)
	add_child(st_tick)
	fe_bar = _bar(Color("d9d3c3"), 260, Vector2(24, 488))
	fe_bar.max_value = 30.0
	# heal charges as pips (genre shape), not a text count
	for i in 3:
		var pip := ColorRect.new()
		pip.position = Vector2(292 + i * 18, 506)
		pip.custom_minimum_size = Vector2(14, 9)
		pip.size = Vector2(14, 9)
		pip.color = Color("d9b25a")
		add_child(pip)
		heal_pips.append(pip)
	fe_text = Label.new()
	fe_text.position = Vector2(292, 482)
	fe_text.add_theme_font_size_override("font_size", 15)
	fe_text.add_theme_color_override("font_color", Color("d9d3c3"))
	add_child(fe_text)

	en_panel = VBoxContainer.new()
	en_panel.position = Vector2(280, 18)
	en_panel.custom_minimum_size = Vector2(400, 40)
	add_child(en_panel)
	en_label = Label.new()
	en_label.text = "EFFIGY"
	en_label.add_theme_font_size_override("font_size", 14)
	en_label.add_theme_color_override("font_color", Color("aab2bd"))
	en_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	en_panel.add_child(en_label)
	var en_wrap := Control.new()
	en_wrap.custom_minimum_size = Vector2(400, 11)
	en_ghost_bar = ProgressBar.new()
	en_ghost_bar.min_value = 0.0
	en_ghost_bar.max_value = 60.0
	en_ghost_bar.value = 60.0
	en_ghost_bar.custom_minimum_size = Vector2(400, 11)
	en_ghost_bar.show_percentage = false
	var gbg := StyleBoxFlat.new()
	gbg.bg_color = Color(0.04, 0.05, 0.07, 0.85)
	var gfill := StyleBoxFlat.new()
	gfill.bg_color = Color("b8a878")   # pale trail of damage just dealt
	en_ghost_bar.add_theme_stylebox_override("background", gbg)
	en_ghost_bar.add_theme_stylebox_override("fill", gfill)
	en_ghost_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	en_ghost_bar.size = Vector2(400, 11)
	en_wrap.add_child(en_ghost_bar)
	en_bar = ProgressBar.new()
	en_bar.min_value = 0.0
	en_bar.max_value = 60.0
	en_bar.value = 60.0
	en_bar.custom_minimum_size = Vector2(400, 11)
	en_bar.show_percentage = false
	var ebg := StyleBoxFlat.new()
	ebg.bg_color = Color(0.0, 0.0, 0.0, 0.0)   # transparent: the ghost shows through where the real bar has fallen
	var efill := StyleBoxFlat.new()
	efill.bg_color = Color("6d7383")
	en_bar.add_theme_stylebox_override("background", ebg)
	en_bar.add_theme_stylebox_override("fill", efill)
	en_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	en_bar.size = Vector2(400, 11)
	en_wrap.add_child(en_bar)
	en_panel.add_child(en_wrap)

	room_label = Label.new()
	room_label.position = Vector2(24, 44)
	room_label.add_theme_font_size_override("font_size", 17)
	room_label.add_theme_color_override("font_color", Color("c8ccd4"))
	room_label.text = ""
	add_child(room_label)

	toast_label = Label.new()
	toast_label.position = Vector2(24, 200)
	toast_label.add_theme_font_size_override("font_size", 17)
	toast_label.add_theme_color_override("font_color", Color("d8d2c4"))
	add_child(toast_label)
	log_label = Label.new()
	log_label.position = Vector2(24, 70)
	log_label.add_theme_font_size_override("font_size", 13)
	log_label.add_theme_color_override("font_color", Color("8f99a8"))
	add_child(log_label)

	banner = Label.new()
	banner.position = Vector2(0, 190)
	banner.custom_minimum_size = Vector2(960, 80)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 64)
	banner.add_theme_color_override("font_color", Color("9e2b22"))
	banner.text = ""
	add_child(banner)

	var build := Label.new()
	build.text = "build " + build_id
	build.position = Vector2(700, 512)
	build.add_theme_font_size_override("font_size", 12)
	build.add_theme_color_override("font_color", Color("5a6472"))
	add_child(build)

	var hint := Label.new()
	hint.text = "WASD move · SHIFT sprint · SPACE roll · LMB attack · F heavy · R volley · RMB block (tight = parry) · Q heal · E interact · CTRL sneak · 1 item · V jump · I items · O equip · TAB lock-on · arrows/mouse camera · ESC cursor"
	hint.position = Vector2(24, 528)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color("5a6472"))
	add_child(hint)

func set_banner(text: String) -> void:
	banner.text = text

func set_room(text: String) -> void:
	room_label.text = text

func _process(_dt: float) -> void:
	if player == null:
		return
	hp_bar.value = player.hp
	# [overnight proposal] damage trail: ghost snaps up on heal, drains down slow after a hit
	if player.hp > hp_ghost:
		hp_ghost = player.hp
	else:
		hp_ghost = move_toward(hp_ghost, player.hp, 25.0 * _dt)
	hp_ghost_bar.value = hp_ghost
	st_bar.value = player.stamina
	if st_tick != null:
		var swing_cost: float = T.ATTACK_COST * player.moveset.get("cost_mult", 1.0)
		st_tick.position = Vector2(st_bar.position.x + st_bar.custom_minimum_size.x * clampf(swing_cost / st_bar.max_value, 0.0, 1.0), st_bar.position.y)
		st_tick.color = Color(0.85, 0.28, 0.22, 0.9) if player.stamina < swing_cost else Color(1.0, 1.0, 1.0, 0.45)
	# [overnight proposal] stamina low-warning: below roll cost the bar pulses hot
	if st_fill != null:
		if player.stamina < T.ROLL_COST:
			var w: float = sin(Time.get_ticks_msec() / 150.0) * 0.5 + 0.5
			st_fill.bg_color = Color("5e6e4a").lerp(Color("a04a38"), 0.4 + 0.6 * w)
		else:
			st_fill.bg_color = Color("5e6e4a")
	fe_bar.value = player.feathers
	fe_text.text = "%s · %d feathers · %d%% resist%s" % [player.moveset.get("id", "?").to_upper(), int(player.feathers), int(round(player.feather_resist() * 100.0)), (" · SNEAK" if player.sneaking else "")]
	for i in heal_pips.size():
		heal_pips[i].color = Color("d9b25a") if player.heal_charges > i else Color(0.35, 0.33, 0.28, 0.6)
	if effigy != null and (player.lock_target == effigy or effigy.since_hit < 4.0) and not effigy.dead:
		en_panel.visible = true
		en_bar.value = effigy.hp
		if effigy.hp > en_ghost:
			en_ghost = effigy.hp
		else:
			en_ghost = move_toward(en_ghost, effigy.hp, 20.0 * _dt)
		en_ghost_bar.value = en_ghost
	else:
		en_panel.visible = false
	log_label.text = "\n".join(Sim.log_lines)
	var recent: Array = Sim.toasts.slice(maxi(0, Sim.toasts.size() - 4))
	toast_label.text = "\n".join(recent)
