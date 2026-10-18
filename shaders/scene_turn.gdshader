shader_type canvas_item;
// หมุนฉาก (คัทซีนข้ามทางม้าลาย): มองฉากเป็นชุดฉาก 3 มิติง่ายๆ แล้วหมุนกล้องรอบแกนตั้งที่เท้าของทั้งคู่
// - พื้น (ทางเท้า ถนน ทางม้าลาย) = พื้นราบ: ภาพทางม้าลายวาดแบบเปอร์สเปกทีฟอยู่แล้ว (แถบห่างกันมากขึ้นเมื่อใกล้)
//   หาเส้นขอบฟ้าได้จากระยะแถบ (แถว 203 ของโลก) พื้นแต่ละแถว = ความลึก Z = F / (แถว - ขอบฟ้า)
// - ทุกอย่างเหนือฐานกำแพง (กำแพง ราว รถไฟ ต้นไม้ ฟ้า) = แผ่นตั้งที่ความลึกของฐานกำแพง
// หมุนแล้วทางม้าลายบนพื้นเฉียงไปตามทิศที่ทั้งคู่เดิน (เข้าหากล้องเยื้องซ้าย) เสายังตั้งตรง
// advance = ทั้งคู่ (และกล้องที่ตามหลัง) เดินไปข้างหน้ากี่หน่วยความลึก: พื้นไหลเข้าหากล้อง กำแพงไกลออก
// พื้นที่ใกล้กว่าแถวล่างสุดของภาพ (ไม่มีภาพ) ใช้ถนนซ้ำตามระยะแถบทางม้าลาย
// zoom = กล้องซูมเข้าหาจุด focus บนจอ (นับจากกลางจอ) ตอนหมุน
//
// ภาพต้นทาง = จอที่กล้องเกมถ่ายไว้ที่ซูม src_zoom (ถอยออกให้เห็นกว้างกว่าจอ) กลางจอ = เท้าแนวนอน, แถว 180 ของโลก
// หน่วย: พิกเซลโลก นับจากกลางกล้อง (x ขวา, y ลง)

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float yaw = 0.0;
uniform float advance = 0.0;
uniform float src_zoom = 0.7;
uniform float src_shift = 0.0;     // กล้องเกมเลื่อนไปทางซ้าย (พิกเซลโลก) ให้ภาพต้นทางมีด้านที่ไกลออกมากพอ
uniform float focal = 500.0;
uniform float horizon = 23.0;       // ขอบฟ้าของภาพต้นทาง (แถว 203 - 180)
uniform float feet_row = 93.0;      // แถวเท้าในภาพต้นทาง (273 - 180) = จุดหมุน
uniform float wall_row = 70.0;      // ฐานกำแพง (250 - 180)
uniform float bottom_row = 179.0;   // แถวล่างสุดที่มีภาพพื้น (359 - 180)
uniform float stripe_depth = 0.55;  // ระยะแถบทางม้าลายหนึ่งรอบ (ความลึก)
uniform float out_horizon = -17.0;  // ขอบฟ้าบนจอผลลัพธ์ (นับจากกลางจอ)
uniform float zoom = 1.0;
uniform vec2 focus = vec2(0.0);

void fragment() {
	vec2 q = (SCREEN_UV - 0.5) * vec2(640.0, 360.0);
	q = focus + (q - focus) / zoom;
	float zp = focal / (feet_row - horizon);
	float zw = focal / (wall_row - horizon);
	float zb = focal / (bottom_row - horizon);
	float c = cos(yaw);
	float s = sin(yaw);
	vec3 d = vec3(q.x, q.y - out_horizon, focal);
	vec3 w = vec3(d.x * c + d.z * s, d.y, -d.x * s + d.z * c);
	vec3 cam = vec3(-zp * s, 0.0, -zp * c + zp - advance);
	float tf = w.y > 0.0 ? 1.0 / w.y : 1e9;            // พื้นอยู่ต่ำกว่ากล้อง 1 หน่วย
	float tw = (zw - cam.z) / w.z;
	bool floor_hit = tf > 0.0 && (tf < tw || tw <= 0.0);
	float t = floor_hit ? tf : tw;
	vec3 p = cam + t * w;
	float z = p.z;
	if (floor_hit && z < zb) {
		z += ceil((zb - z) / stripe_depth) * stripe_depth;
	}
	if (!floor_hit) {
		z = zw;
	}
	vec2 src = vec2(focal * p.x / z, focal * p.y / z + horizon);
	src.y = clamp(src.y, -180.0, bottom_row);
	// พื้นด้านขวาเกินภาพต้นทาง: ถนนในภาพซ้ำทุก 720 พิกเซล ใช้ช่วงเดียวกันที่อยู่ทางซ้าย
	float right_edge = src_shift + 320.0 / src_zoom - 2.0;
	if (floor_hit && src.x > right_edge) {
		src.x -= ceil((src.x - right_edge) / 720.0) * 720.0;
	}
	vec2 uv = 0.5 + (src - vec2(src_shift, 0.0)) * src_zoom / vec2(640.0, 360.0);
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	COLOR = vec4(textureLod(screen_tex, uv, 0.0).rgb, 1.0);
}
