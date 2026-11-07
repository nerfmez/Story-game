# How the diorama is built

## Files

| File | What it holds |
|---|---|
| `scenes/konbini_diorama.tscn`, `scenes/konbini_diorama_thai.tscn` | A Node3D with `konbini_diorama.gd`; the Thai one sets `country = "thailand"` |
| `scripts/konbini_diorama.gd` | Entry point: environment, lights, glass, doors, rain lamps, reflections, camera presets (`VIEWS`), all per-frame animation, command line (`--view`, `--capture`, `--wait`) |
| `scripts/konbini_kit.gd` | The geometry kit: primitives merged into a few meshes |
| `scripts/konbini_exterior.gd` | Base, roads, lot, shop shell, sign, street furniture, poles and wires, signals |
| `scripts/konbini_interior.gd` | Everything inside the shop (render layer 2) |
| `scripts/konbini_thai.gd` | Pieces only the Thai version has; called from the exterior builder |
| `scripts/konbini_viaduct.gd` | A whole block of its own (`layout = "viaduct"`): brick railway arches with four shops, a passing train, street, back lane, its own snow, lights, shelters and camera views |
| `scripts/konbini_snow.gd` | Snow lying on everything when `weather_kind = "snow"` |
| `scripts/konbini_beach.gd` | The beach block (`layout = "beach"`), first daytime scene; its sea is `shaders/konbini_sea.gdshader` (`shore()` in both must match) |
| `scenes/beach_diorama.tscn` | The beach: `layout = "beach"`, `time_of_day = "day"`, `weather_kind = "clear"` |
| `scenes/ramen_diorama.tscn` | The viaduct block on a snowy night: `layout = "viaduct"`, `weather_kind = "snow"` |
| `scripts/konbini_weather.gd` | Rain, splash rings, drips, puddles, gutter flow, ground reflections |
| `scripts/konbini_camera.gd` | Orbit camera: mouse, touch, keys, eased, clamped |
| `shaders/konbini_*.gdshader` | toon, outline, rain, splash, drip, puddle, reflection, glass, steam, sky |
| `tools/package_konbini.py` | Stages a standalone project (`--thai` makes the Thai scene the main scene) |
| `tools/test_konbini_diorama.gd` | No UI nodes, camera limits, touch, door, signals, Thai countdown |

## The base and its coordinates

Metres. The base is X, Z in -9..9; the wooden plinth sits below Y = 0. Road A runs along X at Z 5.2..8.6,
road B along Z at X 5.2..8.6; they meet at the far corner. Roads are at Y 0, the lot and sidewalks at
`LOT` = 0.12, the shop floor at 0.2. The shop is X -5.0..2.4, Z -5.2..0.0 (front faces +Z, door at
X -0.1..1.6), the awning reaches Z 1.4, the alley is X -6.6..-5.0 and the neighbour building X -9..-6.75.
Japan and Thailand both drive on the left, which decides signal and lane layout.

## The kit (konbini_kit.gd)

Call `k.box`, `k.slab(from, to)`, `k.cyl`, `k.rod(a, b)`, `k.ball`, `k.prism`, `k.torus`, `k.quad` and
`k.text` (a Label3D). Every primitive is appended to a batch keyed by material, render layer, parent node and
a 6 m grid cell; `k.finish()` turns each batch into one MeshInstance3D. About 3,300 primitives become about
80 meshes, so adding detail is cheap.

Per vertex: `COLOR.rgb` albedo and `COLOR.a` emission; `UV2.x` wet gloss and `UV2.y` indoor fill light;
`CUSTOM0.xyz` the direction the ink line pushes the vertex and `CUSTOM0.w` the line weight. Options on every
primitive: `rot` (degrees) or `basis`, `emit`, `gloss`, `lit`, `line` (0 = no ink line, about 0.3 for small
things and wires), `mat` (a named material, see below), `node` (merge into a moving node such as a door
panel), `indoor` (layer 2).

Named materials (`k.material(name, pattern, params)`) are separate ShaderMaterials on the same toon shader.
Use one when something must be animated as a group (`sign_band`, `pole_sign`, each signal lens animates
`emit_energy`) or needs a surface pattern: 1 pavers, 2 floor tiles, 3 asphalt, 4 wood, 5 concrete blocks,
6 siding (also used for the roller shutter).

## Switches and new blocks

`layout` picks the whole block: `corner` (the konbini street corner, which `country` turns Thai), `viaduct`
or `beach`. `time_of_day` (night, day) switches moon and lamps for a sun with shadows (merged meshes cast
shadows when `kit.shadows` is on) and the sky shader's day mode with clouds. `weather_kind` (rain, snow,
clear) changes the weather layer. Daylight is easy to overexpose: ambient about 0.55, sun about 1.0,
exposure 0.85, very light fog. A new request gets a new layout file like
`konbini_viaduct.gd`, never a reskin of an old one. A layout file provides `build(kit, scene)` (it may reuse
the street helpers of `konbini_exterior.gd`: plinth, poles, wires, rails, bikes, signs), `lights(scene)`,
`reflections(scene)`, `animate(scene, clock)` for its own loops, and the constants `VIEWS` (camera presets),
`SHELTERS` (roofs the rain or snow skips) and `RAIN_LAMPS`. It registers door panels (meta `travel`),
swaying nodes, and the animated materials `sign_band` and `pole_sign` with lights named `SignBand` and
`PoleSign`. Things that move past the base edge (a train) use a material with `clip_x` so they are cut
cleanly at the edge.
Japanese text uses `"jp": true` on `k.text` (Noto Sans JP subset); add new characters by re-subsetting the
font with fontTools from the full Noto Sans JP on raw.githubusercontent.com.

## Adding a variant (how the Thai version was done)

1. `@export_enum(...) var country` in `konbini_diorama.gd`; a new `.tscn` that sets it.
2. In each builder, read `thai = diorama.country == "thailand"` once, translate strings with `_t(japan, thai)`,
   and branch only where geometry differs.
3. Put the variant's own props in their own file (`konbini_thai.gd`) as static functions taking the kit.
4. Variant-only lights, reflections and rain lamps go in `konbini_diorama.gd` behind the same check.
5. Extend the test to build the variant and check its own moving parts; add its renders to the workflow.

## Moving parts

`_process` in `konbini_diorama.gd` runs the door (sliding panels on a 9 s cycle), sign hum and pole-sign
stutter (material `emit_energy` plus the matching light's energy), the traffic cycle (lens materials, the
traffic light's colour, its two reflections, the rain lamp colour and the Thai countdown labels) and turns the
reflection strips toward the camera. Rain, ripples, drips, glass rivulets and steam are shader-only.
