extends Node
## ฉากหลัก: โหลดบทพูดจาก JSON แล้วสั่งกล่องข้อความ กล้อง และรถไฟตามบท
## ใช้ได้ทั้งฉาก 2D (main.tscn) และ HD-2D (main_3d.tscn)

## ฉากเปิดเรื่อง (scripts/prologue.gd) และการ์ดคำโปรย/ชื่อเรื่อง (scripts/title_cards.gd)
@export var prologue: Node
@export var cards: Node
## กล้องที่มีฟังก์ชัน pan_to(x)
@export var camera: Node
## รถไฟที่มีฟังก์ชัน pass_by()
@export var train: Node

@onready var dialogue_box: DialogueBox = $UI/DialogueBox

const SMOOTH_PIXEL := preload("res://shaders/smooth_pixel.gdshader")
## เสียงฝนระหว่างคำโปรย (dB): เบากว่าในฉาก (-5) ให้เสียงพากย์ชัด
const AMBIENCE_UNDER_VOICE := -20.0

var _ambience_db := 0.0

## ช่วงเวลาของฉาก: ภาพเย็นอยู่ใน assets/bg/sunset/ ช่วงเวลาอื่นมีภาพชื่อเดียวกันในโฟลเดอร์ของตัวเอง
## (morning: tools/compose_morning_scene.py, rain: tools/compose_rain_scene.py) แต่ละช่วงเปลี่ยนภาพ
## ทุกชั้นที่มีเวอร์ชันของมัน ซ่อน/แสดงบางชั้น เปลี่ยนโทนสีทั้งจอ ฝุ่นในแสง เสียงบรรยากาศ และความสว่างตัวละคร
## ตอนนี้ใช้แค่ฉากฝน (ฉากเปิดเรื่อง) เช้า/เย็นเก็บไว้ก่อน (ภาพและค่าต่างๆ ยังอยู่ครบ เปลี่ยนค่านี้ได้)
@export_enum("evening", "morning", "rain") var time_of_day := "rain"
const TIMES := {
	"evening": {"folder": "", "hide": [], "show": []},
	"morning": {
		"folder": "morning",
		"hide": [^"SunLight", ^"Wisps", ^"TrainLayer/Train/Glow"],
		"show": [],
		# เงาฟ้าอ่อนๆ ไฮไลต์อุ่นนิดหน่อย ขอบจอมืดน้อยลง
		"grade": [Vector3(0.0, 0.03, 0.07), Vector3(0.03, 0.02, 0.0), 0.3, 0.15],
		"dust": Color(1.0, 1.25, 1.35, 0.7),          # ฝุ่นในแสงเช้า: ขาวอมฟ้า
		"ambience": "res://assets/audio/ambience_morning.ogg",
		"morning": true,
	},
	"rain": {
		# เช้ามืด ครึ้ม ฝนตก: ไม่มีแดด ไม่มีฝุ่นในแสง ไม่มีนก ไฟในรถไฟยังเปิด มีฝนตกกับน้ำกระเซ็น
		"folder": "rain",
		"hide": [^"SunLight", ^"Wisps", ^"Dust", ^"Birds"],
		"show": [^"Grade/Rain", ^"RainSplash"],
		"grade": [Vector3(0.0, 0.02, 0.07), Vector3(0.0, 0.01, 0.03), 0.35, 0.4],
		"ambience": "res://assets/audio/ambience_rain.ogg",
		"characters": Color(0.8, 0.84, 0.94),        # ตัวละครอยู่ในแสงครึ้มด้วย
		"umbrella": true,                             # พระเอกกางร่ม (ยืน/เดินถือร่ม)
		"morning": true,
	},
}


