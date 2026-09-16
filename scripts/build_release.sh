#!/bin/zsh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd -P)"
BASE_APP="${1:-/Applications/AltServer.app}"
BASE_ORIGINAL_APP="$BASE_APP"
if (( $# >= 2 )); then
    OUTPUT="$2"
    OUTPUT_IS_DEFAULT=0
else
    OUTPUT="$ROOT/out/v1.0.8"
    OUTPUT_IS_DEFAULT=1
fi
SOURCE_ROOT="$(cd "$ROOT/.." && pwd -P)"
RELEASE_DIR_NAME="v1.0.8"
OBJC_SOURCE="$SOURCE_ROOT/src/AltServerAnisetteFix.m"
SWIFT_CLIENT_SOURCE="$SOURCE_ROOT/src/AnisetteHelper/AnisetteV3Client.swift"
SWIFT_MAIN_SOURCE="$SOURCE_ROOT/src/AnisetteHelper/main.swift"
EXPECTED_OBJC_SOURCE_SHA="35b29f26b50776a46c184bce9ced7634d24f8b6f2b4aaf915942271b1d60cf24"
EXPECTED_SWIFT_CLIENT_SHA="118c5b84d2a8d2c5e8741a7e27d521628b29b15f337f8c70684343555e177112"
EXPECTED_SWIFT_MAIN_SHA="0abfdd8ef5c3e0293d48421f6dc52cb5f2fab3dd8a120677035036dc0ee4f40e"
EXPECTED_FIX_SHA="$EXPECTED_OBJC_SOURCE_SHA"
EXPECTED_OFFICIAL_TEAM_ID="6XVY5G3U44"
# Raw SHA-256 of the untouched universal official main executable (arm64+x86_64).
# Keep this as an allowlist so adding a future explicitly approved official build
# remains an intentional review decision rather than a loose version check.
OFFICIAL_MAIN_SHA_ALLOWLIST=(
    "d1e4188b67adbd120af597ffa11708a18cb139db9919baa5be806a129a3cf819"
)
EXPECTED_OFFICIAL_MAIN_SHA="d1e4188b67adbd120af597ffa11708a18cb139db9919baa5be806a129a3cf819"
TMP_BASE="${TMPDIR:-/tmp}"
TEMP_ROOT="$(mktemp -d "$TMP_BASE/altserver-macos27-v37-build.XXXXXX")"
TEMP_ROOT="${TEMP_ROOT:A}"
TEMP_PARENT_REAL="${TEMP_ROOT:h}"
TEMP_PARENT_KEY="$(stat -f '%d:%i' "$TEMP_PARENT_REAL" 2>/dev/null || true)"
TEMP_ROOT_KEY="$(stat -f '%d:%i' "$TEMP_ROOT" 2>/dev/null || true)"
STAGED_APP="$TEMP_ROOT/AltServer.app"
BASE_INPUT_APP="$TEMP_ROOT/Input-AltServer.app"
HELPER_BUILD="$TEMP_ROOT/AltServerAnisetteHelper"
DYLIB_BUILD="$TEMP_ROOT/AltServerAnisetteFix.dylib"
PAYLOAD_ZIP="$OUTPUT/AltServer-macOS27-v3.7.zip"
EXECUTABLE_MANIFEST="$OUTPUT/AltServer-macOS27-v3.7.executables.txt"
METADATA="$OUTPUT/BUILD-METADATA.txt"
CHECKSUMS="$OUTPUT/CHECKSUMS-SHA256.txt"
MAIN_REL="Contents/MacOS/AltServer"
PLIST="$BASE_APP/Contents/Info.plist"
STAGED_PLIST="$STAGED_APP/Contents/Info.plist"
PRIVATE_TMP_ROOT="/private/tmp"

SOURCE_REVISION=""
SOURCE_TREE_STATE=""
SOURCE_WORKTREE_DIRTY="no"
DIRTY_ATTESTED="no"
SOURCE_SNAPSHOT_REQUIRED="no"
DOCS_DIRTY="no"
OBJC_SOURCE_SHA256=""
SWIFT_CLIENT_SHA256=""
SWIFT_MAIN_SHA256=""
BUILD_SCRIPT_SHA256=""
OBJC_SOURCE_SNAPSHOT="$TEMP_ROOT/source-AltServerAnisetteFix.m"
SWIFT_CLIENT_SOURCE_SNAPSHOT="$TEMP_ROOT/source-AnisetteV3Client.swift"
SWIFT_MAIN_SOURCE_SNAPSHOT="$TEMP_ROOT/source-main.swift"
OBJC_SOURCE_SNAPSHOT_KEY=""
SWIFT_CLIENT_SOURCE_SNAPSHOT_KEY=""
SWIFT_MAIN_SOURCE_SNAPSHOT_KEY=""
BASE_INPUT_SNAPSHOT_HASH=""
BASE_ORIGINAL_KEY=""

source_provenance()
{
    SOURCE_REVISION="$(git -C "$SOURCE_ROOT" rev-parse --verify HEAD 2>/dev/null || true)"
    /usr/bin/grep -Eq '^[0-9a-fA-F]{40}$' <<< "$SOURCE_REVISION" || fail "source revision is unavailable; a Git checkout is required."

    OBJC_SOURCE_SHA256="$(shasum -a 256 "$OBJC_SOURCE" | awk '{ print $1 }')"
    SWIFT_CLIENT_SHA256="$(shasum -a 256 "$SWIFT_CLIENT_SOURCE" | awk '{ print $1 }')"
    SWIFT_MAIN_SHA256="$(shasum -a 256 "$SWIFT_MAIN_SOURCE" | awk '{ print $1 }')"
    [[ "$OBJC_SOURCE_SHA256" == "$EXPECTED_OBJC_SOURCE_SHA" ]] || fail "approved ObjC source hash mismatch."
    [[ "$SWIFT_CLIENT_SHA256" == "$EXPECTED_SWIFT_CLIENT_SHA" ]] || fail "approved Swift client source hash mismatch."
    [[ "$SWIFT_MAIN_SHA256" == "$EXPECTED_SWIFT_MAIN_SHA" ]] || fail "approved Swift main source hash mismatch."
    [[ -f "$OBJC_SOURCE" && ! -L "$OBJC_SOURCE" && -f "$SWIFT_CLIENT_SOURCE" && ! -L "$SWIFT_CLIENT_SOURCE" && -f "$SWIFT_MAIN_SOURCE" && ! -L "$SWIFT_MAIN_SOURCE" ]] || fail "approved source input is missing or symlinked."
    /usr/bin/grep -Eq '^[[:space:]]*#ifndef[[:space:]]+ALT_EXPECTED_HELPER_SHA256([[:space:]]|$)' "$OBJC_SOURCE" || \
        fail "ObjC source is missing the required helper SHA macro guard."

    BUILD_SCRIPT_SHA256="$(shasum -a 256 "$ROOT/build_release.sh" | awk '{ print $1 }')"
    /usr/bin/grep -Eq '^[0-9a-fA-F]{64}$' <<< "$BUILD_SCRIPT_SHA256" || fail "build script hash is unavailable."

    local status_line source_path
    local binary_dirty=0
    local docs_dirty=0
    local status_output
    status_output="$(git -C "$SOURCE_ROOT" status --porcelain=v1 --untracked-files=all 2>/dev/null || true)"
    if [[ -n "$status_output" ]]; then
        SOURCE_WORKTREE_DIRTY="yes"
        while IFS= read -r status_line; do
            [[ -n "$status_line" ]] || continue
            source_path="${status_line[4,-1]}"
            if [[ "$source_path" == *" -> "* ]]; then
                source_path="${source_path##* -> }"
            fi
            case "$source_path" in
                *.md|docs/*|documentation/*)
                    docs_dirty=1
                    ;;
                *)
                    binary_dirty=1
                    ;;
            esac
        done <<< "$status_output"
    fi
    (( docs_dirty == 1 )) && DOCS_DIRTY="yes"
    if (( binary_dirty == 1 )); then
        if [[ "${ALTSERVER_ALLOW_DIRTY_ATTESTED_SOURCE:-0}" != "1" ]]; then
            fail "binary-affecting source tree is dirty; set ALTSERVER_ALLOW_DIRTY_ATTESTED_SOURCE=1 only for an attested build."
        fi
        SOURCE_TREE_STATE="dirty-attested"
        DIRTY_ATTESTED="yes"
        SOURCE_SNAPSHOT_REQUIRED="yes"
    else
        SOURCE_TREE_STATE="clean"
    fi
}

cleanup_temp_early()
{
    if [[ "$TEMP_ROOT" == /* && "$TEMP_ROOT" != "/" && "${TEMP_ROOT:t}" != "" && "${TEMP_ROOT:t}" != "." && "${TEMP_ROOT:t}" != ".." && "${TEMP_ROOT:t}" != -* && -n "$TEMP_ROOT_KEY" && ! -L "$TEMP_ROOT" && "$(stat -f '%d:%i' "$TEMP_ROOT" 2>/dev/null || true)" == "$TEMP_ROOT_KEY" ]]; then
        rmdir "$TEMP_ROOT" 2>/dev/null || true
    fi
}

trap cleanup_temp_early EXIT

fail()
{
    echo "build_release: $1" >&2
    exit 1
}

spctl_assess()
{
    local app="$1"
    if /usr/sbin/spctl --help 2>&1 | /usr/bin/grep -q -- '--strict'; then
        /usr/sbin/spctl --assess --type execute --strict "$app"
    else
        /usr/sbin/spctl --assess --type execute "$app"
    fi
}

if [[ "$(uname -m)" != "arm64" ]]; then
    fail "Apple Silicon arm64 host required."
fi
source_provenance
TRANSLATED="$(sysctl -in sysctl.proc_translated 2>/dev/null || true)"
if [[ "$TRANSLATED" == "1" ]]; then
    fail "Rosetta-translated execution is not supported; run natively under arm64."
fi

plist_value()
{
    /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null || true
}

validate_official_input()
{
    [[ -d "$BASE_APP" && ! -L "$BASE_APP" ]] || fail "official AltServer.app input snapshot not found."
    [[ -f "$PLIST" && ! -L "$PLIST" ]] || fail "official AltServer.app snapshot Info.plist is missing."
    [[ -f "$BASE_APP/$MAIN_REL" && ! -L "$BASE_APP/$MAIN_REL" ]] || fail "official AltServer.app snapshot main executable is missing."
    BUNDLE_ID="$(plist_value CFBundleIdentifier)"
    BASE_VERSION="$(plist_value CFBundleShortVersionString)"
    BASE_BUILD="$(plist_value CFBundleVersion)"
    [[ "$BUNDLE_ID" == "com.rileytestut.AltServer" ]] || fail "input bundle identifier is not the official AltServer bundle."
    [[ "$BASE_VERSION" == "1.7.6" ]] || fail "input must be official AltServer 1.7.6, not a stale or patched base."
    [[ "$BASE_BUILD" == "94" ]] || fail "input must be official AltServer build 94."
    [[ "$BASE_VERSION" != *"macOS27-v3.6"* ]] || fail "v3.6 input is not accepted."

    ARCHES="$(lipo -archs "$BASE_APP/$MAIN_REL" 2>/dev/null || true)"
    [[ " $ARCHES " == *" arm64 "* && " $ARCHES " == *" x86_64 "* ]] || fail "official input must remain universal arm64+x86_64."

    SIGNING_DETAILS="$(codesign --display --verbose=4 "$BASE_APP" 2>&1)" || fail "official input signature verification failed."
    [[ "$SIGNING_DETAILS" == *"Authority=Developer ID Application:"* ]] || fail "official input is not Developer ID signed."
    TEAM_IDENTIFIER="$(printf '%s\n' "$SIGNING_DETAILS" | awk -F= '/^TeamIdentifier=/{ print $2; exit }')"
    [[ "$TEAM_IDENTIFIER" == "$EXPECTED_OFFICIAL_TEAM_ID" ]] || fail "official input signing team is not approved."
    OFFICIAL_MAIN_SHA="$(shasum -a 256 "$BASE_APP/$MAIN_REL" | awk '{ print $1 }')"
    OFFICIAL_MAIN_SHA_APPROVED=0
    for allowed_sha in "${OFFICIAL_MAIN_SHA_ALLOWLIST[@]}"; do
        if [[ "$OFFICIAL_MAIN_SHA" == "$allowed_sha" ]]; then
            OFFICIAL_MAIN_SHA_APPROVED=1
            break
        fi
    done
    (( OFFICIAL_MAIN_SHA_APPROVED == 1 )) || fail "official input main executable provenance is not approved."
    codesign --verify --deep --strict "$BASE_APP" >/dev/null 2>&1 || fail "official input deep signature is invalid."
    spctl_assess "$BASE_APP" >/dev/null 2>&1 || fail "official input is not accepted by Gatekeeper."
    xcrun stapler validate "$BASE_APP" >/dev/null 2>&1 || fail "official input notarization ticket is not valid."

    if find -P "$BASE_APP" \( -path '*AltSign-Dynamic.framework' -o -name '*.ipa' \) -print -quit | grep -q .; then
        fail "input contains a dynamic AltSign or IPA payload; official static AltSign must be preserved."
    fi
}

text_hash()
{
    otool -arch arm64 -s __TEXT __text "$1" | tail -n +3 | shasum -a 256 | awk '{ print $1 }'
}

clear_bundle_detritus()
{
    local bundle="$1"
    local item
    /usr/bin/xattr -cr "$bundle" 2>/dev/null || true
    /usr/bin/xattr -rc "$bundle" 2>/dev/null || true
    # CloudDocs may add these after a delay; remove the exact attributes that
    # codesign rejects without touching provenance metadata used by the OS.
    while IFS= read -r -d '' item; do
        /usr/bin/xattr -d 'com.apple.FinderInfo' "$item" >/dev/null 2>&1 || true
        /usr/bin/xattr -d 'com.apple.ResourceFork' "$item" >/dev/null 2>&1 || true
        /usr/bin/xattr -d 'com.apple.fileprovider.fpfs#P' "$item" >/dev/null 2>&1 || true
    done < <(find -P "$bundle" -print0)
}

path_has_symlink()
{
    local absolute="${1:a}"
    local current="/"
    local component
    for component in ${(s:/:)absolute}; do
        [[ -n "$component" ]] || continue
        current="$current/$component"
        [[ -L "$current" ]] && return 0
    done
    return 1
}

resolve_path()
{
    local absolute="${1:a}"
    [[ "$absolute" == "/" ]] && { print -r -- /; return; }
    local parent="${absolute:h}"
    local leaf="${absolute:t}"
    local parent_real="${parent:A}"
    local joined="$parent_real/$leaf"
    if [[ -e "$joined" || -L "$joined" ]]; then
        print -r -- "${joined:A}"
    else
        print -r -- "$joined"
    fi
}

prepare_default_output_parent()
{
    [[ "$OUTPUT_IS_DEFAULT" == "1" ]] || return 0
    local root_real="${ROOT:A}"
    local source_real="${SOURCE_ROOT:A}"
    local default_parent="$ROOT/out"
    [[ "$ROOT" == "$source_real/scripts" && "$ROOT:t" == "scripts" ]] || fail "default output requires the expected repository layout."
    [[ -d "$SOURCE_ROOT/src" && -f "$SOURCE_ROOT/src/AltServerAnisetteFix.m" ]] || fail "default output requires the expected source tree."
    [[ "$ROOT" == "$root_real" && ! -L "$ROOT" ]] || fail "default output repository path must not alias through a symlink."
    path_has_symlink "$ROOT" && fail "default output repository path contains a symlink."
    [[ "$default_parent:h" == "$ROOT" && "$default_parent:t" == "out" ]] || fail "default output parent is not the exact repository out directory."
    if [[ -e "$default_parent" || -L "$default_parent" ]]; then
        [[ -d "$default_parent" && ! -L "$default_parent" ]] || fail "default output parent is not a directory."
        path_has_symlink "$default_parent" && fail "default output parent contains a symlink."
        [[ "$default_parent" == "${default_parent:A}" ]] || fail "default output parent aliases through a symlink."
    else
        mkdir "$default_parent" || fail "could not create the exact default output parent."
    fi
    [[ -d "$default_parent" && ! -L "$default_parent" ]] || fail "default output parent is unavailable."
}

is_descendant_or_equal()
{
    local child="$1"
    local parent="$2"
    [[ "$child" == "$parent" ]] && return 0
    [[ "$parent" == "/" ]] && return 0
    [[ "$child" == "$parent"/* ]]
}

same_inode()
{
    local first_key second_key
    first_key="$(stat -f '%d:%i' "$1" 2>/dev/null || true)"
    second_key="$(stat -f '%d:%i' "$2" 2>/dev/null || true)"
    [[ -n "$first_key" && "$first_key" == "$second_key" ]]
}

validate_output_parent_scope()
{
    local parent="$1"
    local home_real="$(resolve_path "${HOME:-/}")"
    local workspace_real="$(resolve_path "$SOURCE_ROOT")"
    local base_real="$(resolve_path "$BASE_APP")"
    local base_parent="${base_real:h}"
    local -a forbidden=(
        "/"
        "/private"
        "/tmp"
        "/private/tmp"
        "/var"
        "/private/var"
        "/Applications"
        "/Users"
        "/private/Users"
        "$home_real"
        "$workspace_real"
        "$base_parent"
    )
    local item
    for item in "${forbidden[@]}"; do
        [[ "$parent" != "$item" ]] || return 1
    done
    [[ "$parent" != "${parent:A}" || ! -L "$parent" ]] || return 1
    path_has_symlink "$parent" && return 1
    return 0
}

validate_existing_release_schema()
{
    local candidate="$1"
    [[ -d "$candidate" && ! -L "$candidate" ]] || return 1
    [[ "$candidate" == "${candidate:A}" ]] || return 1
    path_has_symlink "$candidate" && return 1
    python3 - "$candidate" <<'PY'
import hashlib
import re
import sys
from pathlib import Path, PurePosixPath

root = Path(sys.argv[1])
expected_files = {
    "AltServer-macOS27-v3.7.zip",
    "AltServer-macOS27-v3.7.executables.txt",
    "BUILD-METADATA.txt",
    "CHECKSUMS-SHA256.txt",
}
entries = list(root.iterdir())
if not entries:
    raise SystemExit(0)
if {item.name for item in entries} != expected_files:
    raise SystemExit("existing output has unrelated entries")
if any(item.is_symlink() or not item.is_file() for item in entries):
    raise SystemExit("existing output contains a non-regular artifact")
checksum_file = root / "CHECKSUMS-SHA256.txt"
checksums = {}
for line in checksum_file.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    fields = line.split()
    if len(fields) != 2:
        raise SystemExit("invalid existing checksum line")
    digest, relative = fields
    path = PurePosixPath(relative)
    if not re.fullmatch(r"[0-9a-fA-F]{64}", digest) or path.is_absolute() or ".." in path.parts or "\\" in relative or relative != path.as_posix():
        raise SystemExit("unsafe existing checksum entry")
    if relative in checksums:
        raise SystemExit("duplicate existing checksum entry")
    checksums[relative] = digest.lower()
if set(checksums) != {
    "AltServer-macOS27-v3.7.zip",
    "AltServer-macOS27-v3.7.executables.txt",
    "BUILD-METADATA.txt",
}:
    raise SystemExit("existing output checksum schema changed")
for relative, digest in checksums.items():
    target = root / relative
    if target.parent != root or target.is_symlink() or not target.is_file():
        raise SystemExit("existing checksum target is unsafe")
    if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
        raise SystemExit("existing output checksum mismatch")
PY
}

validate_output_paths()
{
    local candidate_output="${1:-$OUTPUT}"
    local base_abs="${BASE_APP:a}"
    local output_abs="${candidate_output:a}"
    local output_app_abs="$output_abs/AltServer.app"
    local payload_abs="$output_abs/Payload"
    local base_real="$(resolve_path "$BASE_APP")"
    local output_real="$(resolve_path "$candidate_output")"
    local output_app_real="$(resolve_path "$output_app_abs")"
    local payload_real="$(resolve_path "$payload_abs")"
    local output_parent_abs="${output_abs:h}"
    local output_parent_real="$(resolve_path "$output_parent_abs")"
    local home_real="$(resolve_path "${HOME:-/}")"
    local workspace_real="$(resolve_path "$SOURCE_ROOT")"
    local -a destinations=(
        "$output_app_abs"
        "$output_abs/AltServer-macOS27-v3.7.zip"
        "$output_abs/AltServer-macOS27-v3.7.executables.txt"
        "$output_abs/BUILD-METADATA.txt"
        "$payload_abs/AltServer-macOS27-v3.7.zip"
        "$payload_abs/AltServer-macOS27-v3.7.executables.txt"
        "$payload_abs/BUILD-METADATA.txt"
        "$output_abs/CHECKSUMS-SHA256.txt"
    )

    path_has_symlink "$BASE_APP" && fail "official input path must not contain a symlink."
    path_has_symlink "$candidate_output" && fail "output path must not contain a symlink."
    path_has_symlink "$output_app_abs" && fail "output app path must not contain a symlink."
    path_has_symlink "$payload_abs" && fail "payload path must not contain a symlink."
    [[ "$base_abs" == "$base_real" ]] || fail "official input path aliases through a symlink."
    [[ "$output_abs" == "$output_real" ]] || fail "output path aliases through a symlink."
    [[ "$output_app_abs" == "$output_app_real" ]] || fail "output app aliases through a symlink."
    [[ "$payload_abs" == "$payload_real" ]] || fail "payload path aliases through a symlink."
    [[ -d "$output_parent_abs" && ! -L "$output_parent_abs" ]] || fail "output parent must already exist."
    [[ "$output_parent_abs" == "$output_parent_real" ]] || fail "output parent aliases through a symlink."
    validate_output_parent_scope "$output_parent_real" || fail "output parent is too broad or unsafe."
    if [[ -e "$candidate_output" || -L "$candidate_output" ]]; then
        [[ -d "$candidate_output" && ! -L "$candidate_output" ]] || fail "output must be a directory or a new path."
    fi

    [[ "$output_real" != "/" ]] || fail "output root is not a safe release destination."
    [[ "$output_real" != "$home_real" ]] || fail "home directory is not a safe release destination."
    [[ "$output_real" != "$workspace_real" ]] || fail "workspace root is not a safe release destination."
    is_descendant_or_equal "$base_real" "$output_real" && fail "output tree contains the official input app."
    is_descendant_or_equal "$output_real" "$base_real" && fail "output tree is inside the official input app."
    is_descendant_or_equal "$payload_real" "$base_real" && fail "payload tree is inside the official input app."
    [[ "$output_app_real" != "$base_real" ]] || fail "output app aliases the official input app."
    is_descendant_or_equal "$output_app_real" "$base_real" && fail "output app is inside the official input app."

    if [[ -d "$BASE_APP" && -d "$output_app_abs" ]] && same_inode "$BASE_APP" "$output_app_abs"; then
        fail "output app has the same device/inode as the official input app."
    fi
    local destination destination_real
    for destination in "${destinations[@]}"; do
        path_has_symlink "$destination" && fail "release destination aliases through a symlink."
        destination_real="$(resolve_path "$destination")"
        is_descendant_or_equal "$destination_real" "$base_real" && fail "release destination is inside the official input app."
    done
}

OUTPUT_REAL=""
OUTPUT_PARENT_REAL=""
OUTPUT_NAME=""
OUTPUT_PREEXISTING=0
OUTPUT_INITIAL_KEY=""
STAGE_ROOT=""
OLD_ROOT=""
FAILED_ROOT=""
PARENT_KEY=""
PARENT_DEV=""
PARENT_INO=""
RENAME_HELPER_SOURCE=""
RENAME_HELPER=""
LOCK_NAME=""
LOCK_PATH=""
LOCK_DIR_KEY=""
LOCK_STALE_AFTER_SECONDS=300
LOCK_HELD=0
STAGE_KEY=""
STAGE_MOVE_KEY=""
OUTPUT_MOVE_KEY=""
FAILED_KEY=""
TRANSACTION_ACTIVE=0
OLD_MOVED=0
NEW_MOVED=0
CLEANUP_RUNNING=0
RECOVERY_FAILED=0
RELEASE_FAULT="${ALTSERVER_RELEASE_FAULT:-}"

fault_enabled()
{
    local wanted="$1"
    local token
    for token in ${(s:,:)RELEASE_FAULT}; do
        [[ "$token" == "$wanted" || "${token//_/-}" == "$wanted" || "${token//-/_}" == "$wanted" ]] && return 0
    done
    return 1
}

fault_if()
{
    if fault_enabled "$1"; then
        fail "fault injection: $1"
    fi
    return 0
}

safe_remove_transaction_path()
{
    local target="$1"
    local expected_key="${2:-}"
    [[ -n "$target" && -n "$OUTPUT_PARENT_REAL" ]] || return 1
    # Every destructive transaction cleanup is tied to the parent directory
    # captured before publishing.  If the parent was swapped or symlinked,
    # preserve the recovery trees instead of deleting a same-named path.
    recovery_parent_ok || return 1
    [[ "$target" == /* && "$target" != "/" ]] || return 1
    [[ "${target:t}" != "" && "${target:t}" != "." && "${target:t}" != ".." && "${target:t}" != -* ]] || return 1
    [[ "$target" == "$OUTPUT_PARENT_REAL"/.altserver-release-* ]] || return 1
    [[ "$target" != "/" && "$target" != "${HOME:-}" && "$target" != "$SOURCE_ROOT" && "$target" != "${BASE_REAL:-}" ]] || return 1
    path_has_symlink "$target" && return 1
    [[ -e "$target" || -L "$target" ]] || return 0
    [[ -n "$expected_key" ]] || return 1
    [[ "$(stat -f '%d:%i' "$target" 2>/dev/null || true)" == "$expected_key" ]] || return 1
    bound_remove_tree_path "$OUTPUT_PARENT_REAL" "$PARENT_DEV" "$PARENT_INO" "$target" "$expected_key"
}

recovery_parent_ok()
{
    [[ -n "$OUTPUT_PARENT_REAL" && -n "$PARENT_KEY" ]] || return 1
    [[ -d "$OUTPUT_PARENT_REAL" && ! -L "$OUTPUT_PARENT_REAL" ]] || return 1
    [[ "$OUTPUT_PARENT_REAL" == "${OUTPUT_PARENT_REAL:A}" ]] || return 1
    path_has_symlink "$OUTPUT_PARENT_REAL" && return 1
    [[ "$(stat -f '%d:%i' "$OUTPUT_PARENT_REAL" 2>/dev/null || true)" == "$PARENT_KEY" ]] || return 1
    return 0
}

compile_bound_rename_helper()
{
    RENAME_HELPER_SOURCE="$TEMP_ROOT/renameatx_excl.c"
    RENAME_HELPER="$TEMP_ROOT/renameatx_excl"
    cat > "$RENAME_HELPER_SOURCE" <<'C_SOURCE'
#define _DARWIN_C_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stdio.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef RENAME_EXCL
#error "RENAME_EXCL is required from <sys/stdio.h>"
#endif
#if RENAME_EXCL != 0x00000004
#error "unexpected RENAME_EXCL value"
#endif
#ifndef RENAME_NOFOLLOW_ANY
#error "RENAME_NOFOLLOW_ANY is required from <sys/stdio.h>"
#endif

extern int renameatx_np(int, const char *, int, const char *, unsigned int);

static int parse_u64(const char *text, unsigned long long *value)
{
    char *end = NULL;
    unsigned long long parsed;
    if (text == NULL || *text == '\0') {
        return -1;
    }
    errno = 0;
    parsed = strtoull(text, &end, 10);
    if (errno != 0 || end == text || *end != '\0') {
        return -1;
    }
    *value = parsed;
    return 0;
}

static int safe_component(const char *name)
{
    size_t length;
    if (name == NULL || *name == '\0' || *name == '-' || strcmp(name, ".") == 0 || strcmp(name, "..") == 0) {
        return 0;
    }
    length = strlen(name);
    return length < NAME_MAX && strchr(name, '/') == NULL && strchr(name, '\\') == NULL;
}

static int open_bound_parent(const char *path)
{
    char copy[PATH_MAX];
    char *cursor;
    int fd;
    if (path == NULL || path[0] != '/' || strlen(path) >= sizeof(copy)) {
        errno = EINVAL;
        return -1;
    }
    strlcpy(copy, path, sizeof(copy));
    fd = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0) {
        return -1;
    }
    cursor = copy + 1;
    while (*cursor != '\0') {
        char *slash = strchr(cursor, '/');
        int next;
        if (slash != NULL) {
            *slash = '\0';
        }
        if (!safe_component(cursor)) {
            close(fd);
            errno = EINVAL;
            return -1;
        }
        next = openat(fd, cursor, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (next < 0) {
            close(fd);
            return -1;
        }
        close(fd);
        fd = next;
        if (slash == NULL) {
            break;
        }
        cursor = slash + 1;
    }
    return fd;
}

static int write_metadata_at(int directory_fd, const char *name, const char *value)
{
    int fd;
    size_t length = strlen(value);
    size_t written = 0;
    fd = openat(directory_fd, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (fd < 0) {
        return -1;
    }
    while (written < length) {
        ssize_t count = write(fd, value + written, length - written);
        if (count <= 0) {
            close(fd);
            unlinkat(directory_fd, name, 0);
            return -1;
        }
        written += (size_t)count;
    }
    if (write(fd, "\n", 1) != 1 || close(fd) != 0) {
        unlinkat(directory_fd, name, 0);
        return -1;
    }
    return 0;
}

static int identity_matches(const struct stat *value, unsigned long long device, unsigned long long inode)
{
    return (unsigned long long)value->st_dev == device &&
           (unsigned long long)value->st_ino == inode;
}

static int remove_tree_contents(int directory_fd)
{
    int scan_fd = dup(directory_fd);
    DIR *directory;
    struct dirent *entry;
    if (scan_fd < 0) {
        return 70;
    }
    directory = fdopendir(scan_fd);
    if (directory == NULL) {
        close(scan_fd);
        return 70;
    }
    while ((entry = readdir(directory)) != NULL) {
        struct stat before, after, opened;
        int child_fd = -1;
        if (!safe_component(entry->d_name)) {
            continue;
        }
        if (fstatat(directory_fd, entry->d_name, &before, AT_SYMLINK_NOFOLLOW) != 0) {
            closedir(directory);
            return 70;
        }
        if (S_ISDIR(before.st_mode)) {
            child_fd = openat(directory_fd, entry->d_name,
                              O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            if (child_fd < 0 || fstat(child_fd, &opened) != 0 ||
                !identity_matches(&opened, (unsigned long long)before.st_dev,
                                  (unsigned long long)before.st_ino)) {
                if (child_fd >= 0) {
                    close(child_fd);
                }
                closedir(directory);
                return 70;
            }
            if (remove_tree_contents(child_fd) != 0) {
                close(child_fd);
                closedir(directory);
                return 70;
            }
            close(child_fd);
            if (fstatat(directory_fd, entry->d_name, &after, AT_SYMLINK_NOFOLLOW) != 0 ||
                !S_ISDIR(after.st_mode) ||
                !identity_matches(&after, (unsigned long long)before.st_dev,
                                  (unsigned long long)before.st_ino) ||
                unlinkat(directory_fd, entry->d_name, AT_REMOVEDIR) != 0) {
                closedir(directory);
                return 70;
            }
        } else if (S_ISREG(before.st_mode)) {
            int file_fd = openat(directory_fd, entry->d_name,
                                 O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
            if (file_fd < 0 || fstat(file_fd, &opened) != 0 ||
                !S_ISREG(opened.st_mode) ||
                !identity_matches(&opened, (unsigned long long)before.st_dev,
                                  (unsigned long long)before.st_ino)) {
                if (file_fd >= 0) {
                    close(file_fd);
                }
                closedir(directory);
                return 70;
            }
            if (fchflags(file_fd, 0) != 0 && errno != EPERM) {
                close(file_fd);
                closedir(directory);
                return 70;
            }
            close(file_fd);
            if (fstatat(directory_fd, entry->d_name, &after, AT_SYMLINK_NOFOLLOW) != 0 ||
                !S_ISREG(after.st_mode) ||
                !identity_matches(&after, (unsigned long long)before.st_dev,
                                  (unsigned long long)before.st_ino) ||
                unlinkat(directory_fd, entry->d_name, 0) != 0) {
                closedir(directory);
                return 70;
            }
        } else if (S_ISLNK(before.st_mode)) {
            if (fstatat(directory_fd, entry->d_name, &after, AT_SYMLINK_NOFOLLOW) != 0 ||
                !S_ISLNK(after.st_mode) ||
                !identity_matches(&after, (unsigned long long)before.st_dev,
                                  (unsigned long long)before.st_ino) ||
                unlinkat(directory_fd, entry->d_name, 0) != 0) {
                closedir(directory);
                return 70;
            }
        } else {
            closedir(directory);
            return 70;
        }
    }
    closedir(directory);
    return 0;
}

static int remove_tree_root(int parent_fd, const char *name,
                            unsigned long long expected_device,
                            unsigned long long expected_inode)
{
    struct stat before, opened, after;
    int root_fd;
    if (fstatat(parent_fd, name, &before, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(before.st_mode) || !identity_matches(&before, expected_device, expected_inode)) {
        return 70;
    }
    root_fd = openat(parent_fd, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (root_fd < 0 || fstat(root_fd, &opened) != 0 ||
        !S_ISDIR(opened.st_mode) || !identity_matches(&opened, expected_device, expected_inode)) {
        if (root_fd >= 0) {
            close(root_fd);
        }
        return 70;
    }
    if (remove_tree_contents(root_fd) != 0) {
        close(root_fd);
        return 70;
    }
    close(root_fd);
    if (fstatat(parent_fd, name, &after, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(after.st_mode) || !identity_matches(&after, expected_device, expected_inode) ||
        unlinkat(parent_fd, name, AT_REMOVEDIR) != 0) {
        return 70;
    }
    return 0;
}

static int copy_fd(int source_fd, int destination_fd)
{
    unsigned char buffer[65536];
    ssize_t count;
    while ((count = read(source_fd, buffer, sizeof(buffer))) > 0) {
        ssize_t offset = 0;
        while (offset < count) {
            ssize_t written = write(destination_fd, buffer + offset, (size_t)(count - offset));
            if (written <= 0) {
                return 70;
            }
            offset += written;
        }
    }
    return count == 0 ? 0 : 70;
}

static int copy_file_bound(const char *destination_parent_path,
                           unsigned long long destination_parent_device,
                           unsigned long long destination_parent_inode,
                           const char *destination_root_name,
                           unsigned long long destination_root_device,
                           unsigned long long destination_root_inode,
                           const char *destination_name,
                           const char *source_parent_path,
                           unsigned long long source_parent_device,
                           unsigned long long source_parent_inode,
                           const char *source_name,
                           unsigned long long source_device,
                           unsigned long long source_inode)
{
    struct stat destination_parent_stat, destination_root_stat, source_parent_stat;
    struct stat source_stat, source_opened, destination_stat;
    int destination_parent_fd = -1, destination_root_fd = -1;
    int source_parent_fd = -1, source_fd = -1, destination_fd = -1;
    int result = 70;

    destination_parent_fd = open_bound_parent(destination_parent_path);
    if (destination_parent_fd < 0 || fstat(destination_parent_fd, &destination_parent_stat) != 0 ||
        !identity_matches(&destination_parent_stat, destination_parent_device, destination_parent_inode)) {
        goto done;
    }
    if (fstatat(destination_parent_fd, destination_root_name, &destination_root_stat, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(destination_root_stat.st_mode) ||
        !identity_matches(&destination_root_stat, destination_root_device, destination_root_inode)) {
        goto done;
    }
    destination_root_fd = openat(destination_parent_fd, destination_root_name,
                                 O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (destination_root_fd < 0 || fstat(destination_root_fd, &destination_root_stat) != 0 ||
        !identity_matches(&destination_root_stat, destination_root_device, destination_root_inode)) {
        goto done;
    }
    source_parent_fd = open_bound_parent(source_parent_path);
    if (source_parent_fd < 0 || fstat(source_parent_fd, &source_parent_stat) != 0 ||
        !identity_matches(&source_parent_stat, source_parent_device, source_parent_inode)) {
        goto done;
    }
    if (fstatat(source_parent_fd, source_name, &source_stat, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISREG(source_stat.st_mode) || !identity_matches(&source_stat, source_device, source_inode)) {
        goto done;
    }
    source_fd = openat(source_parent_fd, source_name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (source_fd < 0 || fstat(source_fd, &source_opened) != 0 ||
        !S_ISREG(source_opened.st_mode) ||
        !identity_matches(&source_opened, source_device, source_inode)) {
        goto done;
    }
    destination_fd = openat(destination_root_fd, destination_name,
                            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (destination_fd < 0) {
        result = errno == EEXIST ? 17 : 70;
        goto done;
    }
    if (fchmod(destination_fd, source_stat.st_mode & 0777) != 0 ||
        copy_fd(source_fd, destination_fd) != 0 || fsync(destination_fd) != 0 ||
        fstat(destination_fd, &destination_stat) != 0 || !S_ISREG(destination_stat.st_mode)) {
        goto done;
    }
    if (fstatat(source_parent_fd, source_name, &source_stat, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISREG(source_stat.st_mode) || !identity_matches(&source_stat, source_device, source_inode)) {
        goto done;
    }
    result = 0;
done:
    if (destination_fd >= 0) {
        close(destination_fd);
        if (result != 0) {
            unlinkat(destination_root_fd, destination_name, 0);
        }
    }
    if (source_fd >= 0) {
        close(source_fd);
    }
    if (source_parent_fd >= 0) {
        close(source_parent_fd);
    }
    if (destination_root_fd >= 0) {
        close(destination_root_fd);
    }
    if (destination_parent_fd >= 0) {
        close(destination_parent_fd);
    }
    return result;
}

int main(int argc, char **argv)
{
    unsigned long long expected_dev, expected_ino, expected_source_dev, expected_source_ino;
    struct stat parent_stat, source_stat, source_opened, destination_stat;
    int parent_fd;
    int source_fd = -1;
    int destination_status;

    if (argc == 8 && strcmp(argv[1], "--remove-tree") == 0) {
        unsigned long long expected_remove_parent_device, expected_remove_parent_inode;
        unsigned long long expected_remove_root_device, expected_remove_root_inode;
        struct stat remove_parent_stat;
        if (parse_u64(argv[3], &expected_remove_parent_device) != 0 ||
            parse_u64(argv[4], &expected_remove_parent_inode) != 0 ||
            parse_u64(argv[6], &expected_remove_root_device) != 0 ||
            parse_u64(argv[7], &expected_remove_root_inode) != 0 ||
            !safe_component(argv[5])) {
            return 64;
        }
        parent_fd = open_bound_parent(argv[2]);
        if (parent_fd < 0 || fstat(parent_fd, &remove_parent_stat) != 0 ||
            !identity_matches(&remove_parent_stat, expected_remove_parent_device,
                              expected_remove_parent_inode)) {
            if (parent_fd >= 0) {
                close(parent_fd);
            }
            return 70;
        }
        destination_status = remove_tree_root(parent_fd, argv[5], expected_remove_root_device,
                                              expected_remove_root_inode);
        close(parent_fd);
        return destination_status;
    }
    if (argc == 15 && strcmp(argv[1], "--copy-file") == 0) {
        unsigned long long destination_parent_device, destination_parent_inode;
        unsigned long long destination_root_device, destination_root_inode;
        unsigned long long source_parent_device, source_parent_inode;
        unsigned long long source_device, source_inode;
        if (parse_u64(argv[3], &destination_parent_device) != 0 ||
            parse_u64(argv[4], &destination_parent_inode) != 0 ||
            parse_u64(argv[6], &destination_root_device) != 0 ||
            parse_u64(argv[7], &destination_root_inode) != 0 ||
            parse_u64(argv[10], &source_parent_device) != 0 ||
            parse_u64(argv[11], &source_parent_inode) != 0 ||
            parse_u64(argv[13], &source_device) != 0 ||
            parse_u64(argv[14], &source_inode) != 0 ||
            !safe_component(argv[5]) || !safe_component(argv[8]) ||
            !safe_component(argv[12])) {
            return 64;
        }
        return copy_file_bound(argv[2], destination_parent_device, destination_parent_inode,
                               argv[5], destination_root_device, destination_root_inode,
                               argv[8], argv[9], source_parent_device, source_parent_inode,
                               argv[12], source_device, source_inode);
    }
    if (argc == 11 && strcmp(argv[1], "--lock-init") == 0) {
        unsigned long long expected_init_parent_dev, expected_init_parent_ino;
        unsigned long long expected_init_lock_dev, expected_init_lock_ino;
        struct stat init_parent_stat, init_lock_stat, init_path_stat, init_metadata_stat;
        int init_lock_fd;
        const char *init_metadata_names[] = { "pid", "parent", "born" };
        size_t init_index;
        if (parse_u64(argv[3], &expected_init_parent_dev) != 0 ||
            parse_u64(argv[4], &expected_init_parent_ino) != 0 ||
            parse_u64(argv[6], &expected_init_lock_dev) != 0 ||
            parse_u64(argv[7], &expected_init_lock_ino) != 0 ||
            !safe_component(argv[5])) {
            return 64;
        }
        parent_fd = open_bound_parent(argv[2]);
        if (parent_fd < 0 || fstat(parent_fd, &init_parent_stat) != 0 ||
            (unsigned long long)init_parent_stat.st_dev != expected_init_parent_dev ||
            (unsigned long long)init_parent_stat.st_ino != expected_init_parent_ino) {
            if (parent_fd >= 0) {
                close(parent_fd);
            }
            return 70;
        }
        init_lock_fd = openat(parent_fd, argv[5], O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (init_lock_fd < 0 || fstat(init_lock_fd, &init_lock_stat) != 0 ||
            (unsigned long long)init_lock_stat.st_dev != expected_init_lock_dev ||
            (unsigned long long)init_lock_stat.st_ino != expected_init_lock_ino ||
            write_metadata_at(init_lock_fd, "pid", argv[8]) != 0 ||
            write_metadata_at(init_lock_fd, "parent", argv[9]) != 0 ||
            write_metadata_at(init_lock_fd, "born", argv[10]) != 0) {
            if (init_lock_fd >= 0) {
                close(init_lock_fd);
            }
            close(parent_fd);
            return 70;
        }
        if (fstat(parent_fd, &init_parent_stat) != 0 ||
            !identity_matches(&init_parent_stat, expected_init_parent_dev, expected_init_parent_ino) ||
            fstat(init_lock_fd, &init_lock_stat) != 0 ||
            !identity_matches(&init_lock_stat, expected_init_lock_dev, expected_init_lock_ino) ||
            fstatat(parent_fd, argv[5], &init_path_stat, AT_SYMLINK_NOFOLLOW) != 0 ||
            !S_ISDIR(init_path_stat.st_mode) ||
            !identity_matches(&init_path_stat, expected_init_lock_dev, expected_init_lock_ino)) {
            close(init_lock_fd);
            close(parent_fd);
            return 70;
        }
        for (init_index = 0; init_index < sizeof(init_metadata_names) / sizeof(init_metadata_names[0]); ++init_index) {
            if (fstatat(init_lock_fd, init_metadata_names[init_index], &init_metadata_stat, AT_SYMLINK_NOFOLLOW) != 0 ||
                !S_ISREG(init_metadata_stat.st_mode)) {
                close(init_lock_fd);
                close(parent_fd);
                return 70;
            }
        }
        close(init_lock_fd);
        close(parent_fd);
        return 0;
    }
    if (argc == 6 && strcmp(argv[1], "--mkdir") == 0) {
        unsigned long long expected_mkdir_dev, expected_mkdir_ino;
        struct stat mkdir_parent_stat, mkdir_created_stat, mkdir_child_stat, mkdir_path_stat;
        int mkdir_child_fd;
        if (parse_u64(argv[3], &expected_mkdir_dev) != 0 ||
            parse_u64(argv[4], &expected_mkdir_ino) != 0 || !safe_component(argv[5])) {
            return 64;
        }
        parent_fd = open_bound_parent(argv[2]);
        if (parent_fd < 0 || fstat(parent_fd, &mkdir_parent_stat) != 0) {
            return 70;
        }
        if ((unsigned long long)mkdir_parent_stat.st_dev != expected_mkdir_dev ||
            (unsigned long long)mkdir_parent_stat.st_ino != expected_mkdir_ino) {
            close(parent_fd);
            return 70;
        }
        if (mkdirat(parent_fd, argv[5], 0700) != 0) {
            int status = errno == EEXIST ? 17 : 70;
            close(parent_fd);
            return status;
        }
        if (fstatat(parent_fd, argv[5], &mkdir_created_stat, AT_SYMLINK_NOFOLLOW) != 0 ||
            !S_ISDIR(mkdir_created_stat.st_mode)) {
            close(parent_fd);
            return 70;
        }
        mkdir_child_fd = openat(parent_fd, argv[5], O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (mkdir_child_fd < 0 || fstat(mkdir_child_fd, &mkdir_child_stat) != 0 ||
            !S_ISDIR(mkdir_child_stat.st_mode) ||
            !identity_matches(&mkdir_child_stat, (unsigned long long)mkdir_created_stat.st_dev,
                              (unsigned long long)mkdir_created_stat.st_ino) ||
            fstatat(parent_fd, argv[5], &mkdir_path_stat, AT_SYMLINK_NOFOLLOW) != 0 ||
            !S_ISDIR(mkdir_path_stat.st_mode) ||
            !identity_matches(&mkdir_path_stat, (unsigned long long)mkdir_created_stat.st_dev,
                              (unsigned long long)mkdir_created_stat.st_ino) ||
            fstat(parent_fd, &mkdir_parent_stat) != 0 ||
            !identity_matches(&mkdir_parent_stat, expected_mkdir_dev, expected_mkdir_ino)) {
            if (mkdir_child_fd >= 0) {
                close(mkdir_child_fd);
            }
            close(parent_fd);
            return 70;
        }
        close(mkdir_child_fd);
        close(parent_fd);
        return 0;
    }
    if (argc == 8 && strcmp(argv[1], "--lock-release") == 0) {
        unsigned long long expected_release_parent_dev, expected_release_parent_ino;
        unsigned long long expected_release_lock_dev, expected_release_lock_ino;
        struct stat lock_parent_stat, lock_stat, metadata_stat;
        int lock_fd;
        const char *metadata_names[] = { "pid", "parent", "born" };
        size_t index;
        if (parse_u64(argv[3], &expected_release_parent_dev) != 0 ||
            parse_u64(argv[4], &expected_release_parent_ino) != 0 ||
            parse_u64(argv[6], &expected_release_lock_dev) != 0 ||
            parse_u64(argv[7], &expected_release_lock_ino) != 0 || !safe_component(argv[5])) {
            return 64;
        }
        parent_fd = open_bound_parent(argv[2]);
        if (parent_fd < 0 || fstat(parent_fd, &lock_parent_stat) != 0 ||
            (unsigned long long)lock_parent_stat.st_dev != expected_release_parent_dev ||
            (unsigned long long)lock_parent_stat.st_ino != expected_release_parent_ino) {
            return 70;
        }
        if (fstatat(parent_fd, argv[5], &lock_stat, AT_SYMLINK_NOFOLLOW) != 0 ||
            S_ISLNK(lock_stat.st_mode) || !S_ISDIR(lock_stat.st_mode)) {
            close(parent_fd);
            return 70;
        }
        lock_fd = openat(parent_fd, argv[5], O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (lock_fd < 0 || fstat(lock_fd, &lock_stat) != 0 ||
            (unsigned long long)lock_stat.st_dev != expected_release_lock_dev ||
            (unsigned long long)lock_stat.st_ino != expected_release_lock_ino) {
            if (lock_fd >= 0) {
                close(lock_fd);
            }
            close(parent_fd);
            return 70;
        }
        for (index = 0; index < sizeof(metadata_names) / sizeof(metadata_names[0]); ++index) {
        if (fstatat(lock_fd, metadata_names[index], &metadata_stat, AT_SYMLINK_NOFOLLOW) != 0 ||
                S_ISLNK(metadata_stat.st_mode) || !S_ISREG(metadata_stat.st_mode) ||
                unlinkat(lock_fd, metadata_names[index], 0) != 0) {
                close(lock_fd);
                close(parent_fd);
                return 70;
            }
        }
        if (fstat(parent_fd, &lock_parent_stat) != 0 ||
            !identity_matches(&lock_parent_stat, expected_release_parent_dev,
                              expected_release_parent_ino) ||
            fstat(lock_fd, &lock_stat) != 0 ||
            !identity_matches(&lock_stat, expected_release_lock_dev,
                              expected_release_lock_ino) ||
            fstatat(parent_fd, argv[5], &lock_stat, AT_SYMLINK_NOFOLLOW) != 0 ||
            !S_ISDIR(lock_stat.st_mode) ||
            !identity_matches(&lock_stat, expected_release_lock_dev,
                              expected_release_lock_ino)) {
            close(lock_fd);
            close(parent_fd);
            return 70;
        }
        if (unlinkat(parent_fd, argv[5], AT_REMOVEDIR) != 0 ||
            fstat(parent_fd, &lock_parent_stat) != 0 ||
            !identity_matches(&lock_parent_stat, expected_release_parent_dev,
                              expected_release_parent_ino)) {
            close(lock_fd);
            close(parent_fd);
            return 70;
        }
        close(lock_fd);
        close(parent_fd);
        return 0;
    }
    if (argc != 8 || parse_u64(argv[2], &expected_dev) != 0 ||
        parse_u64(argv[3], &expected_ino) != 0 ||
        parse_u64(argv[4], &expected_source_dev) != 0 ||
        parse_u64(argv[5], &expected_source_ino) != 0 ||
        !safe_component(argv[6]) || !safe_component(argv[7])) {
        fprintf(stderr, "invalid bound rename arguments\n");
        return 64;
    }
    parent_fd = open_bound_parent(argv[1]);
    if (parent_fd < 0 || fstat(parent_fd, &parent_stat) != 0) {
        perror("open bound parent");
        return 70;
    }
    if ((unsigned long long)parent_stat.st_dev != expected_dev ||
        (unsigned long long)parent_stat.st_ino != expected_ino) {
        fprintf(stderr, "bound parent identity changed\n");
        close(parent_fd);
        return 70;
    }
    if (fstatat(parent_fd, argv[6], &source_stat, AT_SYMLINK_NOFOLLOW) != 0 ||
        S_ISLNK(source_stat.st_mode) || !S_ISDIR(source_stat.st_mode)) {
        fprintf(stderr, "source is not a real directory\n");
        close(parent_fd);
        return 70;
    }
    if ((unsigned long long)source_stat.st_dev != expected_source_dev ||
        (unsigned long long)source_stat.st_ino != expected_source_ino) {
        fprintf(stderr, "source identity changed\n");
        close(parent_fd);
        return 70;
    }
    source_fd = openat(parent_fd, argv[6], O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (source_fd < 0 || fstat(source_fd, &source_opened) != 0 ||
        !S_ISDIR(source_opened.st_mode) ||
        !identity_matches(&source_opened, expected_source_dev, expected_source_ino) ||
        fstatat(parent_fd, argv[6], &source_stat, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(source_stat.st_mode) ||
        !identity_matches(&source_stat, expected_source_dev, expected_source_ino)) {
        if (source_fd >= 0) {
            close(source_fd);
        }
        close(parent_fd);
        return 70;
    }
    destination_status = fstatat(parent_fd, argv[7], &destination_stat, AT_SYMLINK_NOFOLLOW);
    if (destination_status == 0) {
        close(source_fd);
        close(parent_fd);
        return 17;
    }
    if (errno != ENOENT) {
        close(source_fd);
        close(parent_fd);
        return 70;
    }
    if (fstatat(parent_fd, argv[6], &source_stat, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(source_stat.st_mode) ||
        !identity_matches(&source_stat, expected_source_dev, expected_source_ino) ||
        fstat(source_fd, &source_opened) != 0 ||
        !identity_matches(&source_opened, expected_source_dev, expected_source_ino)) {
        close(source_fd);
        close(parent_fd);
        return 70;
    }
    if (renameatx_np(parent_fd, argv[6], parent_fd, argv[7],
                    RENAME_EXCL | RENAME_NOFOLLOW_ANY) != 0) {
        int status = errno == EEXIST ? 17 : 70;
        if (status != 17) {
            perror("renameatx_np");
        }
        close(source_fd);
        close(parent_fd);
        return status;
    }
    if (fstat(parent_fd, &parent_stat) != 0 ||
        !identity_matches(&parent_stat, expected_dev, expected_ino) ||
        fstatat(parent_fd, argv[7], &destination_stat, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(destination_stat.st_mode) ||
        !identity_matches(&destination_stat, expected_source_dev, expected_source_ino)) {
        close(source_fd);
        close(parent_fd);
        return 70;
    }
    close(source_fd);
    close(parent_fd);
    return 0;
}
C_SOURCE
    xcrun clang -O2 -Wall -Wextra -Werror "$RENAME_HELPER_SOURCE" -o "$RENAME_HELPER" || \
        fail "could not compile the bound atomic rename helper."
    [[ -x "$RENAME_HELPER" ]] || fail "bound atomic rename helper is unavailable."
}

atomic_rename_excl()
{
    local source_name="$1"
    local destination_name="$2"
    local source_key="${3:-}"
    local source_dev source_ino rename_status
    [[ -x "$RENAME_HELPER" && -n "$PARENT_DEV" && -n "$PARENT_INO" ]] || return 70
    [[ "$source_name" != "" && "$destination_name" != "" && "$source_name" != */* && "$destination_name" != */* ]] || return 70
    [[ "$source_name" != "." && "$source_name" != ".." && "$destination_name" != "." && "$destination_name" != ".." ]] || return 70
    [[ -n "$source_key" ]] || return 70
    source_dev="${source_key%%:*}"
    source_ino="${source_key##*:}"
    [[ "$source_dev" != "$source_key" && "$source_ino" != "$source_key" && -n "$source_dev" && -n "$source_ino" ]] || return 70
    if "$RENAME_HELPER" "$OUTPUT_PARENT_REAL" "$PARENT_DEV" "$PARENT_INO" "$source_dev" "$source_ino" "$source_name" "$destination_name"; then
        return 0
    else
        rename_status=$?
        return "$rename_status"
    fi
}

atomic_mkdir_excl()
{
    local name="$1"
    local mkdir_status
    [[ -x "$RENAME_HELPER" && -n "$PARENT_DEV" && -n "$PARENT_INO" ]] || return 70
    [[ "$name" != "" && "$name" != */* && "$name" != "." && "$name" != ".." ]] || return 70
    if "$RENAME_HELPER" --mkdir "$OUTPUT_PARENT_REAL" "$PARENT_DEV" "$PARENT_INO" "$name"; then
        return 0
    else
        mkdir_status=$?
        return "$mkdir_status"
    fi
}

