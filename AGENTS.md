# Notes for AI agents working on this repository (ChatGPT, Codex, Claude and others)

This repository holds a small Godot 4.3 story game and, alongside it, a series of **cel-shaded anime
dioramas** built entirely from code: a rainy-night konbini corner (Japan and Thailand), a ramen shop under
a railway viaduct in the snow, and a summer **coast**: a beach and a lighthouse headland joined into one
diorama, with a painted backdrop behind it. The work is on branch `ccr-f1b5a560-y1h5ug` (pull request #17).
The owner writes in Thai; answer in Thai.

## Read these first

The knowledge is in the Claude skill folder, but it is plain Markdown and applies to any agent:

| File | What it holds |
|---|---|
| `.claude/skills/godot-diorama-scene/SKILL.md` | the working loop: plan, build, render, look, fix, ship |
| `.../references/art-direction.md` | the look the owner expects: focal point, warm against cool, real things simplified |
| `.../references/architecture.md` | how the code is laid out (kit, builders, shaders, layouts) |
| `.../references/atmosphere.md` | light, weather, the clear summer day, and **the painted backdrop** |
| `.../references/water.md` | the approved sea: sloped sand under clear water, waves, swash, foam |
| `.../references/foliage.md` | the approved anime trees: clumps, leaf cards, four tones, smooth trunks |
| `.../references/blocks.md` | building a block next to another and joining blocks with no seam |
| `.../references/pitfalls.md` | every mistake already made once; read before rendering |
| `docs/konbini-diorama/README.md` | what each scene contains, how to run, test and render it |

Each reference lists what the owner **rejected** along the way. Do not bring those back.

## The job most likely to be handed to you: paint the backdrop

Behind the coast diorama, thin boards stand on a shelf like a stage or model-railway backscene
(`scripts/konbini_backdrop.gd`). Each board is painted by a shader (`shaders/konbini_flat.gdshader`) unless a
**painted image** exists for it. Claude cannot make images; an agent that can should paint them:

1. Look at the reference renders in `docs/konbini-diorama/`: `coast-view-1.png` (the whole diorama),
   `backdrop-behind-shop.png` (the current backdrop up close), `foliage-demo.png` (the trees).
2. Follow `docs/konbini-diorama/chatgpt-backdrop-brief.md`: the style, the palette, and one prompt per
   layer. In short: Ghibli/Shinkai-style hand-painted anime background in poster colour, few simple shapes
   in two tones each, paler and bluer with distance, light from the **upper left**, mist at the foot of each
   range, no outlines, no people or text.
3. Save each image as a **PNG with a transparent sky**, 1536 x 1024, whose left and right edges join (it is
   repeated across the board), under exactly these names:

   | `assets/backdrop/far_peaks.png` | `mountains.png` | `hills.png` | `cloud.png` | `cloud_small.png` |
   |---|---|---|---|---|
   | distant peaks, very pale | mid mountains, blue-teal | near wooded hills, greens | tall summer cumulus | small cumulus |

4. Commit them to the branch. The game picks them up by itself (`PAINTED` in `konbini_backdrop.gd`); a layer
   with no image keeps the shader painting. Nothing else needs to change. Godot creates the `.import`
   files on the next import.

## If you change code

- Godot **4.3**, Compatibility renderer. GDScript in this project needs explicit types where the value is
  untyped (`var x: Color = array[i]`), or the scene fails to parse.
- Stage, import, test and render (commands in `docs/konbini-diorama/README.md`):
  `python3 tools/package_konbini.py --coast --output <dir>`, then
  `godot --headless --editor --path <project> --import --quit`, then run `tools/test_konbini_diorama.gd`,
  and capture views with `-- --view=N --capture <png>`. Look at every render before you commit.
- Keep every scene working: the test builds all of them.
- The owner judges by eye, in the playable web link, on an iPad. Small, visible improvements beat big
  rewrites; when they reject something, remove exactly that and record why in the references.
