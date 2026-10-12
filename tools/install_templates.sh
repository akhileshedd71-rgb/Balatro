#!/usr/bin/env bash
# Official release archive, verified before use. Downloads about 1.26 GB once.
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
version=4.6.3
release="$version-stable"
archive="Godot_v${release}_export_templates.tpz"
expected_sha512=da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68
download_dir="${GODOT_DOWNLOAD_DIR:-$XDG_CACHE_HOME/downloads}"
template_dir="$XDG_DATA_HOME/godot/export_templates/$version.stable"
mkdir -p "$download_dir" "$template_dir"
if [[ -f "$template_dir/.verified_source_sha512" ]] \
    && [[ "$(cat "$template_dir/.verified_source_sha512")" == "$expected_sha512" ]] \
    && [[ -s "$template_dir/linux_release.x86_64" && -s "$template_dir/linux_debug.x86_64" \
        && -s "$template_dir/web_nothreads_release.zip" && -s "$template_dir/web_nothreads_debug.zip" \
        && -s "$template_dir/android_debug.apk" && -s "$template_dir/android_release.apk" ]]; then
    printf 'Godot %s templates are already installed at %s\n' "$version" "$template_dir"
    exit 0
fi
if [[ ! -f "$download_dir/$archive" ]]; then
    curl --fail --location --retry 2 \
        "https://github.com/godotengine/godot/releases/download/$release/$archive" \
        --output "$download_dir/$archive.partial"
    mv -- "$download_dir/$archive.partial" "$download_dir/$archive"
fi
printf '%s  %s\n' "$expected_sha512" "$download_dir/$archive" | sha512sum --check --status
unzip -jo "$download_dir/$archive" \
    'templates/linux_*x86_64' 'templates/web*zip' \
    'templates/android_debug.apk' 'templates/android_release.apk' \
    'templates/android_source.zip' 'templates/version.txt' -d "$template_dir"
printf '%s\n' "$expected_sha512" > "$template_dir/.verified_source_sha512"
printf 'Verified Godot %s templates installed at %s\n' "$version" "$template_dir"
