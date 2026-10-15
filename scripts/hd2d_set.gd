@tool
extends Node3D
## ฉาก HD-2D: สร้างฉากหน้าโรงเรียนจากกล่อง 3D + texture แบบพิกเซล + ภาพ 2D
## (ท้องฟ้า เมืองไกล ตัวละคร) แล้วใส่แสงไฟจริง ป้ายภาษาไทย และเงาสะท้อนบนพื้นเปียก
##
## เมื่อมีโมเดลจริงจาก Blender แล้ว ให้วางโมเดลไว้ใต้โหนด Set แทนกล่องพวกนี้
## เงาสะท้อนจะสร้างให้อัตโนมัติจากทุกอย่างใต้ Set

const SKY_TEX := preload("res://assets/bg/01_sky.png")
const CITY_TEX := preload("res://assets/bg/02_city_far.png")
const LEAVES_TEX := preload("res://assets/bg/06_foreground.png")
const FONT := preload("res://assets/fonts/Sarabun-Regular.ttf")
const TEX := {
	"plaster": preload("res://assets/textures/plaster.png"),
	"brick": preload("res://assets/textures/brick.png"),
	"wood": preload("res://assets/textures/wood.png"),
	"roof": preload("res://assets/textures/roof.png"),
	"road": preload("res://assets/textures/road.png"),
	"tiles": preload("res://assets/textures/tiles.png"),
	"leaves": preload("res://assets/textures/leaves.png"),
	"awning": preload("res://assets/textures/awning.png"),
	"vending": preload("res://assets/textures/vending.png"),
}
const CHARACTERS := [
	["FriendGirl", preload("res://assets/characters/friend_girl.png"), Vector3(-1.5, 0, 3.0)],
	["Player", preload("res://assets/characters/player.png"), Vector3(-0.4, 0, 3.3)],
	["FriendGlasses", preload("res://assets/characters/friend_glasses.png"), Vector3(1.6, 0, 3.1)],
	["FriendPonytail", preload("res://assets/characters/friend_ponytail.png"), Vector3(2.5, 0, 2.9)],
]
const WHITE := Color(1, 1, 1)

## ความเข้มของเงาสะท้อนบนพื้น (0 = ไม่มี, 1 = เหมือนกระจก)
@export_range(0.0, 1.0) var wetness := 0.5:
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
	_build_street_props(set_root)
	_build_trees(set_root)
	_build_characters(set_root)

	_build_ground()
	_build_reflection(set_root)
	_build_atmosphere()
	_build_foreground_leaves()


# ---------- helpers ----------

## วัสดุพื้นฐาน: ถ้ามี texture จะใช้ world triplanar (ขนาดพิกเซลเท่ากันทุกกล่อง)
func _mat(color: Color, emission := 0.0, tex: Texture2D = null, texels_per_meter := 32.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED  # ให้เงาสะท้อน (scale.y = -1) แสดงผลถูก
	if tex:
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		var s := texels_per_meter / tex.get_width()
		m.uv1_scale = Vector3(s, s, s)
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
		if tex:
			m.emission_texture = tex
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emission := 0.0, rot_deg := Vector3.ZERO, tex: Texture2D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, emission, tex)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _tbox(parent: Node3D, tex_name: String, size: Vector3, pos: Vector3, tint := WHITE) -> MeshInstance3D:
	return _box(parent, size, pos, tint, 0.0, Vector3.ZERO, TEX[tex_name])


func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, emission := 0.0, tex: Texture2D = null) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, emission, tex)
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


