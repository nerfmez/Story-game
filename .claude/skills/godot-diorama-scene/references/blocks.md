# Blocks that join: neighbours and one-piece dioramas

The user builds a world block by block ("make a block to the left of that one") and wants it to work two
ways: each block stands alone on its own plinth, and blocks can be joined into one diorama with no seam
anywhere, not even in the sea. The beach (`scripts/konbini_beach.gd`), the headland to its left
(`scripts/konbini_headland.gd`) and the two joined (`scripts/konbini_coast.gd`, `scenes/coast_diorama.tscn`)
are the worked example. Follow it for the next block.

## 1. Plan the new block from its neighbour's edge

- Read the neighbour's edge first: road and wall positions, ground heights, waterline, what stops at the
  edge and what runs on. Write the shared edge into the plan and the 3D blockout (`blockout.gd`) so the
  user sees both sides line up. Plans still come from the subject, not from a template.
- Tell the user what the back of each block is (a road, a railway, nothing) if it could be misread: the
  coast road's white guard rail was taken for a railway once. Ask before changing a block they approved.

## 2. Make the seam exact, not approximate

- Place blocks on an 18 m grid. A block knows its offset from its neighbour (`OFFSET := -18.0` for the
  headland) and evaluates the neighbour's own functions with it: `shore(x) = Beach.shore(x + OFFSET)`,
  and the sand at the seam comes from `Beach.ground_u` and `Beach._sand_color`. Never copy numbers that
  only look the same.
- Everything that runs across the edge (road, kerb, wall, rail, centre line) uses the same heights,
  widths and colours as the neighbour.
- World-space shaders take the offset as a uniform: `shore_offset` in the beach include (waterline, wave
  timing, swash), the `rocks` list for the surf, and the tunnel cut-out in the toon shader.
- Add a test that compares ground heights across the seam at several z values
  (`tools/test_konbini_diorama.gd`). It caught a rock shelf whose fall-off lifted the seabed far away.
- Keep the left or right edge of the new block open for a next block: cut through what continues (hill,
  tunnel, sea) as a clean section instead of rounding it off.

## 3. Join blocks into one diorama

`scripts/konbini_coast.gd` does it without duplicating any block code:

1. **One long plinth**, made in the same wood and brass, with one name plate.
2. **Shared strips laid once along the whole length**: road bed, asphalt, centre line, sea wall and rail.
   Two road slabs that meet each draw an ink outline at their ends, and that line shows the seam.
3. **Each block built by its own builder in `joined` mode**, under a `Node3D` shifted to its half (x = -9
   and +9 for two blocks). In joined mode a block skips its plinth, its road and the cut faces on the seam
   side, and builds its props as usual. Its own `Kit` is made on the shifted node (`Kit.new(node)`,
   `shadows = true`, `finish()` after the build).
4. **Move added nodes**: block builders add some nodes straight to the diorama (sea props, trees, flags,
   steam, gulls). Record the diorama's children before the build, then `reparent(node, false)` every new
   one, so it keeps its local placement and lands in the right half.
5. **One sea and one swash across the whole front**, with `shore_offset` set so both halves get the same
   waterline (here `Beach.shore(x - 9)` for both) and the rocks of all blocks in one list (world
   coordinates, at most 10). Two sea planes, even if they match, are a risk; one plane cannot have a seam.
6. **Anything strung along the coast is one object**: the swimming floats are one line from end to end
   (`Beach.float_line`), not one line per block.
7. **Shift the remaining world-space inputs**: `block_x` in the scene meta goes to the tunnel cut-out.
   Shaders that need a local centre (the tide pool) use model-space positions (`VERTEX`), so they work
   wherever the block sits.
8. **Camera**: widen the rig's `pan_limit` and `max_distance` for the longer plinth, and give the joined
   scene its own `VIEWS`, including one aimed at the seam.
9. **Wiring**: a layout name, a scene, `--coast`-style flags in `tools/package_konbini.py` and
   `export_web.py`, a CI render step and a test that checks there is exactly one sea surface.

## 4. Check it

- Render the overview, a view aimed right at the seam, and the top view. Look along the sand, the road, the
  wall and through the shallow water for any line, step or colour change.
- Open the single blocks again: joined mode must not change them.
