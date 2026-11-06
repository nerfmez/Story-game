---
name: godot-diorama-scene
description: Art direction and build method for cel-shaded "3D that looks 2D" anime diorama scenes in Godot 4.3 (the rainy-night konbini corner in this repo, Japan and Thailand versions), and how to publish them as a playable web link. It turns a one-line request ("ร้านราเมนตอนหิมะตก", "a small station at dusk") into a full art-direction brief and then into a scene of the same quality as the konbini. Use it whenever the user wants a new diorama, miniature or scene in this style for any subject, or to change one that exists: another country or city, another shop or building, time of day, weather (rain, snow, fog, clear), season, mood, colours, props, signs or text, camera views; also for "make it look more anime", "make it darker/warmer", "send me a link to play it", or adding an animated detail such as a door, sign flicker, traffic light or steam. Use it even when the user only describes the atmosphere they want and never says "diorama".
---

# Godot cel-shaded diorama scenes

The konbini diorama (`scenes/konbini_diorama.tscn`, `scenes/konbini_diorama_thai.tscn`) is built entirely
from code when the scene loads: no model files, no textures. That is what makes it cheap to change: a new
country, a new prop or a different night is an edit to a builder script, then a render to check it.

Start with `references/art-direction.md`: it is the reason the konbini looks the way it does, and the user
expects that quality from short requests. Read `references/architecture.md` before editing code. Read `references/atmosphere.md` when the request is about
mood, light, weather, time of day or a regional version. Read `references/pitfalls.md` before the first render of
a session: it lists the mistakes that already happened once.

## Plan first, then ask, then build

There is no template layout. The konbini corner (two roads along the edges, poles, a neighbour house) is one
plan among many, and reusing it for a new subject is a reskin, which the user rejected. Each request gets a
new plan: no road at all, a road through the middle, a lane, a roundabout, a canal with a bridge, a slope with
steps, a plaza, whatever suits the subject and the brief. Every element (ground, paths, buildings, props,
lights) is placed fresh for that plan.

Examples the user gives ("no road, a road through the middle, a roundabout, anything") show how free the
layout is; they are not a menu. Never turn them into the options. Derive each plan from the subject itself:
where would this place really be, what makes it special, what gives a strong composition and its own motion.

Before writing any scene code:

