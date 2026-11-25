web:
	mkdir -p build/web
	godot --headless --path . --export-release "Web" build/web/index.html

serve:
	cd build/web && python3 -m http.server 8060

test:
	godot --headless --path . -- --smoke
