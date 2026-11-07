# Changing the mood

Change one group of knobs at a time and render after each: light, colour and weather interact, and a scene
that was right can turn flat with one ambient tweak.

## Where each knob lives

| Want | Change |
|---|---|
| Overall darkness | `ambient_light_energy` and `ambient_light_color` in `_environment()`; the Moon light's energy |
| Sky and horizon | `shaders/konbini_sky.gdshader` uniforms (top, horizon, low city glow) |
| Haze | `fog_density`, `fog_light_color` (keep `fog_sky_affect = 0` or the background turns into fog) |
| Bloom | `glow_intensity`, `glow_hdr_threshold`; emissive things above about 1.0 glow |
| Shop warmth | shop OmniLights (layer 2) energy and colour; `indoor_light` uniform and per-part `lit` in the interior |
| Light spilling outside | `WindowLeft/Right`, `SideWindow` fill lights and the window reflection strips |
| Cel banding | thresholds in `light()` of `konbini_toon.gdshader` (three bands: 0.3, 0.35, 0.35) |
| Ink lines | `width`, `ink`, `tint` in `konbini_outline.gdshader`; per primitive `line` |
| Wetness | `gloss` on surfaces (roads about 0.85); `sky_sheen` in the toon shader; puddle list in the weather |
| Rain amount and angle | instance count, `speed`, `wind`, `strength` in the rain shader setup |
| Reflections | `add_reflection(base, colour, width, height, energy, sharpness)`; they peak at the light's mirror point |

## Recipes

- **Clear night, no rain:** remove `Rain`, `Splashes`, `Drips`, `DripRings`; set road `gloss` to about 0.2;
  drop puddles and reflection strips (or keep a few faint ones under lamps); set glass `rain` to 0; lift the
  moon a little and add stars to the sky shader.
- **Snow:** built: `weather_kind = "snow"` turns the rain into round drifting flakes (`snow` uniform in the
  rain shader), skips splashes, drips, puddles and gutters, keeps only road reflections, raises and cools the
  ambient, thickens the fog, and `konbini_snow.gd` lays the snow. Snow takes warm light easily: keep window
  spill lights under about 1.0 or the snow turns pink. Slush on roads must be broken lumps, not bands, or it
  reads as road paint.
- **Dusk:** sky gradient orange to violet, ambient warm and higher, shop lights already on but weaker,
  street lamp off or just starting; reflections short and faint.
- **Late, lonely:** fewer lit windows next door, darker ambient, one lamp flickering, door cycle slower,
  traffic signal on flashing amber.
- **Another country:** list the signature street items first (see SKILL.md), then follow the variant recipe in
  architecture.md. Thailand needed: Thai text, red-and-white kerb, octagon stop sign, vertical signals with a
  countdown, cable bundles, scooters, a drinking-water machine, a shophouse with a shutter, an ATM inside, a
  bao steamer instead of oden, cigarettes behind closed doors.

## Camera presets

`VIEWS` in `konbini_diorama.gd`: look-at point, yaw (0 is from +Z, 90 from +X), pitch, distance. Keep view 0
as the three-quarter overview with the far traffic light visible, and keep one view straight into the windows
so the interior can be checked. A new important area gets its own preset so the CI render shows it.

## A clear summer day: what moves instead of rain

Rain and snow fill the whole frame with motion; a clear day needs its own layer, or it looks frozen.
`scripts/konbini_summer.gd` is turned on for any `time_of_day = "day"` with `weather_kind = "clear"` and
placed by the layout's `SUMMER` dictionary (area, heat ribbons, dragonfly spots):

- **Cloud shadows** (the strongest one): soft blobs several metres across drifting over everything. One
  include, `shaders/konbini_clouds.gdshaderinc`, with a global shader uniform `cloud_shadow` (declared under
  `[shader_globals]` in project.godot and the packaged project) that the toon shader reads in `light()`
  for the sun, and the painted shaders (sea, foliage, bark, swash) use to step down a tone. Every new lit
  shader should include it.
- **Heat haze**: standing ribbons over the road and hot sand that refract the screen a little, fading to
  nothing at their edges.
- **Motes**: a MultiMesh of soft additive dots drifting and twinkling in the sun.
- **Dragonflies**: hover, turn and dart every few seconds, with shimmering wings.
- **Sound**: synthesised live in an `AudioStreamGenerator` (no sound files). Cicadas are band-limited
  noise chopped by a fast buzz and sung in swelling phrases; near the sea, a low rush swells with each wave
  on the sea shader's 7 s beat, with a hiss of foam. In the browser, sound starts after the first touch.
