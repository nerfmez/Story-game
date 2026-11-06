"""Export the konbini diorama as a web page that a claude.ai artifact can serve.

Artifacts serve only some file types and at most 15 MB per binary file, while
Godot's engine binary is 35 MB. So the engine is gzip-compressed and published
under a .wasm name, the scene pack also gets a .wasm name, and the page patches
fetch() to undo both. The output folder is ready for the Artifact tool:
publish <out>/<name>.html with the other files in `files`.

usage: python3 export_web.py --godot PATH --out DIR [--thai | --ramen] [--title "Name"]
"""
from pathlib import Path
import argparse
import gzip
import json
import re
import shutil
import struct
import subprocess
import urllib.request
import zlib

REPO = Path(__file__).resolve().parents[4]
TEMPLATES = Path.home() / ".local/share/godot/export_templates/4.3.stable"
TPZ = "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz"
PRESET = '''[preset.0]

name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="tools/*"
export_path=""

[preset.0.options]

variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
'''
FETCH_PATCH = '''<script>
// Files are published under served types: the engine gzip-compressed and
// unpacked on the fly, the scene pack under a .wasm name.
(function () {
	const realFetch = window.fetch.bind(window);
	window.fetch = function (input, init) {
		const url = typeof input === "string" ? input : input.url;
		if (/index\\.wasm(\\?|$)/.test(url)) {
			return realFetch(url.replace("index.wasm", "engine.gz.wasm"), init).then(function (r) {
				if (!r.ok) return r;
				const body = r.body.pipeThrough(new DecompressionStream("gzip"));
				return new Response(body, { status: 200, headers: { "Content-Type": "application/wasm" } });
			});
		}
		if (/index\\.pck(\\?|$)/.test(url)) {
			return realFetch(url.replace("index.pck", "scene.pck.wasm"), init);
		}
		return realFetch(input, init);
	};
})();
</script>'''


def fetch_web_template():
    """Pull only web_nothreads_release.zip out of the 1 GB template archive with range requests."""
    target = TEMPLATES / "web_nothreads_release.zip"
    if target.exists():
        return
    def get(a, b):
        return urllib.request.urlopen(urllib.request.Request(TPZ, headers={"Range": f"bytes={a}-{b}"})).read()
    size = int(urllib.request.urlopen(urllib.request.Request(TPZ, method="HEAD")).headers["Content-Length"])
    tail = get(size - 65536, size - 1)
    end = tail.rfind(b"PK\x05\x06")
    cd_size, cd_offset = struct.unpack("<II", tail[end + 12:end + 20])
    directory = get(cd_offset, cd_offset + cd_size - 1)
    pos = 0
    while pos < len(directory):
        fields = struct.unpack("<IHHHHHHIIIHHHHHII", directory[pos:pos + 46])
        method, packed, name_len, extra_len, comment_len, offset = fields[4], fields[8], fields[10], fields[11], fields[12], fields[16]
        name = directory[pos + 46:pos + 46 + name_len].decode()
        if name.endswith("web_nothreads_release.zip"):
            header = get(offset, offset + 29)
            start = offset + 30 + sum(struct.unpack("<HH", header[26:30]))
            data = get(start, start + packed - 1)
            TEMPLATES.mkdir(parents=True, exist_ok=True)
            target.write_bytes(zlib.decompress(data, -15) if method == 8 else data)
            return
        pos += 46 + name_len + extra_len + comment_len
    raise SystemExit("web_nothreads_release.zip not found in the template archive")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", required=True, help="Godot 4.3 binary")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--thai", action="store_true")
    parser.add_argument("--ramen", action="store_true")
    parser.add_argument("--title", default="Rainy Night Konbini")
    args = parser.parse_args()
    out = args.out.resolve()
    stage = out / "stage"
    shutil.rmtree(stage, ignore_errors=True)
    package = [ "python3", str(REPO / "tools/package_konbini.py"), "--output", str(stage)] + (["--thai"] if args.thai else []) + (["--ramen"] if args.ramen else [])
    subprocess.run(package, check=True, stdout=subprocess.DEVNULL)
    project = stage / "Konbini-Diorama-Godot43"
    (project / "export_presets.cfg").write_text(PRESET, encoding="utf-8")
    fetch_web_template()
    shutil.copyfile(TEMPLATES / "web_nothreads_release.zip", TEMPLATES / "web_release.zip")
    subprocess.run([args.godot, "--headless", "--editor", "--path", str(project), "--import", "--quit"], capture_output=True)
    web = stage / "web"
    web.mkdir()
    subprocess.run([args.godot, "--headless", "--path", str(project), "--export-release", "Web", str(web / "index.html")], check=True, capture_output=True)
    pub = out / "publish"
    shutil.rmtree(pub, ignore_errors=True)
    pub.mkdir()
    with open(web / "index.wasm", "rb") as raw, gzip.open(pub / "engine.gz.wasm", "wb", compresslevel=9) as packed:
        shutil.copyfileobj(raw, packed)
    shutil.copyfile(web / "index.pck", pub / "scene.pck.wasm")
    for name in ["index.js", "index.audio.worklet.js", "index.png"]:
        shutil.copyfile(web / name, pub / name)
    html = (web / "index.html").read_text(encoding="utf-8")
    style = re.search(r"<style>.*?</style>", html, re.S).group(0).replace("background-color: black;", "background-color: #0b0a1e;").replace("background-color: #242424;", "background-color: #0b0a1e;")
    body = re.search(r"<body>(.*)</body>", html, re.S).group(1)
    config = json.loads(re.search(r"const GODOT_CONFIG = (\{.*?\});", body).group(1))
    config["ensureCrossOriginIsolationHeaders"] = False
    body = re.sub(r"const GODOT_CONFIG = \{.*?\};", "const GODOT_CONFIG = " + json.dumps(config) + ";", body)
    page = f'<title>{args.title}</title>\n<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">\n{style}\n<style>html,body{{height:100%}}</style>\n{FETCH_PATCH}\n{body}'
    page_name = ("ramen" if args.ramen else "konbini-thai" if args.thai else "konbini") + ".html"
    (pub / page_name).write_text(page, encoding="utf-8")
    print(pub / page_name)


if __name__ == "__main__":
    main()