1. Write the brief (below) and make 2 or 3 genuinely different plans of the 18 × 18 m base. Flat top-down
   diagrams are hard for the user to picture: show each plan as a quick 3D blockout render (plain boxes in
   the scene's palette from the default three-quarter camera, labelled), with a small top-down map beside it.
   `scripts/blockout.gd` renders such a blockout from a small JSON plan (boxes, cylinders, water, labels);
   run it inside a staged project. Keep labels short and apart so they do not overlap.
   Mark what crosses each edge of the base (lane, road, canal, wall, nothing) so blocks can be joined later.
2. Send the image and ask the user to pick one and say what to cut or add. Wait for the answer; do not build
   on a plan the user has not chosen.
3. To extend an existing map, the new block's edge must carry the same things at the same places as the
   neighbour's edge it touches; read the neighbour's plan, draw the new one to match, and show both side by side.

## The loop

Every change goes through the same loop. Do not skip the render: the look of this scene cannot be judged from
code, and the first render after a change is usually wrong in some small way.

1. **Write the brief.** However short the request, expand it into the full art-direction brief in
   `references/art-direction.md` (format, focal point, time and weather, palette, 15 to 25 exterior objects,
   interior objects, signs of life, 6 to 10 motions, a mood sentence) and show the user a compact version.
   For a region or theme, list what makes a real street there recognisable and what to remove because it
   belongs to the old place. Ask only if the place or mood is genuinely unclear; otherwise decide, show the
   brief and the plans, and build once the user has chosen. `references/example-brief.md` is the request that
   produced the konbini: match its depth.
   A different subject (not a konbini) gets its own builder scripts made the same way, reusing the kit,
   shaders, weather and camera.
2. **Edit the builders.** Shared geometry lives in the exterior and interior builders; anything specific to a
   variant goes in its own builder file and is switched by the `country` property (see architecture.md).
   Keep the existing version working: add a variant, do not overwrite the original unless the user asks.
3. **Stage, import, test.** `python3 tools/package_konbini.py [--thai] --output <dir>` stages a small
   standalone project; import it with `godot --headless --editor --path <project> --import --quit`, then run
   `tools/test_konbini_diorama.gd` under `xvfb-run` (commands in `docs/konbini-diorama/README.md`).
   A parse error shows up at the import step.
4. **Render and look.** Capture several presets (`-- --view=N --capture PATH`; 0 overview, 1 windows, 2 top,
   3 alley, 4 door, 5 corner) with `LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24"`, then look at
   each image yourself. Check: is the mood right, does anything float or intersect, is text readable, are
   reflections streaks rather than blobs, is the interior visible and warm, does the new thing read at the
   overview distance. Fix and render again; two or three rounds is normal.
5. **Check you did not break the other version.** Render the other variant's overview and compare with its
   picture in `docs/konbini-diorama/` (a mean pixel difference of a few units is just rain moving).
6. **Ship.** Update `docs/konbini-diorama/README.md` and its preview images, commit, push, and keep CI
   (`.github/workflows/konbini-preview.yml`) green. If the user wants to play it, build the web link with
   `scripts/export_web.py` and publish it (below).

## How to think about a scene

- **One focal point, warm against cool.** The shop is the light source of the whole composition: bright, warm,
  full of colourful product. Everything outside is cool, wet and dimmer. When a change adds light, ask whether
  it competes with the shop. Fill lights that only spill (window glow, sign glow) carry `fill = true` so they
  make no specular highlight on the wet ground.
- **Real things, simplified.** Every prop is a few boxes, cylinders and prisms with an ink line. Get the
  silhouette and the colour right and skip detail that will not read at 20 m. A street is recognised by its
  signature items (a red-and-white kerb, a vertical signal with a countdown, a tangle of cables), not by
  modelling one object perfectly.
- **Lived in, but nobody there.** Small traces of people: a forgotten coffee, a helmet on a scooter seat,
  notices on a board, a lit upstairs window. No characters unless the user asks.
- **Small loops make it alive.** Rain, drips, ripples, a door, a flickering sign, a signal cycle, steam. New
  motion belongs in `_process` of `konbini_diorama.gd` or in a shader driven by `TIME`; keep each loop subtle.
- **Text belongs to the place.** Use the local script with the project font (Sarabun covers Latin and Thai, not
  Japanese or Chinese). Invent shop names; never copy a real chain's name, logo or colour scheme.
- **The user's taste wins.** If they remove something ("no food cart"), remove it cleanly with its light,
  reflection, rain shelter and docs mention, and do not bring it back in another form.

## Publishing a playable link

```
python3 .claude/skills/godot-diorama-scene/scripts/export_web.py --godot <godot-4.3-binary> \
    --out <scratchpad>/web [--thai] --title "Rainy Night Konbini"
```

It stages the project (`--thai` or `--ramen` picks the scene), fetches only the web template it needs (range
requests into the 1 GB archive), exports, gzips the engine to `engine.gz.wasm`, renames the pack to
`scene.pck.wasm` and writes `index.html`, a complete page that undoes both in the browser. Publish every file
in `<out>/publish` with whichever artifact tool the session has: `publish_files` (each file `as` its own name)
or the Artifact tool (`index.html` as the page, the rest in `files`, `root` set to the publish folder). The
files must sit under the working directory or the scratchpad. To update a link, republish to the same
artifact. Test it first with a local `python3 -m http.server`
and Playwright (Chromium at `/opt/pw-browsers/chromium`, flags `--use-gl=angle --use-angle=swiftshader`): the
console should print the Godot and WebGL lines and the screenshot should show the scene.
