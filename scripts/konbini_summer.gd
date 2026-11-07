extends RefCounted
## The air of a clear summer day, the daytime counterpart of rain and snow
## (scripts/konbini_weather.gd):
##   - heat haze wavering over the hot road and sand (shaders/konbini_heat.gdshader)
##   - specks of dust and pollen drifting and twinkling in the sun (konbini_motes.gdshader)
##   - the sound: cicadas in the trees and, by the sea, the waves on the shore, from
##     free-licensed recordings (assets/audio/CREDITS-diorama.md). In a browser, sound
##     starts after the first touch or click (browsers do not allow it before that).
## Each layout says where the haze goes with a SUMMER dictionary (see build()).
## Tried and removed at the user's request: drifting cloud shadows and dragonflies.

const HEAT := preload("res://shaders/konbini_heat.gdshader")
const MOTES := preload("res://shaders/konbini_motes.gdshader")

const WAVES := preload("res://assets/audio/sea_waves.ogg")
const CICADAS := preload("res://assets/audio/cicadas.ogg")

## spec keys (all optional):
##   area: Rect2 over x, z where the motes drift (default the 18 m base)
##   heat: Array of [Vector3 centre on the ground, length along x]
##   waves: bool, whether the sea is heard (default true)
static func build(scene: Node3D, spec: Dictionary) -> void:
	for h in spec.get("heat", []):
		_heat(scene, h[0], h[1])
	_motes(scene, spec.get("area", Rect2(-9, -9, 18, 18)))
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

# --- the sound ----------------------------------------------------------------------

## Looping recordings of the sea and of cicadas (free licences, see
## assets/audio/CREDITS-diorama.md). They start with the scene; a browser plays them
## after the first touch or click.
static func _sound(scene: Node3D, waves: bool) -> void:
	_loop(scene, "Cicadas", CICADAS, -6.0)
	if waves:
		_loop(scene, "Waves", WAVES, -1.0)

static func _loop(scene: Node3D, name: String, stream: AudioStreamOggVorbis, db: float) -> void:
	var s := stream.duplicate() as AudioStreamOggVorbis
	s.loop = true
	var player := AudioStreamPlayer.new()
	player.name = name
	player.stream = s
	player.volume_db = db
	player.autoplay = true
	scene.add_child(player)
