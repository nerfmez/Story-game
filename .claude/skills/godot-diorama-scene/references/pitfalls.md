# Mistakes already made once

- **Packed arrays are values in GDScript.** `var a = dict["v"]; a.append(x)` changes a copy. The kit keeps
  its arrays as members of an inner `Batch` class for this reason.
- **Typed inference fails on calls into the diorama script** (`var glass := scene.add_glass(...)`): give the
  type (`var glass: MeshInstance3D = ...`).
- **Fake lights make real highlights.** A fill light with no visible source still drew an egg-shaped specular
  blob on the wet ground. Fill lights get `light_specular = 0` (`fill = true` in `_omni`), and both the toon
  and puddle shaders multiply their highlight by `SPECULAR_AMOUNT`.
- **Reflection strips.** A strip that simply fades from the light toward the camera reads as a solid oval or a
  wavy flag. Peak it at the mirror point (`reach * h / (eye_height + h)`), break it into irregular dashes with a
  per-strip seed, and discard outside the base (|x|, |z| > 9) or it floats in the void.
- **Light limit.** The Compatibility renderer drops lights beyond 8 per object by default; the projects set
  `rendering/limits/opengl/max_lights_per_object=16`. Interior meshes are on layer 2 and lit only by the shop
  lights; outdoor lights use layer 1.
- **Interior washes out.** Glow plus fill plus three lights made the shop pure white. Keep indoor `lit` around
  0.3 and shop lights below 1.0; products carry a little more `lit` so their colours survive.
- **Euler rotations tilt things.** `rot (90, 22.5, 0)` on an octagon tilted it out of its plane and hid half the
  text. Build such bases explicitly: `Basis(RIGHT, PI/2) * Basis(UP, PI/8)`.
- **Rain under roofs.** Every new roof, canopy or umbrella needs a rectangle in `SHELTERS` (8 slots) or rain
  falls through it, and through the shop into the interior view.
- **Relative capture paths** land relative to Godot's process, not your shell: pass absolute paths to
  `--capture`.
- **Headless dummy renderer** prints `mesh_get_surface_count` errors for QuadMesh and MultiMesh; run the test
  under `xvfb-run` with the real renderer instead. Texture-leak messages at exit are normal.
- **Web export.** Artifacts serve only some extensions and 15 MB per binary; the engine is 35 MB. That is why
  `export_web.py` gzips it and renames the pack. `ensureCrossOriginIsolationHeaders` must be false (no
  service workers in artifacts).
- **Do not run code from external repositories** without the user's go-ahead; the auto-mode classifier blocks
  `npm install` there.
