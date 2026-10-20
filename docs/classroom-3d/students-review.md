# Seated students v2 — visual review, 2026-10-20

Target: twelve distinct background identities, readable differences in build/hair/posture, low-detail pixel art, natural seated poses, and Thai upper-secondary girls' uniforms (white pointed-collar shirts tucked into dark pleated skirts, black belts, white socks and black school shoes). Sun/Saifon art and seats 19/25 are preserved.

Inspected all twelve generated turnarounds and final packed atlases, then the final native Godot 4.3 GL Compatibility renders at 640×360: front, rear, diagonal, leads-front, leads-side and seating-overview. Front/back/side cast sheets expose the silhouettes without furniture covering them. This is a still-pose review, not animation playback or a mobile browser performance test.

The new cast includes broader/stockier/slender bodies, cropped/curly/parted/braided/bob/ponytail/wavy hair, and reading, slouching, chin-resting, chatting, folded-arm and hair/glasses-adjusting poses. Each NPC design appears two or three times; Sun and Saifon are unique. This replaces four repeated neutral NPC designs. Girls' sprites have shirt collars and belts; the former sailor-uniform assets are removed.

The generator reversed some profile cells. The packing manifest reorders complete cells into front/back/left/right before import. Existing chair transforms and depth cutout remain in use; the rendered views were checked for seating support and desk occlusion. No major visible issue remains in the inspected views. Direction changes remain discrete because these are 2D directional sprites in a 3D room.

Validation: three Godot scripts passed (30 occupied seats, 14 identities with at most three copies per NPC design, lead placement and viewing directions; existing room/render-budget checks; camera input). OpenGL captures completed without script errors. The headless dummy renderer logs its existing mesh cleanup warnings. GitHub Actions results are separate from these local checks.

## Artifact SHA-256

- `scenes/classroom_3d_pixel.tscn`: `151e25c7c8304abdc857dc25cf1379f7483415a62d7333324c53b7ee0a35df23`
- `assets/classroom/students/boy_buzz.png`: `49a9eee718a042249dd078c7108e818642413a6c2ce329861daf626e4ad349a6`
- `assets/classroom/students/boy_curly.png`: `02432685a3d81e09c23d617d4a6510642c70333302f7ef4e66ee93edc963ada4`
- `assets/classroom/students/boy_daydream.png`: `c31dd9207a8e418b669df0af4234efb0cb1ca770c13d5bbab3979762a595f4fc`
- `assets/classroom/students/boy_reader.png`: `21aa4c54d77986db294a34544013fbde7aa0e80568a670973c293f2f4186ec60`
- `assets/classroom/students/boy_sleepy.png`: `c1256e9b33306ff198859acd35378aa82b6c791e632cba93e5f8f0af0a831cb4`
- `assets/classroom/students/boy_stocky.png`: `6a6f537c2a231a528a32da614c685e4d8ba8aeab94af7b4b3a666753ac9adca2`
- `assets/classroom/students/girl_bob_v2.png`: `d7ddf71fcd87584942349bc9062aa309474f2792652749ebc99544121de6d366`
- `assets/classroom/students/girl_braided.png`: `a5814ecf69dd718b6b380ac600636e84619d952e27bc19715933a56ac7b35678`
- `assets/classroom/students/girl_glasses.png`: `1fc2a4b7e151d712260d0ef5b4677b34dcb2f21e01b0f2bbfb77903a1e0fe59e`
- `assets/classroom/students/girl_ponytail_v2.png`: `3653516fe0018eb2797fe5187443e52625b67a189372fe02f30bbbe579cfda63`
- `assets/classroom/students/girl_short.png`: `cf44e957b7c466648139625e0d1903baed07d80e1207a0480dc64c052122b321`
- `assets/classroom/students/girl_wavy.png`: `5bc5b4c6c3173a23b1d5da63a67f061919f8cfe0be80573b8ef65a68f6a4146f`
- `assets/classroom/students/saifon.png`: `60caf93173ed1403fcfb0c9cb7bfbdf2caa7a72e23ea544bf1965381a124fff1`
- `assets/classroom/students/sun.png`: `0ed723494158ed5247bbc53cb60968e316235f68c80083a80a19719c3e17e9b2`
- `docs/classroom-3d/students-cast-back.png`: `c1cc9b182624e58997ccc67ac1c0ab1ec240719bac09a35721f5ed51afefd2d9`
- `docs/classroom-3d/students-cast-front.png`: `b23b9fd584e19cae44b3a436538cd3c721067bba2bb19c2410f6af9c7ee6ac47`
- `docs/classroom-3d/students-cast-side.png`: `d77d1cddfbd8d8a4ce7f18a20ab27b664cd3eb8894bdfb761526af9b0086d7de`
- `docs/classroom-3d/students-diagonal.png`: `878cf3501978cfb15c18d3c144816a5ad84950bc4849e2ff907365da8c32eaf6`
- `docs/classroom-3d/students-front.png`: `d5acee8a8df1d662019195f1efd0778ddbe63f336c656f8c32f59fa6589ed528`
- `docs/classroom-3d/students-leads-side.png`: `b579086a8d20038357b3835a0f79d98342e1aaf18b09c2bb2a33fe7ff722cc86`
- `docs/classroom-3d/students-rear.png`: `3ddf7270cfa0b925c7ddc063df2dc341497721c676bc30c82625f83abd8583b0`
- `docs/classroom-3d/students-seating-overview.png`: `a37d07c9e13f8996775f7439ab4654b186e23388d43bc8098dad430af5bea4a9`
- `docs/classroom-3d/students-v2-progress.png`: `7501fc25443600a1c90471a5da3a7eed781e5269bf19958576d884f79e0a8e7d`
