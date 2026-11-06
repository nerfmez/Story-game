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
   fragment shader cuts each card into a 5- or 6-lobed leaf cluster (no texture needed). The silhouette
   becomes scalloped, and shadows on the ground get leafy edges for free. Leaf size is about 0.3 x tree
   size; density is about 34 per square metre for broadleaf and 60 for pine.
4. **Three flat tones with a hue shift.** Light is yellow-green, mid is green, shadow is blue-green, chosen by
   `dot(spherized normal, sun)`. Wobble the band edges with noise (brush strokes) and darken the underside
   of the crown. Each card gets a touch of random value, and each cut edge a darker band of the same hue
   (no black ink on foliage). The trunk and branches keep the toon kit's ink line.
5. **Glow.** Brighten the rim on the side facing away from the sun, as if light comes through the leaves.
   It is subtle.
6. **Wind.** Sway slowly in the vertex shader, more toward the top and the outside of the crown.

## Notes

- The shader is unshaded and takes `sun_dir` as a uniform (`Foliage.sun_from(sun.rotation_degrees)`).
  For a night scene, pass darker, bluer tones and a lower `brightness`.
- Cards move in the shader, so the mesh needs a grown `custom_aabb`, or it is culled at the screen edge.
- Recolour for the season with the four colour uniforms (cherry blossom: pinks with a mauve shadow; autumn:
  orange, red-brown, purple shadow).
- Cards cast shadows through the discard, so ground shadows come out leafy without extra work.
