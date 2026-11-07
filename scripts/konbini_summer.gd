extends RefCounted
## The air of a clear summer day, the daytime counterpart of rain and snow
## (scripts/konbini_weather.gd): what moves over the whole scene when nothing falls.
##   - cloud shadows drifting over land, sea and trees (shaders/konbini_clouds.gdshaderinc,
##     switched on through the global shader uniform cloud_shadow)
##   - heat haze wavering over the hot road and sand (shaders/konbini_heat.gdshader)
##   - specks of dust and pollen drifting and twinkling in the sun (konbini_motes.gdshader)
##   - a few dragonflies hovering and darting
##   - the sound: cicadas in the trees and the waves on the shore, synthesised as it
##     plays (no sound files), the waves on the same 7 s beat as the sea shader
## Each layout says where these go with a SUMMER dictionary (see build()).

const Kit := preload("res://scripts/konbini_kit.gd")
const HEAT := preload("res://shaders/konbini_heat.gdshader")
const MOTES := preload("res://shaders/konbini_motes.gdshader")

const MIX_RATE := 22050.0
const WAVE_PERIOD := 7.0

## spec keys (all optional):
##   area: Rect2 over x, z where motes drift (default the 18 m base)
##   heat: Array of [Vector3 centre on the ground, length along x]
##   dragonflies: Array of Vector3 places they hover around
##   waves: bool, whether the sea is heard
static func build(kit: Kit, scene: Node3D, spec: Dictionary) -> void:
	RenderingServer.global_shader_parameter_set("cloud_shadow", 1.0)
	var area: Rect2 = spec.get("area", Rect2(-9, -9, 18, 18))
	for h in spec.get("heat", []):
		_heat(scene, h[0], h[1])
	_motes(scene, area)
	var flies: Array = []
	var i := 0
	for home: Vector3 in spec.get("dragonflies", []):
		flies.append(_dragonfly(kit, scene, home, i))
		i += 1
	scene.set_meta("dragonflies", flies)
	_sound(scene, spec.get("waves", true))

## Turns the summer air off again (a scene that is not a clear day).
static func clear() -> void:
	RenderingServer.global_shader_parameter_set("cloud_shadow", 0.0)

static func _heat(scene: Node3D, centre: Vector3, length: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(length, 0.9)
	var mat := ShaderMaterial.new()
	mat.shader = HEAT
	var mi := MeshInstance3D.new()
	mi.name = "HeatHaze"
	mi.mesh = quad
	mi.material_override = mat
	mi.position = centre + Vector3(0, 0.45, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(mi)

static func _motes(scene: Node3D, area: Rect2) -> void:
	var count := int(area.size.x * area.size.y * 0.45)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in count:
		var p := Vector3(rng.randf_range(area.position.x, area.end.x), rng.randf_range(0.6, 3.2), rng.randf_range(area.position.y, area.end.y))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf_range(0.2, 0.9), 0.0))
	var mat := ShaderMaterial.new()
	mat.shader = MOTES
	var mi := MultiMeshInstance3D.new()
	mi.name = "Motes"
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the motes move in the shader, so give the culling box the whole volume
	mi.custom_aabb = AABB(Vector3(area.position.x - 1, 0, area.position.y - 1), Vector3(area.size.x + 2, 4.5, area.size.y + 2))
	scene.add_child(mi)

## A small blue-grey dragonfly: a slim body, a round head and two pairs of glassy wings.
static func _dragonfly(kit: Kit, scene: Node3D, home: Vector3, index: int) -> Node3D:
	var fly := Node3D.new()
	fly.name = "Dragonfly%d" % index
	fly.position = home
	fly.set_meta("home", home)
	fly.set_meta("seed", index * 3.7 + 1.3)
	scene.add_child(fly)
	var body := Color(0.36, 0.52, 0.7)
	kit.box(Vector3(0, 0, -0.06), Vector3(0.025, 0.025, 0.26), body, {"node": fly, "line": 0.5})
	kit.ball(Vector3(0, 0, 0.08), Vector3(0.035, 0.03, 0.035), Color(0.2, 0.28, 0.32), {"node": fly, "seg": 6, "line": 0.5})
	kit.box(Vector3(0, 0, 0.03), Vector3(0.04, 0.035, 0.07), Color(0.25, 0.3, 0.35), {"node": fly, "line": 0.4})
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "Wings"
		wing.position = Vector3(0, 0.02, 0.03)
		wing.set_meta("side", side)
		fly.add_child(wing)
		for zoff in [0.02, -0.03]:
			kit.box(Vector3(side * 0.09, 0, zoff), Vector3(0.17, 0.004, 0.035), Color(0.88, 0.94, 0.98), {"node": wing, "line": 0.3, "emit": 0.15})
	return fly

