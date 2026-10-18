@tool
class_name RevealFx
extends RichTextEffect
## [reveal speed=20 span=8]ข้อความ[/reveal]: ตัวอักษรค่อยๆ ปรากฏทีละตัวเป็นคลื่นนุ่มๆ
## (speed = ตัวต่อวินาที, span = จำนวนตัวที่กำลังจางเข้าพร้อมกัน) นับเวลาตั้งแต่ป้ายข้อความเข้าฉาก
## สระ/วรรณยุกต์ไทยเป็นตัวแยกที่ติดกับพยัญชนะ จึงจางเข้าแทบพร้อมกันกับพยัญชนะของมัน

var bbcode := "reveal"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var speed := float(char_fx.env.get("speed", 20.0))
	var span := maxf(1.0, float(char_fx.env.get("span", 8.0)))
	var t := clampf((char_fx.elapsed_time * speed - char_fx.relative_index) / span, 0.0, 1.0)
	char_fx.color.a *= t * t * (3.0 - 2.0 * t)
	return true
