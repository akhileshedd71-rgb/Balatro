# Development and exports

Use **Godot 4.6.3, standard GDScript edition**. The project uses the Compatibility renderer, editable `.tscn` scenes, and `.tres` data. It has no package-manager dependencies, backend service, API keys, telemetry, or paid services.

With Godot 4.6.3 and a JDK already installed, run `./tools/setup.sh` for the complete cloud setup: verify the engine version, install verified export templates and minimal Android tools, then import the project. Individual setup steps are documented below.

## Run and test

```sh
./tools/run.sh --editor
./tools/run.sh
./tools/test.sh
```

`GODOT_BIN=/path/to/godot` selects a different executable. The helper scripts use writable sibling `.godot-data`, `.godot-cache`, and `.godot-config` directories; existing `XDG_DATA_HOME`, `XDG_CACHE_HOME`, and `XDG_CONFIG_HOME` overrides take precedence. Godot saves game state under `user://` in its application-data directory. Test runners receive separate temporary application-data directories, so testing does not overwrite a player's run or progression.

`tools/test.sh` imports the project before running every `tests/test_*.gd` SceneTree runner. It treats logged script/import errors as failures even if Godot exits successfully. Tests cover rules and transitions; they complement graphical inspection and physical-device testing.

## Build playable exports

Install the matching official export templates through Godot's template manager or the checksum-verified helper:

```sh
./tools/install_templates.sh
./tools/export.sh web
./tools/export.sh linux
./tools/serve_web.sh
```

The helper downloads the official 4.6.3 template archive (approximately 1.26 GB), checks the SHA-512 published in that release's `SHA512-SUMS.txt`, and extracts the relevant platforms. Templates are external to the checkout. Build outputs under `builds/` are ignored by Git.

Open `http://127.0.0.1:8060` for the web build. Set `PORT` to choose another port. To view a local development server from another device on a trusted network, set `BIND=0.0.0.0` and use the machine's reachable address. Serve every generated web file together; opening `index.html` with `file://` will not work.

The Web preset uses WebAssembly, WebGL 2, and single-threaded mode. It does not require cross-origin-isolation headers. The Linux preset creates a standalone x86_64 executable with the PCK embedded. Neither export requires access to GitHub or other services at runtime.

With a web server running, `python3 tools/test_web.py` checks the exported game in Chromium at desktop, portrait-phone, and landscape-phone sizes. It plays two hands to reach the shop using keyboard on desktop and actual touchscreen taps on both phone layouts, waits for saved-state changes and the visible hand/shop redraw, reloads to check persistence, fails on console errors, and saves screenshots in `captures/web/` for review. This optional integration check requires Python Playwright, Pillow, and Chromium; all are present in the prepared cloud environment. `CHROMIUM_BIN` can select a browser binary and the first argument can select a different local server URL. Screenshot inspection is still needed to assess clipping and readability.

## Android

The `Android` preset targets ARM64 phones with an immersive, orientation-adaptive view. It uses the official prebuilt Godot template and disables Internet permission. For a local debug APK, configure the Android SDK and Java SDK paths in Godot's **Editor Settings → Export → Android** and run:

```sh
./tools/export.sh android
```

On Linux, `./tools/install_android.sh` installs the minimal official, checksum-verified SDK tools into the sibling `.android-sdk` directory and configures those two editor settings. It pins Platform Tools 37.0.1 and Build Tools 36.0.0, matching Godot 4.6.3's default Android target. It uses an existing JDK, or `JAVA_HOME` when set. The script does not install a full Gradle/NDK development environment.

The official Godot 4.6 documentation recommends OpenJDK 17 (newer versions are supported), Android platform tools, Build Tools 35.0.1, and Android Platform 35. The prebuilt-template export only needs the platform-tools and build-tools executables; a custom Gradle build additionally needs the documented platform, command-line tools, NDK, and CMake packages. Godot creates a local development signing key automatically. Never commit signing keys or passwords.

An exported debug APK is suitable for development installation, not an app-store submission. Release distribution needs a privately managed release signing key, final package identity, store metadata, and physical-device performance/testing. An iOS release additionally requires macOS, Xcode, and Apple signing; no iOS binary is supplied here.

## Rendering in this cloud workspace

Godot's `--headless` mode uses a dummy renderer and cannot validate visuals or produce a real screenshot. This workspace has a working Xorg dummy display at `:98`, rendered through Mesa llvmpipe. With that display running:

```sh
DISPLAY=:98 ./tools/run.sh --display-driver x11 --audio-driver Dummy
```

The current display's configuration and log are outside the repository at `/workspace/.x11/`. Graphical tests should wait for `RenderingServer.frame_post_draw` before capturing a viewport. A software-rendered screenshot is useful for layout and shader correctness, but cannot establish frame rate on mobile hardware.

To recreate a dummy display on a later cloud machine that has Xorg and the dummy video driver, run `./tools/start_display.sh :98` in a separate terminal. Its files live in the configured cache directory.

## Mobile considerations

- The project uses `canvas_items` stretch and adapts the table layout to portrait/landscape viewport shape.
- Mouse-from-touch emulation drives the same selection and button signals on phones. Inspect screens and confirm buttons avoid hover-only actions.
- The 2D Compatibility renderer and lightweight canvas shaders support WebGL 2 and OpenGL ES 3. Shader effects should remain optional and be profiled on a real midrange phone.
- Test narrow portrait, short landscape, safe areas, browser navigation bars, font scaling/readability, audio after a user gesture, suspension/resume, and save persistence before distribution.

## References

The implementation/export decisions were checked against the official Godot 4.6 documentation:

- [Exporting for the Web](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html): WebGL 2, Compatibility renderer, single-threaded deployment and mobile limitations.
- [Exporting for Android](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html): SDK, Java, templates, signing, and device deployment.
- [Multiple resolutions](https://docs.godotengine.org/en/4.6/tutorials/rendering/multiple_resolutions.html): canvas stretch and aspect-ratio handling.
- [Godot 4.6.3 release](https://github.com/godotengine/godot/releases/tag/4.6.3-stable): engine and template artifacts with published checksums.

Every cloud task is already isolated. Reuse its existing checkout; do not create a Git worktree unless explicitly requested.
