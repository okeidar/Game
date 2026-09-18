extends CanvasLayer
## Pale ink on dark glass. Bars for vigor/stamina/feathers, the effigy's bar
## when it matters, a short combat log, and the death banner.

const Sim = preload("res://src/combat/combat_sim.gd")

var player: Node3D
var effigy: Node3D
var build_id := "dev"

var hp_bar: ProgressBar
var st_bar: ProgressBar
var fe_bar: ProgressBar
var fe_text: Label
var en_panel: VBoxContainer
var en_bar: ProgressBar
var en_label: Label
var log_label: Label
var banner: Label
var room_label: Label

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
	hp_bar = _bar(Color("7e2b26"), 260, Vector2(24, 452))
	st_bar = _bar(Color("5e6e4a"), 260, Vector2(24, 470))
	fe_bar = _bar(Color("d9d3c3"), 260, Vector2(24, 488))
	fe_bar.max_value = 30.0
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
	en_bar = ProgressBar.new()
	en_bar.min_value = 0.0
	en_bar.max_value = 60.0
	en_bar.value = 60.0
	en_bar.custom_minimum_size = Vector2(400, 11)
	en_bar.show_percentage = false
	var ebg := StyleBoxFlat.new()
	ebg.bg_color = Color(0.04, 0.05, 0.07, 0.85)
	var efill := StyleBoxFlat.new()
	efill.bg_color = Color("6d7383")
	en_bar.add_theme_stylebox_override("background", ebg)
	en_bar.add_theme_stylebox_override("fill", efill)
	en_panel.add_child(en_bar)

	room_label = Label.new()
	room_label.position = Vector2(24, 44)
	room_label.add_theme_font_size_override("font_size", 17)
	room_label.add_theme_color_override("font_color", Color("c8ccd4"))
	room_label.text = ""
	add_child(room_label)

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
	hint.text = "WASD move · SHIFT sprint · SPACE roll · LMB attack · F heavy · R volley · RMB block (tight = parry) · Q heal · E interact · TAB lock-on · arrows/mouse camera · ESC cursor"
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
	st_bar.value = player.stamina
	fe_bar.value = player.feathers
	fe_text.text = "%d feathers · %d%% resist · heal x%d" % [int(player.feathers), int(round(player.feather_resist() * 100.0)), player.heal_charges]
	if effigy != null and (player.lock_target == effigy or effigy.since_hit < 4.0) and not effigy.dead:
		en_panel.visible = true
		en_bar.value = effigy.hp
	else:
		en_panel.visible = false
	log_label.text = "\n".join(Sim.log_lines)
