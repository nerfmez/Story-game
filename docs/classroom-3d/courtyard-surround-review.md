# Expanded classroom window scenery

Base: Site v7, source `b571b8a5639dd25b7c0f9ffafca7b9028c174126`.
Reviewed 2026-10-20. Exact exported PCK SHA-256: `cd46d4d14aba4f6b76999c543486e01cf5a28e3db52883384f8a6ac6835f8be7`.

## Change

The former 38 × 15.2 m painted rectangle at x = -16 could be looked past from
a window's edge or when tilting down. It is replaced by a full spherical
background using a newly painted 2:1 panorama:
`godot/assets/classroom/courtyard-surround.png` (1774 × 887).

Built-in imagegen continued the approved inner-courtyard visual language around
the viewing sphere: cream Thai school wings, blue roofs, connected tropical
trees, wet paving below and pixel clouds above. The generated size is 1774 × 887,
not the larger size requested in the [prompt](courtyard-surround-prompt.txt).
Earlier images remain as references. This is an expanded illustration, not
recovered pixels outside the previous crop.

A PanoramaSkyMaterial fills every background viewing ray without finite-card
edges. Nearest panorama sampling keeps the pixel art visible. Ambient colour,
energy, lights, classroom geometry, camera controls and movement bounds are
unchanged. The obsolete scenic card is removed; the scene is now 1,147 mesh
parts / 211 render instances, plus the original labels.

## Actual artifact review

Native Godot 4.3 OpenGL Compatibility captures of both the source and the exact
exported PCK. Review script: `godot/tools/review_window_coverage.gd`.

Thirteen views were inspected: room presets; central outside preset; glancing
left/right views from both ends of the four-window wall; looking up/down; two
diagonal downward views; and the permitted ±63° pitch extremes. The sky, trees,
buildings and paving continue through the visible apertures. No uncovered
background, finite card edge or missing texture was observed in these views.
Window jambs, curtains, sill and ceiling correctly occlude the background.

Evidence files use the `surround-` prefix in this folder. The backdrop is an
infinite-distance illustrated panorama. It has no independent near-tree/building
parallax during lateral camera movement, and its architectural perspective is
illustrated rather than a reconstructed 3D campus.

Native rendering completes with no script/shader errors, only the usual
unsupported VSync warning from the software driver. Scene/readiness and
panorama-coverage configuration checks pass. Godot Web export and lossless
engine reconstruction pass; all hosted assets are below 25 MiB.
Headless dummy-renderer cleanup emits the existing mesh_get_surface_count
warnings. Browser/mobile playback and a physical Android device were unavailable.

Decision: ready within the checked classroom-window coverage scope. Static
native frames establish the visual evidence; no browser playback claim is made.
