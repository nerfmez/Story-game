extends Node2D
## ฝูงนกเล็กๆ บินผ่านท้องฟ้าเป็นระยะ (ใส่ไว้ใน Parallax2D ชั้นไกล)
## ภาพนก 2 เฟรม (กางปีก/หุบปีก) เรียงแนวนอน

@export var bird_texture: Texture2D
## ช่วงเวลาสุ่มระหว่างฝูง (วินาที)
@export var interval_min := 14.0
@export var interval_max := 30.0
## ฝูงแรกมาหลังเริ่มกี่วินาที
@export var first_delay := 5.0
## เสียงนกร้อง (สุ่มหลายแบบ) เล่นเฉพาะตอนฝูงบินอยู่บนจอ
@export var call_sound: AudioStreamPlayer
## ช่วงเวลาสุ่มระหว่างเสียงร้องแต่ละครั้ง (วินาที)
@export var call_gap_min := 0.5
@export var call_gap_max := 1.8
## ความสูงบนจอที่ฝูงบิน (พิกเซล)
@export var y_min := 40.0
@export var y_max := 120.0

var _wait := 0.0
var _call_wait := 0.0
var _flock: Array = []   # [sprite, speed, phase, base_y]


func _ready() -> void:
	_wait = first_delay


func _process(delta: float) -> void:
	if _flock.is_empty():
		_wait -= delta
		if _wait <= 0.0:
			_spawn()
		return
	var view_w := get_viewport_rect().size.x
	var t := Time.get_ticks_msec() / 1000.0
	var alive := false
	var on_screen := false
	for b in _flock:
		var s: Sprite2D = b[0]
		s.position.x += b[1] * delta
		s.position.y = b[3] + sin(t * 1.7 + b[2]) * 3.0
		s.frame = int(t * 7.0 + b[2] * 3.0) % 2
		var sx := s.get_global_transform_with_canvas().origin.x
		if (b[1] > 0.0 and sx < view_w + 20.0) or (b[1] < 0.0 and sx > -20.0):
			alive = true
		if sx > 0.0 and sx < view_w:
			on_screen = true
	if on_screen and call_sound and is_visible_in_tree():   # ซ่อนฝูงนก (เช่นตอนฝนตก) = ไม่มีเสียงร้อง
		_call_wait -= delta
		if _call_wait <= 0.0:
			call_sound.play()
			_call_wait = randf_range(call_gap_min, call_gap_max)
	if not alive:
		for b in _flock:
			b[0].queue_free()
		_flock.clear()
		_wait = randf_range(interval_min, interval_max)


func _spawn() -> void:
	_call_wait = randf_range(0.2, 0.8)
	var dir := 1.0 if randf() < 0.5 else -1.0
	var speed := randf_range(22.0, 34.0) * dir
	var y := randf_range(y_min, y_max)
	var count := randi_range(3, 7)
	# จุดเริ่มนอกจอ ในพิกัดของโหนดนี้ (ชั้น parallax เลื่อนตามกล้อง)
	var screen_to_local := position.x - get_global_transform_with_canvas().origin.x
	var start := (-24.0 if dir > 0.0 else get_viewport_rect().size.x + 24.0) + screen_to_local
	for i in count:
		var s := Sprite2D.new()
		s.texture = bird_texture
		s.hframes = 2
		s.centered = false
		# รูปตัววีหลวมๆ: ตัวหลังๆ อยู่ถัดไปและสูง/ต่ำสลับ
		var back := float(i) * randf_range(9.0, 15.0)
		s.position = Vector2(start - back * dir, y + (i % 2) * 5.0 + i * 1.5 * (1 if i % 2 else -1))
		add_child(s)
		_flock.append([s, speed * randf_range(0.95, 1.05), randf() * TAU, s.position.y])
