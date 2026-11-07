# ส่งต่อให้ ChatGPT: วาดฉากหลังของ "Summer Coast"

> ถ้า ChatGPT เข้าถึง repo นี้ได้ ให้บอกแค่ว่า "อ่าน AGENTS.md แล้ววาดฉากหลังตาม docs/konbini-diorama/chatgpt-backdrop-brief.md แล้ว commit ภาพเข้า branch ccr-f1b5a560-y1h5ug" ก็พอ ข้างล่างนี้คือวิธีสั่งด้วยมือในแชทแบบปกติ

เอกสารนี้ใช้สั่ง ChatGPT (หรือเครื่องมือสร้างภาพตัวอื่น) ให้วาดภาพฉากหลังของไดออรามาชายฝั่งหน้าร้อน แล้วนำภาพกลับมาใส่ในเกมได้ทันที
วิธีใช้มี 3 ขั้น:

1. เปิดแชทใหม่ใน ChatGPT แล้วแนบภาพอ้างอิง 3 ภาพจากโฟลเดอร์นี้:
   - `coast-view-1.png`: ทั้งฉาก ให้เห็นสไตล์โดยรวม
   - `backdrop-behind-shop.png`: มุมใกล้หลังร้านริมหาด เห็นต้นไม้ ภูเขา และเมฆของฉากหลังปัจจุบัน
   - `foliage-demo.png`: สไตล์ต้นไม้ที่ใช้ในฉาก
2. คัดลอกข้อความในกล่อง **"ข้อความแรก (style brief)"** ไปวาง แล้วตามด้วยคำสั่งของแต่ละภาพทีละภาพ (ภาพละหนึ่งข้อความ)
3. ดาวน์โหลดภาพ PNG ที่ได้ ตั้งชื่อตามตาราง แล้วส่งกลับมาให้ Claude ในแชท หรือวางไว้ที่ `assets/backdrop/` ในโปรเจกต์
   เกมจะใช้ภาพนั้นแทนภาพที่โค้ดวาดเองโดยอัตโนมัติ ภาพไหนยังไม่มี เกมจะใช้แบบที่โค้ดวาดไปก่อน

---

## ฉากหลังทำงานอย่างไร

ด้านหลังฐานไดออรามามีชั้นไม้ต่อออกไป บนชั้นตั้งแผ่นไม้บางๆ เรียงกันห่างกันแผ่นละราว 30 ซม. แบบฉากละครเวทีหรือฉากหลังโมเดลรถไฟ
แต่ละแผ่นแปะภาพวาดหนึ่งชั้น เรียงจากหลังไปหน้า:

| ไฟล์ | ชั้น | แผ่นจริง (กว้าง × สูง) | ภาพที่ขอ | ภาพซ้ำกี่ครั้งตามแนวกว้าง |
|---|---|---|---|---|
| `far_peaks.png` | ยอดเขาไกลสุด | 37 × 6.2 ม. | 1536 × 1024 โปร่งใส | 3 |
| `mountains.png` | ภูเขากลาง | 37 × 4.4 ม. | 1536 × 1024 โปร่งใส | 3 |
| `hills.png` | เนินเขามีป่าใกล้สุด | 37 × 2.6 ม. | 1536 × 1024 โปร่งใส | 5 |
| `cloud.png` | เมฆหน้าร้อนก้อนใหญ่ | 11 × 7.5 ม. | 1536 × 1024 โปร่งใส | 1 |
| `cloud_small.png` | เมฆก้อนเล็ก | 6.5 × 4.4 ม. | 1536 × 1024 โปร่งใส | 1 |

ภาพจะถูกยืดตามแนวกว้างให้เต็มแผ่น ประมาณ 1.3–1.9 เท่า ภูเขาจะดูกว้างขึ้นนิดหน่อย ซึ่งไม่เป็นปัญหา

**ข้อกำหนดที่ต้องได้ ไม่งั้นใส่ในเกมแล้วจะดูผิด:**

- **พื้นหลังโปร่งใส (PNG มี alpha):** เห็นเฉพาะภูเขาหรือเมฆ ส่วนที่เป็นฟ้าต้องใส เพราะเกมมีท้องฟ้าของตัวเองอยู่ข้างหลัง
- **ต่อกันซ้ายขวาได้ (seamless):** สำหรับ far_peaks, mountains และ hills ขอบซ้ายกับขอบขวาต้องจบที่ความสูงเดียวกันและสีเดียวกัน เพราะภาพจะถูกวางซ้ำต่อกัน
- **เนื้อภาพเต็มถึงขอบล่าง:** ภูเขาต้องลงไปถึงขอบล่างของภาพ ไม่มีช่องว่างข้างใต้ ขอบล่างควรจางเป็นหมอกสีขาวอมฟ้า
- **แสงมาจากซ้ายบน:** ด้านซ้ายของภูเขาโดนแดด ด้านขวาเป็นเงา ให้ตรงกับแสงในฉาก
- **ห้ามมีคน รถ ตัวหนังสือ ลายน้ำ หรือกรอบ**

---

## ข้อความแรก (style brief), วางก่อนทุกครั้ง

