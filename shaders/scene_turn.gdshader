shader_type canvas_item;
// หมุนฉากเป็นมุมเฉียง (คัทซีนข้ามทางม้าลาย): ภาพฉากที่วาดเสร็จแล้วบนจอ = แผ่นภาพแบน
// หมุนแผ่นนั้นรอบแกนตั้งกลางจอ (yaw) แล้วมองด้วยมุมมองแบบเปอร์สเปกทีฟ: ฝั่งหนึ่งไกลออก (เล็กลง) อีกฝั่งเข้าใกล้
// ทุกพิกเซลบนจอหาตำแหน่งบนแผ่นภาพที่มองเห็น (inverse homography)
// x ในหน่วยครึ่งความกว้างจอ, กล้องห่างแผ่นภาพ dist หน่วย (มุมมองเดิมเมื่อ yaw = 0)
// zoom ขยายรอบแถว pivot_y (แถวเท้าตัวละคร) เพื่อไม่ให้เห็นขอบภาพตอนหมุน และพื้นใต้เท้าอยู่ที่เดิม

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float yaw = 0.0;
uniform float dist = 1.8;
uniform float zoom = 1.0;
uniform float pivot_y = 0.667;
// เส้นขอบฟ้าของการมองแบบเปอร์สเปกทีฟ (แถวที่เส้นแนวนอนไม่เอียง) ไว้สูงใกล้แถบดำบน:
// เส้นราว ถนน พื้นข้างล่างจึงเอียงลู่เข้าหาฝั่งที่ไกลออกชัดๆ (ถ้าไว้กลางจอ เส้นกลางจอแทบไม่เอียง ดูไม่ออกว่าหมุน)
uniform float horizon = -0.75;

void fragment() {
	vec2 p = SCREEN_UV * 2.0 - 1.0;
	p = vec2(p.x / zoom, (p.y - pivot_y) / zoom + pivot_y);
	float c = cos(yaw);
	float s = sin(yaw);
	float u = p.x * dist / (dist * c - p.x * s);
	float v = (p.y - horizon) * (dist + u * s) / dist + horizon;
	vec2 src = vec2(u, v) * 0.5 + 0.5;
	if (src.x < 0.0 || src.x > 1.0 || src.y < 0.0 || src.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		COLOR = vec4(texture(screen_tex, src).rgb, 1.0);
	}
}