func _sign(parent: Node3D, text: String, pos: Vector3, size_px: int, color: Color, outline: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = size_px
	l.outline_size = 6
	l.modulate = color
	l.outline_modulate = outline
	l.pixel_size = 0.01
	l.position = pos
	l.double_sided = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	parent.add_child(l)
	return l


# ---------- set pieces (หน่วยเป็นเมตร: x ซ้าย-ขวา, y สูง, z ลึก ค่าลบ = ไกล) ----------

func _build_backdrop(parent: Node3D) -> void:
	# ท้องฟ้าและเมืองไกลใช้ภาพ 2D เดิม วางเป็นแผ่นไกลๆ กล้อง 3D จะสร้าง parallax ให้เอง
	_picture(parent, SKY_TEX, 40.0, Vector3(0, 12, -45))
	_picture(parent, CITY_TEX, 20.0, Vector3(0, 3.5, -32))


func _build_school_gate(parent: Node3D) -> void:
	var gate := Node3D.new()
	gate.name = "SchoolGate"
	gate.position = Vector3(-7.0, 0, -1.5)
	parent.add_child(gate)
	_tbox(gate, "plaster", Vector3(6.0, 2.8, 0.5), Vector3(0, 1.4, -0.4))  # wall
	_box(gate, Vector3(4.8, 1.1, 0.12), Vector3(0, 2.15, -0.1), Color(0.1, 0.13, 0.28))  # sign board
	_box(gate, Vector3(4.9, 0.06, 0.14), Vector3(0, 2.72, -0.1), Color(0.85, 0.68, 0.3))  # gold trim
	_box(gate, Vector3(4.9, 0.06, 0.14), Vector3(0, 1.58, -0.1), Color(0.85, 0.68, 0.3))
	_sphere(gate, 0.16, Vector3(-1.9, 2.15, -0.02), Color(0.95, 0.75, 0.3), 1.2)  # emblem
	_sign(gate, "โรงเรียนริมทางวิทยา", Vector3(0.25, 2.2, 0.0), 40, Color(1.0, 0.86, 0.5), Color(0.1, 0.08, 0.2))
	for x in [-3.2, 3.2]:
		_tbox(gate, "plaster", Vector3(0.7, 4.0, 0.7), Vector3(x, 2.0, 0))  # pillars
		_tbox(gate, "plaster", Vector3(0.9, 0.25, 0.9), Vector3(x, 4.1, 0), Color(0.9, 0.88, 0.85))
		_sphere(gate, 0.18, Vector3(x, 4.4, 0), Color(1.0, 0.9, 0.7), 1.5)  # lamp on top
		_omni(gate, Vector3(x, 4.4, 0.4), Color(1.0, 0.85, 0.6), 0.8, 4.0)
	# Brick base + iron fence to the right of the gate
	_tbox(gate, "brick", Vector3(3.6, 0.5, 0.3), Vector3(5.4, 0.25, 0.0))
	for i in 14:
		_box(gate, Vector3(0.06, 1.4, 0.06), Vector3(3.8 + i * 0.25, 1.2, 0.0), Color(0.1, 0.1, 0.12))
	_box(gate, Vector3(3.6, 0.08, 0.08), Vector3(5.4, 1.85, 0.0), Color(0.1, 0.1, 0.12))


func _build_railway(parent: Node3D) -> void:
	_tbox(parent, "brick", Vector3(80, 1.2, 3), Vector3(0, 0.6, -9), Color(0.75, 0.7, 0.85))  # embankment
	for i in 16:
		_box(parent, Vector3(0.1, 0.9, 0.1), Vector3(-30 + i * 4.0, 1.65, -7.6), Color(0.2, 0.2, 0.25))
	_box(parent, Vector3(80, 0.06, 0.06), Vector3(0, 2.05, -7.6), Color(0.2, 0.2, 0.25))
	# Power poles + sagging overhead wires
	var poles := [-14.0, -4.5, 5.0, 14.5]
	for x in poles:
		_box(parent, Vector3(0.25, 9.0, 0.25), Vector3(x, 4.5, -6.5), Color(0.15, 0.15, 0.2))
		_box(parent, Vector3(2.2, 0.15, 0.15), Vector3(x, 8.4, -6.5), Color(0.15, 0.15, 0.2))
		_box(parent, Vector3(1.6, 0.15, 0.15), Vector3(x, 7.6, -6.5), Color(0.15, 0.15, 0.2))
	for i in poles.size() - 1:
		for wire_y in [8.45, 7.65]:
			for wire_x in [-0.9, 0.9]:
				var a := Vector3(poles[i] + wire_x, wire_y, -6.5)
				var b := Vector3(poles[i + 1] + wire_x, wire_y, -6.5)
				var mid := (a + b) / 2.0 - Vector3(0, 0.45, 0)
				_wire(parent, a, mid)
				_wire(parent, mid, b)


func _wire(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var mi := _box(parent, Vector3((b - a).length(), 0.03, 0.03), (a + b) / 2.0, Color(0.08, 0.08, 0.1))
	mi.rotation.z = atan2(b.y - a.y, b.x - a.x)


func _build_crossing(parent: Node3D) -> void:
	var c := Node3D.new()
	c.name = "Crossing"
	c.position = Vector3(1.0, 0, -3.0)
	parent.add_child(c)
	_box(c, Vector3(0.14, 3.4, 0.14), Vector3(0, 1.7, 0), Color(0.85, 0.85, 0.88))
	for i in 6:
		_box(c, Vector3(0.15, 0.2, 0.15), Vector3(0, 0.3 + i * 0.5, 0), Color(0.12, 0.12, 0.14))  # black stripes
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
	# Barrier arm, raised, with red/white stripes
	var arm := Node3D.new()
	arm.position = Vector3(0.25, 1.0, 0.1)
	arm.rotation_degrees = Vector3(0, 0, 70)
	c.add_child(arm)
	_box(arm, Vector3(0.3, 0.3, 0.3), Vector3.ZERO, Color(0.15, 0.15, 0.18))
	for i in 8:
		var col := Color(0.9, 0.15, 0.12) if i % 2 == 0 else Color(0.95, 0.95, 0.95)
		_box(arm, Vector3(0.45, 0.07, 0.07), Vector3(0.3 + i * 0.45, 0, 0), col)


func _build_shop(parent: Node3D) -> void:
	var shop := Node3D.new()
	shop.name = "DrinkShop"
	shop.position = Vector3(6.6, 0, -1.0)
	parent.add_child(shop)
	_tbox(shop, "wood", Vector3(7.0, 3.6, 0.3), Vector3(0, 1.8, -1.6))  # back wall
	_tbox(shop, "wood", Vector3(0.3, 3.6, 2.0), Vector3(-3.4, 1.8, -0.7))  # side wall
	_tbox(shop, "roof", Vector3(7.8, 0.25, 2.8), Vector3(0, 3.75, -0.5))  # roof
	_box(shop, Vector3(6.4, 2.2, 0.05), Vector3(0, 1.9, -1.4), Color(1.0, 0.82, 0.55), 0.3)  # bright interior
	# Sign board on the roof edge
	_box(shop, Vector3(4.2, 0.7, 0.1), Vector3(-0.6, 4.25, 0.85), Color(0.75, 0.16, 0.14))
	_box(shop, Vector3(4.3, 0.05, 0.12), Vector3(-0.6, 4.6, 0.85), Color(1.0, 0.85, 0.4), 1.5)
	_sign(shop, "ชาเย็น · น้ำปั่น · ขนมปังปิ้ง", Vector3(-0.6, 4.25, 0.92), 30, Color(1.0, 0.97, 0.88), Color(0.4, 0.05, 0.05))
	# Striped awning (one tilted textured slab)
	var awning := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6.6, 1.4)
	awning.mesh = plane
	var am := _mat(WHITE)
	am.albedo_texture = TEX["awning"]
	am.uv1_scale = Vector3(6.6 / 2.0, 1.0, 1.0)
	awning.material_override = am
	awning.position = Vector3(-0.2, 3.2, 1.0)
	awning.rotation_degrees = Vector3(-22, 0, 0)
	shop.add_child(awning)
	# Shelves with colourful goods
	var goods := [Color(0.85, 0.3, 0.28), Color(0.3, 0.6, 0.8), Color(0.95, 0.78, 0.3), Color(0.5, 0.75, 0.4), Color(0.9, 0.55, 0.75)]
	for row in 3:
		_tbox(shop, "wood", Vector3(3.0, 0.06, 0.4), Vector3(1.2, 1.0 + row * 0.6, -1.2))
		for k in 8:
			var h := 0.22 + (k * 7 + row * 3) % 4 * 0.05
			_box(shop, Vector3(0.22, h, 0.22), Vector3(-0.1 + k * 0.36, 1.03 + row * 0.6 + h / 2.0, -1.2), goods[(k + row) % goods.size()])
	# Counter with a tea jar, cooler and blue stools + table
	_tbox(shop, "wood", Vector3(2.4, 1.0, 0.7), Vector3(-1.6, 0.5, -0.4), Color(1.0, 0.75, 0.7))
	_sphere(shop, 0.22, Vector3(-2.2, 1.25, -0.4), Color(0.95, 0.55, 0.25), 0.4)  # Thai tea jar
	_sphere(shop, 0.18, Vector3(-1.6, 1.2, -0.4), Color(0.6, 0.8, 0.95), 0.2)
	_box(shop, Vector3(1.0, 1.1, 0.8), Vector3(2.9, 0.55, 0.2), Color(0.85, 0.2, 0.2))
	_box(shop, Vector3(0.8, 0.5, 0.05), Vector3(2.9, 0.7, 0.62), Color(0.75, 0.9, 1.0), 0.8)  # cooler window
	for x in [-2.6, -1.8, -0.4, 0.4]:
		_box(shop, Vector3(0.4, 0.5, 0.4), Vector3(x, 0.25, 1.0), Color(0.2, 0.35, 0.75))
	_box(shop, Vector3(1.6, 0.08, 0.7), Vector3(0.0, 0.8, 1.0), Color(0.2, 0.35, 0.75))
	_box(shop, Vector3(0.08, 0.75, 0.08), Vector3(0.0, 0.4, 1.0), Color(0.15, 0.25, 0.6))
	# Hanging bulbs: the main warm light sources in the scene
	for i in 4:
		var x := -2.4 + i * 1.6
		_box(shop, Vector3(0.02, 0.4, 0.02), Vector3(x, 3.2, 0.2), Color(0.1, 0.1, 0.1))
		_sphere(shop, 0.12, Vector3(x, 2.95, 0.2), Color(1.0, 0.85, 0.5), 6.0)
		_omni(shop, Vector3(x, 2.7, 0.6), Color(1.0, 0.75, 0.45), 1.6, 5.0, i == 1)


func _build_street_props(parent: Node3D) -> void:
	# Vending machine between the gate and the crossing: a cool blue light source
	var vm := Node3D.new()
	vm.name = "VendingMachine"
	vm.position = Vector3(-2.6, 0, -1.6)
	parent.add_child(vm)
	_box(vm, Vector3(1.0, 1.9, 0.8), Vector3(0, 0.95, 0), Color(0.2, 0.4, 0.8))
	var front := _box(vm, Vector3(0.84, 1.3, 0.02), Vector3(0, 1.15, 0.41), WHITE, 0.0)
	var fm := _mat(WHITE, 0.35)
	fm.albedo_texture = TEX["vending"]
	fm.emission_texture = TEX["vending"]
	front.material_override = fm
	_omni(vm, Vector3(0, 1.2, 0.9), Color(0.7, 0.85, 1.0), 0.6, 3.0)
	# Street lamp at the left edge
	var lamp := Node3D.new()
	lamp.position = Vector3(-4.6, 0, 0.4)
	parent.add_child(lamp)
	_box(lamp, Vector3(0.12, 4.6, 0.12), Vector3(0, 2.3, 0), Color(0.25, 0.28, 0.32))
	_box(lamp, Vector3(0.9, 0.08, 0.08), Vector3(0.4, 4.55, 0), Color(0.25, 0.28, 0.32))
	_box(lamp, Vector3(0.4, 0.12, 0.25), Vector3(0.8, 4.48, 0), Color(1.0, 0.9, 0.7), 1.5)
	_omni(lamp, Vector3(0.8, 4.2, 0.2), Color(1.0, 0.85, 0.6), 1.4, 7.0, true)
	# Curb and road markings
	_box(parent, Vector3(40, 0.18, 0.18), Vector3(0, 0.09, 0.05), Color(0.6, 0.58, 0.62))
	for i in 10:
		_box(parent, Vector3(1.6, 0.012, 0.15), Vector3(-18 + i * 4.0, 0.006, 4.5), Color(0.85, 0.82, 0.7))


func _build_trees(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var tints := [Color(0.85, 0.9, 0.85), Color(1, 1, 1), Color(1.1, 1.05, 0.9)]
	for center in [Vector3(-9.5, 5.5, -3.5), Vector3(-5.5, 6.5, -5.0), Vector3(11.8, 5.0, -3.0), Vector3(-1.5, 7.5, -12.0)]:
		_tbox(parent, "wood", Vector3(0.45, center.y, 0.45), Vector3(center.x, center.y / 2.0, center.z), Color(0.7, 0.6, 0.55))
		for i in 16:
			var offset := Vector3(rng.randf_range(-2.2, 2.2), rng.randf_range(-1.3, 1.3), rng.randf_range(-1, 1))
			_sphere(parent, rng.randf_range(0.7, 1.3), center + offset, tints[i % tints.size()], 0.0, TEX["leaves"])


func _build_characters(parent: Node3D) -> void:
	for c in CHARACTERS:
		var s := _picture(parent, c[1], 1.68, c[2] + Vector3(0, 0.84, 0), false)
		s.name = c[0]
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _build_ground() -> void:
	# พื้นถนนโปร่งแสงบางส่วน เพื่อให้เห็นฉากกลับหัวข้างใต้ = เงาสะท้อนพื้นเปียก
	# texture road.png มี alpha ต่ำตรงแอ่งน้ำ แอ่งจึงสะท้อนชัดกว่าพื้นรอบๆ
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(90, 40)
	var ground := MeshInstance3D.new()
	ground.name = "WetRoad"
	ground.mesh = mesh
	var m := _mat(Color(1, 1, 1, 1.0 - wetness * 0.6))
	m.albedo_texture = TEX["road"]
	m.uv1_scale = Vector3(90.0 / 4.0, 40.0 / 4.0, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.2
	m.metallic_specular = 1.0
	ground.material_override = m
	add_child(ground)
	# Tiled sidewalk in front of the school and shop
	_tbox(self, "tiles", Vector3(40, 0.12, 2.6), Vector3(0, 0.06, -1.3))


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


func _build_atmosphere() -> void:
	# ฝุ่นละอองเรืองแสงลอยในแสงไฟร้าน
	var motes := CPUParticles3D.new()
	motes.name = "LightMotes"
	motes.position = Vector3(5.0, 2.0, 0.5)
	motes.amount = 60
	motes.lifetime = 8.0
	motes.preprocess = 8.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(5.0, 1.6, 1.5)
	motes.gravity = Vector3(0, 0.02, 0)
	motes.direction = Vector3(0, 1, 0)
	motes.spread = 180.0
	motes.initial_velocity_min = 0.02
	motes.initial_velocity_max = 0.12
	motes.scale_amount_min = 0.6
	motes.scale_amount_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.04, 0.04)
	var qm := _mat(Color(1.0, 0.85, 0.55), 3.0)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = qm
	motes.mesh = quad
	add_child(motes)
	# หยดน้ำจากชายกันสาด (ฝนเพิ่งหยุด)
	var drips := CPUParticles3D.new()
	drips.name = "AwningDrips"
	drips.position = Vector3(6.4, 2.9, 1.65)
	drips.amount = 24
	drips.lifetime = 0.9
	drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drips.emission_box_extents = Vector3(3.2, 0.0, 0.05)
	drips.gravity = Vector3(0, -6.0, 0)
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.12)
	var dm := _mat(Color(0.8, 0.85, 1.0, 0.8), 1.5)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = dm
	drips.mesh = drop
	add_child(drips)


func _build_foreground_leaves() -> void:
	# ใบไม้ใกล้กล้อง: จะเบลอจาก tilt-shift ทำให้ฉากดูเหมือนโมเดลจิ๋ว
	var leaves := _picture(self, LEAVES_TEX, 3.4, Vector3(0.0, 3.0, 10.5), false)
	leaves.name = "ForegroundLeaves"
