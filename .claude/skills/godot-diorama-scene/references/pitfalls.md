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
- **`k.ball` takes radii, not diameters.** A snowman given diameters came out two metres tall.
- **A-frame boards** lean in at the top: the front board rotates by a negative angle about X; put its text in
  the same basis.
- **Reskinning an old layout** (the ramen shop on the konbini's corner) was rejected: a new subject is a
  new layout file with its own ground, paths, neighbours, lights and views.
- **A camera preset placed behind buildings** shows a wall. Check every preset after building a layout.
- **Relative capture paths** land relative to Godot's process, not your shell: pass absolute paths to
  `--capture`.
- **Headless dummy renderer** prints `mesh_get_surface_count` errors for QuadMesh and MultiMesh; run the test
  under `xvfb-run` with the real renderer instead. Texture-leak messages at exit are normal.
- **Web export.** Artifacts serve only some extensions and 15 MB per binary; the engine is 35 MB. That is why
  `export_web.py` gzips it and renames the pack. `ensureCrossOriginIsolationHeaders` must be false (no
  service workers in artifacts).
- **Do not run code from external repositories** without the user's go-ahead; the auto-mode classifier blocks
  `npm install` there.

## Sea that stands still, trees as lollipops, towers with floating parts (beach, first try)

- A sea is not a fixed foam band at the waterline. Waves come one at a time: a crest travels in, grows
  where it shallows, turns white and breaks, then a thin sheet of water runs up the sand with a foam
  front, slows and slides back, leaving dark wet sand that dries. Do the sea and the swash as two
  shaders sharing one timing (`konbini_sea` and `konbini_swash`) and check frames at several `--wait`
  values: if they all look the same, the sea is wrong.
- A tree is a trunk that bends, branches and foliage masses at the branch tips (for a black pine: flat
  two-tone pads), never one stick through three balls.
- Anything climbable or standing must connect: ladder rungs are placed along the rail line (lerp between
  the rail ends), legs reach the ground, parasol poles start on something. Zoom in on every structure.
- Second try still failed: a flat sand slab with a flat sea plane beside it always shows a drawn
  waterline, however the foam is animated. Model the shore as it is: sand that slopes down under the
  water (a height field, `kit.grid`), water that is clear where shallow (alpha from water depth over
  the sand), and a surface that rises and falls on the slope so the edge moves by itself. Keep the
  beach shape and wave timing in one shader include mirrored in GDScript.
- Third round: a large smooth timing offset along the beach (lag = 0.6 sin(0.25x)) made the breaker
  sweep sideways along the shore; waves roll in toward the beach, so keep the along-shore offset small
  and wiggly. After breaking, the white water should spread into a foam field that thins into patches
  and fades (time since the crest passed, rising noise threshold). And no overlay may end inside the
  sea: its straight edge shows through clear water.
- Any looping motion must start each cycle where the last one ended. The swash front ended at the
  drawn-down level but restarted at the still-water line with new random values, so the water edge
  and the wet sand jumped as each wave began. Make per-cycle randomness fade to zero at both ends of
  the cycle, and let effects left behind (wet sand) grow with the motion instead of switching on.

## Joining a new block to an existing one (the headland left of the beach)

- Make the seam exact, not approximate: the new block evaluates the old block's shore and ground
  functions with its offset (`Beach.shore(x - 18)`), the sea and swash shaders take `shore_offset`, and the
  test compares ground heights across the seam. Anything that only "looks" continuous drifts.
- A height-field hill with steep terraces turns into saw teeth on the grid, and vertex colours by height or
  slope zigzag too. Keep the shape soft and draw strata and the grass/rock split per pixel in the shader.
- Fallback shapes (a shelf that drops off outside its outline) must fall well below everything else, or
  they lift the ground far from where they belong.
- Camera presets inside or right against props (a bench filling the frame, the lighthouse gallery) happen
  easily on a hill: render every view after placing things.
