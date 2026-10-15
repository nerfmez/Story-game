@tool
extends Node3D
## ฉาก HD-2D แบบทดลอง: สร้างฉากหน้าโรงเรียนจากกล่อง 3D ง่ายๆ + ภาพ 2D เดิม
## (ท้องฟ้า เมืองไกล ตัวละคร) แล้วใส่แสงไฟจริงและเงาสะท้อนบนพื้นเปียก
##
## เมื่อมีโมเดลจริงจาก Blender แล้ว ให้วางโมเดลไว้ใต้โหนด Set แทนกล่องพวกนี้
## เงาสะท้อนจะสร้างให้อัตโนมัติจากทุกอย่างใต้ Set

const SKY_TEX := preload("res://assets/bg/01_sky.png")
const CITY_TEX := preload("res://assets/bg/02_city_far.png")
const LEAVES_TEX := preload("res://assets/bg/06_foreground.png")
const CHARACTERS := [
	["FriendGirl", preload("res://assets/characters/friend_girl.png"), Vector3(-1.6, 0, 1.0)],
	["Player", preload("res://assets/characters/player.png"), Vector3(-0.4, 0, 1.2)],
	["FriendGlasses", preload("res://assets/characters/friend_glasses.png"), Vector3(2.3, 0, 1.4)],
]

## ความเข้มของเงาสะท้อนบนพื้น (0 = ไม่มี, 1 = เหมือนกระจก)
@export_range(0.0, 1.0) var wetness := 0.45:
	set(value):
		wetness = value
		if is_inside_tree():
			_rebuild()

var _crossing_lights: Array[Node3D] = []
var _time := 0.0


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	# ไฟไม้กั้นรถไฟกะพริบสลับซ้าย-ขวา
	_time += delta
	var left_on := int(_time * 2.0) % 2 == 0
	for i in _crossing_lights.size():
		_crossing_lights[i].visible = left_on == (i % 2 == 0)


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_crossing_lights.clear()

	var set_root := Node3D.new()
	set_root.name = "Set"
	add_child(set_root)
	_build_backdrop(set_root)
	_build_school_gate(set_root)
	_build_railway(set_root)
	_build_crossing(set_root)
	_build_shop(set_root)
	_build_trees(set_root)
	_build_characters(set_root)

	_build_ground()
	_build_reflection(set_root)
	_build_foreground_leaves()


# ---------- helpers ----------

