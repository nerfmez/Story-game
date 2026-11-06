# Anime trees: simple but pretty

How to make trees and bushes that look like painted anime backgrounds without modelling leaves. The code is
`scripts/konbini_foliage.gd` (`crown`, `broadleaf`, `pine`, `sun_from`) and
`shaders/konbini_foliage.gdshader`. Check the look on its own with `tools/konbini_foliage_demo.gd`; the
result is `docs/konbini-diorama/foliage-demo.png`.

## What makes a tree read as anime

Background painters block a tree as a few big masses (clumps) with one light / shadow split across the whole
crown. Each mass then gets a bumpy silhouette of leaf clusters, and the lit side is warm while the shadow is
cool. Detail inside the masses is a hint, not a leaf count. A tree made of spheres or one stick through some
balls (the first beach pines) reads as a toy, not as anime.

## The technique (from the stylized-foliage pipelines used in Blender, Unity and Godot)

1. **Clumps.** A crown is 4 to 7 ellipsoids: a big central mass and smaller ones around it, set at the tips of
   the limbs. A pine uses flattened pads instead (radii about 0.85 x 0.26 x 0.7).
2. **Spherized normals.** Ignore the real normals. Each normal points out from its clump centre, blended with
   the crown centre (`clump_mix` about 0.55 for broadleaf, 0.85 for pine pads, which should read as separate
   layers). This is the "normal transfer from a sphere" trick, and it makes the crown light up as one
   volume.
3. **Leaf cards.** Small quads scattered over each clump surface. All four vertices of a card share its
   centre, and the vertex shader spreads the corners in the camera plane, turned by a random angle. The
   fragment shader cuts each card into a
   ragged clump edge (`card_edge`): two bumps of random count, size and phase around the angle, a random
   squash, and on about half the cards one side bitten away. The user rejected identical 5-lobed stars on
   every card ("the same star repeated, a whole closed shape"): every card must differ, and many should
   be partial, so only a few bumps show at the crown edge. Leaf size is about 0.3 x tree
   size; density is about 34 per square metre for broadleaf and 60 for pine.
4. **Four flat tones with a hue shift.** Light is yellow-green, mid is green, shadow is blue-green, chosen by
   `dot(spherized normal, sun)`. On the lit side, each clump also gets its own brighter highlight cap from
   its own clump normal (`high_col`, with a noisy edge). With only one lit tone the user found the crown
   flat; the caps make the lit mass read as several rounded clumps. Wobble the band edges with noise (brush strokes) and darken the underside
   of the crown. Keep the lit tones flat: the user preferred them to cards with random values,
   whose shapes showed inside the mass. In the mid and shadow tones only, each cut edge gets a darker band
   of the same hue (no black ink on foliage). The trunk and branches keep the toon kit's ink line.
5. **Glow.** Brighten the rim on the side facing away from the sun, as if light comes through the leaves.
   It is subtle.
6. **Trunk and limbs** (`trunk`, `branch`, `limb`).
   - The trunk bends gently through a few points, tapering (the `top` ratio of each rod), with a round joint
     ball a hair fatter than the limbs at every bend, so it curves without kinks or cap seams.
   - The foot flares out, and 4 to 5 surface roots run out into the ground.
   - Add one knot and a few thin darker bark strokes.
   - Limbs rise and then reach out in two segments, each with a small twig, and end in a clump. Pine limbs
     dip and then lift toward their pad.
   - The bark is a warm brown (pine is greyer) with a little fill light (`lit` 0.3), so the part in the
     crown's shade stays a readable dark brown instead of black. The bark keeps the ink line.
7. **Wind.** Sway slowly in the vertex shader, more toward the top and the outside of the crown.

## Notes

- The shader is unshaded and takes `sun_dir` as a uniform (`Foliage.sun_from(sun.rotation_degrees)`).
  For a night scene, pass darker, bluer tones (all four colours) and a lower `brightness`.
- Cards move in the shader, so the mesh needs a grown `custom_aabb`, or it is culled at the screen edge.
- Recolour for the season with the four colour uniforms (cherry blossom: pinks with a mauve shadow; autumn:
  orange, red-brown, purple shadow).
- Cards cast shadows through the discard, so ground shadows come out leafy without extra work.
