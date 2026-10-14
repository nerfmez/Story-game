# Story-game

เกมเนื้อเรื่องแนว visual novel ภาพ pixel art สร้างด้วย **Godot 4.3** (GDScript, renderer: Compatibility)

![ภาพตัวอย่าง](docs/screenshot.png)

## วิธีเปิดโปรเจกต์

1. ดาวน์โหลด [Godot 4.3+](https://godotengine.org/download) (ตัวธรรมดา ไม่ต้องใช้ .NET)
2. เปิด Godot → **Import** → เลือกไฟล์ `project.godot` ในโฟลเดอร์นี้
3. กด **F5** เพื่อรันเกม
   - คลิกซ้าย / Space / Enter = ข้อความถัดไป
   - ขยับเมาส์ซ้าย-ขวา = กล้องโยก เห็นเอฟเฟกต์ parallax

## โครงสร้าง

```
project.godot            ตั้งค่าโปรเจกต์ (640x360 ขยาย x2 แบบ integer, filter = Nearest)
scenes/main.tscn         ฉากหลัก: กล้อง + ชั้น Parallax2D + ตัวละคร + UI
scenes/dialogue_box.tscn กล่องข้อความ + ป้ายชื่อ
scripts/main.gd          โหลดบทจาก JSON และสั่งกล้อง/อีเวนต์
scripts/dialogue_box.gd  ข้อความพิมพ์ทีละตัว, คลิกเพื่อไปต่อ
scripts/scene_camera.gd  กล้องเลื่อนตามบทและโยกตามเมาส์
scripts/train.gd         รถไฟวิ่งผ่านฉาก
data/chapter1.json       บทพูด (แก้ตรงนี้เพื่อเขียนเนื้อเรื่อง)
assets/bg/               ภาพพื้นหลังแยกชั้น
assets/characters/       สไปรต์ตัวละคร
assets/fonts/            ฟอนต์ไทย Sarabun (SIL OFL)
tools/                   สคริปต์สร้างภาพ placeholder
```

## ชั้น Parallax (จากไกล → ใกล้)

| ชั้น | ไฟล์ | scroll_scale |
|---|---|---|
| ท้องฟ้า / พระอาทิตย์ / เมฆ | `01_sky.png` | 0.05 |
| เมืองไกล / เสาไฟ | `02_city_far.png` | 0.25 |
| รถไฟ | `03_train.png` | 0.45 |
| ประตูโรงเรียน / ร้านน้ำ / ไม้กั้น | `04_mid.png` | 0.7 |
| พื้นถนนเปียก | `05_ground.png` | 1.0 |
| ตัวละคร | `assets/characters/` | 1.0 |
| ใบไม้หน้าจอ | `06_foreground.png` | 1.3 |

`scroll_scale` น้อย = อยู่ไกล เลื่อนช้า, มากกว่า 1 = อยู่หน้ากล้อง เลื่อนเร็วกว่าตัวละคร

ภาพตอนนี้เป็น **placeholder** ที่สร้างจาก `python3 tools/make_placeholder_art.py`
เปลี่ยนเป็นภาพจริงได้เลย (เช่น วาดใน Aseprite แล้ว export ทีละเลเยอร์) โดยใช้ชื่อไฟล์เดิม
ภาพพื้นหลังกว้าง 800px สูง 360px (กว้างกว่าจอ 640px เพื่อให้กล้องเลื่อนได้)

## เขียนบท

แก้ไฟล์ `data/chapter1.json`:

```json
{ "speaker": "เพื่อนสาว", "text": "จะยืนเหม่ออีกนานไหม", "camera_x": 270, "event": "train" }
```

- `speaker` ชื่อผู้พูด (เว้นว่าง = คำบรรยาย ไม่แสดงป้ายชื่อ)
- `text` ข้อความ (รองรับ BBCode เช่น `[color=yellow]คำ[/color]`)
- `camera_x` (ไม่ใส่ก็ได้) เลื่อนกล้องไปตำแหน่ง x (260–380)
- `event` (ไม่ใส่ก็ได้) ตอนนี้มี `"train"` = รถไฟวิ่งผ่าน
