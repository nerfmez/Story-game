# Sea and water: the recipe the user signed off on

The beach block (`scenes/beach_diorama.tscn`) took eight rounds of feedback before the user called the sea
perfect. This file is the result. Reuse it for any coast, lake shore, river bank or harbour, and read the
"what the user rejected" list before changing anything: each item there was tried and refused.

Code: `shaders/konbini_beach.gdshaderinc` (shared shape and timing), `shaders/konbini_sea.gdshader`
(the water), `shaders/konbini_swash.gdshader` (foam fringe and wet sand on the beach),
`scripts/konbini_beach.gd` (`ground_u`, `shore`, `_ground`, `_sea`, `_sand_color`) and `kit.grid()` in
`scripts/konbini_kit.gd`.

## The principle

Model the shore as it really is, then let the edge happen by itself. A real waterline is not a line anyone
draws: it is where a moving water surface meets sand that slopes down under it, seen through water that is
clear where it is shallow. Every round that drew the edge (a foam band, a darker strip, a flat slab beside a
flat plane) was rejected.

## Building blocks

1. **One shared definition of the shore.** A shader include holds `shore(x)` (the still-water line, a sum
   of two sines so it curves), `ground_u(u)` (sand height at `u` metres seaward of that line), `SEA_Y`,
   `SAND_Y`, `PERIOD`, `SPEED`, `wave_lag(x)` and `swash_front()`. Mirror `shore`, `ground_u` and
   `wave_lag` in GDScript so props can sit on the slope. Packaging must copy `*.gdshaderinc`.
2. **Sand that slopes under the water.** The beach profile is flat dry sand, then a gentle slope to the
   water (0.04 per metre), then a steeper shelf (0.1 per metre), then a slow fall to just above the plinth
   floor. Build it with `kit.grid()` (a vertex-coloured height field on the toon material, about 0.2 by
   0.15 m cells). Colour per vertex: dry sand, damp toward the water, wetter and slightly green under it.
   Close the sides and front of the base with thin cut slices: sand from the floor up to the ground, blue
   from the ground up to the still-water level. In `_base()`, skip the shared soil top for this layout, or
   it hides the seabed.
3. **Clear water.** The sea is a subdivided plane (about 0.2 by 0.15 m) with a transparent shader:
   `ALPHA` comes from water depth over the sand, from about 0.05 at zero depth to about 0.9 at 0.3 m. The
   colour goes from turquoise to deep blue with distance from shore. Where the surface dips below the
   sand, the opaque height field hides it, and that intersection is the waterline.
4. **Waves roll in.** A crest travels toward the beach every `PERIOD` (7 s) at `SPEED` (1.5 m/s). It grows
   as the water shallows, turns white near the top as it breaks, and collapses before the swash zone. The
   along-shore timing offset `wave_lag` must be small and wiggly (about ±0.2 s): a large smooth offset makes
   the breaker slide sideways along the beach.
5. **Swash on the slope.** Near the shore the surface becomes a thin sheet whose edge sits on the sand at
   the swash front. It climbs quickly (about 1.4 s), slows, then draws back below the still-water line.
   The sheet slopes down toward the sea more gently than the sand does, so it always meets it.
6. **Broken foam, never solid lines.**
   - At the swash front, a lacy fringe (noise with holes) that thins as the water slows.
   - Where the crest broke, a foam field that spreads and then breaks into patches: a noise threshold
     rising with the time since the crest passed, gone after about 3 s.
7. **Wet sand that spreads and dries.** It is drawn by an unshaded overlay that follows the ground, drawn
   before the sea (`render_priority -1`). It darkens only as far as this wave has run so far, and dries from
   the top down. It must end on the beach, never inside the sea: its straight edge shows through clear
   water.
8. **Light on the shallows (caustics).** A net of thin cel lines from Voronoi cell borders (F2 minus F1),
   warped by noise.
   - About 0.9 m cells, one layer, faint (about 0.28 colour mix, 0.2 alpha), slightly green-blue.
   - Slow: points wander at `t * 0.3`.
   - Only past the swash zone, roughly 0.9 to 4 m from shore, and away from any foam.
   - Shown in patches that form and fade in turn: two noise fields morph into each other, with a phase
     that varies from place to place.
9. **Sun glints.** Irregular specks from thresholded noise (`smoothstep(0.92, 0.95)`), only on the open
   water. They do not scroll. The field morphs between two noise samples with a spatially varying phase
   (about 11 s per cycle), and the threshold is rescaled where the two are mixed so specks stay crisp.
10. **Rocks in the surf.**
    - Their waterline outline is a few ellipses (`rock_dist`).
    - A thin foam line always laps at their foot, its width wavering with angle, time and noise.
    - When a crest reaches them (time since the crest passed, the same clock as the waves), the surface
      heaps up against them and drains off, and white water spreads out from them and breaks into
      patches.
    - No spray particles: the user removed them.

## Checking it

- Render the same view at five or six `--wait` values across one wave period, and crop the shore or the
  rocks into a contact sheet. Frames that look alike mean the sea is not moving the way it should.
- Look in particular for:
  - a straight line anywhere in the water (an overlay or a mesh ending);
  - a jump between the last frame of one wave and the first of the next;
  - the breaker moving sideways;
  - texture that is too dense at the overview distance.
- Motion speed cannot be judged from stills. Say so, and ask the user to check the link.

## What the user rejected (do not do these again)

- A fixed white foam band at the edge of the beach: "it stays in the same place".
- A flat sand slab beside a flat sea plane, even with animated foam: "a waterline like a drawing".
- A wet-sand sheet reaching under the sea: its straight edge showed through the water.
- A breaker that swept from right to left along the shore. Waves come forward and dissolve into foam.
- Restarting the swash at a new level each wave: "it jumps when the wet sand first rises".
- A dense caustic net, a net inside the swash zone, a net that moved fast: "too busy, hurts the eyes".
- Glints as many identical dashes that blinked quickly: "too many, all the same shape and size, too fast".
  The original specks were right; they only needed to form and dissolve.
- Spray droplets off the rocks.
