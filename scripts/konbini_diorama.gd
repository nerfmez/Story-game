extends Node3D
## Rainy-night konbini on a street corner, as a small collectible diorama in
## cel-shaded "3D that looks 2D" style. Separate from the story; open
## scenes/konbini_diorama.tscn and press F6. No UI: drag, pinch and scroll to look around
## (see scripts/konbini_camera.gd).
## The model is built from code when the scene loads; afterwards only small loops
## run: rain, drips, the auto door, the flickering signs and the traffic signals.
##
## Command line (after --): --view=N picks a camera preset, --capture PATH saves a
## frame and quits, --wait=SECONDS delays that capture.

const Kit := preload("res://scripts/konbini_kit.gd")
const Exterior := preload("res://scripts/konbini_exterior.gd")
const Interior := preload("res://scripts/konbini_interior.gd")
const Weather := preload("res://scripts/konbini_weather.gd")
const CameraRig := preload("res://scripts/konbini_camera.gd")
const GLASS := preload("res://shaders/konbini_glass.gdshader")
const STEAM := preload("res://shaders/konbini_steam.gdshader")
const SKY := preload("res://shaders/konbini_sky.gdshader")

## look-at point, yaw, pitch, distance
const VIEWS := [
	[Vector3(0.0, 0.6, 1.2), -27.0, 29.0, 28.5],    # three-quarter view, the crossing beyond
	[Vector3(-1.4, 1.4, -0.6), 6.0, 9.0, 10.5],     # straight into the windows
	[Vector3(-0.2, 0.0, 0.0), 45.0, 58.0, 31.0],    # from above, the whole base
	[Vector3(-5.8, 1.1, -1.6), -8.0, 13.0, 10.5],  # into the alley from the sidewalk
	[Vector3(0.6, 1.25, -0.4), 22.0, 11.0, 6.2],    # at the door
	[Vector3(3.6, 1.7, 2.0), 62.0, 8.0, 11.0],      # vending machines and the pole sign
]
const DOOR_CLOSED := [0.325, 1.175]
const DOOR_TRAVEL := 0.8
const DOOR_CYCLE := 9.0

# filled in by the builders
var sign_band_material: ShaderMaterial
var pole_sign_material: ShaderMaterial
var signal_a: Array
var signal_b: Array
var walk_a: Array
var walk_b: Array

var rig: Node3D
var weather: Node3D
var door_panels: Array[Node3D] = []
var lights := {}
var traffic_reflections: Array = []
var traffic_lamp_index := -1
var _flicker_rng := RandomNumberGenerator.new()
var _sign_level := 1.0
var _pole_level := 1.0
var _flicker_until := 0.0
var _next_flicker := 4.0
var _clock := 0.0
var _glass_seed := 0.0

func _ready() -> void:
	_flicker_rng.seed = 99
	_environment()
	var kit := Kit.new(self)
	Exterior.build(kit, self)
	Interior.build(kit, self)
	_doors(kit)
	kit.finish()
	_shop_glass()
	_lights()
	weather = Weather.new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(_rain_lamps())
	_reflections()
	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	var view: Array = VIEWS[0]
	rig.set_view(view[0], view[1], view[2], view[3])
	get_viewport().msaa_3d = Viewport.MSAA_4X
	set_meta("primitive_count", kit.primitive_count)
	_read_command_line()

func _read_command_line() -> void:
	var args := OS.get_cmdline_user_args()
	var wait := 1.5
	var capture := ""
	for i in args.size():
		if args[i].begins_with("--view="):
			show_view(int(args[i].get_slice("=", 1)))
		elif args[i].begins_with("--wait="):
			wait = float(args[i].get_slice("=", 1))
		elif args[i] == "--capture" and i + 1 < args.size():
			capture = args[i + 1]
	if capture != "":
		_capture(capture, wait)

func show_view(index: int) -> void:
	var view: Array = VIEWS[clampi(index, 0, VIEWS.size() - 1)]
	rig.set_view(view[0], view[1], view[2], view[3])