func _ready() -> void:
	# บนมือถือ/เบราว์เซอร์ ให้ภาพขยายเต็มจอแบบไม่ต้องเป็นจำนวนเท่าเต็ม (ไม่งั้นภาพเล็กมีขอบดำหนา)
	if OS.has_feature("web") or OS.has_feature("mobile"):
		get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	# ฉากและตัวละคร: คมแบบพิกเซลแต่เลื่อนทีละเศษพิกเซลได้ (ชั้นไกลที่เลื่อนช้าจะไม่กระตุก)
	var smooth := ShaderMaterial.new()
	smooth.shader = SMOOTH_PIXEL
	_use_smooth_pixels(self, smooth)
	_evening_ambience = ($Ambience as AudioStreamPlayer).stream if has_node("Ambience") else null
	set_time(time_of_day)
	dialogue_box.line_started.connect(_on_line_started)
	dialogue_box.hide()
	if OS.has_feature("web"):
		_prepare_sounds(self)
	# เบราว์เซอร์ไม่ให้เล่นเสียงจนกว่าผู้เล่นจะแตะ: แตะครั้งแรกแล้วคำโปรยเล่นพร้อมเสียงพากย์และเสียงฝนเบาๆ
	var ambience := get_node_or_null("Ambience") as AudioStreamPlayer
	if ambience:
		ambience.stop()
		_ambience_db = ambience.volume_db
	cards.restart_pressed.connect(func(): get_tree().reload_current_scene())
	var hash := str(JavaScriptBridge.eval("location.hash")) if OS.has_feature("web") else ""
	if hash == "#cross" or hash == "#school" or hash == "#class":
		if ambience:
			ambience.play()
		if hash == "#cross":
			prologue.debug_crossing()          # ทดสอบช่วงข้ามทางม้าลาย (ต่อด้วยเดินไปโรงเรียน)
		elif hash == "#class":
			prologue.debug_class()             # ทดสอบห้องเรียนอย่างเดียว
		else:
			prologue.debug_school()            # ทดสอบช่วงเดินไปโรงเรียนอย่างเดียว
		return
	# วิดีโอเปิดเรื่องเล่นทันทีที่แตะเพื่อเริ่ม (scripts/intro_video.gd) จบแล้วค่อยเปิดเสียงฝนของเกม
	var intro := IntroVideo.new()
	add_child(intro)
	cards.start_ready.connect(intro.arm)
	# ระหว่างคำโปรย/ชื่อเรื่อง (จอดำ) ไม่มีรถไฟวิ่งผ่านในฉากข้างหลัง (เสียงรถไฟทับเสียงพากย์) มีแค่เสียงฝนเบาๆ
	if train:
		train.process_mode = Node.PROCESS_MODE_DISABLED
	if ambience:
		cards.begin_pressed.connect(func():
			ambience.volume_db = AMBIENCE_UNDER_VOICE
			ambience.play())
	await cards.play_opening()
	cards.clear_now()
	await cards.fade_music(0.8)                # เพลงชื่อเรื่องจางออกขณะวิดีโอเริ่ม (วิดีโอเล่นจาก JavaScript ตั้งแต่ตอนแตะ)
	AudioServer.set_bus_mute(0, true)          # ระหว่างวิดีโอมีแต่เสียงของวิดีโอ
	await intro.play()
	AudioServer.set_bus_mute(0, false)
	if train:
		train.process_mode = Node.PROCESS_MODE_INHERIT
	if ambience:
		ambience.volume_db = _ambience_db
		ambience.play()
	prologue.begin()                           # การ์ดชื่อตอน บทบนจอดำ แล้วค่อยเผยฉาก (prologue.gd)


## เตรียมเสียงทุกไฟล์ไว้ล่วงหน้า (บนเว็บ Godot จะเตรียมตอนเล่นครั้งแรก ทำให้เสียงแรกช้า)
func _prepare_sounds(node: Node) -> void:
	for child in node.get_children():
		if child is AudioStreamPlayer and child.stream:
			var stream: AudioStream = child.stream
			var streams: Array = [stream]
			if stream is AudioStreamRandomizer:
				streams = []
				for i in stream.streams_count:
					streams.append(stream.get_stream(i))
			for st in streams:
				if st and not AudioServer.is_stream_registered_as_sample(st):
					AudioServer.register_stream_as_sample(st)
		_prepare_sounds(child)


var _evening_ambience: AudioStream


## เดิม: สลับเช้า/เย็น (ยังใช้ได้)
func set_morning(on: bool) -> void:
	set_time("morning" if on else "evening")


