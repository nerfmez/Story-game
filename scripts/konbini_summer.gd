extends RefCounted
## The air of a clear summer day, the daytime counterpart of rain and snow
## (scripts/konbini_weather.gd):
##   - heat haze wavering over the hot road and sand (shaders/konbini_heat.gdshader)
##   - the sound: cicadas in the trees and, by the sea, the waves on the shore
## The sounds are synthesised once when the scene loads (no sound files) into short
## looping clips: a web build plays clips natively, while a stream fed from script
## stays silent there. The wave loop is exactly one wave long and starts in step with
## the sea shader, so each rush is heard as a wave breaks. In a browser, sound starts
## after the first touch or click (browsers do not let a page play sound before that).
## Each layout says where the haze goes with a SUMMER dictionary (see build()).
## Tried and removed at the user's request: drifting cloud shadows, dust motes and
## dragonflies (they read as bugs flying about).

const HEAT := preload("res://shaders/konbini_heat.gdshader")

const RATE := 22050
const WAVE_PERIOD := 7.0
const CICADA_LOOP := 9.0

## spec keys (all optional):
##   heat: Array of [Vector3 centre on the ground, length along x]
##   waves: bool, whether the sea is heard (default true)
static func build(scene: Node3D, spec: Dictionary) -> void:
	for h in spec.get("heat", []):
		_heat(scene, h[0], h[1])
	_sound(scene, spec.get("waves", true))

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

# --- the sound ----------------------------------------------------------------------

static func _sound(scene: Node3D, waves: bool) -> void:
	var cicadas := AudioStreamPlayer.new()
	cicadas.name = "Cicadas"
	cicadas.stream = _clip(_cicada_samples())
	cicadas.volume_db = -7.0
	cicadas.autoplay = true
	scene.add_child(cicadas)
	if waves:
		var sea := AudioStreamPlayer.new()
		sea.name = "Waves"
		sea.stream = _clip(_wave_samples())
		sea.volume_db = -4.0
		scene.add_child(sea)
		# start in step with the sea shader's clock (TIME counts from engine start)
		sea.play(fmod(Time.get_ticks_msec() * 0.001, WAVE_PERIOD))

## A looping stereo 16-bit clip from interleaved samples in -1..1.
static func _clip(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = true
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples.size() / 2
	return wav

## Two cicadas: noise narrowed to a high band, chopped by a fast buzz and sung in
## phrases that swell and fade, one a little to each side. Every slow rhythm fits a
## whole number of times into the loop, so it repeats without a seam.
static func _cicada_samples() -> PackedFloat32Array:
	var n := int(CICADA_LOOP * RATE)
	var out := PackedFloat32Array()
	out.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var c1 := 0.0
	var c2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf() * 2.0 - 1.0
		c1 += 0.55 * (white - c1)
		var band := white - c1
		c2 += 0.5 * (band - c2)
		var buzz := 0.55 + 0.45 * signf(sin(t * TAU * 95.0))
		var u := t / CICADA_LOOP   # 0..1 over the loop
		var phrase_a := pow(maxf(sin(u * TAU * 8.0), 0.0), 2.0) * (0.55 + 0.45 * sin(u * TAU))
		var phrase_b := pow(maxf(sin(u * TAU * 7.0 + 1.7), 0.0), 2.0) * (0.55 + 0.45 * sin(u * TAU + 2.5))
		var v := c2 * buzz * 2.7
		out[i * 2] = v * (phrase_a * 0.9 + phrase_b * 0.35)
		out[i * 2 + 1] = v * (phrase_a * 0.35 + phrase_b * 0.9)
	return out

## One wave, exactly WAVE_PERIOD long: a low rush that swells as the wave breaks and
## a hiss of foam as the water runs up the sand, then the quiet wash between waves.
static func _wave_samples() -> PackedFloat32Array:
	var n := int(WAVE_PERIOD * RATE)
	var out := PackedFloat32Array()
	out.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lp1 := 0.0
	var lp2 := 0.0
	var hp := 0.0
	var r1 := 0.0
	var r2 := 0.0
	for i in n:
		var s := float(i) / RATE
		var wl := rng.randf() * 2.0 - 1.0
		var wr := rng.randf() * 2.0 - 1.0
		lp1 += 0.03 * (wl - lp1)
		lp2 += 0.03 * (lp1 - lp2)
		r1 += 0.03 * (wr - r1)
		r2 += 0.03 * (r1 - r2)
		hp += 0.2 * (wl - hp)
		# swell rises fast at the break and dies away; it ends where it began so the loop
		# has no click
		var swell := 0.3 + 0.7 * smoothstep(0.0, 0.5, s) * exp(-s * 0.55) * smoothstep(WAVE_PERIOD, WAVE_PERIOD - 0.6, s)
		var hiss := smoothstep(0.2, 0.8, s) * exp(-maxf(s - 0.8, 0.0) * 1.1)
		var foam := (wl - hp) * 0.12 * hiss
		out[i * 2] = lp2 * 6.0 * swell + foam
		out[i * 2 + 1] = r2 * 6.0 * swell + foam
	return out
