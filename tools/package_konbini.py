"""Package only the rainy-night konbini diorama as its own Godot 4.3 project."""
from pathlib import Path
import argparse
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
NAME = "Konbini-Diorama-Godot43"
PROJECT = '''config_version=5

[application]
config/name="Konbini Diorama - Rainy Night"
run/main_scene="res://scenes/{scene}"
config/features=PackedStringArray("4.3", "GL Compatibility")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="disabled"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
limits/opengl/max_lights_per_object=16
anti_aliasing/quality/msaa_3d=2

'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/konbini")
    parser.add_argument("--thai", action="store_true", help="Open the Thai street corner instead of the Japanese one")
    parser.add_argument("--ramen", action="store_true", help="Open the ramen shop on a snowy night")
    parser.add_argument("--beach", action="store_true", help="Open the beach on a summer afternoon")
    parser.add_argument("--headland", action="store_true", help="Open the rocky headland with the lighthouse, left of the beach")
    parser.add_argument("--coast", action="store_true", help="Open the headland and the beach joined into one diorama")
    parser.add_argument("--zip-only", action="store_true", help="Archive an already staged and tested project without copying it again")
    args = parser.parse_args()
    target = args.output.resolve()
    project_dir = target / NAME
    project_dir.mkdir(parents=True, exist_ok=True)
    if args.zip_only:
        if not (project_dir / "project.godot").is_file():
            parser.error("No staged konbini project to archive")
        write_archive(target, project_dir)
        return
    paths = ["scenes/konbini_diorama.tscn", "scenes/konbini_diorama_thai.tscn", "scenes/ramen_diorama.tscn", "scenes/beach_diorama.tscn", "scenes/headland_diorama.tscn", "scenes/coast_diorama.tscn", "assets/fonts/NotoSansJP-Bold-subset.ttf", "assets/fonts/NotoSansJP-OFL.txt", "assets/fonts/Sarabun-Regular.ttf", "assets/fonts/Sarabun-Regular.ttf.import", "assets/fonts/OFL.txt", "assets/audio/sea_waves.ogg", "assets/audio/cicadas.ogg", "assets/audio/CREDITS-diorama.md"]
    paths += [str(p.relative_to(ROOT)) for p in sorted((ROOT / "scripts").glob("konbini_*.gd"))]
    paths += [str(p.relative_to(ROOT)) for p in sorted((ROOT / "shaders").glob("konbini_*.gdshader*"))]
    paths += [str(p.relative_to(ROOT)) for p in sorted((ROOT / "tools").glob("*konbini*.gd"))]
    # painted backdrop images, if any have been added (with their import files)
    paths += [str(p.relative_to(ROOT)) for p in sorted((ROOT / "assets/backdrop").glob("*.png*"))]
    for name in paths:
        dest = project_dir / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, dest)
    scene = "coast_diorama.tscn" if args.coast else "headland_diorama.tscn" if args.headland else "beach_diorama.tscn" if args.beach else "ramen_diorama.tscn" if args.ramen else "konbini_diorama_thai.tscn" if args.thai else "konbini_diorama.tscn"
    (project_dir / "project.godot").write_text(PROJECT.replace("{scene}", scene), encoding="utf-8")
    shutil.copyfile(ROOT / "docs/konbini-diorama/README.md", project_dir / "README.md")
    write_archive(target, project_dir)


def write_archive(target, project_dir):
    with zipfile.ZipFile(target / f"{NAME}.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(project_dir.rglob("*")):
            if path.is_file() and ".godot" not in path.parts:
                archive.write(path, path.relative_to(target))
    print(target / f"{NAME}.zip")


if __name__ == "__main__":
    main()