## เปลี่ยนช่วงเวลาของฉาก (evening / morning / rain)
func set_time(time: String) -> void:
	time_of_day = time
	var t: Dictionary = TIMES[time]
	_swap_textures(self, t["folder"])
	# ชั้นที่ช่วงเวลาไหนซ่อน/แสดง: ทุกชั้นที่ถูกพูดถึงในตาราง กลับเป็นค่าปกติก่อน
	for other in TIMES.values():
		for path in other["hide"]:
			_set_visible(path, not path in t["hide"])
		for path in other["show"]:
			_set_visible(path, path in t["show"])
	var grade := get_node_or_null("Grade/Screen") as ColorRect
	if grade and grade.material is ShaderMaterial:
		var m := grade.material as ShaderMaterial
		var params := ["shadow_tint", "highlight_tint", "tint_amount", "vignette"]
		for i in params.size():   # ไม่มีในตาราง = ค่าเดิมของ shader (เย็น)
			m.set_shader_parameter(params[i], t["grade"][i] if t.has("grade") else null)
	var dust := get_node_or_null("Dust") as CPUParticles2D
	if dust:
		dust.modulate = t.get("dust", Color.WHITE)
	var characters := get_node_or_null("Characters") as CanvasItem
	if characters:
		characters.modulate = t.get("characters", Color.WHITE)
	var hero := get_node_or_null("Characters/Hero")
	if hero and hero.has_method("set_umbrella"):
		hero.set_umbrella(t.get("umbrella", false))
	var heroine := get_node_or_null("Characters/Heroine")
	if heroine and heroine.has_method("set_wet"):   # ฝนตก: นางเอกตัวเปียก แว่นขึ้นฝ้า
		heroine.set_wet(t.get("umbrella", false))
	var ambience := get_node_or_null("Ambience") as AudioStreamPlayer
	if ambience and _evening_ambience:
		var want: AudioStream = load(t["ambience"]) if t.has("ambience") else _evening_ambience
		if ambience.stream != want:
			var was_playing := ambience.playing
			ambience.stream = want
			if OS.has_feature("web") and not AudioServer.is_stream_registered_as_sample(want):
				AudioServer.register_stream_as_sample(want)
			if was_playing:
				ambience.play()


func _set_visible(path: NodePath, on: bool) -> void:
	var node := get_node_or_null(path) as CanvasItem
	if node:
		node.visible = on


## เปลี่ยนภาพของทุก Sprite2D ที่มีเวอร์ชันของช่วงเวลานี้ (ชื่อไฟล์เดียวกันในโฟลเดอร์ folder)
func _swap_textures(node: Node, folder: String) -> void:
	for child in node.get_children():
		if child is Sprite2D and child.texture:
			if not child.has_meta("evening_texture"):
				child.set_meta("evening_texture", child.texture)
			var evening: Texture2D = child.get_meta("evening_texture")
			var path := evening.resource_path
			var other := path.replace("/bg/sunset/", "/bg/%s/" % folder)
			if folder != "" and other != path and ResourceLoader.exists(other):
				child.texture = load(other)
			else:
				child.texture = evening
		if not child is CanvasLayer:
			_swap_textures(child, folder)


func _use_smooth_pixels(node: Node, smooth: ShaderMaterial) -> void:
	for child in node.get_children():
		if child is Sprite2D and child.material == null:
			child.material = smooth
			child.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if not child is CanvasLayer:  # UI อยู่ใน CanvasLayer: ไม่ต้องเปลี่ยน
			_use_smooth_pixels(child, smooth)


static func load_lines(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("เปิดไฟล์บทไม่ได้: %s" % path)
		return []
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("lines"):
		push_error("รูปแบบไฟล์บทไม่ถูกต้อง: %s" % path)
		return []
	return data["lines"]


func _on_line_started(line: Dictionary) -> void:
	# คำสั่งเสริมในแต่ละบรรทัดของบท (ไม่ใส่ก็ได้)
	if line.has("camera_x"):
		camera.pan_to(float(line["camera_x"]))
	if line.get("event", "") == "train" and not train._running:   # ผ่านอยู่แล้วก็ไม่เริ่มใหม่
		train.pass_by()
