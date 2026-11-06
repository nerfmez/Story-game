extends SceneTree
## Quick 3D blockout of a plan, for showing the user before building anything.
## Reads a JSON plan and renders it in the diorama's toon style from a three-quarter
## camera, with floating Thai labels, then saves a PNG and quits.
##
## Run inside a staged diorama project (it needs scripts/konbini_kit.gd):
##   godot --path <project> --rendering-method gl_compatibility -s res://tools/blockout.gd -- PLAN.json OUT.png
##
## Plan: {"day": true, "items": [
##   {"t": "box", "p": [x, y, z], "s": [sx, sy, sz], "c": "#rrggbb", "label": "..."},
##   {"t": "cyl", "p": [x, y, z], "r": 0.5, "h": 2.0, "c": "#rrggbb", "top": 1.0},
##   {"t": "water", "rect": [x0, z0, x1, z1], "y": -0.2}]}
## The base is X, Z in -9..9 metres; y is height.

const Kit := preload("res://scripts/konbini_kit.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var day: bool = plan.get("day", true)
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.8, 0.95) if day else Color(0.05, 0.05, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.82, 0.95) if day else Color(0.33, 0.38, 0.7)
	env.ambient_light_energy = 0.75 if day else 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.2 if day else 0.3
	sun.rotation_degrees = Vector3(-50, -30, 0)
	world.add_child(sun)
	var k := Kit.new(world)
	k.slab(Vector3(-9.3, -0.8, -9.3), Vector3(9.3, -0.25, 9.3), Color(0.33, 0.2, 0.14))
	for item in plan["items"]:
		var c := Color(item.get("c", "#cccccc"))
		match item["t"]:
			"box":
				var p: Array = item["p"]
				var s: Array = item["s"]
				k.box(Vector3(p[0], p[1], p[2]), Vector3(s[0], s[1], s[2]), c, {"rot": Vector3(0, item.get("yaw", 0.0), 0)})
			"cyl":
				var p: Array = item["p"]
				k.cyl(Vector3(p[0], p[1], p[2]), item["r"], item["h"], c, {"top": item.get("top", 1.0), "seg": 16})
			"water":
				var r: Array = item["rect"]
				var y: float = item.get("y", -0.2)
				k.slab(Vector3(r[0], -0.25, r[1]), Vector3(r[2], y, r[3]), Color(item.get("c", "#3f8fc8")), {"gloss": 0.8, "line": 0.0})
		if item.has("label"):
			var p: Array = item["p"] if item.has("p") else [(item["rect"][0] + item["rect"][2]) * 0.5, 0.0, (item["rect"][1] + item["rect"][3]) * 0.5]
			var h: float = item.get("s", [0, item.get("h", 0.5), 0])[1] if item.has("s") or item.has("h") else 0.5
			var label := k.text(item["label"], Vector3(p[0], p[1] + h * 0.5 + 0.7, p[2]), 0.55, Color(1, 1, 1), {"outline": 14, "outline_color": Color(0.1, 0.1, 0.18)})
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
	k.finish()
	var cam := Camera3D.new()
	cam.fov = 36.0
	world.add_child(cam)
	var yaw := deg_to_rad(plan.get("yaw", -27.0))
	var pitch := deg_to_rad(plan.get("pitch", 32.0))
	var dist: float = plan.get("dist", 30.0)
	cam.position = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.look_at(Vector3(0, 0.5, 0))
	cam.current = true
	root.get_viewport().msaa_3d = Viewport.MSAA_4X
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(args[1])
	quit(0)