func _capture(path: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("KONBINI_CAPTURE ", path, " result=", result)
	get_tree().quit(0 if result == OK else 1)

# --- building helpers used by the builders ----------------------------------------

## A pane of glass (QuadMesh facing the basis' +Z). rain > 0 adds sliding drops.
func add_glass(center: Vector3, size: Vector2, basis: Basis, rain: float, cooler := false, parent: Node3D = null) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mat := ShaderMaterial.new()
	mat.shader = GLASS
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("rain", rain)
	_glass_seed += 1.0
	mat.set_shader_parameter("seed", _glass_seed)
	if cooler:
		mat.set_shader_parameter("tint", Color(0.8, 0.92, 1.0))
		mat.set_shader_parameter("base_alpha", 0.06)
	var mi := MeshInstance3D.new()
	mi.name = "Glass"
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(basis, center)
	(parent if parent != null else self).add_child(mi)
	return mi

func add_steam(base: Vector3, size: Vector2, strength: float) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var mat := ShaderMaterial.new()
	mat.shader = STEAM
	mat.set_shader_parameter("strength", strength)
	var mi := MeshInstance3D.new()
	mi.name = "Steam"
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = base + Vector3(0, size.y * 0.5, 0)
	add_child(mi)

func _shop_glass() -> void:
	var front := [[-4.8, -3.55], [-3.55, -2.3], [-2.3, -1.05], [-1.05, -0.16]]
	for pane in front:
		var w: float = pane[1] - pane[0] - 0.08
		add_glass(Vector3((pane[0] + pane[1]) * 0.5, 1.575, -0.07), Vector2(w, 2.05), Basis.IDENTITY, 1.0)
	for pane in [[-2.75, -1.48], [-1.48, -0.2]]:
		var w: float = pane[1] - pane[0] - 0.08
		add_glass(Vector3(2.33, 1.575, (pane[0] + pane[1]) * 0.5), Vector2(w, 2.05), Basis(Vector3.UP, PI * 0.5), 1.0)

func _doors(kit: Kit) -> void:
	var frame := Color(0.62, 0.65, 0.72)
	for i in 2:
		var panel := Node3D.new()
		panel.name = "DoorPanel%d" % i
		panel.position = Vector3(DOOR_CLOSED[i], 1.325, -0.22)
		add_child(panel)
		door_panels.append(panel)
		var opts := {"node": panel, "gloss": 0.6}
		kit.box(Vector3(-0.4, 0, 0), Vector3(0.05, 2.25, 0.05), frame, opts)
		kit.box(Vector3(0.4, 0, 0), Vector3(0.05, 2.25, 0.05), frame, opts)
		kit.box(Vector3(0, 1.1, 0), Vector3(0.85, 0.05, 0.05), frame, opts)
		kit.box(Vector3(0, -1.09, 0), Vector3(0.85, 0.07, 0.05), frame, opts)
		var handle_x := 0.33 if i == 0 else -0.33
		kit.rod(Vector3(handle_x, -0.25, 0.05), Vector3(handle_x, 0.35, 0.05), 0.012, Color(0.85, 0.87, 0.92), opts)
		add_glass(Vector3.ZERO, Vector2(0.75, 2.14), Basis.IDENTITY, 1.0, false, panel)
		var sticker := Vector3(0, 0.15, 0.03)
		if i == 0:
			kit.cyl(sticker, 0.1, 0.004, Color(0.2, 0.7, 0.4), {"node": panel, "rot": Vector3(90, 0, 0), "seg": 18, "line": 0.0, "emit": 0.2})
			kit.text("AUTO\nDOOR", sticker + Vector3(0, 0, 0.004), 0.035, Color(1, 1, 1), {"node": panel})
		else:
			kit.cyl(sticker, 0.1, 0.004, Color(1.0, 0.55, 0.24), {"node": panel, "rot": Vector3(90, 0, 0), "seg": 18, "line": 0.0, "emit": 0.2})
			kit.text("24H", sticker + Vector3(0, 0, 0.004), 0.06, Color(1, 1, 1), {"node": panel})

# --- light -------------------------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.33, 0.38, 0.7)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.18, 0.32)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = env
	add_child(world)

## A point light. Fill lights (glow spilling out of the windows) have no visible
## source, so they get no specular highlight on the wet ground.
func _omni(name_: String, pos: Vector3, color: Color, energy: float, radius: float, layer := Kit.LAYER_OUT, fill := false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = name_
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.2
	light.light_cull_mask = layer
	light.shadow_enabled = false
	light.light_specular = 0.0 if fill else 0.5
	light.set_meta("energy", energy)
	add_child(light)
	lights[name_] = light
	return light

func _lights() -> void:
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.5, 0.6, 1.0)
	moon.light_energy = 0.3
	moon.rotation_degrees = Vector3(-52, -35, 0)
	moon.light_cull_mask = Kit.LAYER_OUT
	add_child(moon)
	var warm := Color(1.0, 0.74, 0.44)
	var shop := Color(1.0, 0.93, 0.8)
	for p in [Vector3(-3.0, 2.8, -1.3), Vector3(-3.0, 2.8, -3.4), Vector3(0.6, 2.8, -2.0)]:
		_omni("Shop", p, shop, 0.75, 5.0, Kit.LAYER_IN, true)
	_omni("WindowLeft", Vector3(-3.4, 1.4, 1.0), warm, 1.5, 4.6, Kit.LAYER_OUT, true)
	_omni("WindowRight", Vector3(0.4, 1.4, 1.0), warm, 1.5, 4.6, Kit.LAYER_OUT, true)
	_omni("SideWindow", Vector3(3.1, 1.4, -1.4), warm, 1.0, 3.6, Kit.LAYER_OUT, true)
	_omni("SignBand", Vector3(-1.3, 3.5, 1.3), Color(0.85, 1.0, 0.96), 0.8, 5.0, Kit.LAYER_OUT, true)
	_omni("PoleSign", Vector3(3.3, 4.5, 3.3), Color(0.88, 0.97, 1.0), 1.2, 6.0)
	_omni("StreetLamp", Vector3(-6.0, 5.0, 5.95), Color(0.75, 0.88, 1.0), 2.4, 8.0)
	_omni("Vending", Vector3(3.6, 1.2, -3.9), Color(0.8, 0.92, 1.0), 1.4, 3.6)
	_omni("Traffic", Vector3(7.7, 4.6, 7.7), Color(0.1, 0.95, 0.75), 1.2, 6.0)
	_omni("AlleyLamp", Vector3(-6.2, 2.45, -1.0), Color(1.0, 0.75, 0.45), 0.7, 3.2)
	_omni("BackDoor", Vector3(-1.65, 2.3, -6.0), Color(1.0, 0.82, 0.55), 0.45, 3.0)
	_omni("Security", Vector3(4.9, 4.6, -7.7), Color(0.82, 1.0, 0.88), 1.1, 5.5)
	_omni("Neighbour", Vector3(-7.85, 3.9, 3.0), Color(1.0, 0.75, 0.45), 0.7, 3.2, Kit.LAYER_OUT, true)

func _rain_lamps() -> Array:
	var list := [
		[Vector3(-6.0, 5.0, 5.95), 4.5, Color(0.45, 0.55, 0.65)],
		[Vector3(3.3, 4.5, 3.3), 3.4, Color(0.4, 0.5, 0.55)],
		[Vector3(-1.8, 1.8, 1.6), 3.6, Color(0.55, 0.42, 0.25)],
		[Vector3(3.0, 1.5, -1.5), 2.4, Color(0.45, 0.35, 0.2)],
		[Vector3(3.6, 1.3, -3.9), 2.2, Color(0.35, 0.45, 0.55)],
		[Vector3(-6.2, 2.4, -1.0), 2.4, Color(0.45, 0.32, 0.18)],
		[Vector3(4.9, 4.6, -7.7), 3.0, Color(0.35, 0.45, 0.38)],
		[Vector3(-1.3, 3.6, 0.9), 3.0, Color(0.3, 0.45, 0.42)],
		[Vector3(7.5, 4.8, 7.5), 3.0, Color(0.05, 0.4, 0.3)],
	]
	traffic_lamp_index = list.size() - 1
	return list

func _reflections() -> void:
	var warm := Color(1.0, 0.76, 0.46)
	for pane in [[-4.18, 1.1], [-2.93, 1.1], [-1.68, 1.1], [-0.6, 0.75]]:
		weather.add_reflection(Vector3(pane[0], 0.12, 0.05), warm, pane[1], 1.5, 0.5, 0.8)
	weather.add_reflection(Vector3(0.75, 0.12, 0.05), warm, 1.4, 1.3, 0.55, 0.8)
	for z in [-2.1, -0.85]:
		weather.add_reflection(Vector3(2.45, 0.12, z), warm, 1.1, 1.5, 0.45, 0.8)
	weather.add_reflection(Vector3(-1.3, 0.12, 0.2), Color(0.7, 1.0, 0.95), 4.5, 3.6, 0.16, 0.6)
	weather.add_reflection(Vector3(3.3, 0.12, 3.3), Color(0.85, 0.97, 1.0), 1.3, 4.5, 0.6, 1.2)
	weather.add_reflection(Vector3(-6.0, 0.0, 5.95), Color(0.75, 0.88, 1.0), 0.6, 5.3, 0.55, 2.0)
	weather.add_reflection(Vector3(3.2, 0.12, -3.9), Color(0.85, 0.95, 1.0), 1.4, 1.3, 0.5, 1.0)
	weather.add_reflection(Vector3(-6.4, 0.12, -1.0), Color(1.0, 0.75, 0.45), 0.5, 2.4, 0.5, 2.0)
	weather.add_reflection(Vector3(4.9, 0.12, -7.7), Color(0.82, 1.0, 0.88), 0.6, 4.6, 0.55, 2.0)
	weather.add_reflection(Vector3(-7.85, 0.12, 2.5), Color(1.0, 0.78, 0.5), 1.1, 4.0, 0.3, 1.0)
	traffic_reflections = [
		weather.add_reflection(Vector3(8.6, 0.0, 6.9), Color.WHITE, 1.1, 5.0, 0.0, 1.6),
		weather.add_reflection(Vector3(6.9, 0.0, 8.6), Color.WHITE, 1.1, 5.0, 0.0, 1.6),
	]

# --- the small loops ---------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	_animate_door()
	_animate_signs(delta)
	_animate_traffic()
	weather.face_camera(rig.camera)

func _animate_door() -> void:
	# closed, slide open, stay open while nobody walks through, slide shut
	var t := fmod(_clock + 3.0, DOOR_CYCLE)
	var open := 0.0
	if t > 5.0 and t < 5.7:
		open = smoothstep(5.0, 5.7, t)
	elif t >= 5.7 and t < 8.0:
		open = 1.0
	elif t >= 8.0 and t < 8.8:
		open = 1.0 - smoothstep(8.0, 8.8, t)
	door_panels[0].position.x = DOOR_CLOSED[0] - DOOR_TRAVEL * open
	door_panels[1].position.x = DOOR_CLOSED[1] + DOOR_TRAVEL * open

func _animate_signs(delta: float) -> void:
	# Mostly a steady soft hum; now and then the pole sign stutters for a moment.
	if _clock > _next_flicker:
		_flicker_until = _clock + _flicker_rng.randf_range(0.25, 0.7)
		_next_flicker = _clock + _flicker_rng.randf_range(5.0, 11.0)
	var hum := 0.97 + 0.03 * sin(_clock * 7.3) * sin(_clock * 2.1)
	var pole := hum
	if _clock < _flicker_until:
		pole = 0.35 if fmod(_clock * 17.0 + sin(_clock * 31.0), 1.0) < 0.45 else 1.0
	_pole_level = lerpf(_pole_level, pole, 1.0 - exp(-delta * 40.0))
	_sign_level = hum
	sign_band_material.set_shader_parameter("emit_energy", 1.6 * _sign_level)
	pole_sign_material.set_shader_parameter("emit_energy", 1.6 * _pole_level)
	lights["PoleSign"].light_energy = lights["PoleSign"].get_meta("energy") * _pole_level
	lights["SignBand"].light_energy = lights["SignBand"].get_meta("energy") * _sign_level

func _animate_traffic() -> void:
	# road A green 8 s, amber 3 s, all red 2 s, then the same for road B
	var t := fmod(_clock + 5.0, 26.0)
	var a := _phase(t)
	var b := _phase(fmod(t + 13.0, 26.0))
	_set_lenses(signal_a, a)
	_set_lenses(signal_b, b)
	# pedestrians cross road A while road B has green, and the other way round
	_set_walk(walk_a, fmod(t + 13.0, 26.0))
	_set_walk(walk_b, t)
	var colors := [Color(0.1, 0.95, 0.75), Color(1.0, 0.7, 0.1), Color(1.0, 0.18, 0.15)]
	var lit_color := Color(0, 0, 0)
	for i in 3:
		lit_color += colors[i] * maxf(a[i], b[i] * 0.6)
	lights["Traffic"].light_color = lit_color.clamp()
	var refl := [a, b]
	for i in 2:
		var lamp: Array = refl[i]
		var c := Color(0, 0, 0)
		for j in 3:
			c += colors[j] * lamp[j]
		traffic_reflections[i].set_shader_parameter("color", c.clamp())
		traffic_reflections[i].set_shader_parameter("energy", 0.75)
	weather.lamps[traffic_lamp_index][2] = lit_color.clamp() * 0.4
	weather.update_lamps()

## Lens levels [green, amber, red] at time t of one road's cycle, with soft edges.
func _phase(t: float) -> Array:
	var fade := 0.25
	var green := _window(t, 0.0, 8.0, fade)
	var amber := _window(t, 8.0, 11.0, fade)
	var red := _window(t, 11.0, 26.0, fade) + _window(t, -15.0, 0.0, fade)
	return [green, amber, clampf(red, 0.0, 1.0)]

func _window(t: float, from: float, to: float, fade: float) -> float:
	return smoothstep(from - fade, from + fade, t) * (1.0 - smoothstep(to - fade, to + fade, t))

func _set_lenses(mats: Array, levels: Array) -> void:
	for i in 3:
		mats[i].set_shader_parameter("emit_energy", 0.15 + levels[i] * 2.4)

## Walk signal: green while crossing is allowed, blinking for its last 3 s.
func _set_walk(mats: Array, road_t: float) -> void:
	var green := 0.0
	if road_t < 5.0:
		green = 1.0
	elif road_t < 8.0:
		green = 1.0 if fmod(road_t * 2.0, 1.0) < 0.5 else 0.0
	mats[0].set_shader_parameter("emit_energy", 0.15 + (1.0 - green) * 2.2)
	mats[1].set_shader_parameter("emit_energy", 0.15 + green * 2.2)
