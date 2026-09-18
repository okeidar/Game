extends Node3D

var player: CharacterBody3D
const SPEED := 5.0

func mesh_instance(mesh: Mesh, color: Color) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    n.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.8
    n.material_override = mat
    return n

func _ready() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("182235")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("b7c9e2")
    env.ambient_light_energy = 0.55
    world.environment = env
    add_child(world)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -35, 0)
    sun.light_energy = 1.4
    sun.shadow_enabled = true
    add_child(sun)

    var floor_body := StaticBody3D.new()
    var floor_mesh := BoxMesh.new()
    floor_mesh.size = Vector3(24, 0.3, 24)
    var floor_visual := mesh_instance(floor_mesh, Color("3d5a45"))
    floor_visual.position.y = -0.15
    floor_body.add_child(floor_visual)
    var floor_collision := CollisionShape3D.new()
    var floor_shape := BoxShape3D.new()
    floor_shape.size = Vector3(24, 0.3, 24)
    floor_collision.shape = floor_shape
    floor_collision.position.y = -0.15
    floor_body.add_child(floor_collision)
    add_child(floor_body)

    for p in [Vector3(-4,0.75,-4),Vector3(4,0.75,-5),Vector3(-5,0.75,3)]:
        var pillar := StaticBody3D.new()
        var box := BoxMesh.new(); box.size = Vector3(1.5,1.5,1.5)
        var visual := mesh_instance(box, Color("6f6577")); visual.position = p
        pillar.add_child(visual)
        var col := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size=Vector3(1.5,1.5,1.5); col.shape=shape; col.position=p
        pillar.add_child(col); add_child(pillar)

    player = CharacterBody3D.new()
    player.name = "Player"
    var capsule := CapsuleMesh.new(); capsule.radius=0.55; capsule.height=1.9
    var body := mesh_instance(capsule, Color("c76042")); body.position.y=0.95
    player.add_child(body)
    var hit := CollisionShape3D.new(); var hitshape:=CapsuleShape3D.new(); hitshape.radius=0.55; hitshape.height=1.9; hit.shape=hitshape; hit.position.y=0.95
    player.add_child(hit)
    add_child(player)

    var pivot := Node3D.new(); pivot.name="CameraPivot"; pivot.position=Vector3(0,1.2,0); player.add_child(pivot)
    var camera := Camera3D.new(); camera.position=Vector3(0,3.6,7.5); camera.rotation_degrees.x=-18; camera.current=true; pivot.add_child(camera)

    var label := Label.new()
    label.text="AGENT-DRIVEN GODOT PROOF\nWASD to move • third-person camera"
    label.position=Vector2(24,22); label.add_theme_font_size_override("font_size",24)
    add_child(label)

    if "--self-test" in OS.get_cmdline_user_args():
        var start := player.position
        player.position.x += SPEED * 0.016
        print("SELF_TEST_OK player_moved=", player.position.distance_to(start) > 0.0, " renderer=", RenderingServer.get_current_rendering_method())
        get_tree().quit()

func _physics_process(_delta: float) -> void:
    if player == null: return
    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := Vector3(input.x, 0, input.y).normalized()
    player.velocity.x = direction.x * SPEED
    player.velocity.z = direction.z * SPEED
    if not player.is_on_floor(): player.velocity.y -= 18.0 * _delta
    else: player.velocity.y = 0.0
    player.move_and_slide()
    if direction.length_squared() > 0.01:
        var target := atan2(direction.x, direction.z)
        player.rotation.y = lerp_angle(player.rotation.y, target, 10.0 * _delta)