## Dragonflies hover, turn and now and then dart to a new spot; wings shimmer.
static func animate(scene: Node3D, clock: float) -> void:
	if scene.has_meta("dragonflies"):
		for fly: Node3D in scene.get_meta("dragonflies"):
			var home: Vector3 = fly.get_meta("home")
			var sd: float = fly.get_meta("seed")
			# a dart every few seconds: the target jumps, the fly glides to it quickly
			var hop := floorf(clock / 3.2 + sd)
			var target := home + Vector3(sin(hop * 2.3 + sd) * 1.6, sin(hop * 1.7 + sd * 2.0) * 0.35, cos(hop * 1.9 + sd) * 1.2)
			var bob := Vector3(sin(clock * 2.1 + sd) * 0.05, sin(clock * 3.3 + sd) * 0.04, 0)
			var p := fly.position.lerp(target, 0.08) + bob * 0.2
			var dir := target - fly.position
			if dir.length() > 0.05:
				fly.rotation.y = lerp_angle(fly.rotation.y, atan2(dir.x, dir.z), 0.15)
			fly.position = p
			for w in fly.get_children():
				if w.has_meta("side"):
					w.rotation.z = float(w.get_meta("side")) * (0.35 if int(clock * 60.0) % 2 == 0 else -0.25)
	_feed_sound(scene, clock)

# --- the sound ----------------------------------------------------------------------

static func _sound(scene: Node3D, waves: bool) -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.25
	var player := AudioStreamPlayer.new()
	player.name = "SummerSound"
	player.stream = gen
	player.volume_db = -9.0
	scene.add_child(player)
	player.play()
	scene.set_meta("summer_sound", player)
	scene.set_meta("summer_state", {"t": 0.0, "lp1": 0.0, "lp2": 0.0, "hp": 0.0, "c1": 0.0, "c2": 0.0, "waves": waves})

## Fills the audio buffer: two cicadas buzzing in phrases that swell and fade, and,
## near the sea, the low rush of each wave with a hiss of foam as it runs up the sand.
static func _feed_sound(scene: Node3D, _clock: float) -> void:
	if not scene.has_meta("summer_sound"):
		return
	var player: AudioStreamPlayer = scene.get_meta("summer_sound")
	if not player.playing:
		return
	var pb := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var n := pb.get_frames_available()
	if n <= 0:
		return
	var st: Dictionary = scene.get_meta("summer_state")
	var t: float = st["t"]
	var lp1: float = st["lp1"]
	var lp2: float = st["lp2"]
	var hp: float = st["hp"]
	var c1: float = st["c1"]
	var c2: float = st["c2"]
	var waves: bool = st["waves"]
	var dt := 1.0 / MIX_RATE
	var frames := PackedVector2Array()
	frames.resize(n)
	for i in n:
		var white := randf() * 2.0 - 1.0
		# cicadas: noise narrowed to a high band, chopped by a fast buzz, sung in phrases
		c1 += 0.55 * (white - c1)
		var band := white - c1
		c2 += 0.5 * (band - c2)
		var buzz := 0.55 + 0.45 * signf(sin(t * TAU * 95.0))
		var phrase_a := pow(maxf(sin(t * TAU * 0.9), 0.0), 2.0) * (0.5 + 0.5 * sin(t * 0.11))
		var phrase_b := pow(maxf(sin(t * TAU * 0.75 + 1.7), 0.0), 2.0) * (0.5 + 0.5 * sin(t * 0.07 + 2.0))
		var cicada := c2 * buzz * 0.32
		var left := cicada * (phrase_a * 0.9 + phrase_b * 0.35)
		var right := cicada * (phrase_a * 0.35 + phrase_b * 0.9)
		if waves:
			# the sea: a low rush that swells as each wave breaks, and a hiss of foam
			lp1 += 0.03 * (white - lp1)
			lp2 += 0.03 * (lp1 - lp2)
			var s := fmod(t, WAVE_PERIOD)
			var swell := 0.35 + 0.65 * smoothstep(0.0, 0.5, s) * exp(-s * 0.55)
			var hiss_env := smoothstep(0.2, 0.8, s) * exp(-maxf(s - 0.8, 0.0) * 1.1)
			hp += 0.2 * (white - hp)
			var sea := lp2 * 5.0 * swell + (white - hp) * 0.09 * hiss_env
			left += sea
			right += sea
		frames[i] = Vector2(clampf(left, -1.0, 1.0), clampf(right, -1.0, 1.0))
		t += dt
	pb.push_buffer(frames)
	st["t"] = t
	st["lp1"] = lp1
	st["lp2"] = lp2
	st["hp"] = hp
	st["c1"] = c1
	st["c2"] = c2