```
I am making a small 3D diorama of a Japanese seaside in summer, cel-shaded in an anime style
(see the reference images: the whole diorama, a close view, and the trees). I need painted
BACKDROP LAYERS that will be printed onto thin boards standing behind the model, like the
painted backscene of a model railway or the background art of a Japanese anime film.

Style for every image:
- Hand-painted anime background art, like the backgrounds of Studio Ghibli or Makoto Shinkai
  films, painted with poster colour (gouache): visible but soft brush strokes, no photo texture.
- Simple, readable shapes. Each layer has very few values: a lit side and a shadow side, and
  the shadow is a cooler blue. No black outlines.
- Atmospheric perspective: the farther the layer, the paler, bluer and lower in contrast it is.
- Summer afternoon light coming from the UPPER LEFT: left-facing slopes are lit, right-facing
  slopes are in shadow.
- Palette: sky-blue haze #C8E0F5, pale mist #E6F0F7, far mountains #93ADD6 / #6B85BD,
  mid mountains #80A3BD / #52739E, near wooded hills #80B36B / #336B61, cloud whites #FFFFFA
  with blue-grey shadows #BDD1F0.
- TRANSPARENT background (PNG with alpha): only the land or the cloud is painted, the sky is
  empty/transparent.
- No people, vehicles, buildings, text, signatures, watermarks or frames.
Reply "ready" and wait for the first layer.
```

## คำสั่งของแต่ละภาพ

**1. `far_peaks.png`: ยอดเขาไกลสุด**
```
Layer 1, far peaks. A wide strip of distant mountain range, 1536x1024, transparent sky.
The range fills the lower 60% of the image, with a few rounded summits of different heights
and widths and small notches along the ridgeline. Very pale and hazy blue, almost the colour
of the sky; lit and shadow sides only slightly different. The bottom 25% dissolves into a
band of bright white-blue mist. Seamless: the left and right edges must meet at the same
height so the image can repeat side by side. Transparent PNG.
```

**2. `mountains.png`: ภูเขากลาง**
```
Layer 2, middle mountains. 1536x1024, transparent sky. A range of forested mountains in the
lower 55% of the image, closer than layer 1: clearer shapes, gentle ridges and a couple of
valleys, blue-teal colours with a lit left side and a cooler shadowed right side, soft
brush strokes running down the slopes. The foot of the range fades into horizontal bands of
pale valley mist. Seamless left-right edges. Transparent PNG.
```

**3. `hills.png`: เนินเขาใกล้สุด**
```
Layer 3, near wooded hills. 1536x1024, transparent sky. Low rolling hills covered by forest,
in the lower 45% of the image. The skyline is a soft scalloped line of rounded tree crowns
(like the trees in the reference), painted as clumps in 3-4 flat tones of green with a
yellow-green lit top and a blue-green shadow, no individual leaves. The bottom edge is dark
green forest, filled to the bottom of the image. Seamless left-right edges. Transparent PNG.
```

**4. `cloud.png`: เมฆก้อนใหญ่**
```
Layer 4, a towering summer cumulus cloud (cumulonimbus), 1536x1024 landscape, transparent
background. Billowing puffs stacked into a tall tower on a flat base. Bright white tops lit
from the upper left, soft blue-grey shadows underneath and on the right, painted in the same
anime poster-colour style with a few flat tones. The whole cloud inside the frame, nothing
cut off. Transparent PNG.
```

**5. `cloud_small.png`: เมฆก้อนเล็ก**
```
Layer 5, a smaller summer cumulus cloud, 1536x1024, transparent background. A low, wide
cloud of a few puffs on a flat base, same lighting and style as layer 4, the whole cloud
inside the frame. Transparent PNG.
```

---

## ถ้าภาพที่ได้ยังไม่ตรง ให้สั่งแก้ด้วยประโยคเหล่านี้

- พื้นหลังไม่ใส: `Make the background fully transparent; only the mountains should be painted.`
- ต่อกันไม่สนิท: `Make it tileable: the left and right edges must line up at the same height and colour.`
- ภาพละเอียดเกินหรือเหมือนรูปถ่าย: `Simpler shapes, fewer details, flatter anime poster-colour tones, no photographic texture.`
- ชั้นไกลเข้มไป: `Paler and bluer, much less contrast, it is very far away.`
- แสงผิดฝั่ง: `The sun is at the upper left: light on the left slopes, shadow on the right.`
- มีขอบล่างว่าง: `Fill the land all the way down to the bottom edge, fading into mist.`

## สไตล์ของฉากทั้งหมด (ถ้าจะให้ ChatGPT ช่วยออกแบบส่วนอื่นต่อ)

- **ไดออรามา:** ฐานไม้ขอบทองเหลือง ฉากจริงยาว 36 × 18 เมตร มองแบบโมเดลสะสม มีแหลมหินกับประภาคารขาวคาดแดงอยู่ซ้าย และชายหาดกับร้านริมหาด "海の家 なぎさ" อยู่ขวา
- **การลงสี:** แบบ cel-shaded มีเส้นขอบดำบางๆ บนวัตถุใกล้ แต่ต้นไม้ไม่มีเส้นดำ ใช้ขอบสีเดียวกันที่เข้มขึ้นแทน และของไกลไม่มีเส้นขอบเลย
- **ต้นไม้:** สนดำญี่ปุ่นกับต้นไม้ใบกว้าง ทรงพุ่มเป็นก้อนกลม ลงสี 4 โทน คือเหลืองเขียว เขียว เขียวเข้ม และเขียวอมฟ้า
- **ทะเล:** น้ำตื้นใสสีเขียวฟ้า ไล่เป็นน้ำเงินเข้ม คลื่นแตกเป็นฟองขาว มีลายแสงในน้ำตื้น
- **บรรยากาศ:** บ่ายหน้าร้อนแดดจ้า เงาอมฟ้า มีเสียงจักจั่นกับเสียงคลื่น
