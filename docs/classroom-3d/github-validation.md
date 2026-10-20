# GitHub classroom integration validation

Base PR13 head: `b1ff75c423895f3178b6f5adfff81d2e0d810e18`.
Scene SHA-256: `fcd248ce24cac45e9a1f1d390464d2978a833630aa647f5060fd356e613e58d8`.

The latest independent classroom source and active images were moved into the
existing root scene/assets layout. The story's project.godot, main scene, dialogue,
GitHub Pages workflow and PR12 building code are unchanged.

Godot 4.3 native validation of the packaged standalone project:
- Import and scene rebuild completed.
- Camera command/vertical limits/preset restoration checks pass.
- MultiMesh transforms, 211 render instances / 1,147 parts, rotating fan blades,
  fixed stems, clock-board clearance and spherical background configuration pass.
- Captured and inspected 13 window-coverage/room views using OpenGL Compatibility.
  No finite scenery-card edge or uncovered exterior was visible at the tested
  angles, including ±63-degree pitch and glancing views from either end.
- Font and texture import metadata are included in the standalone project.
- The final ZIP is checked for required resources and excludes .godot caches.

The existing GitHub Actions workflow now stages an isolated project, rebuilds
and tests it, captures four presets and the 13 coverage views, then zips the
exact staged/tested directory. It uploads PNGs and the ZIP as artifacts. It has
read-only contents permission and no Site or Pages publication step.

These local validations precede the remote Actions run. Native static images
establish visual inspection, not browser/mobile playback or measured performance.
Existing dummy-renderer mesh_get_surface_count cleanup warnings remain; native
rendering only reports unsupported VSync on the software driver.