func _mat(color: Color, emission := 0.0, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED  # ให้เงาสะท้อน (scale.y = -1) แสดงผลถูก
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emission := 0.0, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, emission)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, emission)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _omni(parent: Node3D, pos: Vector3, color: Color, energy: float, light_range: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.shadow_enabled = shadow
	parent.add_child(l)
	return l


func _picture(parent: Node3D, tex: Texture2D, height_m: float, pos: Vector3, unshaded := true) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = height_m / tex.get_height()
	s.position = pos
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = not unshaded
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	parent.add_child(s)
	return s


# ---------- set pieces (หน่วยเป็นเมตร: x ซ้าย-ขวา, y สูง, z ลึก ค่าลบ = ไกล) ----------

func _build_backdrop(parent: Node3D) -> void:
	# ท้องฟ้าและเมืองไกลใช้ภาพ 2D เดิม วางเป็นแผ่นไกลๆ กล้อง 3D จะสร้าง parallax ให้เอง
	_picture(parent, SKY_TEX, 40.0, Vector3(0, 12, -45))
	_picture(parent, CITY_TEX, 20.0, Vector3(0, 3.5, -32))


func _build_school_gate(parent: Node3D) -> void:
	var cream := Color(0.86, 0.83, 0.76)
	var gate := Node3D.new()
	gate.name = "SchoolGate"
	gate.position = Vector3(-7.0, 0, -1.5)
	parent.add_child(gate)
	_box(gate, Vector3(6.0, 2.8, 0.5), Vector3(0, 1.4, -0.4), cream)  # wall
	_box(gate, Vector3(4.6, 1.0, 0.1), Vector3(0, 2.1, -0.1), Color(0.12, 0.16, 0.32))  # sign
	_box(gate, Vector3(0.3, 0.4, 0.05), Vector3(0, 2.1, -0.03), Color(0.95, 0.75, 0.3), 1.5)  # emblem
	for x in [-3.2, 3.2]:
		_box(gate, Vector3(0.7, 4.0, 0.7), Vector3(x, 2.0, 0), cream)  # pillars
		_box(gate, Vector3(0.9, 0.25, 0.9), Vector3(x, 4.1, 0), cream)
	# Iron fence to the right of the gate
	for i in 14:
		_box(gate, Vector3(0.06, 1.6, 0.06), Vector3(3.7 + i * 0.25, 0.8, 0.0), Color(0.1, 0.1, 0.12))
	_box(gate, Vector3(3.5, 0.08, 0.08), Vector3(5.3, 1.5, 0.0), Color(0.1, 0.1, 0.12))
	# Warm light from inside the school grounds
	_omni(gate, Vector3(0, 2.5, 1.0), Color(1.0, 0.85, 0.6), 0.6, 6.0)


func _build_railway(parent: Node3D) -> void:
	_box(parent, Vector3(80, 1.2, 3), Vector3(0, 0.6, -9), Color(0.25, 0.24, 0.35))  # embankment
	for i in 12:
		_box(parent, Vector3(0.12, 0.9, 0.12), Vector3(-30 + i * 5.5, 1.65, -7.6), Color(0.2, 0.2, 0.25))
	_box(parent, Vector3(80, 0.06, 0.06), Vector3(0, 2.05, -7.6), Color(0.2, 0.2, 0.25))
	# Power poles
	for x in [-12.0, -2.5, 8.0]:
		_box(parent, Vector3(0.25, 9.0, 0.25), Vector3(x, 4.5, -6.5), Color(0.15, 0.15, 0.2))
		_box(parent, Vector3(2.2, 0.15, 0.15), Vector3(x, 8.4, -6.5), Color(0.15, 0.15, 0.2))
		_box(parent, Vector3(1.6, 0.15, 0.15), Vector3(x, 7.6, -6.5), Color(0.15, 0.15, 0.2))


func _build_crossing(parent: Node3D) -> void:
	var c := Node3D.new()
	c.name = "Crossing"
	c.position = Vector3(1.2, 0, -2.5)
	parent.add_child(c)
	_box(c, Vector3(0.14, 3.4, 0.14), Vector3(0, 1.7, 0), Color(0.2, 0.2, 0.22))
	_box(c, Vector3(1.2, 0.18, 0.05), Vector3(0, 3.1, 0.08), Color(0.95, 0.95, 0.95), 0.0, Vector3(0, 0, 35))
	_box(c, Vector3(1.2, 0.18, 0.05), Vector3(0, 3.1, 0.08), Color(0.95, 0.95, 0.95), 0.0, Vector3(0, 0, -35))
	_box(c, Vector3(0.9, 0.12, 0.08), Vector3(0, 2.45, 0.05), Color(0.12, 0.12, 0.14))
	for x in [-0.4, 0.4]:
		_sphere(c, 0.13, Vector3(x, 2.45, 0.12), Color(0.3, 0.05, 0.05))  # unlit lens
		var on := Node3D.new()
		on.name = "LampLeft" if x < 0.0 else "LampRight"
		on.position = Vector3(x, 2.45, 0.14)
		c.add_child(on)
		_sphere(on, 0.14, Vector3.ZERO, Color(1.0, 0.15, 0.1), 4.0)
		_omni(on, Vector3(0, 0, 0.3), Color(1.0, 0.2, 0.15), 1.2, 3.5)
		_crossing_lights.append(on)


func _build_shop(parent: Node3D) -> void:
	var shop := Node3D.new()
	shop.name = "DrinkShop"
	shop.position = Vector3(6.5, 0, -1.0)
	parent.add_child(shop)
	var wood := Color(0.42, 0.28, 0.2)
	_box(shop, Vector3(7.0, 3.6, 0.3), Vector3(0, 1.8, -1.6), wood)  # back wall
	_box(shop, Vector3(0.3, 3.6, 2.0), Vector3(-3.4, 1.8, -0.7), wood)  # side wall
	_box(shop, Vector3(7.6, 0.3, 2.6), Vector3(0, 3.7, -0.5), Color(0.3, 0.2, 0.16))  # roof
	_box(shop, Vector3(6.4, 2.2, 0.05), Vector3(0, 1.9, -1.4), Color(1.0, 0.82, 0.55), 0.3)  # bright interior
	# Striped awning
	for i in 10:
		var col := Color(0.25, 0.38, 0.7) if i % 2 == 0 else Color(0.92, 0.92, 0.95)
		_box(shop, Vector3(0.36, 0.06, 1.2), Vector3(-3.0 + i * 0.36, 3.25, 1.0), col, 0.0, Vector3(-20, 0, 0))
	# Shelves with colourful goods
	var goods := [Color(0.85, 0.3, 0.28), Color(0.3, 0.6, 0.8), Color(0.95, 0.78, 0.3), Color(0.5, 0.75, 0.4)]
	for row in 3:
		_box(shop, Vector3(3.0, 0.06, 0.4), Vector3(1.2, 1.0 + row * 0.6, -1.2), wood)
		for k in 8:
			_box(shop, Vector3(0.22, 0.32, 0.22), Vector3(-0.1 + k * 0.36, 1.2 + row * 0.6, -1.2), goods[(k + row) % goods.size()])
	# Counter, cooler and blue stools
	_box(shop, Vector3(2.4, 1.0, 0.7), Vector3(-1.6, 0.5, -0.4), Color(0.75, 0.25, 0.22))
	_box(shop, Vector3(1.0, 1.1, 0.8), Vector3(2.9, 0.55, 0.2), Color(0.85, 0.2, 0.2))
	for x in [-2.6, -1.8, -0.4, 0.4]:
		_box(shop, Vector3(0.4, 0.5, 0.4), Vector3(x, 0.25, 0.9), Color(0.2, 0.35, 0.75))
	_box(shop, Vector3(1.6, 0.08, 0.7), Vector3(0.0, 0.8, 0.9), Color(0.2, 0.35, 0.75))
	# Hanging bulbs: the main warm light sources in the scene
	for i in 4:
		var x := -2.4 + i * 1.6
		_box(shop, Vector3(0.02, 0.4, 0.02), Vector3(x, 3.2, 0.2), Color(0.1, 0.1, 0.1))
		_sphere(shop, 0.12, Vector3(x, 2.95, 0.2), Color(1.0, 0.85, 0.5), 6.0)
		_omni(shop, Vector3(x, 2.7, 0.6), Color(1.0, 0.75, 0.45), 1.6, 5.0, i == 1)


func _build_trees(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var greens := [Color(0.18, 0.35, 0.25), Color(0.25, 0.45, 0.28), Color(0.32, 0.52, 0.3)]
	for center in [Vector3(-9.5, 5.5, -3.5), Vector3(-4.0, 6.5, -5.0), Vector3(11.5, 5.0, -3.0)]:
		_box(parent, Vector3(0.4, center.y, 0.4), Vector3(center.x, center.y / 2.0, center.z), Color(0.3, 0.22, 0.16))
		for i in 14:
			var offset := Vector3(rng.randf_range(-2, 2), rng.randf_range(-1.2, 1.2), rng.randf_range(-1, 1))
			_sphere(parent, rng.randf_range(0.6, 1.2), center + offset, greens[i % greens.size()])


func _build_characters(parent: Node3D) -> void:
	for c in CHARACTERS:
		var s := _picture(parent, c[1], 1.68, c[2] + Vector3(0, 0.84, 0), false)
		s.name = c[0]
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _build_ground() -> void:
	# พื้นถนนโปร่งแสงบางส่วน เพื่อให้เห็นฉากกลับหัวข้างใต้ = เงาสะท้อนพื้นเปียก
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(90, 40)
	var ground := MeshInstance3D.new()
	ground.name = "WetRoad"
	ground.mesh = mesh
	var m := _mat(Color(0.16, 0.17, 0.3, 1.0 - wetness))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.25
	m.metallic_specular = 0.9
	ground.material_override = m
	add_child(ground)
	# Sidewalk strip in front of the school and shop
	_box(self, Vector3(40, 0.12, 2.0), Vector3(0, 0.06, -1.0), Color(0.4, 0.38, 0.45))


func _build_reflection(set_root: Node3D) -> void:
	if wetness <= 0.0:
		return
	var mirror := set_root.duplicate()
	mirror.name = "Reflection"
	mirror.scale = Vector3(1, -1, 1)
	# แสงไฟอยู่ในฉากจริงแล้ว ไม่ต้องซ้ำในเงาสะท้อน
	for light in mirror.find_children("*", "Light3D", true, false):
		light.queue_free()
	add_child(mirror)
	for lamp in _crossing_lights.duplicate():
		_crossing_lights.append(mirror.get_node(set_root.get_path_to(lamp)))


func _build_foreground_leaves() -> void:
	# ใบไม้ใกล้กล้อง: จะเบลอจาก tilt-shift ทำให้ฉากดูเหมือนโมเดลจิ๋ว
	var leaves := _picture(self, LEAVES_TEX, 3.4, Vector3(0.0, 3.0, 10.5), false)
	leaves.name = "ForegroundLeaves"
