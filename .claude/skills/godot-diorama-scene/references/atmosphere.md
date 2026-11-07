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

Rain and snow fill the frame with motion; a clear day needs its own layer. `scripts/konbini_summer.gd`
turns on for any `time_of_day = "day"` with `weather_kind = "clear"`, placed by the layout's `SUMMER`
dictionary:

- **Heat haze**: standing ribbons over the road and hot sand that refract the screen a little and fade to
  nothing at their edges (`shaders/konbini_heat.gdshader`).
- **Sound**: free-licensed recordings of the sea and of cicadas from Wikimedia Commons, looping
  (`assets/audio/sea_waves.ogg`, `cicadas.ogg`, credits in `assets/audio/CREDITS-diorama.md`). The user
  could not hear the synthesised waves (a rumble around 100 Hz is lost on tablet speakers) and asked for
  real recordings. Keep the licence and author in the credits file for every sound added; CC0 or CC BY
  are easiest. Commons rate-limits shared IPs: use a descriptive User-Agent and back off; the `transcoded`
  MP3/OGG copies download when the original is refused. In a browser, sound starts after the first touch.
  On iPad/iPhone, Web Audio is muted by the silent switch: the page made by `export_web.py` sets
  `navigator.audioSession.type = "playback"` and unlocks audio on every touch (resume the contexts, play a
  moment of silence through an `<audio>` element). The user heard nothing until that was in place.
- **Motes**: soft additive specks of dust and pollen drifting and twinkling in the sun (a MultiMesh,
  `shaders/konbini_motes.gdshader`). The user wants these.
- The user removed these, do not bring them back: drifting cloud shadows and dragonflies (insects).
  When the user asks to remove one thing, remove exactly that; I once took out the motes too and was told
  off for it.

## A painted backscene (forced perspective)

For a far view behind a diorama, do not model distance: stand thin painted flats on a shelf added to the
back of the plinth (`scripts/konbini_backdrop.gd`, `shaders/konbini_flat.gdshader`), like a stage or a model
railway backscene. The backs are plain plywood with struts, so the trick shows from the side; the user
liked that concept. Two versions were rejected before this one ("quality not there, doesn't match the
style", then "still not it, research how people do it"). What people actually do, and what the approved
version follows:

- **Few layers, value grouping.** Far peaks, mountains, wooded hills: each a simple silhouette in two tones
  only (lit and shade from the scene's sun), not lots of small painted detail. Busy flats (painted towns,
  stacked puffs, gullies everywhere) read as noise.
- **Atmospheric perspective.** The farther the layer, the lower its contrast, until the two tones nearly
  meet; both slide toward the sky colour, shadows toward blue. Use a haze/mist colour a little brighter and
  warmer than the sky, not the sky colour itself.
- **Layered valley mist.** Every range fades into a bright band of mist at its foot, which separates the
  layers and hides each board's bottom edge.
- **No ink on far things.** The skyline is the drawing; a faint lighter rim catches the sun on lit ridges.
  Rounded peaks of varied width with small notches; straight cones look fake.
- **Blend 3D into 2D at the join.** A row of real low-relief objects (small anime trees, house fronts 0.3 m
  deep) stands in front of the flats on the shelf and hides where the painting meets the model, as model
  railway layouts do with low-relief buildings and trees.
- **Let the real sky be the sky** (no sky board with an edge). Summer clouds can be flats hung on rods:
  puffs on a flat base, bright on top, blue-grey underneath.
- Keep the horizon roughly at the eye height of the main camera views.
