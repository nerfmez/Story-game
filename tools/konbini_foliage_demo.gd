extends SceneTree
## Renders the anime trees of scripts/konbini_foliage.gd on a patch of grass in daylight,
## for checking the foliage look on its own. Run in a staged project:
##   godot --path <project> --rendering-method gl_compatibility -s res://tools/konbini_foliage_demo.gd -- OUT.png [yaw]

const Kit := preload("res://scripts/konbini_kit.gd")
const Foliage := preload("res://scripts/konbini_foliage.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.8, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.66, 0.92)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var k := Kit.new(world)
	k.shadows = true
	k.slab(Vector3(-7, -0.4, -5), Vector3(7, 0.0, 5), Color(0.55, 0.72, 0.4))
	var s := Foliage.sun_from(sun.rotation_degrees)
	Foliage.broadleaf(k, world, Vector3(-3.6, 0, -1.0), 1.0, {"sun_dir": s, "seed": 3})
	Foliage.broadleaf(k, world, Vector3(0.2, 0, 1.2), 0.7, {"sun_dir": s, "seed": 8})
	Foliage.broadleaf(k, world, Vector3(0.6, 0, -2.6), 0.85, {"sun_dir": s, "seed": 12,
		"high_col": Color(1.0, 0.9, 0.93), "light_col": Color(1.0, 0.8, 0.86), "mid_col": Color(0.93, 0.6, 0.72), "shadow_col": Color(0.66, 0.44, 0.6), "glow_col": Color(1.0, 0.92, 0.94)})
	Foliage.pine(k, world, Vector3(4.0, 0, 0.0), 1.0, {"sun_dir": s, "seed": 5})
	k.finish()
	var cam := Camera3D.new()
	cam.fov = 36.0
	world.add_child(cam)
	var yaw := deg_to_rad(float(args[1]) if args.size() > 1 else -20.0)
	cam.position = Vector3(sin(yaw), 0.42, cos(yaw)) * 17.0 + Vector3(0, 1.0, 0)
	cam.look_at(Vector3(0, 1.9, 0))
	cam.current = true
	root.get_viewport().msaa_3d = Viewport.MSAA_4X
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(args[0])
	quit(0)
