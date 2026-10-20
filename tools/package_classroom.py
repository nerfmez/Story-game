"""Package only the independent Godot 4.3 classroom, without the story game."""
from pathlib import Path
import argparse
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = '''config_version=5

[application]
config/name="Thai Classroom - 3D Pixel"
run/main_scene="res://scenes/classroom_3d_pixel.tscn"
config/features=PackedStringArray("4.3", "GL Compatibility")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/classroom")
    parser.add_argument("--zip-only", action="store_true", help="Archive an already staged and tested project without copying it again")
    args = parser.parse_args()
    target = args.output.resolve()
    target.mkdir(parents=True, exist_ok=True)
    project_dir = target / "Thai-Classroom-Godot43"
    project_dir.mkdir(exist_ok=True)
    if args.zip_only:
        if not (project_dir / "project.godot").is_file():
            parser.error("No staged classroom project to archive")
        write_archive(target, project_dir)
        return
    # This is a generated preview folder; do not archive retired character files.
    shutil.rmtree(project_dir)
    project_dir.mkdir()
    paths = [
        "scenes/classroom_3d_pixel.tscn",
        "scripts/classroom_pixel.gd",
        "scripts/classroom_students.gd",
        "tools/review_classroom_students.gd",
        "tools/test_classroom_students.gd",
        "tools/build_classroom_scene.gd",
        "tools/test_camera_input.gd",
        "tools/test_web_scene.gd",
        "tools/review_window_coverage.gd",
        "tools/review_outside.gd",
        "assets/fonts/Sarabun-Regular.ttf",
        "assets/fonts/Sarabun-Regular.ttf.import",
    ]
    paths += [str(path.relative_to(ROOT)) for path in (ROOT / "assets/classroom").rglob("*.png*") if path.name.endswith((".png", ".png.import"))]
    for name in paths:
        dest = project_dir / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, dest)
    font_license = ROOT / "assets/fonts/OFL.txt"
    if font_license.exists():
        shutil.copyfile(font_license, project_dir / "assets/fonts/OFL.txt")
    for source in list((ROOT / "docs/classroom-3d").glob("surround-*.png")) + list((ROOT / "docs/classroom-3d").glob("students-*.png")):
        shutil.copyfile(source, project_dir / source.name)
    for name in ["courtyard-surround-review.md", "courtyard-surround-prompt.txt", "seated-students.md", "student-v2-prompts.json", "students-review.md"]:
        shutil.copyfile(ROOT / "docs/classroom-3d" / name, project_dir / name)
    (project_dir / "project.godot").write_text(PROJECT, encoding="utf-8")
    shutil.copyfile(ROOT / "docs/classroom-3d/README.md", project_dir / "README.md")
    write_archive(target, project_dir)


def write_archive(target, project_dir):
    with zipfile.ZipFile(target / "Thai-Classroom-Godot43.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(project_dir.rglob("*")):
            if path.is_file() and ".godot" not in path.parts:
                archive.write(path, path.relative_to(target))
    print(target / "Thai-Classroom-Godot43.zip")


if __name__ == "__main__":
    main()
