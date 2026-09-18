# Agent-Driven Godot Proof
Pinned to Godot 4.7.2. The scene and gameplay are text files. WASD moves the capsule; the camera follows.

## Headless verification and export
Install the matching Godot editor binary and export templates, then:

    godot --headless --path . --editor --quit
    godot --headless --path . -- --self-test
    mkdir -p build/web build/windows
    godot --headless --path . --export-release Web build/web/index.html
    godot --headless --path . --export-release "Windows Desktop" build/windows/AgentDrivenGodot.exe

The web build must be served over HTTP, not opened as a file. The Windows executable is standalone.
