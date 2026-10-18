class_name SchoolBuildingView
extends SubViewportContainer
## โรงเรียน (SchoolModel3D) เรนเดอร์ที่ความละเอียดเกม 640x360 แล้วขยายแบบ Nearest ให้เป็นพิกเซลเหมือนฉากอื่น
## แสงเช้าฝนตก: ฟ้าครึ้มให้แสงรอบตัว แดดอ่อนผ่านเมฆทำเงานุ่ม หลอดนีออนในอาคารส่องจริง หมอกบางๆ
## กล้องเลื่อนไปที่ไหนก็ได้ look(จุดยืน, เป้า)

const SIZE := Vector2i(640, 360)

var camera: Camera3D
var school: SchoolModel3D
var _viewport: SubViewport


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.positional_shadow_atlas_size = 2048
	add_child(_viewport)
	_viewport.add_child(_environment())
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	sun.light_color = Color("dfe6f2")
	sun.light_energy = 0.42
	sun.shadow_enabled = true
	sun.shadow_blur = 2.5
	sun.directional_shadow_max_distance = 70.0
	_viewport.add_child(sun)
	school = SchoolModel3D.new()
	_viewport.add_child(school)
	# ไฟจริงเฉพาะในช่องบันได (ไม่มีแสงฟ้าเข้าถึง) หลอดทางเดินเรืองแสงเอง
	for p in school.lamps:
		if p.z > -2.6 or p.x < SchoolModel3D.CORE[0] or p.x > SchoolModel3D.CORE[1]:
			continue
		var lamp := OmniLight3D.new()
		lamp.position = p
		lamp.light_color = Color("eef4ff")
		lamp.light_energy = 0.7
		lamp.omni_range = 5.0
		lamp.omni_attenuation = 1.6
		_viewport.add_child(lamp)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.near = 0.05
	camera.far = 200.0
	_viewport.add_child(camera)
	look(Vector3(0.0, 1.6, 30.0), Vector3(0.0, 5.0, 0.0))


func _environment() -> WorldEnvironment:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("8d9bb3")
	sky_mat.sky_horizon_color = Color("b9c1cf")
	sky_mat.ground_bottom_color = Color("7d8796")
	sky_mat.ground_horizon_color = Color("9aa3b0")
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# แสงรอบตัวจากฟ้าครึ้ม (กำหนดสีตรงๆ: ฟ้าในเรนเดอร์แบบ compatibility ให้แสงจ้าเกิน)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7f8796")
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("aeb7c6")
	env.fog_density = 0.004
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.2
	var node := WorldEnvironment.new()
	node.environment = env
	return node


func look(from: Vector3, at: Vector3) -> void:
	camera.position = from
	camera.look_at(at, Vector3.UP)
