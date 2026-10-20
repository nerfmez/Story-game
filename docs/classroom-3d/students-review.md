# Seated students — visual review, 2026-10-20

Reference: existing Sun/Saifon sprites and the merged PR13 classroom. Acceptance: occupied chairs; Saifon at leftmost rear seat 25; Sun one desk ahead at 19; pixel rendering; preserved character outfits; desk/chair depth occlusion.

Inspected the final native Godot 4.3 GL Compatibility renders at 640×360: rear, front, diagonal, leads-front, leads-side, seating-overview. Checked the six generated character sheets and packed RGBA atlases. This is a still-image review, not animation playback or a mobile browser performance test.

Observed: the first bob-haired sheet supplied two right profiles. The left-facing view now mirrors a right profile at runtime, anchored at the hip. Verified the final diagonal view and chair alignment after this change. Background RGB visible in image previews has transparent alpha; the scene uses alpha cutout and shows no background rectangles or colored fringe.

Final review: seats and desk occlusion read correctly in the inspected views; no major visible defect found in this scope. Characters are directional 2D cutouts, so high camera angles do not expose a 3D top surface and four direction changes remain discrete. No character animation is added.

Validation: three Godot scripts passed (30-seat placement/directions, existing geometry/render budget and camera input). The scene has 241 counted render instances including 30 sprites, below the existing 300-instance limit. Headless Godot logs its dummy-renderer mesh cleanup warnings; actual OpenGL captures completed without script errors. GitHub Actions results are separate from these local checks.

## Artifact SHA-256

- `scenes/classroom_3d_pixel.tscn`: `0398ec5b0fb1dacc6c4052b20113277b261f2fab5a501a69885d6dfbd9c3de3c`
- `assets/classroom/students/boy_glasses.png`: `1027ba302baa4daf51c6bb251281ce69e87ddadf1f7f8c9e0c8bb41c6a329ba4`
- `assets/classroom/students/boy_short.png`: `83de791b0f1190c049299936338128cfeb76877d3fd1df59a2cebcaeb203be1c`
- `assets/classroom/students/girl_bob.png`: `7c753a999ba5ce81d731b9a04c64ce991185410aaa8eff3af5ab76815813f082`
- `assets/classroom/students/girl_ponytail.png`: `308bd6d282bf144594cc24357939d6cf0a5132a6e8e9c04345eb4540b53fb6db`
- `assets/classroom/students/saifon.png`: `60caf93173ed1403fcfb0c9cb7bfbdf2caa7a72e23ea544bf1965381a124fff1`
- `assets/classroom/students/sun.png`: `0ed723494158ed5247bbc53cb60968e316235f68c80083a80a19719c3e17e9b2`
- `docs/classroom-3d/students-diagonal.png`: `c2a63a357ac81e1bc1fd781030bbd35025da8cde06491d3444803785c89aae95`
- `docs/classroom-3d/students-front.png`: `5c241302f4190177780b1d069ced74fca4a3e5bcc2ebc890884d5038e5640a44`
- `docs/classroom-3d/students-leads-side.png`: `291d909f8b1c608661c062d203d14bb0df94fe5a7295256f73d874b523f4097f`
- `docs/classroom-3d/students-rear.png`: `19faeddea73fcca7865f8044c32b2c4e3471021146edf16c9036eb0c393c760a`
- `docs/classroom-3d/students-seating-overview.png`: `25fe53e7167fc9504b907651635c015ecf5164e2c0821c871b4f4eb46a3f0720`