bound_remove_tree_path()
{
    local parent_path="$1"
    local parent_device="$2"
    local parent_inode="$3"
    local target="$4"
    local expected_key="$5"
    local root_name root_device root_inode remove_status
    root_name="${target:t}"
    root_device="${expected_key%%:*}"
    root_inode="${expected_key##*:}"
    [[ "$target" == "$parent_path"/* && "$root_name" != "" && "$root_name" != "." && "$root_name" != ".." && "$root_name" != -* ]] || return 70
    [[ "$root_device" != "$expected_key" && "$root_inode" != "$expected_key" && -n "$root_device" && -n "$root_inode" ]] || return 70
    if "$RENAME_HELPER" --remove-tree "$parent_path" "$parent_device" "$parent_inode" "$root_name" "$root_device" "$root_inode"; then
        return 0
    else
        remove_status=$?
        return "$remove_status"
    fi
}

bound_copy_file_to_root()
{
    local source_path="$1"
    local destination_root="$2"
    local destination_name="$3"
    local expected_destination_parent_key="${4:-}"
    local expected_destination_root_key="${5:-}"
    local expected_source_parent_key="${6:-}"
    local expected_source_key="${7:-}"
    local destination_parent destination_parent_key destination_root_key
    local source_parent source_name source_parent_key source_key
    local destination_parent_device destination_parent_inode destination_root_name destination_root_device destination_root_inode
    local source_parent_device source_parent_inode source_device source_inode copy_status
    destination_parent="${destination_root:h}"
    destination_root_name="${destination_root:t}"
    destination_parent_key="$(stat -f '%d:%i' "$destination_parent" 2>/dev/null || true)"
    destination_root_key="$(stat -f '%d:%i' "$destination_root" 2>/dev/null || true)"
    source_parent="${source_path:h}"
    source_name="${source_path:t}"
    source_parent_key="$(stat -f '%d:%i' "$source_parent" 2>/dev/null || true)"
    source_key="$(stat -f '%d:%i' "$source_path" 2>/dev/null || true)"
    destination_parent_device="${destination_parent_key%%:*}"
    destination_parent_inode="${destination_parent_key##*:}"
    destination_root_device="${destination_root_key%%:*}"
    destination_root_inode="${destination_root_key##*:}"
    [[ -n "$expected_destination_parent_key" ]] || expected_destination_parent_key="$destination_parent_key"
    [[ -n "$expected_destination_root_key" ]] || expected_destination_root_key="$destination_root_key"
    [[ -n "$expected_source_parent_key" ]] || expected_source_parent_key="$source_parent_key"
    [[ -n "$expected_source_key" ]] || expected_source_key="$source_key"
    [[ "$destination_parent_key" == "$expected_destination_parent_key" && "$destination_root_key" == "$expected_destination_root_key" ]] || return 70
    [[ "$source_parent_key" == "$expected_source_parent_key" && "$source_key" == "$expected_source_key" ]] || return 70
    destination_parent_device="${expected_destination_parent_key%%:*}"
    destination_parent_inode="${expected_destination_parent_key##*:}"
    destination_root_device="${expected_destination_root_key%%:*}"
    destination_root_inode="${expected_destination_root_key##*:}"
    source_parent_device="${expected_source_parent_key%%:*}"
    source_parent_inode="${expected_source_parent_key##*:}"
    source_device="${expected_source_key%%:*}"
    source_inode="${expected_source_key##*:}"
    [[ -f "$source_path" && ! -L "$source_path" && -d "$destination_root" && ! -L "$destination_root" ]] || return 70
    [[ "$destination_root" == "${destination_root:A}" && "$destination_parent" == "${destination_parent:A}" ]] || return 70
    path_has_symlink "$destination_root" && return 70
    [[ "$destination_parent_device" != "$destination_parent_key" && "$destination_parent_inode" != "$destination_parent_key" && -n "$destination_parent_device" && -n "$destination_parent_inode" ]] || return 70
    [[ "$destination_root_device" != "$destination_root_key" && "$destination_root_inode" != "$destination_root_key" && -n "$destination_root_device" && -n "$destination_root_inode" ]] || return 70
    [[ "$source_parent_device" != "$source_parent_key" && "$source_parent_inode" != "$source_parent_key" && -n "$source_parent_device" && -n "$source_parent_inode" ]] || return 70
    [[ "$source_device" != "$source_key" && "$source_inode" != "$source_key" && -n "$source_device" && -n "$source_inode" ]] || return 70
    if "$RENAME_HELPER" --copy-file "$destination_parent" "$destination_parent_device" "$destination_parent_inode" "$destination_root_name" "$destination_root_device" "$destination_root_inode" "$destination_name" "$source_parent" "$source_parent_device" "$source_parent_inode" "$source_name" "$source_device" "$source_inode"; then
        return 0
    else
        copy_status=$?
        return "$copy_status"
    fi
}

bound_copy_file()
{
    bound_copy_file_to_root "$1" "$STAGE_ROOT" "$2" "$PARENT_KEY" "$STAGE_KEY"
}

snapshot_tree_hash()
{
    local root="$1"
    python3 - "$root" <<'PY'
import hashlib
import os
import stat
import sys

root = os.path.abspath(sys.argv[1])
if not os.path.isdir(root) or os.path.islink(root):
    raise SystemExit("snapshot root is not a real directory")
entries = []
for directory, names, files in os.walk(root, topdown=True, followlinks=False):
    names.sort()
    files.sort()
    for name in names + files:
        path = os.path.join(directory, name)
        relative = os.path.relpath(path, root).replace(os.sep, "/")
        entries.append((relative, path))
digest = hashlib.sha256()
root_stat = os.lstat(root)
digest.update(b"D\0.\0" + str(stat.S_IMODE(root_stat.st_mode)).encode() + b"\0")
for relative, path in sorted(entries):
    value = os.lstat(path)
    mode = stat.S_IMODE(value.st_mode)
    if stat.S_ISLNK(value.st_mode):
        kind = b"L"
        payload = os.readlink(path).encode("utf-8", "surrogateescape")
    elif stat.S_ISREG(value.st_mode):
        kind = b"F"
        with open(path, "rb") as source:
            payload = source.read()
    elif stat.S_ISDIR(value.st_mode):
        kind = b"D"
        payload = b""
    else:
        raise SystemExit(f"unsupported snapshot entry: {relative}")
    digest.update(kind + b"\0" + relative.encode("utf-8", "surrogateescape") + b"\0")
    digest.update(str(mode).encode() + b"\0" + payload + b"\0")
print(digest.hexdigest())
PY
}

snapshot_source_inputs()
{
    local source_path="$1"
    local destination_path="$2"
    local expected_hash="$3"
    local source_parent source_name source_parent_key source_key
    source_parent="${source_path:h}"
    source_name="${source_path:t}"
    source_parent_key="$(stat -f '%d:%i' "$source_parent" 2>/dev/null || true)"
    source_key="$(stat -f '%d:%i' "$source_path" 2>/dev/null || true)"
    [[ -f "$source_path" && ! -L "$source_path" ]] || fail "approved source changed before snapshot."
    [[ -n "$source_parent_key" && -n "$source_key" ]] || fail "approved source identity is unavailable."
    bound_copy_file_to_root "$source_path" "$TEMP_ROOT" "${destination_path:t}" "$TEMP_PARENT_KEY" "$TEMP_ROOT_KEY" "$source_parent_key" "$source_key" || \
        fail "could not create the immutable source snapshot."
    [[ -f "$destination_path" && ! -L "$destination_path" ]] || fail "source snapshot is not a regular file."
    [[ "$(shasum -a 256 "$destination_path" | awk '{ print $1 }')" == "$expected_hash" ]] || fail "source snapshot hash does not match its approved pin."
    chmod 0444 "$destination_path" || fail "could not make the source snapshot read-only."
    chflags uchg "$destination_path" || fail "could not make the source snapshot immutable."
    [[ "$(stat -f '%d:%i' "$destination_path" 2>/dev/null || true)" != "" ]] || fail "source snapshot identity is unavailable."
}

verify_source_snapshots()
{
    verify_one_source_snapshot()
    {
        local source_path="$1"
        local expected_key="$2"
        local expected_hash="$3"
        [[ -f "$source_path" && ! -L "$source_path" ]] || fail "immutable source snapshot disappeared."
        [[ "$(stat -f '%d:%i' "$source_path" 2>/dev/null || true)" == "$expected_key" ]] || fail "immutable source snapshot identity changed."
        [[ "$(shasum -a 256 "$source_path" | awk '{ print $1 }')" == "$expected_hash" ]] || fail "immutable source snapshot bytes changed."
    }
    verify_one_source_snapshot "$OBJC_SOURCE_SNAPSHOT" "$OBJC_SOURCE_SNAPSHOT_KEY" "$EXPECTED_OBJC_SOURCE_SHA"
    verify_one_source_snapshot "$SWIFT_CLIENT_SOURCE_SNAPSHOT" "$SWIFT_CLIENT_SOURCE_SNAPSHOT_KEY" "$EXPECTED_SWIFT_CLIENT_SHA"
    verify_one_source_snapshot "$SWIFT_MAIN_SOURCE_SNAPSHOT" "$SWIFT_MAIN_SOURCE_SNAPSHOT_KEY" "$EXPECTED_SWIFT_MAIN_SHA"
}

snapshot_base_input()
{
    [[ -d "$BASE_ORIGINAL_APP" && ! -L "$BASE_ORIGINAL_APP" ]] || fail "official AltServer.app input not found."
    [[ "$BASE_ORIGINAL_APP" == "${BASE_ORIGINAL_APP:A}" ]] || fail "official AltServer.app input path aliases through a symlink."
    path_has_symlink "$BASE_ORIGINAL_APP" && fail "official AltServer.app input path contains a symlink."
    BASE_ORIGINAL_KEY="$(stat -f '%d:%i' "$BASE_ORIGINAL_APP" 2>/dev/null || true)"
    [[ -n "$BASE_ORIGINAL_KEY" ]] || fail "official AltServer.app input identity is unavailable."
    BASE_INPUT_SNAPSHOT_HASH="$(snapshot_tree_hash "$BASE_ORIGINAL_APP")" || fail "could not snapshot official AltServer.app input."
    [[ ! -e "$BASE_INPUT_APP" && ! -L "$BASE_INPUT_APP" ]] || fail "private official input destination already exists."
    ditto --norsrc --noextattr --noqtn "$BASE_ORIGINAL_APP" "$BASE_INPUT_APP"
    [[ -d "$BASE_INPUT_APP" && ! -L "$BASE_INPUT_APP" ]] || fail "private official input copy is missing."
    [[ "$(stat -f '%d:%i' "$BASE_ORIGINAL_APP" 2>/dev/null || true)" == "$BASE_ORIGINAL_KEY" ]] || fail "official AltServer.app input changed during snapshot."
    [[ "$(snapshot_tree_hash "$BASE_ORIGINAL_APP")" == "$BASE_INPUT_SNAPSHOT_HASH" ]] || fail "official AltServer.app input contents changed during snapshot."
    [[ "$(snapshot_tree_hash "$BASE_INPUT_APP")" == "$BASE_INPUT_SNAPSHOT_HASH" ]] || fail "private official input copy is contaminated."
    BASE_APP="$BASE_INPUT_APP"
    PLIST="$BASE_APP/Contents/Info.plist"
    [[ "$(stat -f '%d:%i' "$BASE_ORIGINAL_APP" 2>/dev/null || true)" == "$BASE_ORIGINAL_KEY" ]] || fail "official AltServer.app input changed after snapshot."
}

verify_base_input_snapshot()
{
    [[ "$(stat -f '%d:%i' "$BASE_ORIGINAL_APP" 2>/dev/null || true)" == "$BASE_ORIGINAL_KEY" ]] || fail "official AltServer.app input changed after its private snapshot."
    [[ "$(snapshot_tree_hash "$BASE_ORIGINAL_APP")" == "$BASE_INPUT_SNAPSHOT_HASH" ]] || fail "official AltServer.app input contents changed after its private snapshot."
    [[ "$(snapshot_tree_hash "$BASE_APP")" == "$BASE_INPUT_SNAPSHOT_HASH" ]] || fail "private official input snapshot changed."
}

bound_lock_init()
{
    local lock_dev lock_ino born init_status
    lock_dev="${LOCK_DIR_KEY%%:*}"
    lock_ino="${LOCK_DIR_KEY##*:}"
    born="$(date +%s)"
    [[ "$lock_dev" != "$LOCK_DIR_KEY" && "$lock_ino" != "$LOCK_DIR_KEY" && -n "$lock_dev" && -n "$lock_ino" ]] || return 70
    if "$RENAME_HELPER" --lock-init "$OUTPUT_PARENT_REAL" "$PARENT_DEV" "$PARENT_INO" "$LOCK_NAME" "$lock_dev" "$lock_ino" "$$" "$PARENT_KEY" "$born"; then
        return 0
    else
        init_status=$?
        return "$init_status"
    fi
}

bound_lock_release_named()
{
    local name="$1"
    local directory_key="$2"
    local lock_dev lock_ino release_status
    lock_dev="${directory_key%%:*}"
    lock_ino="${directory_key##*:}"
    [[ "$lock_dev" != "$directory_key" && "$lock_ino" != "$directory_key" && -n "$lock_dev" && -n "$lock_ino" ]] || return 70
    if "$RENAME_HELPER" --lock-release "$OUTPUT_PARENT_REAL" "$PARENT_DEV" "$PARENT_INO" "$name" "$lock_dev" "$lock_ino"; then
        return 0
    else
        release_status=$?
        return "$release_status"
    fi
}

bound_lock_release()
{
    bound_lock_release_named "$LOCK_NAME" "$LOCK_DIR_KEY"
}

acquire_transaction_lock()
{
    local owner_key owner_pid owner_parent owner_born now stale_name stale_path stale_key
    LOCK_NAME=".altserver-release-${OUTPUT_NAME}.lock"
    LOCK_PATH="$OUTPUT_PARENT_REAL/$LOCK_NAME"
    recovery_parent_ok || fail "output parent is not stable before acquiring the release lock."
    if atomic_mkdir_excl "$LOCK_NAME"; then
        LOCK_DIR_KEY="$(stat -f '%d:%i' "$LOCK_PATH" 2>/dev/null || true)"
        [[ -n "$LOCK_DIR_KEY" ]] || fail "release lock identity unavailable."
        LOCK_HELD=1
        bound_lock_init || fail "could not initialize the bound release lock metadata."
        [[ ! -L "$LOCK_PATH/pid" && ! -L "$LOCK_PATH/parent" && ! -L "$LOCK_PATH/born" ]] || fail "release lock metadata became a symlink."
        return 0
    fi
    [[ -d "$LOCK_PATH" && ! -L "$LOCK_PATH" ]] || fail "release lock path is occupied by a non-directory."
    owner_key="$(stat -f '%d:%i' "$LOCK_PATH" 2>/dev/null || true)"
    [[ -n "$owner_key" ]] || fail "existing release lock identity is unavailable."
    [[ -f "$LOCK_PATH/pid" && ! -L "$LOCK_PATH/pid" && -f "$LOCK_PATH/parent" && ! -L "$LOCK_PATH/parent" && -f "$LOCK_PATH/born" && ! -L "$LOCK_PATH/born" ]] || \
        fail "existing release lock metadata is incomplete; it was preserved."
    owner_pid="$(< "$LOCK_PATH/pid")"
    owner_parent="$(< "$LOCK_PATH/parent")"
    owner_born="$(< "$LOCK_PATH/born")"
    /usr/bin/grep -Eq '^[0-9]+$' <<< "$owner_pid" || fail "existing release lock PID is invalid; it was preserved."
    /usr/bin/grep -Eq '^[0-9]+:[0-9]+$' <<< "$owner_parent" || fail "existing release lock parent identity is invalid; it was preserved."
    /usr/bin/grep -Eq '^[0-9]+$' <<< "$owner_born" || fail "existing release lock timestamp is invalid; it was preserved."
    [[ "$owner_parent" == "$PARENT_KEY" ]] || fail "existing release lock belongs to another output parent; it was preserved."
    now="$(date +%s)"
    (( now >= owner_born && now - owner_born >= LOCK_STALE_AFTER_SECONDS )) || fail "release lock is active or too young to reclaim."
    if kill -0 "$owner_pid" 2>/dev/null; then
        fail "release lock owner PID $owner_pid is still running."
    fi
    stale_name="${LOCK_NAME}.stale.${PUBLISH_NONCE}"
    stale_path="$OUTPUT_PARENT_REAL/$stale_name"
    [[ ! -e "$stale_path" && ! -L "$stale_path" ]] || fail "stale release lock quarantine path already exists."
    atomic_rename_excl "$LOCK_NAME" "$stale_name" "$owner_key" || fail "release lock changed while reclaiming; it was preserved."
    stale_key="$(stat -f '%d:%i' "$stale_path" 2>/dev/null || true)"
    bound_lock_release_named "$stale_name" "$stale_key" || fail "stale release lock was quarantined but could not be removed."
    [[ ! -e "$stale_path" && ! -L "$stale_path" ]] || fail "stale release lock quarantine remained."
    atomic_mkdir_excl "$LOCK_NAME" || fail "could not acquire release lock after stale-lock reclamation."
    LOCK_DIR_KEY="$(stat -f '%d:%i' "$LOCK_PATH" 2>/dev/null || true)"
    [[ -n "$LOCK_DIR_KEY" ]] || fail "release lock identity unavailable after reclamation."
    LOCK_HELD=1
    bound_lock_init || fail "could not initialize the bound release lock metadata after reclamation."
}

release_transaction_lock()
{
    [[ "$LOCK_HELD" == "1" ]] || return 0
    recovery_parent_ok || return 1
    [[ -d "$LOCK_PATH" && ! -L "$LOCK_PATH" && "$(stat -f '%d:%i' "$LOCK_PATH" 2>/dev/null || true)" == "$LOCK_DIR_KEY" ]] || return 1
    [[ -f "$LOCK_PATH/pid" && ! -L "$LOCK_PATH/pid" && "$(< "$LOCK_PATH/pid")" == "$$" ]] || return 1
    [[ -f "$LOCK_PATH/parent" && ! -L "$LOCK_PATH/parent" && "$(< "$LOCK_PATH/parent")" == "$PARENT_KEY" ]] || return 1
    [[ -f "$LOCK_PATH/born" && ! -L "$LOCK_PATH/born" ]] || return 1
    bound_lock_release || return 1
    [[ ! -e "$LOCK_PATH" && ! -L "$LOCK_PATH" ]] || return 1
    LOCK_HELD=0
    return 0
}

recovery_path_ok()
{
    local path="$1"
    [[ "$path" == /* && "$path" != "/" ]] || return 1
    [[ "${path:t}" != "" && "${path:t}" != "." && "${path:t}" != ".." && "${path:t}" != -* ]] || return 1
    [[ "$path:h" == "$OUTPUT_PARENT_REAL" ]] || return 1
    [[ "$path" == "$OUTPUT_REAL" || "$path" == "$OLD_ROOT" || "$path" == "$FAILED_ROOT" ]] || return 1
    [[ "$path" == "${path:A}" ]] || return 1
    path_has_symlink "$path" && return 1
    return 0
}

recovery_rename()
{
    local phase="$1"
    local source="$2"
    local destination="$3"
    local expected_key="${4:-}"
    local move_status
    recovery_parent_ok || return 70
    recovery_path_ok "$source" || return 70
    recovery_path_ok "$destination" || return 70
    [[ -d "$source" && ! -L "$source" ]] || return 70
    [[ ! -e "$destination" && ! -L "$destination" ]] || return 70
    [[ "$(stat -f '%d' "$source" 2>/dev/null || true)" == "$(stat -f '%d' "$OUTPUT_PARENT_REAL" 2>/dev/null || true)" ]] || return 70
    [[ -n "$expected_key" && "$(stat -f '%d:%i' "$source" 2>/dev/null || true)" == "$expected_key" ]] || return 70
    if fault_enabled "$phase"; then
        return 75
    fi
    atomic_rename_excl "${source:t}" "${destination:t}" "$expected_key"
    move_status=$?
    (( move_status == 0 )) || return "$move_status"
    # Verify the rename landed at the intended canonical sibling and retained
    # the exact source inode.  A failed post-check leaves both recovery paths.
    recovery_parent_ok || return 70
    recovery_path_ok "$destination" || return 70
    [[ ! -e "$source" && ! -L "$source" ]] || return 70
    [[ -d "$destination" && ! -L "$destination" ]] || return 70
    [[ "$(stat -f '%d:%i' "$destination" 2>/dev/null || true)" == "$expected_key" ]] || return 70
    return 0
}

report_recovery_failure()
{
    RECOVERY_FAILED=1
    echo "build_release: transaction recovery failed: $1" >&2
    echo "build_release: recoverable paths: output=${OUTPUT_REAL:-<unavailable>} old=${OLD_ROOT:-<unavailable>} failed=${FAILED_ROOT:-<none>}" >&2
}

cleanup_transaction()
{
    local exit_code=$?
    if [[ "$CLEANUP_RUNNING" == "1" ]]; then
        return "$exit_code"
    fi
    CLEANUP_RUNNING=1
    set +e
    if [[ "$TRANSACTION_ACTIVE" == "1" ]]; then
        # If the new tree was renamed into place but a later validation or
        # cleanup failed, move it aside and restore the complete old tree.
        if [[ "$NEW_MOVED" == "1" ]]; then
            FAILED_ROOT="$OUTPUT_PARENT_REAL/.altserver-release-${OUTPUT_NAME}.v3.7-failed.$PUBLISH_NONCE"
            if [[ -e "$OUTPUT_REAL" || -L "$OUTPUT_REAL" ]] && recovery_rename mv-new-aside "$OUTPUT_REAL" "$FAILED_ROOT" "$STAGE_MOVE_KEY"; then
                NEW_MOVED=0
                FAILED_KEY="$(stat -f '%d:%i' "$FAILED_ROOT" 2>/dev/null || true)"
            else
                report_recovery_failure "could not move the published new tree aside before rollback"
            fi
        fi
        if [[ "$RECOVERY_FAILED" == "0" && "$OLD_MOVED" == "1" ]]; then
            if [[ -d "$OLD_ROOT" && ! -L "$OLD_ROOT" && ! -e "$OUTPUT_REAL" && ! -L "$OUTPUT_REAL" ]] && recovery_rename mv-old-restore "$OLD_ROOT" "$OUTPUT_REAL" "$OUTPUT_MOVE_KEY"; then
                OLD_MOVED=0
            else
                report_recovery_failure "could not restore the previous tree to the output path"
            fi
        fi
        if [[ "$RECOVERY_FAILED" == "0" && -n "$FAILED_ROOT" && ( -e "$FAILED_ROOT" || -L "$FAILED_ROOT" ) ]]; then
            if ! recovery_parent_ok || ! safe_remove_transaction_path "$FAILED_ROOT" "$FAILED_KEY" >/dev/null 2>&1; then
                report_recovery_failure "could not remove the rolled-back failed tree"
            fi
        fi
    fi
    if [[ -n "$STAGE_ROOT" && ( -e "$STAGE_ROOT" || -L "$STAGE_ROOT" ) ]]; then
        if recovery_parent_ok && safe_remove_transaction_path "$STAGE_ROOT" "$STAGE_KEY" >/dev/null 2>&1; then
            :
        else
            report_recovery_failure "could not remove the release staging tree; it was preserved"
        fi
    fi
    if [[ "$LOCK_HELD" == "1" ]]; then
        if ! release_transaction_lock; then
            report_recovery_failure "could not release the exclusive release lock; it was preserved"
        fi
    fi
    if [[ "$RECOVERY_FAILED" == "0" && "$TEMP_ROOT" == /* && "$TEMP_ROOT" != "/" && "${TEMP_ROOT:t}" != "" && "${TEMP_ROOT:t}" != "." && "${TEMP_ROOT:t}" != ".." ]]; then
        if [[ -n "$TEMP_ROOT_KEY" && -n "$TEMP_PARENT_KEY" && ! -L "$TEMP_ROOT" && "$(stat -f '%d:%i' "$TEMP_ROOT" 2>/dev/null || true)" == "$TEMP_ROOT_KEY" && "$(stat -f '%d:%i' "$TEMP_PARENT_REAL" 2>/dev/null || true)" == "$TEMP_PARENT_KEY" ]]; then
            if ! bound_remove_tree_path "$TEMP_PARENT_REAL" "${TEMP_PARENT_KEY%%:*}" "${TEMP_PARENT_KEY##*:}" "$TEMP_ROOT" "$TEMP_ROOT_KEY"; then
                report_recovery_failure "could not remove the private build temporary tree; it was preserved"
            fi
        else
            report_recovery_failure "private build temporary tree identity changed; it was preserved"
        fi
    elif [[ "$RECOVERY_FAILED" != "0" && -n "$TEMP_ROOT" ]]; then
        echo "build_release: preserving temporary recovery tree: $TEMP_ROOT" >&2
    fi
    [[ "$RECOVERY_FAILED" == "0" ]] || exit_code=1
    exit "$exit_code"
}

trap cleanup_transaction EXIT

compile_bound_rename_helper
snapshot_source_inputs "$OBJC_SOURCE" "$OBJC_SOURCE_SNAPSHOT" "$EXPECTED_OBJC_SOURCE_SHA"
OBJC_SOURCE_SNAPSHOT_KEY="$(stat -f '%d:%i' "$OBJC_SOURCE_SNAPSHOT" 2>/dev/null || true)"
snapshot_source_inputs "$SWIFT_CLIENT_SOURCE" "$SWIFT_CLIENT_SOURCE_SNAPSHOT" "$EXPECTED_SWIFT_CLIENT_SHA"
SWIFT_CLIENT_SOURCE_SNAPSHOT_KEY="$(stat -f '%d:%i' "$SWIFT_CLIENT_SOURCE_SNAPSHOT" 2>/dev/null || true)"
snapshot_source_inputs "$SWIFT_MAIN_SOURCE" "$SWIFT_MAIN_SOURCE_SNAPSHOT" "$EXPECTED_SWIFT_MAIN_SHA"
SWIFT_MAIN_SOURCE_SNAPSHOT_KEY="$(stat -f '%d:%i' "$SWIFT_MAIN_SOURCE_SNAPSHOT" 2>/dev/null || true)"
verify_source_snapshots
snapshot_base_input
validate_official_input
MAIN_TEXT_HASH="$(text_hash "$BASE_APP/$MAIN_REL")"
[[ -n "$MAIN_TEXT_HASH" ]] || fail "could not fingerprint official AltServer code."

prepare_default_output_parent
validate_output_paths "$OUTPUT"
BASE_REAL="$(resolve_path "$BASE_APP")"
OUTPUT_REAL="$(resolve_path "$OUTPUT")"
if [[ -d "$OUTPUT_REAL" ]] && find -P "$OUTPUT_REAL" \( -path '*AltSign-Dynamic.framework' -o -name '*.ipa' -o -name 'AltServer-macOS27-v3.6*' \) -print -quit | /usr/bin/grep -q .; then
    fail "output contains stale v3.6, dynamic AltSign, or IPA artifacts."
fi
validate_output_paths "$OUTPUT"
OUTPUT_REAL="$(resolve_path "$OUTPUT")"
OUTPUT_PARENT_REAL="${OUTPUT_REAL:h}"
OUTPUT_NAME="${OUTPUT_REAL:t}"
[[ "$OUTPUT_NAME" == "$RELEASE_DIR_NAME" ]] || fail "output directory must be named $RELEASE_DIR_NAME."
if [[ -e "$OUTPUT_REAL" || -L "$OUTPUT_REAL" ]]; then
    validate_existing_release_schema "$OUTPUT_REAL" || fail "existing output is not an empty or valid v1.0.8 release."
    OUTPUT_PREEXISTING=1
    OUTPUT_INITIAL_KEY="$(stat -f '%d:%i' "$OUTPUT_REAL" 2>/dev/null || true)"
    [[ -n "$OUTPUT_INITIAL_KEY" ]] || fail "existing output identity unavailable."
fi
PUBLISH_NONCE="$(date -u +%Y%m%dT%H%M%SZ).$$.$RANDOM"
STAGE_ROOT="$OUTPUT_PARENT_REAL/.altserver-release-${OUTPUT_NAME}.v3.7-stage.$PUBLISH_NONCE"
OLD_ROOT="$OUTPUT_PARENT_REAL/.altserver-release-${OUTPUT_NAME}.v3.7-old.$PUBLISH_NONCE"
[[ "$STAGE_ROOT" != "$OLD_ROOT" && "$STAGE_ROOT" == "$OUTPUT_PARENT_REAL"/.altserver-release-* && "$OLD_ROOT" == "$OUTPUT_PARENT_REAL"/.altserver-release-* ]] || fail "release transaction path is unsafe."
path_has_symlink "$STAGE_ROOT" && fail "release staging path aliases through a symlink."
path_has_symlink "$OLD_ROOT" && fail "release rollback path aliases through a symlink."
[[ ! -e "$STAGE_ROOT" && ! -L "$STAGE_ROOT" ]] || fail "release staging destination already exists."
[[ ! -e "$OLD_ROOT" && ! -L "$OLD_ROOT" ]] || fail "release rollback destination already exists."
PARENT_KEY="$(stat -f '%d:%i' "$OUTPUT_PARENT_REAL" 2>/dev/null || true)"
[[ -n "$PARENT_KEY" ]] || fail "output parent identity unavailable."
PARENT_DEV="${PARENT_KEY%%:*}"
PARENT_INO="${PARENT_KEY##*:}"
[[ "$PARENT_DEV" != "$PARENT_KEY" && "$PARENT_INO" != "$PARENT_KEY" && -n "$PARENT_DEV" && -n "$PARENT_INO" ]] || fail "output parent device/inode is unavailable."
acquire_transaction_lock
[[ ! -e "$STAGE_ROOT" && ! -L "$STAGE_ROOT" && ! -e "$OLD_ROOT" && ! -L "$OLD_ROOT" ]] || fail "release transaction sibling paths appeared while acquiring the lock."
TRANSACTION_ACTIVE=1
atomic_mkdir_excl "${STAGE_ROOT:t}" || fail "could not create release staging tree inside the bound output parent."
STAGE_KEY="$(stat -f '%d:%i' "$STAGE_ROOT" 2>/dev/null || true)"
[[ -n "$STAGE_KEY" ]] || fail "release staging identity unavailable."
STAGE_MOVE_KEY="$STAGE_KEY"
[[ "$(stat -f '%d' "$STAGE_ROOT" 2>/dev/null || true)" == "$(stat -f '%d' "$OUTPUT_PARENT_REAL" 2>/dev/null || true)" ]] || fail "release staging is not on the output filesystem."

# Every final artifact is built in this complete sibling tree.  No final
# output path is written until the single directory rename transaction.
PAYLOAD_ZIP="$STAGE_ROOT/AltServer-macOS27-v3.7.zip"
EXECUTABLE_MANIFEST="$STAGE_ROOT/AltServer-macOS27-v3.7.executables.txt"
METADATA="$STAGE_ROOT/BUILD-METADATA.txt"
CHECKSUMS="$STAGE_ROOT/CHECKSUMS-SHA256.txt"
validate_output_paths "$OUTPUT"
ZIP_STAGE="$TEMP_ROOT/AltServer-macOS27-v3.7.zip"
APP_STAGE="$TEMP_ROOT/Output-AltServer.app"
METADATA_SOURCE=""
CHECKSUMS_SOURCE=""

CLANG_REMAP_FLAGS=(
    "-fdebug-prefix-map=$SOURCE_ROOT=/src/altserver-macos27-anisette-fix"
    "-ffile-prefix-map=$SOURCE_ROOT=/src/altserver-macos27-anisette-fix"
    "-fmacro-prefix-map=$SOURCE_ROOT=/src/altserver-macos27-anisette-fix"
    "-fdebug-prefix-map=/Users=/src/users"
    "-ffile-prefix-map=/Users=/src/users"
    "-fmacro-prefix-map=/Users=/src/users"
    "-fdebug-prefix-map=$PRIVATE_TMP_ROOT=/src/tmp"
    "-ffile-prefix-map=$PRIVATE_TMP_ROOT=/src/tmp"
    "-fmacro-prefix-map=$PRIVATE_TMP_ROOT=/src/tmp"
    "-fdebug-prefix-map=/Volumes/data=/src/volumes"
    "-ffile-prefix-map=/Volumes/data=/src/volumes"
    "-fmacro-prefix-map=/Volumes/data=/src/volumes"
    "-fdebug-prefix-map=/private/var=/src/tmp"
    "-ffile-prefix-map=/private/var=/src/tmp"
    "-fmacro-prefix-map=/private/var=/src/tmp"
)

extract_lc_uuid()
{
    local binary="$1"
    python3 - "$binary" <<'PY'
import re
import subprocess
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    result = subprocess.run(
        ["otool", "-arch", "arm64", "-l", str(path)],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
except (OSError, subprocess.CalledProcessError) as error:
    detail = getattr(error, "stderr", "") or str(error)
    raise SystemExit(f"cannot inspect LC_UUID ({detail.strip()})")

uuid_commands = 0
uuid_values = []
in_uuid_command = False
for line in result.stdout.splitlines():
    fields = line.strip().split()
    if not fields:
        continue
    if fields[0] == "Load" and len(fields) >= 2 and fields[1] == "command":
        in_uuid_command = False
        continue
    if fields[0] == "cmd":
        in_uuid_command = len(fields) >= 2 and fields[1] == "LC_UUID"
        if in_uuid_command:
            uuid_commands += 1
        continue
    if in_uuid_command and fields[0] == "uuid" and len(fields) == 2:
        uuid_values.append(fields[1])

if uuid_commands != 1 or len(uuid_values) != 1:
    raise SystemExit(
        f"expected exactly one LC_UUID/uuid pair, found {uuid_commands}/{len(uuid_values)}"
    )
value = uuid_values[0]
if not re.fullmatch(r"[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}", value):
    raise SystemExit(f"invalid LC_UUID format: {value!r}")
if not any(byte != 0 for byte in bytes.fromhex(value.replace("-", ""))):
    raise SystemExit("LC_UUID is all zeroes")
print(value.lower())
PY
}

patch_deterministic_lc_uuid()
{
    local binary="$1"
    shift
    python3 - "$binary" "$@" <<'PY'
import hashlib
import struct
import sys
import uuid
from pathlib import Path

path = Path(sys.argv[1])
materials = sys.argv[2:]
original = path.read_bytes()
data = bytearray(original)
if len(data) < 32:
    raise SystemExit("Mach-O is truncated before mach_header_64")
magic_le = struct.unpack_from("<I", data, 0)[0]
if magic_le == 0xfeedfacf:
    endian = "<"
elif magic_le == 0xcffaedfe:
    endian = ">"
else:
    raise SystemExit("expected a thin arm64 MH_MAGIC_64/MH_CIGAM_64 image")
magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, reserved = struct.unpack_from(
    endian + "IiiIIIII", data, 0
)
if magic not in (0xfeedfacf, 0xcffaedfe) or cputype != 0x0100000c:
    raise SystemExit("unexpected Mach-O magic or CPU type")
load_start = 32
load_end = load_start + sizeofcmds
if load_end < load_start or load_end > len(data):
    raise SystemExit("Mach-O load-command region is truncated")
cursor = load_start
uuid_offsets = []
for _ in range(ncmds):
    if cursor + 8 > load_end:
        raise SystemExit("Mach-O load command header is truncated")
    command, command_size = struct.unpack_from(endian + "II", data, cursor)
    if command_size < 8 or cursor + command_size > load_end:
        raise SystemExit("Mach-O load command size is invalid")
    if command == 0x1B:
        if command_size != 24:
            raise SystemExit("LC_UUID command size is not exactly 24")
        uuid_offsets.append(cursor + 8)
    cursor += command_size
if cursor != load_end:
    raise SystemExit("Mach-O load-command bytes do not match sizeofcmds")
if len(uuid_offsets) != 1:
    raise SystemExit(f"expected exactly one LC_UUID, found {len(uuid_offsets)}")
uuid_offset = uuid_offsets[0]
old_uuid = bytes(data[uuid_offset:uuid_offset + 16])
if len(old_uuid) != 16 or not any(old_uuid):
    raise SystemExit("linker LC_UUID is missing or all zeroes")
if not materials:
    raise SystemExit("UUID derivation material is missing")
derivation = hashlib.sha256()
derivation.update(b"altserver-macos27-anisette/lc-uuid/v1\0")
for material in materials:
    encoded = material.encode("utf-8", "strict")
    derivation.update(struct.pack(">I", len(encoded)))
    derivation.update(encoded)
new_uuid = bytearray(derivation.digest()[:16])
new_uuid[6] = (new_uuid[6] & 0x0F) | 0x50
new_uuid[8] = (new_uuid[8] & 0x3F) | 0x80
if not any(new_uuid):
    raise SystemExit("derived LC_UUID is all zeroes")
data[uuid_offset:uuid_offset + 16] = new_uuid
uuid_end = uuid_offset + 16
if len(data) != len(original):
    raise SystemExit("UUID patch changed file length")
changed = [index for index, (before, after) in enumerate(zip(original, data)) if before != after]
if any(index < uuid_offset or index >= uuid_end for index in changed):
    raise SystemExit("UUID patch changed bytes outside the existing LC_UUID payload")
if data[:uuid_offset] != original[:uuid_offset] or data[uuid_end:] != original[uuid_end:]:
    raise SystemExit("UUID patch changed bytes outside the existing LC_UUID payload")
if bytes(data[uuid_offset:uuid_end]) != bytes(new_uuid):
    raise SystemExit("UUID patch payload does not match the derived LC_UUID")
if bytes(data[uuid_offset:uuid_end]) == old_uuid:
    raise SystemExit("derived LC_UUID matches the existing LC_UUID")
path.write_bytes(data)
print(str(uuid.UUID(bytes=bytes(new_uuid))))
PY
}

validate_lc_uuid()
{
    extract_lc_uuid "$1" >/dev/null
}

remap_binary_paths()
{
    python3 - "$@" <<'PY'
import sys
from pathlib import Path

for raw in sys.argv[1:]:
    path = Path(raw)
    data = bytearray(path.read_bytes())
    changed = False
    for marker, replacement in (
        (b"/Users/", b"/src/u/anon/"),
        (b"/private/tmp/", b"/src/tmp_____"),
        (b"/private/var/", b"/src/tmp_____"),
        (b"/Volumes/data/", b"/src/volumes__"),
        (b"/src/altserver-macos27-anisette-fix/", b"/src/project/"),
    ):
        start = 0
        while True:
            offset = data.find(marker, start)
            if offset < 0:
                break
            end = data.find(b"\0", offset)
            if end < 0:
                break
            length = end - offset
            mapped = replacement[:length]
            if len(mapped) < length:
                mapped += b"_" * (length - len(mapped))
            data[offset:end] = mapped
            start = offset + len(mapped)
            changed = True
    if changed:
        path.write_bytes(data)
PY
}

xcrun swiftc -target arm64-apple-macos13.0 -O -parse-as-library -gnone \
    -debug-prefix-map "$SOURCE_ROOT=/src/altserver-macos27-anisette-fix" \
    -file-prefix-map "$SOURCE_ROOT=/src/altserver-macos27-anisette-fix" \
    -debug-prefix-map /Users=/src/users \
    -file-prefix-map /Users=/src/users \
    -debug-prefix-map "$PRIVATE_TMP_ROOT=/src/tmp" \
    -file-prefix-map "$PRIVATE_TMP_ROOT=/src/tmp" \
    -debug-prefix-map /Volumes/data=/src/volumes \
    -file-prefix-map /Volumes/data=/src/volumes \
    "$SWIFT_CLIENT_SOURCE_SNAPSHOT" \
    "$SWIFT_MAIN_SOURCE_SNAPSHOT" \
    -o "$HELPER_BUILD"

verify_source_snapshots

xcrun strip -S "$HELPER_BUILD"
remap_binary_paths "$HELPER_BUILD"
HELPER_UUID_DERIVATION_VERSION="lc-uuid-v1"
HELPER_UUID_INPUTS="label=helper-v1;SwiftClientSourceSHA256=$SWIFT_CLIENT_SHA256;SwiftMainSourceSHA256=$SWIFT_MAIN_SHA256;Target=arm64-apple-macos13.0;Optimization=-O;ParseAsLibrary=-parse-as-library;DebugInfo=-gnone;PrefixMaps=canonical"
HELPER_UUID="$(patch_deterministic_lc_uuid "$HELPER_BUILD" \
    "$HELPER_UUID_DERIVATION_VERSION" \
    "label=helper-v1" \
    "SwiftClientSourceSHA256=$SWIFT_CLIENT_SHA256" \
    "SwiftMainSourceSHA256=$SWIFT_MAIN_SHA256" \
    "Target=arm64-apple-macos13.0" \
    "Optimization=-O" \
    "ParseAsLibrary=-parse-as-library" \
    "DebugInfo=-gnone" \
    "PrefixMaps=canonical")" || fail "helper deterministic LC_UUID patch failed."
validate_lc_uuid "$HELPER_BUILD" || fail "helper deterministic LC_UUID is invalid before signing."
codesign --force --sign - "$HELPER_BUILD" >/dev/null
codesign --verify --strict "$HELPER_BUILD" >/dev/null
[[ "$(extract_lc_uuid "$HELPER_BUILD")" == "$HELPER_UUID" ]] || fail "helper LC_UUID changed during signing."
HELPER_SHA256="$(shasum -a 256 "$HELPER_BUILD" | awk '{ print $1 }')"
/usr/bin/grep -Eq '^[0-9a-fA-F]{64}$' <<< "$HELPER_SHA256" || fail "helper final SHA-256 is unavailable."

CPP_HELPER_SHA_DEFINE="-DALT_EXPECTED_HELPER_SHA256=\"${HELPER_SHA256}\""
xcrun clang -arch arm64 -dynamiclib -fobjc-arc -fblocks \
    -framework Foundation -framework Security \
    "$CPP_HELPER_SHA_DEFINE" \
    "${CLANG_REMAP_FLAGS[@]}" \
    -Wl,-install_name,@rpath/AltServerAnisetteFix.dylib \
    "$OBJC_SOURCE_SNAPSHOT" \
    -o "$DYLIB_BUILD"

verify_source_snapshots

xcrun strip -S "$DYLIB_BUILD"
remap_binary_paths "$DYLIB_BUILD"
DYLIB_UUID_DERIVATION_VERSION="lc-uuid-v1"
DYLIB_UUID_INPUTS="label=dylib-v1;ObjCSourceSHA256=$OBJC_SOURCE_SHA256;HelperSHA256=$HELPER_SHA256;Target=arm64;Flags=-fobjc-arc,-fblocks,-dynamiclib;Frameworks=Foundation,Security;InstallName=@rpath/AltServerAnisetteFix.dylib;PrefixMaps=canonical"
DYLIB_UUID="$(patch_deterministic_lc_uuid "$DYLIB_BUILD" \
    "$DYLIB_UUID_DERIVATION_VERSION" \
    "label=dylib-v1" \
    "ObjCSourceSHA256=$OBJC_SOURCE_SHA256" \
    "HelperSHA256=$HELPER_SHA256" \
    "Target=arm64" \
    "Flags=-fobjc-arc,-fblocks,-dynamiclib" \
    "Frameworks=Foundation,Security" \
    "InstallName=@rpath/AltServerAnisetteFix.dylib" \
    "PrefixMaps=canonical")" || fail "dylib deterministic LC_UUID patch failed."
validate_lc_uuid "$DYLIB_BUILD" || fail "dylib deterministic LC_UUID is invalid before signing."

if [[ "$(file -b "$HELPER_BUILD")" != *"arm64"* ]] || \
   [[ "$(file -b "$DYLIB_BUILD")" != *"arm64"* ]]; then
    fail "injected artifacts are not arm64."
fi
if [[ "$(lipo -archs "$HELPER_BUILD" 2>/dev/null)" != "arm64" ]] || \
   [[ "$(lipo -archs "$DYLIB_BUILD" 2>/dev/null)" != "arm64" ]]; then
    fail "injected artifacts must be arm64-only."
fi
if strings "$DYLIB_BUILD" | /usr/bin/grep -Eiq 'GsService2|gsa\.apple\.com|NSURLSession|User-Agent'; then
    fail "forbidden network hook strings found in the dylib."
fi
if nm -u "$DYLIB_BUILD" | /usr/bin/grep -Eiq 'GsService2|gsa\.apple\.com|NSURLSession|User-Agent'; then
    fail "forbidden network hook symbols found in the dylib."
fi
strings "$DYLIB_BUILD" | /usr/bin/grep -Fqx "$HELPER_SHA256" || fail "dylib does not contain the exact helper SHA macro value."
[[ "$DYLIB_UUID" != "$HELPER_UUID" ]] || fail "helper and dylib deterministic LC_UUID values must be distinct."
codesign --force --sign - "$DYLIB_BUILD" >/dev/null
codesign --verify --strict "$DYLIB_BUILD" >/dev/null
[[ "$(extract_lc_uuid "$DYLIB_BUILD")" == "$DYLIB_UUID" ]] || fail "dylib LC_UUID changed during signing."
DYLIB_SHA256="$(shasum -a 256 "$DYLIB_BUILD" | awk '{ print $1 }')"
validate_lc_uuid "$DYLIB_BUILD" || fail "dylib lost its valid nonzero LC_UUID after signing."
[[ "$(otool -D "$DYLIB_BUILD" | tail -1)" == "@rpath/AltServerAnisetteFix.dylib" ]] || fail "dylib install name is not relocatable."

ditto --norsrc --noextattr --noqtn "$BASE_APP" "$STAGED_APP"
mkdir -p "$STAGED_APP/Contents/Frameworks"
STAGED_FRAMEWORKS_ROOT="$STAGED_APP/Contents/Frameworks"
STAGED_FRAMEWORKS_PARENT_KEY="$(stat -f '%d:%i' "${STAGED_FRAMEWORKS_ROOT:h}" 2>/dev/null || true)"
STAGED_FRAMEWORKS_KEY="$(stat -f '%d:%i' "$STAGED_FRAMEWORKS_ROOT" 2>/dev/null || true)"
HELPER_SOURCE_PARENT_KEY="$(stat -f '%d:%i' "${HELPER_BUILD:h}" 2>/dev/null || true)"
HELPER_SOURCE_KEY="$(stat -f '%d:%i' "$HELPER_BUILD" 2>/dev/null || true)"
DYLIB_SOURCE_PARENT_KEY="$(stat -f '%d:%i' "${DYLIB_BUILD:h}" 2>/dev/null || true)"
DYLIB_SOURCE_KEY="$(stat -f '%d:%i' "$DYLIB_BUILD" 2>/dev/null || true)"
[[ -n "$STAGED_FRAMEWORKS_PARENT_KEY" && -n "$STAGED_FRAMEWORKS_KEY" && -n "$HELPER_SOURCE_PARENT_KEY" && -n "$HELPER_SOURCE_KEY" && -n "$DYLIB_SOURCE_PARENT_KEY" && -n "$DYLIB_SOURCE_KEY" ]] || fail "private framework/source identities are unavailable."
bound_copy_file_to_root "$HELPER_BUILD" "$STAGED_FRAMEWORKS_ROOT" "AltServerAnisetteHelper" "$STAGED_FRAMEWORKS_PARENT_KEY" "$STAGED_FRAMEWORKS_KEY" "$HELPER_SOURCE_PARENT_KEY" "$HELPER_SOURCE_KEY" || fail "could not copy helper through the descriptor-bound path."
bound_copy_file_to_root "$DYLIB_BUILD" "$STAGED_FRAMEWORKS_ROOT" "AltServerAnisetteFix.dylib" "$STAGED_FRAMEWORKS_PARENT_KEY" "$STAGED_FRAMEWORKS_KEY" "$DYLIB_SOURCE_PARENT_KEY" "$DYLIB_SOURCE_KEY" || fail "could not copy dylib through the descriptor-bound path."
[[ "$(shasum -a 256 "$STAGED_FRAMEWORKS_ROOT/AltServerAnisetteHelper" | awk '{ print $1 }')" == "$HELPER_SHA256" ]] || fail "descriptor-bound helper copy changed bytes."
[[ "$(shasum -a 256 "$STAGED_FRAMEWORKS_ROOT/AltServerAnisetteFix.dylib" | awk '{ print $1 }')" == "$DYLIB_SHA256" ]] || fail "descriptor-bound dylib copy changed bytes."
[[ "$(extract_lc_uuid "$STAGED_FRAMEWORKS_ROOT/AltServerAnisetteHelper")" == "$HELPER_UUID" ]] || fail "descriptor-bound helper copy changed UUID."
[[ "$(extract_lc_uuid "$STAGED_FRAMEWORKS_ROOT/AltServerAnisetteFix.dylib")" == "$DYLIB_UUID" ]] || fail "descriptor-bound dylib copy changed UUID."

/usr/libexec/PlistBuddy -c 'Delete :LSEnvironment' "$STAGED_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :LSEnvironment dict' "$STAGED_PLIST"
/usr/libexec/PlistBuddy -c 'Add :LSEnvironment:DYLD_INSERT_LIBRARIES string @executable_path/../Frameworks/AltServerAnisetteFix.dylib' "$STAGED_PLIST"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 1.7.6-macOS27-v3.7' "$STAGED_PLIST"
/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 94' "$STAGED_PLIST"

if find -P "$STAGED_APP" \( -name '*.mobileprovision' -o -name 'embedded.provisionprofile' \) -print -quit | grep -q .; then
    fail "profiles are not permitted in the ad-hoc staged output."
fi

while IFS= read -r -d '' code_object; do
    case "$code_object" in
        "$STAGED_APP/Contents/Frameworks/AltServerAnisetteHelper"|"$STAGED_APP/Contents/Frameworks/AltServerAnisetteFix.dylib")
            continue
            ;;
    esac
    codesign --remove-signature "$code_object" >/dev/null 2>&1 || true
done < <(find -P "$STAGED_APP" -type f -print0)

EMBEDDED_MANIFEST="$STAGED_APP/Contents/Resources/AltServer-macOS27-v3.7.executables.txt"
mkdir -p "${EMBEDDED_MANIFEST:h}"
python3 - "$STAGED_APP" "$EMBEDDED_MANIFEST" <<'PY'
import os
import stat
import sys
from pathlib import Path

root = Path(sys.argv[1])
manifest = Path(sys.argv[2])
entries = []
for path in sorted(root.rglob("*")):
    relative = path.relative_to(root).as_posix()
    if relative.startswith("__MACOSX/") or "/._" in relative or relative.startswith("._"):
        raise SystemExit(f"forbidden AppleDouble path: {relative}")
    if path.is_symlink():
        target = os.readlink(path)
        if os.path.isabs(target) or ".." in Path(target).parts or not path.exists():
            raise SystemExit(f"unsafe or dangling symlink: {relative}")
        continue
    if path.is_file() and stat.S_IMODE(path.stat().st_mode) & 0o111:
        entries.append((relative, stat.S_IMODE(path.stat().st_mode)))
manifest.write_text("".join(f"{mode:04o} {relative}\n" for relative, mode in entries), encoding="utf-8")
PY

# The copied official outer signature is invalid after the plist rewrite;
# remove only that container signature before re-signing the complete bundle.
codesign --remove-signature "$STAGED_APP" >/dev/null 2>&1 || true
# Nested helper/dylib signatures are finalized above; deep signing without
# --force preserves those bytes so the dylib's embedded helper hash remains
# the hash that ships in the final app.
codesign --deep --sign - "$STAGED_APP" >/dev/null
codesign --verify --deep --strict "$STAGED_APP" >/dev/null
[[ "$(shasum -a 256 "$STAGED_APP/Contents/Frameworks/AltServerAnisetteHelper" | awk '{ print $1 }')" == "$HELPER_SHA256" ]] || \
    fail "final embedded helper hash changed after app signing."
[[ "$(shasum -a 256 "$STAGED_APP/Contents/Frameworks/AltServerAnisetteFix.dylib" | awk '{ print $1 }')" == "$DYLIB_SHA256" ]] || \
    fail "final embedded dylib hash changed after app signing."
[[ "$(extract_lc_uuid "$STAGED_APP/Contents/Frameworks/AltServerAnisetteHelper")" == "$HELPER_UUID" ]] || \
    fail "final embedded helper UUID changed after app signing."
[[ "$(extract_lc_uuid "$STAGED_APP/Contents/Frameworks/AltServerAnisetteFix.dylib")" == "$DYLIB_UUID" ]] || \
    fail "final embedded dylib UUID changed after app signing."
STAGED_TEXT_HASH="$(text_hash "$STAGED_APP/$MAIN_REL")"
[[ "$STAGED_TEXT_HASH" == "$MAIN_TEXT_HASH" ]] || fail "official AltServer main code changed outside its signature."
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$STAGED_PLIST")" == "1.7.6-macOS27-v3.7" ]] || fail "staged version metadata is incorrect."
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$STAGED_PLIST")" == "94" ]] || fail "staged build metadata is incorrect."
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSEnvironment:DYLD_INSERT_LIBRARIES' "$STAGED_PLIST")" == "@executable_path/../Frameworks/AltServerAnisetteFix.dylib" ]] || fail "relative LSEnvironment is missing."

python3 - "$STAGED_APP" "$ZIP_STAGE" <<'PY'
import os
import stat
import sys
import zipfile
from pathlib import Path

root = Path(sys.argv[1])
destination = Path(sys.argv[2])
items = [root, *sorted(root.rglob("*"))]
with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as output:
    for path in items:
        name = path.relative_to(root.parent).as_posix()
        if path.is_symlink():
            target = os.readlink(path)
            if os.path.isabs(target) or ".." in Path(target).parts or not path.exists():
                raise SystemExit(f"unsafe or dangling symlink: {name}")
            info = zipfile.ZipInfo(name, date_time=(2000, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            output.writestr(info, target.encode("utf-8"))
        elif path.is_dir():
            info = zipfile.ZipInfo(name + "/", date_time=(2000, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IMODE(path.stat().st_mode) << 16) | 0x10
            output.writestr(info, b"")
        elif path.is_file():
            if "/._" in name or name.startswith("._") or name.startswith("__MACOSX/"):
                raise SystemExit(f"forbidden AppleDouble path: {name}")
            info = zipfile.ZipInfo(name, date_time=(2000, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = stat.S_IMODE(path.stat().st_mode) << 16
            output.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
PY

python3 - "$ZIP_STAGE" <<'PY'
import os
import stat
import sys
import zipfile
from pathlib import PurePosixPath

archive = sys.argv[1]
seen = set()
with zipfile.ZipFile(archive) as source:
    for info in source.infolist():
        name = info.filename
        clean = name.rstrip("/")
        if name in seen or clean in seen:
            raise SystemExit(f"duplicate ZIP entry: {name}")
        seen.add(name)
        seen.add(clean)
        path = PurePosixPath(clean)
        if not clean or path.is_absolute() or ".." in path.parts or "\\" in name:
            raise SystemExit(f"unsafe ZIP path: {name}")
        if clean != "AltServer.app" and not clean.startswith("AltServer.app/"):
            raise SystemExit(f"unexpected ZIP root: {name}")
        if any(part == "__MACOSX" or part.startswith("._") for part in path.parts):
            raise SystemExit(f"forbidden AppleDouble ZIP entry: {name}")
        mode = (info.external_attr >> 16) & 0xffff
        kind = stat.S_IFMT(mode)
        if kind == stat.S_IFLNK:
            target = source.read(info).decode("utf-8")
            target_path = PurePosixPath(target)
            if target_path.is_absolute() or ".." in target_path.parts or "\\" in target:
                raise SystemExit(f"unsafe ZIP symlink: {name}")
        elif kind not in (0, stat.S_IFREG, stat.S_IFDIR):
            raise SystemExit(f"unsupported ZIP entry type: {name}")
PY

ditto --norsrc --noextattr --noqtn "$STAGED_APP" "$APP_STAGE"
codesign --verify --deep --strict "$APP_STAGE" >/dev/null || fail "copied output app failed strict signature verification."
[[ "$(shasum -a 256 "$APP_STAGE/Contents/Frameworks/AltServerAnisetteHelper" | awk '{ print $1 }')" == "$HELPER_SHA256" ]] || \
    fail "copied output helper hash changed."
[[ "$(shasum -a 256 "$APP_STAGE/Contents/Frameworks/AltServerAnisetteFix.dylib" | awk '{ print $1 }')" == "$DYLIB_SHA256" ]] || \
    fail "copied output dylib hash changed."
validate_lc_uuid "$APP_STAGE/Contents/Frameworks/AltServerAnisetteHelper" || fail "copied output helper UUID is invalid."
validate_lc_uuid "$APP_STAGE/Contents/Frameworks/AltServerAnisetteFix.dylib" || fail "copied output dylib UUID is invalid."
[[ "$(text_hash "$APP_STAGE/$MAIN_REL")" == "$MAIN_TEXT_HASH" ]] || \
    fail "copied output app changed the official AltServer code."
if find -P "$APP_STAGE" \( -path '*AltSign-Dynamic.framework' -o -name '*.ipa' \) -print -quit | /usr/bin/grep -q .; then
    fail "staged output contains a dynamic AltSign or IPA payload."
fi
validate_output_paths "$OUTPUT"
bound_copy_file "$ZIP_STAGE" "${PAYLOAD_ZIP:t}" || fail "could not create the staged payload ZIP without following a destination path."
bound_copy_file "$EMBEDDED_MANIFEST" "${EXECUTABLE_MANIFEST:t}" || fail "could not create the staged executable manifest without following a destination path."
METADATA_SOURCE="$(mktemp "$TEMP_ROOT/metadata.XXXXXX")" || fail "could not allocate the private metadata source."
CHECKSUMS_SOURCE="$(mktemp "$TEMP_ROOT/checksums.XXXXXX")" || fail "could not allocate the private checksums source."
[[ -f "$METADATA_SOURCE" && ! -L "$METADATA_SOURCE" && -f "$CHECKSUMS_SOURCE" && ! -L "$CHECKSUMS_SOURCE" ]] || fail "private metadata sources are not regular files."
printf '%s\n' \
    'FormatVersion=1' \
    'ReleaseVersion=1.0.8' \
    'PatchVersion=v3.7' \
    'BaseBundleIdentifier=com.rileytestut.AltServer' \
    'BaseVersion=1.7.6' \
    'BaseBuild=94' \
    'OutputVersion=1.7.6-macOS27-v3.7' \
    'OutputBuild=94' \
    'InputAttestation=Developer-ID-and-notarization-verified' \
    'OutputSignature=Ad-hoc; notarization is intentionally not carried forward' \
    'AltSign=Official-static-only' \
    'PatchedIPA=Not-included' \
    'NetworkHooks=No-GSA-or-User-Agent-hook' \
    'MainTextHashPreserved=yes' \
    "SourceRevision=$SOURCE_REVISION" \
    "SourceTreeState=$SOURCE_TREE_STATE" \
    "SourceWorktreeDirty=$SOURCE_WORKTREE_DIRTY" \
    "DirtyAttested=$DIRTY_ATTESTED" \
    "SourceSnapshotRequired=$SOURCE_SNAPSHOT_REQUIRED" \
    "DocsDirty=$DOCS_DIRTY" \
    "ObjCSourceSHA256=$OBJC_SOURCE_SHA256" \
    "SwiftClientSourceSHA256=$SWIFT_CLIENT_SHA256" \
    "SwiftMainSourceSHA256=$SWIFT_MAIN_SHA256" \
    "HelperSwiftClientSourceSHA256=$SWIFT_CLIENT_SHA256" \
    "HelperSwiftMainSourceSHA256=$SWIFT_MAIN_SHA256" \
    "BuildScriptSHA256=$BUILD_SCRIPT_SHA256" \
    "UUIDDerivationVersion=$HELPER_UUID_DERIVATION_VERSION" \
    "HelperUUIDDerivationInputs=$HELPER_UUID_INPUTS" \
    "HelperSHA256=$HELPER_SHA256" \
    "HelperUUID=$HELPER_UUID" \
    "DylibUUIDDerivationVersion=$DYLIB_UUID_DERIVATION_VERSION" \
    "DylibUUIDDerivationInputs=$DYLIB_UUID_INPUTS" \
    "DylibSHA256=$DYLIB_SHA256" \
    "DylibUUID=$DYLIB_UUID" > "$METADATA_SOURCE"
bound_copy_file "$METADATA_SOURCE" "${METADATA:t}" || fail "could not create staged metadata without following a destination path."

{
    shasum -a 256 "$PAYLOAD_ZIP" | awk '{ print $1 "  AltServer-macOS27-v3.7.zip" }'
    shasum -a 256 "$EXECUTABLE_MANIFEST" | awk '{ print $1 "  AltServer-macOS27-v3.7.executables.txt" }'
    shasum -a 256 "$METADATA" | awk '{ print $1 "  BUILD-METADATA.txt" }'
} > "$CHECKSUMS_SOURCE"
bound_copy_file "$CHECKSUMS_SOURCE" "${CHECKSUMS:t}" || fail "could not create staged checksums without following a destination path."

validate_release_tree()
{
    local root="$1"
    local zip="$root/AltServer-macOS27-v3.7.zip"
    local manifest="$root/AltServer-macOS27-v3.7.executables.txt"
    local metadata="$root/BUILD-METADATA.txt"
    local checksums="$root/CHECKSUMS-SHA256.txt"
    local verify_root="$TEMP_ROOT/validate-${RANDOM}"
    local app="$verify_root/AltServer.app"
    [[ -d "$root" && ! -L "$root" ]] || fail "release staging tree is missing."
    [[ -f "$zip" && -f "$manifest" && -f "$metadata" && -f "$checksums" ]] || fail "release staging artifacts are incomplete."
    python3 - "$root" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
expected = {
    "AltServer-macOS27-v3.7.zip",
    "AltServer-macOS27-v3.7.executables.txt",
    "BUILD-METADATA.txt",
    "CHECKSUMS-SHA256.txt",
}
actual = {item.name for item in root.iterdir()}
if actual != expected:
    raise SystemExit("release tree must publish only ZIP, manifest, metadata, and checksums")
if any(item.is_symlink() or not item.is_file() for item in root.iterdir()):
    raise SystemExit("release artifact is not a regular file")
PY
    mkdir "$verify_root"
    /usr/bin/unzip -q "$zip" -d "$verify_root" || fail "release ZIP extraction failed."
    [[ -d "$app" && ! -L "$app" ]] || fail "release ZIP app is missing."
    [[ -f "$app/Contents/Info.plist" && -f "$app/$MAIN_REL" ]] || fail "release ZIP app is incomplete."
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null || true)" == "com.rileytestut.AltServer" ]] || fail "release app bundle identifier changed."
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist" 2>/dev/null || true)" == "1.7.6-macOS27-v3.7" ]] || fail "release app version changed."
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist" 2>/dev/null || true)" == "94" ]] || fail "release app build changed."
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :LSEnvironment:DYLD_INSERT_LIBRARIES' "$app/Contents/Info.plist" 2>/dev/null || true)" == "@executable_path/../Frameworks/AltServerAnisetteFix.dylib" ]] || fail "release app environment changed."
    ARCHES="$(lipo -archs "$app/$MAIN_REL" 2>/dev/null || true)"
    [[ " $ARCHES " == *" arm64 "* && " $ARCHES " == *" x86_64 "* ]] || fail "release ZIP app is not universal."
    [[ -f "$app/Contents/Frameworks/AltServerAnisetteHelper" && -f "$app/Contents/Frameworks/AltServerAnisetteFix.dylib" ]] || fail "release ZIP anisette artifacts are missing."
    [[ ! -L "$app/Contents/Frameworks/AltServerAnisetteFix.dylib" ]] || fail "release ZIP anisette fix dylib is a symlink."
    [[ "$(shasum -a 256 "$app/Contents/Frameworks/AltServerAnisetteHelper" | awk '{ print $1 }')" == "$HELPER_SHA256" ]] || fail "release ZIP helper hash differs from the finalized helper."
    [[ "$(shasum -a 256 "$app/Contents/Frameworks/AltServerAnisetteFix.dylib" | awk '{ print $1 }')" == "$DYLIB_SHA256" ]] || fail "release ZIP dylib hash differs from the finalized dylib."
    [[ "$(extract_lc_uuid "$app/Contents/Frameworks/AltServerAnisetteHelper")" == "$HELPER_UUID" ]] || fail "release ZIP helper UUID differs from the finalized helper."
    validate_lc_uuid "$app/Contents/Frameworks/AltServerAnisetteFix.dylib" || fail "release ZIP dylib must contain exactly one valid nonzero LC_UUID."
    [[ "$(extract_lc_uuid "$app/Contents/Frameworks/AltServerAnisetteFix.dylib")" == "$DYLIB_UUID" ]] || fail "release ZIP dylib UUID differs from the finalized dylib."
    if find -P "$app" \( -path '*AltSign-Dynamic.framework' -o -name '*.ipa' -o -name '*.mobileprovision' -o -name 'embedded.provisionprofile' \) -print -quit | /usr/bin/grep -q .; then
        fail "release ZIP contains a forbidden dynamic AltSign, IPA, or profile."
    fi
    [[ -f "$app/Contents/Resources/AltServer-macOS27-v3.7.executables.txt" ]] || fail "release ZIP embedded manifest is missing."
    cmp -s "$manifest" "$app/Contents/Resources/AltServer-macOS27-v3.7.executables.txt" || fail "release ZIP manifest differs."
    python3 - "$app" "$manifest" <<'PY'
import os
import stat
import sys
from pathlib import Path, PurePosixPath

root = Path(sys.argv[1])
manifest = Path(sys.argv[2])
expected = {}
for line in manifest.read_text(encoding="utf-8").splitlines():
    fields = line.split(" ", 1)
    if len(fields) != 2 or len(fields[0]) != 4 or any(c not in "01234567" for c in fields[0]):
        raise SystemExit("invalid executable manifest")
    rel = fields[1]
    rel_path = PurePosixPath(rel)
    if rel in expected or rel_path.is_absolute() or ".." in rel_path.parts or "\\" in rel:
        raise SystemExit("unsafe executable manifest path")
    expected[rel] = int(fields[0], 8)
actual = {}
for path in sorted(root.rglob("*")):
    rel = path.relative_to(root).as_posix()
    if rel.startswith("__MACOSX/") or rel.startswith("._") or "/._" in rel:
        raise SystemExit("AppleDouble path")
    if path.is_symlink():
        target = os.readlink(path)
        target_path = PurePosixPath(target)
        if target_path.is_absolute() or ".." in target_path.parts or "\\" in target or not path.exists():
            raise SystemExit("unsafe or dangling symlink")
    elif path.is_file() and stat.S_IMODE(path.stat().st_mode) & 0o111:
        actual[rel] = stat.S_IMODE(path.stat().st_mode)
if actual != expected:
    raise SystemExit("executable manifest does not match extracted ZIP")
PY
    clear_bundle_detritus "$app"
    codesign --verify --deep --strict "$app" >/dev/null || fail "release ZIP app failed strict signature verification."
    [[ "$(text_hash "$app/$MAIN_REL")" == "$MAIN_TEXT_HASH" ]] || fail "release staging app changed the official AltServer code."
    [[ "$(shasum -a 256 "$zip" | awk '{ print $1 }')" == "$(awk '$2 == "AltServer-macOS27-v3.7.zip" { print $1; exit }' "$checksums")" ]] || fail "release ZIP checksum is inconsistent."
    [[ "$(shasum -a 256 "$manifest" | awk '{ print $1 }')" == "$(awk '$2 == "AltServer-macOS27-v3.7.executables.txt" { print $1; exit }' "$checksums")" ]] || fail "release manifest checksum is inconsistent."
    [[ "$(shasum -a 256 "$metadata" | awk '{ print $1 }')" == "$(awk '$2 == "BUILD-METADATA.txt" { print $1; exit }' "$checksums")" ]] || fail "release metadata checksum is inconsistent."
    /usr/bin/grep -Fqx "SourceRevision=$SOURCE_REVISION" "$metadata" || fail "release metadata source revision is missing."
    /usr/bin/grep -Fqx "SourceTreeState=$SOURCE_TREE_STATE" "$metadata" || fail "release metadata source tree state is missing."
    /usr/bin/grep -Fqx "DirtyAttested=$DIRTY_ATTESTED" "$metadata" || fail "release metadata dirty attestation is missing."
    /usr/bin/grep -Fqx "SourceSnapshotRequired=$SOURCE_SNAPSHOT_REQUIRED" "$metadata" || fail "release metadata snapshot requirement is missing."
    /usr/bin/grep -Fqx "ObjCSourceSHA256=$OBJC_SOURCE_SHA256" "$metadata" || fail "release metadata ObjC source hash is missing."
    /usr/bin/grep -Fqx "SwiftClientSourceSHA256=$SWIFT_CLIENT_SHA256" "$metadata" || fail "release metadata Swift client source hash is missing."
    /usr/bin/grep -Fqx "SwiftMainSourceSHA256=$SWIFT_MAIN_SHA256" "$metadata" || fail "release metadata Swift main source hash is missing."
    /usr/bin/grep -Fqx "HelperSwiftClientSourceSHA256=$SWIFT_CLIENT_SHA256" "$metadata" || fail "release metadata helper Swift client source hash is missing."
    /usr/bin/grep -Fqx "HelperSwiftMainSourceSHA256=$SWIFT_MAIN_SHA256" "$metadata" || fail "release metadata helper Swift main source hash is missing."
    /usr/bin/grep -Fqx "BuildScriptSHA256=$BUILD_SCRIPT_SHA256" "$metadata" || fail "release metadata build script hash is missing."
    /usr/bin/grep -Fqx "UUIDDerivationVersion=$HELPER_UUID_DERIVATION_VERSION" "$metadata" || fail "release metadata UUID derivation version is missing."
    /usr/bin/grep -Fqx "HelperUUIDDerivationInputs=$HELPER_UUID_INPUTS" "$metadata" || fail "release metadata helper UUID derivation inputs are missing."
    /usr/bin/grep -Fqx "HelperSHA256=$HELPER_SHA256" "$metadata" || fail "release metadata helper hash is missing."
    /usr/bin/grep -Fqx "HelperUUID=$HELPER_UUID" "$metadata" || fail "release metadata helper UUID is missing."
    /usr/bin/grep -Fqx "DylibUUIDDerivationVersion=$DYLIB_UUID_DERIVATION_VERSION" "$metadata" || fail "release metadata dylib UUID derivation version is missing."
    /usr/bin/grep -Fqx "DylibUUIDDerivationInputs=$DYLIB_UUID_INPUTS" "$metadata" || fail "release metadata dylib UUID derivation inputs are missing."
    /usr/bin/grep -Fqx "DylibSHA256=$DYLIB_SHA256" "$metadata" || fail "release metadata dylib hash is missing."
    /usr/bin/grep -Fqx "DylibUUID=$DYLIB_UUID" "$metadata" || fail "release metadata dylib UUID is missing."
}

validate_release_tree "$STAGE_ROOT"

publish_preflight()
{
    local old_expected="${1:-0}"
    validate_output_paths "$OUTPUT"
    [[ "$OUTPUT_PARENT_REAL" == "${OUTPUT_PARENT_REAL:A}" && ! -L "$OUTPUT_PARENT_REAL" ]] || fail "output parent canonical identity changed."
    path_has_symlink "$OUTPUT_PARENT_REAL" && fail "output parent contains a symlink."
    [[ "$(stat -f '%d:%i' "$OUTPUT_PARENT_REAL" 2>/dev/null || true)" == "$PARENT_KEY" ]] || fail "output parent changed during release."
    [[ -d "$STAGE_ROOT" && ! -L "$STAGE_ROOT" ]] || fail "release staging tree changed."
    [[ "$STAGE_ROOT" == "$OUTPUT_PARENT_REAL"/.altserver-release-* && "$STAGE_ROOT" == "${STAGE_ROOT:A}" ]] || fail "release staging path is not canonical."
    path_has_symlink "$STAGE_ROOT" && fail "release staging tree aliases through a symlink."
    [[ "$(stat -f '%d:%i' "$STAGE_ROOT" 2>/dev/null || true)" == "$STAGE_KEY" ]] || fail "release staging identity changed."
    [[ "$(stat -f '%d' "$STAGE_ROOT" 2>/dev/null || true)" == "$(stat -f '%d' "$OUTPUT_PARENT_REAL" 2>/dev/null || true)" ]] || fail "release staging moved across filesystems."
    if [[ "$old_expected" == "1" ]]; then
        [[ ! -e "$OUTPUT_REAL" && ! -L "$OUTPUT_REAL" ]] || fail "output path was recreated before rollback/publish."
    elif [[ "$OUTPUT_PREEXISTING" == "1" ]]; then
        [[ -e "$OUTPUT_REAL" && ! -L "$OUTPUT_REAL" ]] || fail "existing output disappeared during the transaction; it was preserved."
    else
        [[ ! -e "$OUTPUT_REAL" && ! -L "$OUTPUT_REAL" ]] || fail "new output appeared before publish; it was preserved."
    fi
    if [[ -e "$OUTPUT_REAL" || -L "$OUTPUT_REAL" ]]; then
        [[ -d "$OUTPUT_REAL" && ! -L "$OUTPUT_REAL" ]] || fail "existing output is not a directory."
        [[ "$OUTPUT_REAL" == "$OUTPUT_PARENT_REAL"/* && "$OUTPUT_REAL" == "${OUTPUT_REAL:A}" ]] || fail "existing output path is not canonical."
        path_has_symlink "$OUTPUT_REAL" && fail "existing output contains a symlink."
        [[ "$(stat -f '%d' "$OUTPUT_REAL" 2>/dev/null || true)" == "$(stat -f '%d' "$OUTPUT_PARENT_REAL" 2>/dev/null || true)" ]] || fail "existing output moved across filesystems."
        [[ "$OUTPUT_PREEXISTING" == "1" && "$(stat -f '%d:%i' "$OUTPUT_REAL" 2>/dev/null || true)" == "$OUTPUT_INITIAL_KEY" ]] || fail "output appeared or changed after the transaction started; it was preserved."
    fi
    if [[ "$old_expected" == "1" ]]; then
        [[ -d "$OLD_ROOT" && ! -L "$OLD_ROOT" ]] || fail "release rollback tree is missing."
        [[ "$OLD_ROOT" == "$OUTPUT_PARENT_REAL"/.altserver-release-* && "$OLD_ROOT" == "${OLD_ROOT:A}" ]] || fail "release rollback path is not canonical."
        path_has_symlink "$OLD_ROOT" && fail "release rollback tree contains a symlink."
        [[ "$(stat -f '%d:%i' "$OLD_ROOT" 2>/dev/null || true)" == "$OUTPUT_MOVE_KEY" ]] || fail "release rollback tree identity changed."
        [[ "$(stat -f '%d' "$OLD_ROOT" 2>/dev/null || true)" == "$(stat -f '%d' "$OUTPUT_PARENT_REAL" 2>/dev/null || true)" ]] || fail "release rollback moved across filesystems."
    else
        [[ ! -e "$OLD_ROOT" && ! -L "$OLD_ROOT" ]] || fail "release rollback destination already exists."
    fi
}

publish_postflight()
{
    validate_output_paths "$OUTPUT"
    [[ "$(stat -f '%d:%i' "$OUTPUT_PARENT_REAL" 2>/dev/null || true)" == "$PARENT_KEY" ]] || fail "output parent changed during release."
    [[ -d "$OUTPUT_REAL" && ! -L "$OUTPUT_REAL" ]] || fail "published release tree changed."
    path_has_symlink "$OUTPUT_REAL" && fail "published release tree aliases through a symlink."
    [[ "$(stat -f '%d:%i' "$OUTPUT_REAL" 2>/dev/null || true)" == "$STAGE_KEY" ]] || fail "published release identity differs from the captured staging tree."
    [[ "$(stat -f '%d' "$OUTPUT_REAL" 2>/dev/null || true)" == "$(stat -f '%d' "$OUTPUT_PARENT_REAL" 2>/dev/null || true)" ]] || fail "published release moved across filesystems."
}

verify_base_input_snapshot
fault_if before_old_rename
publish_preflight
if [[ -e "$OUTPUT_REAL" || -L "$OUTPUT_REAL" ]]; then
    [[ -d "$OUTPUT_REAL" && ! -L "$OUTPUT_REAL" ]] || fail "existing output is not a directory."
    same_inode "$BASE_APP" "$OUTPUT_REAL/AltServer.app" && fail "existing output aliases the official input app."
    validate_existing_release_schema "$OUTPUT_REAL" || fail "existing output changed during the build; it was preserved."
    [[ "$OUTPUT_PREEXISTING" == "1" && "$(stat -f '%d:%i' "$OUTPUT_REAL" 2>/dev/null || true)" == "$OUTPUT_INITIAL_KEY" ]] || fail "existing output appeared or changed before publish; it was preserved."
    OUTPUT_MOVE_KEY="$OUTPUT_INITIAL_KEY"
    [[ -n "$OUTPUT_MOVE_KEY" && "$(stat -f '%d:%i' "$OUTPUT_REAL" 2>/dev/null || true)" == "$OUTPUT_MOVE_KEY" ]] || fail "existing output identity changed before move."
    atomic_rename_excl "$OUTPUT_NAME" "${OLD_ROOT:t}" "$OUTPUT_MOVE_KEY" || fail "could not move the previous complete release aside without replacing an attacker-created destination."
    OLD_MOVED=1
    [[ ! -e "$OUTPUT_REAL" && ! -L "$OUTPUT_REAL" ]] || fail "previous output remained at its published path."
    [[ -d "$OLD_ROOT" && ! -L "$OLD_ROOT" ]] || fail "previous output move did not produce a rollback tree."
    [[ "$(stat -f '%d:%i' "$OLD_ROOT" 2>/dev/null || true)" == "$OUTPUT_MOVE_KEY" ]] || fail "previous output identity changed during move."
fi
fault_if after_old_rename
publish_preflight "$OLD_MOVED"
if [[ "$OLD_MOVED" == "1" ]]; then
    [[ ! -e "$OUTPUT_REAL" && ! -L "$OUTPUT_REAL" ]] || fail "output path was recreated before publish."
fi
fault_if before_new_rename
STAGE_MOVE_KEY="$STAGE_KEY"
[[ -n "$STAGE_MOVE_KEY" && "$(stat -f '%d:%i' "$STAGE_ROOT" 2>/dev/null || true)" == "$STAGE_MOVE_KEY" ]] || fail "release staging identity changed before publish."
atomic_rename_excl "${STAGE_ROOT:t}" "$OUTPUT_NAME" "$STAGE_MOVE_KEY" || fail "could not publish the complete release tree without replacing an attacker-created destination."
NEW_MOVED=1
[[ ! -e "$STAGE_ROOT" && ! -L "$STAGE_ROOT" ]] || fail "release staging tree remained after publish."
[[ -d "$OUTPUT_REAL" && ! -L "$OUTPUT_REAL" ]] || fail "published release tree is missing."
[[ "$(stat -f '%d:%i' "$OUTPUT_REAL" 2>/dev/null || true)" == "$STAGE_KEY" ]] || fail "published release identity changed during move."
fault_if after_new_rename

validate_release_tree "$OUTPUT_REAL"
fault_if cleanup
publish_postflight
if [[ "$OLD_MOVED" == "1" ]]; then
    safe_remove_transaction_path "$OLD_ROOT" "${OUTPUT_MOVE_KEY:-}" || fail "could not remove the previous release backup."
    if [[ -e "$OLD_ROOT" || -L "$OLD_ROOT" ]]; then
        fail "previous release backup remained after cleanup."
    fi
elif [[ -e "$OLD_ROOT" || -L "$OLD_ROOT" ]]; then
    fail "unexpected release backup path appeared before cleanup."
fi
OLD_MOVED=0
TRANSACTION_ACTIVE=0
echo "Built v3.7 payload in output directory."
