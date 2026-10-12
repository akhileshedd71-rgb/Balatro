"""Install verified Google SDK archives and configure only two Godot settings."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
from urllib.request import urlretrieve
from zipfile import ZipFile

# SHA-1 values are published in Google's HTTPS repository2-1.xml manifest.
# Pinning both archives makes repeat development setup deterministic.
PACKAGES = (
    ("platform-tools_r37.0.1-linux.zip", "477254aa5f903c15cf51001717bdf347fb6b53e0", False),
    ("build-tools_r36_linux.zip", "b0b6376977657e8ad9b969bacf4093601da2c6fb", True),
)


def install() -> None:
    sdk = Path(os.environ["BALATRO_ANDROID_SDK"]).resolve()
    downloads = Path(os.environ["BALATRO_ANDROID_DOWNLOADS"]).resolve()
    downloads.mkdir(parents=True, exist_ok=True)
    for name, expected, is_build_tools in PACKAGES:
        archive = downloads / name
        if not archive.exists():
            partial = archive.with_suffix(".partial")
            print(f"Downloading official Android SDK archive: {name}", flush=True)
            urlretrieve("https://dl.google.com/android/repository/" + name, partial)
            partial.replace(archive)
        digest = hashlib.sha1(archive.read_bytes()).hexdigest()
        if digest != expected:
            raise RuntimeError(f"Google repository checksum mismatch: {name}")
        destination = sdk / "build-tools/36.0.0" if is_build_tools else sdk
        with ZipFile(archive) as package:
            for member in package.infolist():
                relative = Path(member.filename)
                if is_build_tools:
                    relative = Path(*relative.parts[1:])
                if member.is_dir() or not relative.parts:
                    continue
                path = (destination / relative).resolve()
                if not path.is_relative_to(destination.resolve()):
                    raise RuntimeError(f"Invalid archive member: {member.filename}")
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(package.read(member))
                mode = (member.external_attr >> 16) & 0o777
                if mode:
                    path.chmod(mode)
        print(f"Verified and installed {name}")

    java_sdk = Path(os.environ["BALATRO_JAVA_SDK"]).resolve()
    if not (java_sdk / "bin/keytool").is_file():
        raise RuntimeError("A full JDK with keytool is required; set JAVA_HOME.")
    settings = Path(os.environ["XDG_CONFIG_HOME"]) / "godot/editor_settings-4.6.tres"
    settings.parent.mkdir(parents=True, exist_ok=True)
    content = settings.read_text() if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    for key, value in {
        "export/android/android_sdk_path": str(sdk),
        "export/android/java_sdk_path": str(java_sdk),
    }.items():
        line = key + " = " + json.dumps(value)
        pattern = rf"^{re.escape(key)}\s*=.*$"
        if re.search(pattern, content, flags=re.MULTILINE):
            content = re.sub(pattern, lambda _match: line, content, flags=re.MULTILINE)
        else:
            content += "\n" + line + "\n"
    settings.write_text(content)
    print(f"Configured Godot Android SDK: {sdk}")
    print("Create a development APK with ./tools/export.sh android")


if __name__ == "__main__":
    install()
