#!/bin/zsh

set -euo pipefail

# Restore deliberately has one privilege boundary: an actual transaction is
# root-only.  A non-root dry run performs only read-only validation and never
# creates a temporary directory, lock, or staging entry.
RESTORE_DRY_RUN="${ALTSERVER_INSTALL_DRY_RUN:-${ALTSERVER_RESTORE_DRY_RUN:-0}}"
if [[ "$RESTORE_DRY_RUN" != "1" && "$EUID" -ne 0 ]]; then
    echo "Restore: actual restore requires root; rerun with: sudo ALTSERVER_INSTALL_DRY_RUN=0 $0" >&2
    exit 1
fi
# Do not let a caller-controlled PATH select code while processing backup or
# target paths.  Keep the same fixed path for root and non-root dry runs.
PATH="/usr/bin:/bin:/usr/sbin:/sbin"
export PATH
readonly PATH

if [[ "$EUID" -eq 0 && ${+ALTSERVER_RESTORE_BACKUP_ROOT} -eq 1 ]]; then
    echo "Restore: root restores may only use the canonical invoking-user backup path." >&2
    exit 1
fi

TARGET_APP="/Applications/AltServer.app"
EXPECTED_BUNDLE_ID="com.rileytestut.AltServer"
EXPECTED_OFFICIAL_TEAM_ID="6XVY5G3U44"
EXPECTED_OFFICIAL_MAIN_SHA="d1e4188b67adbd120af597ffa11708a18cb139db9919baa5be806a129a3cf819"
EXPECTED_OFFICIAL_VERSION="1.7.6"
EXPECTED_OFFICIAL_BUILD="94"
EXPECTED_PATCHED_VERSION="1.7.6-macOS27-v3.7"
EXPECTED_PATCHED_BUILD="94"

fail()
{
    echo "Restore: $1" >&2
    exit 1
}

if [[ -n "${ALTSERVER_RESTORE_TARGET_APP+x}" ]]; then
    fail "ALTSERVER_RESTORE_TARGET_APP is unsupported; restore target is fixed at /Applications/AltServer.app."
fi

path_has_symlink()
{
    local raw="$1"
    local current="/"
    local component
    [[ "$raw" == /* ]] || return 1
    for component in ${(s:/:)raw}; do
        [[ -n "$component" ]] || continue
        current="$current/$component"
        [[ -L "$current" ]] && return 0
    done
    return 1
}

HOME_PATH="${HOME:-}"
BACKUP_ROOT_OVERRIDE="${ALTSERVER_RESTORE_BACKUP_ROOT:-}"
if [[ "$EUID" -eq 0 && "$RESTORE_DRY_RUN" != "1" ]]; then
    [[ ${+SUDO_USER} -eq 1 && -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]] || {
        echo "Restore: actual root restores require a non-root SUDO_USER." >&2
        exit 1
    }
fi
if [[ "$EUID" -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]]; then
    [[ "$SUDO_USER" =~ '^[A-Za-z0-9._-]+$' ]] || {
        echo "Restore: SUDO_USER contains an unsafe username." >&2
        exit 1
    }
    SUDO_HOME="$(/usr/bin/dscl . -read "/Users/$SUDO_USER" NFSHomeDirectory 2>/dev/null |
        /usr/bin/awk 'NF == 2 && $1 == "NFSHomeDirectory:" { value=$2; count++ } END { if (count == 1) print value }' || true)"
    [[ -n "$SUDO_HOME" && "$SUDO_HOME" == /* && "$SUDO_HOME" == "${SUDO_HOME:A}" &&
       -d "$SUDO_HOME" && ! -L "$SUDO_HOME" && "${SUDO_HOME:t}" == "$SUDO_USER" ]] || {
        echo "Restore: SUDO_USER home is not a canonical expected user home." >&2
        exit 1
    }
    path_has_symlink "$SUDO_HOME" && {
        echo "Restore: SUDO_USER home contains a symlink." >&2
        exit 1
    }
    HOME_PATH="$SUDO_HOME"
fi
[[ -n "$HOME_PATH" && "$HOME_PATH" == /* && "$HOME_PATH" == "${HOME_PATH:A}" &&
   -d "$HOME_PATH" && ! -L "$HOME_PATH" ]] || {
    echo "Restore: HOME is unavailable or not absolute." >&2
    exit 1
}
path_has_symlink "$HOME_PATH" && {
    echo "Restore: HOME contains a symlink." >&2
    exit 1
}
if [[ "$EUID" -ne 0 ]]; then
    home_mode="$(stat -f '%Lp' "$HOME_PATH" 2>/dev/null || true)"
    home_owner="$(stat -f '%u' "$HOME_PATH" 2>/dev/null || true)"
    [[ "$home_mode" == <-> && "$home_owner" == "$EUID" ]] || {
        echo "Restore: non-root HOME is not owned by the invoking user." >&2
        exit 1
    }
    (( 8#$home_mode & 8#022 )) && {
        echo "Restore: non-root HOME is writable by an untrusted group." >&2
        exit 1
    }
fi
DEFAULT_BACKUP_ROOT="$HOME_PATH/Library/Application Support/AltServer-macOS27-Fix/Backups"
BACKUP_ROOT="$DEFAULT_BACKUP_ROOT"
if [[ -n "$BACKUP_ROOT_OVERRIDE" ]]; then
    if [[ "$EUID" -eq 0 || "$RESTORE_DRY_RUN" != "1" ]]; then
        echo "Restore: backup overrides are restricted to non-root dry runs." >&2
        exit 1
    fi
    fixture_dir="${BACKUP_ROOT_OVERRIDE:h}"
    fixture_name="${fixture_dir:t}"
    fixture_mode="$(stat -f '%Mp%Lp' "$fixture_dir" 2>/dev/null || true)"
    fixture_owner="$(stat -f '%u' "$fixture_dir" 2>/dev/null || true)"
    fixture_root_mode="$(stat -f '%Mp%Lp' "$BACKUP_ROOT_OVERRIDE" 2>/dev/null || true)"
    fixture_root_owner="$(stat -f '%u' "$BACKUP_ROOT_OVERRIDE" 2>/dev/null || true)"
    [[ "$BACKUP_ROOT_OVERRIDE" == /* &&
       "$BACKUP_ROOT_OVERRIDE" == "${BACKUP_ROOT_OVERRIDE:A}" ]] || {
        echo "Restore: non-root dry-run backup override must be canonical." >&2
        exit 1
    }
    path_has_symlink "$BACKUP_ROOT_OVERRIDE" && {
        echo "Restore: non-root dry-run backup override contains a symlink." >&2
        exit 1
    }
    [[ "$BACKUP_ROOT_OVERRIDE" == "$DEFAULT_BACKUP_ROOT" ||
       ("$BACKUP_ROOT_OVERRIDE" == "$HOME_PATH"/.altserver-install-*/Backups &&
        "$fixture_name" =~ '^\.altserver-install-[A-Za-z0-9._-]+$' && "$fixture_mode" == "0700" &&
        -d "$fixture_dir" && ! -L "$fixture_dir" && "$fixture_owner" == "$EUID" &&
        ((! -e "$BACKUP_ROOT_OVERRIDE" && ! -L "$BACKUP_ROOT_OVERRIDE") ||
         (-d "$BACKUP_ROOT_OVERRIDE" && ! -L "$BACKUP_ROOT_OVERRIDE" &&
          "$fixture_root_mode" == "0700" && "$fixture_root_owner" == "$EUID"))) ]] || {
        echo "Restore: non-root dry-run backup override must be a canonical private HOME fixture." >&2
        exit 1
    }
    BACKUP_ROOT="$BACKUP_ROOT_OVERRIDE"
fi

spctl_assess()
{
    local app="$1"
    if /usr/sbin/spctl --help 2>&1 | /usr/bin/grep -q -- '--strict'; then
        /usr/sbin/spctl --assess --type execute --strict "$app"
    else
        /usr/sbin/spctl --assess --type execute "$app"
    fi
}

bundle_snapshot_hash()
{
    python3 - "$1" <<'PY'
import hashlib
import os
import stat
import sys

root = os.path.abspath(sys.argv[1])
digest = hashlib.sha256()
entries = [('', root)]
for directory, dirnames, filenames in os.walk(root, topdown=True, followlinks=False):
    dirnames.sort()
    filenames.sort()
    for name in dirnames + filenames:
        path = os.path.join(directory, name)
        entries.append((os.path.relpath(path, root).replace(os.sep, '/'), path))
for relative, path in sorted(entries):
    mode = os.lstat(path).st_mode
    digest.update(relative.encode('utf-8', 'surrogateescape'))
    digest.update(b'\0')
    digest.update(f'{stat.S_IMODE(mode):04o}'.encode('ascii'))
    digest.update(b'\0')
    if stat.S_ISLNK(mode):
        digest.update(b'L\0')
        digest.update(os.readlink(path).encode('utf-8', 'surrogateescape'))
    elif stat.S_ISREG(mode):
        digest.update(b'F\0')
        with open(path, 'rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(chunk)
    elif stat.S_ISDIR(mode):
        digest.update(b'D\0')
    else:
        raise SystemExit('unsupported bundle entry')
    digest.update(b'\0')
print(digest.hexdigest())
PY
}

# Backup and stage trees are copied without following links.  Frameworks in an
# official app legitimately contain relative version links, so links are
# admitted only when their lexical target remains inside the app root.
tree_regular_nlink_one()
{
    python3 - "$1" <<'PY'
import os
import stat
import sys

root = os.path.abspath(sys.argv[1])
for directory, dirnames, filenames in os.walk(root, topdown=True, followlinks=False):
    for name in dirnames + filenames:
        path = os.path.join(directory, name)
        info = os.lstat(path)
        if stat.S_ISLNK(info.st_mode):
            if os.path.isabs(os.readlink(path)):
                raise SystemExit('absolute symlink in app tree')
            resolved = os.path.realpath(path)
            if os.path.commonpath((root, resolved)) != root:
                raise SystemExit('symlink escapes app tree')
            continue
        if stat.S_ISREG(info.st_mode) and info.st_nlink != 1:
            raise SystemExit('hard-linked regular file in app tree')
        if not (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)):
            raise SystemExit('unsupported app entry')
PY
}

required_executable_modes_ok()
{
    local app="$1"
    local executable mode dylib directory
    local -a required=(
        "$app/Contents/MacOS/AltServer"
        "$app/Contents/MacOS/altjit"
        "$app/Contents/Library/LoginItems/LaunchAtLoginHelper.app/Contents/MacOS/LaunchAtLoginHelper"
    )
    if [[ -e "$app/Contents/Frameworks/AltServerAnisetteHelper" || -L "$app/Contents/Frameworks/AltServerAnisetteHelper" ]]; then
        required+=("$app/Contents/Frameworks/AltServerAnisetteHelper")
    fi
    for executable in "${required[@]}"; do
        [[ -f "$executable" && ! -L "$executable" ]] || return 1
        path_has_symlink "$executable" && return 1
        mode="$(stat -f '%Mp%Lp' "$executable" 2>/dev/null || true)"
        [[ "$mode" == "0755" ]] || return 1
    done
    while IFS= read -r -d '' dylib; do
        [[ -f "$dylib" && ! -L "$dylib" ]] || return 1
        path_has_symlink "$dylib" && return 1
        mode="$(stat -f '%Mp%Lp' "$dylib" 2>/dev/null || true)"
        [[ "$mode" == "0755" ]] || return 1
    done < <(find -P "$app" -type f -name '*.dylib' -print0)
    while IFS= read -r -d '' directory; do
        mode="$(stat -f '%Mp%Lp' "$directory" 2>/dev/null || true)"
        [[ "$mode" == "0755" ]] || return 1
    done < <(find -P "$app" -type d -print0)
    return 0
}

backup_metadata_exact_ok()
{
    local metadata="$1"
    local line
    [[ -f "$metadata" && ! -L "$metadata" ]] || return 1
    [[ "$metadata" == "${metadata:A}" ]] || return 1
    path_has_symlink "$metadata" && return 1
    # Install.command writes 0600; older backup records were 0644.  Both are
    # accepted as long as the metadata is not writable by group/other.
    [[ "$(stat -f '%Mp%Lp' "$metadata" 2>/dev/null || true)" == "0600" ||
       "$(stat -f '%Mp%Lp' "$metadata" 2>/dev/null || true)" == "0644" ]] || return 1
    [[ "$(stat -f '%l' "$metadata" 2>/dev/null || true)" == "1" ]] || return 1
    [[ "$(wc -l < "$metadata" | tr -d '[:space:]')" == "6" ]] || return 1
    while IFS= read -r line; do
        case "$line" in
            'FormatVersion=1'|'BundleIdentifier=com.rileytestut.AltServer'|'BundleShortVersion=1.7.6'|'BundleVersion=94'|'MainExecutableSHA256='*|'Signature=Preserved-before-v3.7-install') ;;
            *) return 1 ;;
        esac
    done < "$metadata"
    [[ "$(grep -Fxc 'FormatVersion=1' "$metadata")" == "1" ]] || return 1
    [[ "$(grep -Fxc 'BundleIdentifier=com.rileytestut.AltServer' "$metadata")" == "1" ]] || return 1
    [[ "$(grep -Fxc 'BundleShortVersion=1.7.6' "$metadata")" == "1" ]] || return 1
    [[ "$(grep -Fxc 'BundleVersion=94' "$metadata")" == "1" ]] || return 1
    [[ "$(grep -Ec '^MainExecutableSHA256=[0-9A-Fa-f]{64}$' "$metadata")" == "1" ]] || return 1
    [[ "$(grep -Fxc 'Signature=Preserved-before-v3.7-install' "$metadata")" == "1" ]] || return 1
    return 0
}

backup_app_provenance_ok()
{
    local app="$1"
    local expected_snapshot="${2:-}"
    local plist="$app/Contents/Info.plist"
    local main="$app/Contents/MacOS/AltServer"
    local details team arches actual_hash snapshot
    [[ -d "$app" && ! -L "$app" && "$app" == "${app:A}" ]] || return 1
    path_has_symlink "$app" && return 1
    tree_regular_nlink_one "$app" || return 1
    [[ -f "$plist" && ! -L "$plist" && -f "$main" && ! -L "$main" ]] || return 1
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist" 2>/dev/null || true)" == "$EXPECTED_BUNDLE_ID" ]] || return 1
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist" 2>/dev/null || true)" == "$EXPECTED_OFFICIAL_VERSION" ]] || return 1
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist" 2>/dev/null || true)" == "$EXPECTED_OFFICIAL_BUILD" ]] || return 1
    arches="$(lipo -archs "$main" 2>/dev/null || true)"
    [[ " $arches " == *" arm64 "* && " $arches " == *" x86_64 "* ]] || return 1
    required_executable_modes_ok "$app" || return 1
    [[ ! -e "$app/Contents/Frameworks/AltServerAnisetteFix.dylib" ]] || return 1
    if find -P "$app" \( -path '*AltSign-Dynamic.framework' -o -name '*.ipa' -o -name '*.mobileprovision' -o -name 'embedded.provisionprofile' \) -print -quit | /usr/bin/grep -q .; then
        return 1
    fi
    details="$(codesign --display --verbose=4 "$app" 2>&1)" || return 1
    [[ "$details" == *"Authority=Developer ID Application:"* ]] || return 1
    team="$(printf '%s\n' "$details" | awk -F= '/^TeamIdentifier=/{ print $2; exit }')"
    [[ "$team" == "$EXPECTED_OFFICIAL_TEAM_ID" ]] || return 1
    codesign --verify --deep --strict "$app" >/dev/null 2>&1 || return 1
    spctl_assess "$app" >/dev/null 2>&1 || return 1
    xcrun stapler validate "$app" >/dev/null 2>&1 || return 1
    actual_hash="$(shasum -a 256 "$main" | awk '{ print $1 }')"
    [[ "$actual_hash" == "$EXPECTED_OFFICIAL_MAIN_SHA" ]] || return 1
    if [[ -n "$expected_snapshot" ]]; then
        snapshot="$(bundle_snapshot_hash "$app")" || return 1
        [[ "$snapshot" == "$expected_snapshot" ]] || return 1
    fi
    return 0
}

validate_patched_target()
{
    local app="$1"
    local plist="$app/Contents/Info.plist"
    local details arches
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist" 2>/dev/null || true)" == "$EXPECTED_BUNDLE_ID" ]] || return 1
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist" 2>/dev/null || true)" == "$EXPECTED_PATCHED_VERSION" ]] || return 1
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist" 2>/dev/null || true)" == "$EXPECTED_PATCHED_BUILD" ]] || return 1
    [[ -f "$app/Contents/Frameworks/AltServerAnisetteFix.dylib" && ! -L "$app/Contents/Frameworks/AltServerAnisetteFix.dylib" ]] || return 1
    [[ -f "$app/Contents/Frameworks/AltServerAnisetteHelper" && ! -L "$app/Contents/Frameworks/AltServerAnisetteHelper" ]] || return 1
    if find -P "$app" \( -path '*AltSign-Dynamic.framework' -o -name '*.ipa' -o -name '*.mobileprovision' -o -name 'embedded.provisionprofile' \) -print -quit | /usr/bin/grep -q .; then
        return 1
    fi
    tree_regular_nlink_one "$app" || return 1
    required_executable_modes_ok "$app" || return 1
    arches="$(lipo -archs "$app/Contents/MacOS/AltServer" 2>/dev/null || true)"
    [[ " $arches " == *" arm64 "* && " $arches " == *" x86_64 "* ]] || return 1
    details="$(codesign --display --verbose=4 "$app" 2>&1)" || return 1
    [[ "$details" == *"Signature=adhoc"* ]] || return 1
    codesign --verify --deep --strict "$app" >/dev/null 2>&1 || return 1
    return 0
}

validate_target_state()
{
    local app="$1"
    local plist="$app/Contents/Info.plist"
    local version build
    [[ -d "$app" && ! -L "$app" && "$app" == "${app:A}" ]] || return 1
    path_has_symlink "$app" && return 1
    [[ -f "$plist" && ! -L "$plist" ]] || return 1
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist" 2>/dev/null || true)" == "$EXPECTED_BUNDLE_ID" ]] || return 1
    version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist" 2>/dev/null || true)"
    build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist" 2>/dev/null || true)"
    if [[ "$version" == "$EXPECTED_PATCHED_VERSION" && "$build" == "$EXPECTED_PATCHED_BUILD" ]]; then
        validate_patched_target "$app"
        return $?
    fi
    if [[ "$version" == "$EXPECTED_OFFICIAL_VERSION" && "$build" == "$EXPECTED_OFFICIAL_BUILD" ]]; then
        backup_app_provenance_ok "$app"
        return $?
    fi
    return 1
}

BACKUP_ROOT_KEY=""
BACKUP=""
BACKUP_CANDIDATE_KEY=""
BACKUP_APP_SOURCE=""
BACKUP_METADATA_SOURCE=""
BACKUP_APP_PARENT_KEY=""
BACKUP_METADATA_PARENT_KEY=""
BACKUP_APP_KEY=""
BACKUP_METADATA_KEY=""
BACKUP_METADATA_HASH=""
BACKUP_MAIN_HASH=""
BACKUP_APP_SNAPSHOT_HASH=""

backup_root_ok()
{
    local mode
    [[ -d "$BACKUP_ROOT" && ! -L "$BACKUP_ROOT" ]] || return 1
    [[ "$BACKUP_ROOT" == "${BACKUP_ROOT:A}" ]] || return 1
    path_has_symlink "$BACKUP_ROOT" && return 1
    [[ -n "$BACKUP_ROOT_KEY" ]] || return 1
    [[ "$(stat -f '%d:%i' "$BACKUP_ROOT" 2>/dev/null || true)" == "$BACKUP_ROOT_KEY" ]] || return 1
    mode="$(stat -f '%Lp' "$BACKUP_ROOT" 2>/dev/null || true)"
    [[ "$mode" == <-> ]] || return 1
    # The restore never changes this directory.  Owner-write is compatible
    # with old 0755 roots; group/other write is not.
    (( 8#$mode & 8#022 )) && return 1
    return 0
}

prepare_backup_root()
{
    local backup_parent mode
    [[ -n "$HOME_PATH" && "$HOME_PATH" == "${HOME_PATH:A}" ]] || fail "HOME must be a canonical path for backup storage."
    path_has_symlink "$HOME_PATH" && fail "HOME contains a symlink; backup storage is unsafe."
    backup_parent="${BACKUP_ROOT:h}"
    [[ "$BACKUP_ROOT" == "${BACKUP_ROOT:A}" && "$backup_parent" == "${backup_parent:A}" ]] || fail "backup path aliases through a symlink."
    path_has_symlink "$backup_parent" && fail "backup parent contains a symlink."
    [[ -d "$BACKUP_ROOT" && ! -L "$BACKUP_ROOT" ]] || fail "no official AltServer backup is available."
    mode="$(stat -f '%Lp' "$BACKUP_ROOT" 2>/dev/null || true)"
    [[ "$mode" == <-> ]] || fail "backup root mode is unavailable."
    (( 8#$mode & 8#022 )) && fail "backup root is writable by an untrusted group."
    BACKUP_ROOT_KEY="$(stat -f '%d:%i' "$BACKUP_ROOT" 2>/dev/null || true)"
    [[ -n "$BACKUP_ROOT_KEY" ]] || fail "backup root identity is unavailable."
    backup_root_ok || fail "backup root changed during validation."
}

validate_backup_candidate()
{
    local candidate="$1"
    local app_source metadata main saved_hash actual_hash candidate_key
    local line
    backup_root_ok || return 1
    [[ -d "$candidate" && ! -L "$candidate" ]] || return 1
    [[ "$candidate:h" == "$BACKUP_ROOT" && "$candidate" == "${candidate:A}" ]] || return 1
    path_has_symlink "$candidate" && return 1
    candidate_key="$(stat -f '%d:%i' "$candidate" 2>/dev/null || true)"
    [[ -n "$candidate_key" ]] || return 1
    if [[ "$candidate" == "$BACKUP_ROOT/"*.backup ]]; then
        [[ "${candidate:t}" == AltServer-*.backup ]] || return 1
        app_source="$candidate/AltServer.app"
        metadata="$candidate/metadata"
        [[ -d "$app_source" && ! -L "$app_source" && -f "$metadata" && ! -L "$metadata" ]] || return 1
        while IFS= read -r line; do
            case "${line:t}" in
                AltServer.app|metadata) ;;
                *) return 1 ;;
            esac
        done < <(find -P "$candidate" -mindepth 1 -maxdepth 1 -print)
        [[ "$(find -P "$candidate" -mindepth 1 -maxdepth 1 -print | wc -l | tr -d '[:space:]')" == "2" ]] || return 1
        BACKUP_APP_PARENT_KEY="$candidate_key"
        BACKUP_METADATA_PARENT_KEY="$candidate_key"
    elif [[ "$candidate" == "$BACKUP_ROOT/"*.app ]]; then
        [[ "${candidate:t}" == AltServer-*.app ]] || return 1
        app_source="$candidate"
        metadata="$candidate.metadata"
        # Missing legacy sidecars are intentionally skipped, never repaired.
        [[ -f "$metadata" && ! -L "$metadata" ]] || return 1
        [[ "$metadata:h" == "$BACKUP_ROOT" ]] || return 1
        BACKUP_APP_PARENT_KEY="$BACKUP_ROOT_KEY"
        BACKUP_METADATA_PARENT_KEY="$BACKUP_ROOT_KEY"
    else
        return 1
    fi
    main="$app_source/Contents/MacOS/AltServer"
    [[ "$app_source" == "${app_source:A}" && "$metadata" == "${metadata:A}" ]] || return 1
    path_has_symlink "$app_source" && return 1
    path_has_symlink "$metadata" && return 1
    backup_metadata_exact_ok "$metadata" || return 1
    saved_hash="$(awk -F= '$1 == "MainExecutableSHA256" { print $2; exit }' "$metadata")"
    [[ "$saved_hash" == "$EXPECTED_OFFICIAL_MAIN_SHA" ]] || return 1
    backup_app_provenance_ok "$app_source" || return 1
    actual_hash="$(shasum -a 256 "$main" | awk '{ print $1 }')"
    [[ "$saved_hash" == "$actual_hash" && "$actual_hash" == "$EXPECTED_OFFICIAL_MAIN_SHA" ]] || return 1
    [[ "$(stat -f '%d:%i' "$candidate" 2>/dev/null || true)" == "$candidate_key" ]] || return 1
    BACKUP_CANDIDATE_KEY="$candidate_key"
    BACKUP_APP_SOURCE="$app_source"
    BACKUP_METADATA_SOURCE="$metadata"
    BACKUP_APP_KEY="$(stat -f '%d:%i' "$app_source" 2>/dev/null || true)"
    BACKUP_METADATA_KEY="$(stat -f '%d:%i' "$metadata" 2>/dev/null || true)"
    BACKUP_METADATA_HASH="$(shasum -a 256 "$metadata" | awk '{ print $1 }')"
    BACKUP_MAIN_HASH="$actual_hash"
    BACKUP_APP_SNAPSHOT_HASH="$(bundle_snapshot_hash "$app_source")" || return 1
    [[ -n "$BACKUP_APP_KEY" && -n "$BACKUP_METADATA_KEY" && -n "$BACKUP_METADATA_HASH" && -n "$BACKUP_APP_SNAPSHOT_HASH" ]] || return 1
    [[ -n "$BACKUP_APP_PARENT_KEY" && -n "$BACKUP_METADATA_PARENT_KEY" ]] || return 1
    return 0
}

backup_candidate_unchanged()
{
    local current_snapshot current_meta current_main line
    backup_root_ok || return 1
    [[ -n "$BACKUP_CANDIDATE_KEY" && -n "$BACKUP_APP_KEY" && -n "$BACKUP_METADATA_KEY" ]] || return 1
    [[ "$(stat -f '%d:%i' "$BACKUP" 2>/dev/null || true)" == "$BACKUP_CANDIDATE_KEY" ]] || return 1
    if [[ "$BACKUP" == "$BACKUP_ROOT/"*.backup ]]; then
        [[ "$(find -P "$BACKUP" -mindepth 1 -maxdepth 1 -print | wc -l | tr -d '[:space:]')" == "2" ]] || return 1
        while IFS= read -r line; do
            case "${line:t}" in AltServer.app|metadata) ;; *) return 1 ;; esac
        done < <(find -P "$BACKUP" -mindepth 1 -maxdepth 1 -print)
    fi
    [[ "$(stat -f '%d:%i' "$BACKUP_APP_SOURCE" 2>/dev/null || true)" == "$BACKUP_APP_KEY" ]] || return 1
    [[ "$(stat -f '%d:%i' "$BACKUP_METADATA_SOURCE" 2>/dev/null || true)" == "$BACKUP_METADATA_KEY" ]] || return 1
    backup_metadata_exact_ok "$BACKUP_METADATA_SOURCE" || return 1
    current_meta="$(shasum -a 256 "$BACKUP_METADATA_SOURCE" | awk '{ print $1 }')"
    [[ "$current_meta" == "$BACKUP_METADATA_HASH" ]] || return 1
    current_main="$(shasum -a 256 "$BACKUP_APP_SOURCE/Contents/MacOS/AltServer" | awk '{ print $1 }')"
    [[ "$current_main" == "$BACKUP_MAIN_HASH" ]] || return 1
    current_snapshot="$(bundle_snapshot_hash "$BACKUP_APP_SOURCE")" || return 1
    [[ "$current_snapshot" == "$BACKUP_APP_SNAPSHOT_HASH" ]] || return 1
    backup_app_provenance_ok "$BACKUP_APP_SOURCE" "$BACKUP_APP_SNAPSHOT_HASH" || return 1
    return 0
}

select_backup()
{
    local requested="${1:-}" candidate
    if [[ -n "$requested" ]]; then
        [[ "$requested" == "$BACKUP_ROOT/"*.backup || "$requested" == "$BACKUP_ROOT/"*.app ]] || fail "requested backup is outside the backup directory."
        BACKUP="$requested"
        validate_backup_candidate "$BACKUP" || fail "requested backup is not a verified official AltServer build 94."
        return 0
    fi
    while IFS= read -r candidate; do
        if validate_backup_candidate "$candidate"; then
            BACKUP="$candidate"
            return 0
        fi
    done < <(find -P "$BACKUP_ROOT" -maxdepth 1 \( -type d -name 'AltServer-*.backup' -o -type d -name 'AltServer-*.app' \) -print | sort -r)
    fail "no verified official AltServer backup is available."
}

# The C helper is the only implementation of restore-side move, remove, copy,
# and lock operations.  All paths are reopened from descriptor-bound parents;
# every operation checks the expected device/inode before and after mutation.
ATOMIC_HELPER=""
ATOMIC_HELPER_SOURCE=""
ATOMIC_HELPER_READY=0
TEMP_ROOT=""
TEMP_PARENT_REAL=""
TEMP_PARENT_KEY=""
TEMP_ROOT_KEY=""
RESTORE_LOCK_NAME=".AltServer-install.lock"
RESTORE_LOCK_PARENT_REAL="/private/var/run"
RESTORE_LOCK_PARENT_KEY=""
RESTORE_LOCK_KEY=""
RESTORE_LOCK_OWNER_START="$(date -u +%s)"
RESTORE_LOCK_HELD=0

build_atomic_helper()
{
    ATOMIC_HELPER_SOURCE="$TEMP_ROOT/.altserver-atomic.c"
    ATOMIC_HELPER="$TEMP_ROOT/.altserver-atomic"
    cat > "$ATOMIC_HELPER_SOURCE" <<'ATOMIC_HELPER_C'
#define _DARWIN_C_SOURCE
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/stdio.h>
#include <fcntl.h>
#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>

extern int renameatx_np(int, const char *, int, const char *, unsigned int);

static int valid_name(const char *name)
{
    return name != NULL && name[0] != '\0' && strcmp(name, ".") != 0 &&
           strcmp(name, "..") != 0 && strlen(name) < NAME_MAX &&
           strchr(name, '/') == NULL && strchr(name, '\\') == NULL;
}

static int parse_key(const char *text, dev_t *device, ino_t *inode)
{
    char *end = NULL;
    unsigned long long d;
    unsigned long long i;
    if (text == NULL || device == NULL || inode == NULL)
        return 0;
    d = strtoull(text, &end, 10);
    if (end == text || *end != ':')
        return 0;
    i = strtoull(end + 1, &end, 10);
    if (end == NULL || *end != '\0')
        return 0;
    *device = (dev_t)d;
    *inode = (ino_t)i;
    return 1;
}

static int same_key(const struct stat *info, const char *text)
{
    dev_t device;
    ino_t inode;
    return info != NULL && parse_key(text, &device, &inode) &&
           info->st_dev == device && info->st_ino == inode;
}

static int same_identity(const struct stat *left, const struct stat *right)
{
    return left != NULL && right != NULL && left->st_dev == right->st_dev &&
           left->st_ino == right->st_ino &&
           (left->st_mode & S_IFMT) == (right->st_mode & S_IFMT);
}

static int open_parent(const char *path, const char *expected)
{
    char copy[PATH_MAX];
    char *cursor;
    struct stat info;
    int fd;
    if (path == NULL || path[0] != '/' || strlen(path) >= sizeof(copy))
        return -1;
    memcpy(copy, path, strlen(path) + 1);
    fd = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0)
        return -1;
    cursor = copy + 1;
    while (*cursor != '\0') {
        char *slash = strchr(cursor, '/');
        int next;
        if (slash != NULL)
            *slash = '\0';
        if (!valid_name(cursor)) {
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
        if (slash == NULL)
            break;
        cursor = slash + 1;
    }
    if (fstat(fd, &info) != 0 || !S_ISDIR(info.st_mode) ||
        !same_key(&info, expected)) {
        close(fd);
        errno = EACCES;
        return -1;
    }
    return fd;
}

static int write_all(int fd, const unsigned char *buffer, size_t length)
{
    size_t offset = 0;
    while (offset < length) {
        ssize_t count = write(fd, buffer + offset, length - offset);
        if (count <= 0)
            return 0;
        offset += (size_t)count;
    }
    return 1;
}

/* Validate the complete tree before the destructive pass.  The remove pass
 * still rechecks every opened child, but this preflight prevents an ordinary
 * validation failure from deleting an earlier sibling and then returning a
 * partially removed recovery tree. */
static int verify_tree_fd(int directory_fd, const struct stat *expected_root)
{
    struct stat root_info;
    DIR *directory;
    struct dirent *entry;
    int scan_fd;
    int result = 1;
    if (fstat(directory_fd, &root_info) != 0 || !S_ISDIR(root_info.st_mode) ||
        (expected_root != NULL && !same_identity(&root_info, expected_root)))
        return 0;
    scan_fd = openat(directory_fd, ".",
                     O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (scan_fd < 0)
        return 0;
    directory = fdopendir(scan_fd);
    if (directory == NULL) {
        close(scan_fd);
        return 0;
    }
    errno = 0;
    while ((entry = readdir(directory)) != NULL) {
        struct stat before;
        struct stat opened;
        int parent_fd = dirfd(directory);
        int child_fd = -1;
        int file_fd = -1;
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;
        if (!valid_name(entry->d_name) ||
            fstatat(parent_fd, entry->d_name, &before, AT_SYMLINK_NOFOLLOW) != 0) {
            result = 0;
            break;
        }
        if (S_ISDIR(before.st_mode)) {
            child_fd = openat(parent_fd, entry->d_name,
                              O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            if (child_fd < 0 || fstat(child_fd, &opened) != 0 ||
                !same_identity(&before, &opened) ||
                !verify_tree_fd(child_fd, &opened)) {
                if (child_fd >= 0)
                    close(child_fd);
                result = 0;
                break;
            }
            close(child_fd);
        } else if (S_ISREG(before.st_mode)) {
            file_fd = openat(parent_fd, entry->d_name,
                             O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
            if (file_fd < 0 || fstat(file_fd, &opened) != 0 ||
                !same_identity(&before, &opened) || opened.st_nlink != 1) {
                if (file_fd >= 0)
                    close(file_fd);
                result = 0;
                break;
            }
            close(file_fd);
        } else if (!S_ISLNK(before.st_mode)) {
            result = 0;
            break;
        }
    }
    if (errno != 0)
        result = 0;
    closedir(directory);
    return result;
}

static int remove_tree_fd(int directory_fd, const struct stat *expected_root)
{
    struct stat root_info;
    DIR *directory;
    struct dirent *entry;
    if (fstat(directory_fd, &root_info) != 0 || !S_ISDIR(root_info.st_mode) ||
        (expected_root != NULL && !same_identity(&root_info, expected_root))) {
        close(directory_fd);
        return 0;
    }
    directory = fdopendir(directory_fd);
    if (directory == NULL) {
        close(directory_fd);
        return 0;
    }
    errno = 0;
    while ((entry = readdir(directory)) != NULL) {
        struct stat before;
        struct stat opened;
        struct stat after;
        int child_fd = -1;
        int file_fd = -1;
        int parent_fd = dirfd(directory);
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;
        if (!valid_name(entry->d_name) ||
            fstatat(parent_fd, entry->d_name, &before, AT_SYMLINK_NOFOLLOW) != 0) {
            closedir(directory);
            return 0;
        }
        if (S_ISDIR(before.st_mode)) {
            child_fd = openat(parent_fd, entry->d_name,
                              O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            if (child_fd < 0 || fstat(child_fd, &opened) != 0 ||
                !same_identity(&before, &opened) || fchflags(child_fd, 0) != 0) {
                if (child_fd >= 0)
                    close(child_fd);
                closedir(directory);
                return 0;
            }
            if (!remove_tree_fd(child_fd, &opened)) {
                closedir(directory);
                return 0;
            }
            if (fstatat(parent_fd, entry->d_name, &after, AT_SYMLINK_NOFOLLOW) != 0 ||
                !same_identity(&before, &after) ||
                unlinkat(parent_fd, entry->d_name, AT_REMOVEDIR) != 0) {
                closedir(directory);
                return 0;
            }
            continue;
        }
        if (!S_ISREG(before.st_mode) && !S_ISLNK(before.st_mode)) {
            closedir(directory);
            return 0;
        }
        if (S_ISREG(before.st_mode)) {
            file_fd = openat(parent_fd, entry->d_name,
                             O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
            if (file_fd < 0 || fstat(file_fd, &opened) != 0 ||
                !same_identity(&before, &opened) || opened.st_nlink != 1 ||
                fchflags(file_fd, 0) != 0) {
                if (file_fd >= 0)
                    close(file_fd);
                closedir(directory);
                return 0;
            }
            close(file_fd);
        }
        if (fstatat(parent_fd, entry->d_name, &after, AT_SYMLINK_NOFOLLOW) != 0 ||
            !same_identity(&before, &after) ||
            (S_ISREG(before.st_mode) && !same_identity(&opened, &after)) ||
            unlinkat(parent_fd, entry->d_name, 0) != 0) {
            closedir(directory);
            return 0;
        }
    }
    if (errno != 0) {
        closedir(directory);
        return 0;
    }
    closedir(directory);
    return 1;
}

static int remove_entry(const char *parent_path, const char *parent_key,
                        const char *name, const char *entry_key)
{
    struct stat before;
    struct stat opened;
    struct stat after;
    int parent_fd;
    int child_fd;
    if (!valid_name(name) || (parent_fd = open_parent(parent_path, parent_key)) < 0)
        return 0;
    if (fstatat(parent_fd, name, &before, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(before.st_mode) || !same_key(&before, entry_key)) {
        close(parent_fd);
        return 0;
    }
    child_fd = openat(parent_fd, name,
                      O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (child_fd < 0 || fstat(child_fd, &opened) != 0 ||
        !same_identity(&before, &opened) || !same_key(&opened, entry_key) ||
        fchflags(child_fd, 0) != 0) {
        if (child_fd >= 0)
            close(child_fd);
        close(parent_fd);
        return 0;
    }
    if (!verify_tree_fd(child_fd, &opened) || !remove_tree_fd(child_fd, &opened) ||
        fstatat(parent_fd, name, &after, AT_SYMLINK_NOFOLLOW) != 0 ||
        !same_identity(&before, &after) || !same_key(&after, entry_key) ||
        unlinkat(parent_fd, name, AT_REMOVEDIR) != 0) {
        close(parent_fd);
        return 0;
    }
    close(parent_fd);
    return 1;
}

static int check_entry(const char *parent_path, const char *parent_key,
                       const char *name, const char *entry_key)
{
    struct stat info;
    int parent_fd;
    if (!valid_name(name) || (parent_fd = open_parent(parent_path, parent_key)) < 0)
        return 0;
    if (fstatat(parent_fd, name, &info, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(info.st_mode) || !same_key(&info, entry_key)) {
        close(parent_fd);
        return 0;
    }
    close(parent_fd);
    return 1;
}

static int move_entry(const char *source_parent_path, const char *source_parent_key,
                      const char *source_name, const char *source_key,
                      const char *destination_parent_path,
                      const char *destination_parent_key,
                      const char *destination_name)
{
    struct stat source_info;
    struct stat destination_info;
    int source_parent;
    int destination_parent;
    int same_parent;
    if (!valid_name(source_name) || !valid_name(destination_name))
        return 0;
    source_parent = open_parent(source_parent_path, source_parent_key);
    if (source_parent < 0)
        return 0;
    same_parent = strcmp(source_parent_path, destination_parent_path) == 0 &&
                  strcmp(source_parent_key, destination_parent_key) == 0;
    destination_parent = same_parent ? source_parent :
                         open_parent(destination_parent_path, destination_parent_key);
    if (destination_parent < 0) {
        close(source_parent);
        return 0;
    }
    if (fstatat(source_parent, source_name, &source_info, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(source_info.st_mode) || !same_key(&source_info, source_key) ||
        fstatat(destination_parent, destination_name, &destination_info,
                AT_SYMLINK_NOFOLLOW) == 0 || errno != ENOENT ||
        renameatx_np(source_parent, source_name, destination_parent, destination_name,
                     RENAME_EXCL) != 0) {
        if (!same_parent)
            close(destination_parent);
        close(source_parent);
        return 0;
    }
    /* The rename is now committed.  Return 2 if a post-check sees a race so
     * the shell wrapper still records the source identity for rollback. */
    if (fstatat(destination_parent, destination_name, &destination_info,
                AT_SYMLINK_NOFOLLOW) != 0 || !same_key(&destination_info, source_key) ||
        fstatat(source_parent, source_name, &source_info, AT_SYMLINK_NOFOLLOW) == 0 ||
        errno != ENOENT) {
        if (!same_parent)
            close(destination_parent);
        close(source_parent);
        return 2;
    }
    if (!same_parent)
        close(destination_parent);
    close(source_parent);
    return 1;
}

static int copy_file_at(int source_parent, const char *source_name,
                        const struct stat *expected, int destination_parent,
                        const char *destination_name)
{
    struct stat opened;
    struct stat after;
    int source_fd = -1;
    int destination_fd = -1;
    unsigned char buffer[131072];
    ssize_t count;
    source_fd = openat(source_parent, source_name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (source_fd < 0 || fstat(source_fd, &opened) != 0 ||
        !same_identity(&opened, expected) || !S_ISREG(opened.st_mode) ||
        opened.st_nlink != 1)
        goto failed;
    destination_fd = openat(destination_parent, destination_name,
                            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
                            opened.st_mode & 07777);
    if (destination_fd < 0)
        goto failed;
    while ((count = read(source_fd, buffer, sizeof(buffer))) > 0) {
        if (!write_all(destination_fd, buffer, (size_t)count))
            goto failed;
    }
    if (count < 0 || fchmod(destination_fd, opened.st_mode & 07777) != 0 ||
        fsync(destination_fd) != 0 ||
        fstatat(source_parent, source_name, &after, AT_SYMLINK_NOFOLLOW) != 0 ||
        !same_identity(&opened, &after))
        goto failed;
    close(source_fd);
    close(destination_fd);
    return 1;
failed:
    if (source_fd >= 0)
        close(source_fd);
    if (destination_fd >= 0)
        close(destination_fd);
    (void)unlinkat(destination_parent, destination_name, 0);
    return 0;
}

static int copy_symlink_at(int source_parent, const char *source_name,
                           const struct stat *expected, int destination_parent,
                           const char *destination_name)
{
    struct stat after;
    char target[PATH_MAX];
    ssize_t length;
    length = readlinkat(source_parent, source_name, target, sizeof(target) - 1);
    if (length < 0 || (size_t)length >= sizeof(target) - 1 ||
        fstatat(source_parent, source_name, &after, AT_SYMLINK_NOFOLLOW) != 0 ||
        !same_identity(expected, &after))
        return 0;
    target[length] = '\0';
    if (symlinkat(target, destination_parent, destination_name) != 0)
        return 0;
    if (fstatat(source_parent, source_name, &after, AT_SYMLINK_NOFOLLOW) != 0 ||
        !same_identity(expected, &after)) {
        (void)unlinkat(destination_parent, destination_name, 0);
        return 0;
    }
    return 1;
}

static int copy_directory_contents(int source_fd, int destination_fd)
{
    DIR *directory;
    struct dirent *entry;
    int result = 1;
    directory = fdopendir(dup(source_fd));
    if (directory == NULL)
        return 0;
    errno = 0;
    while ((entry = readdir(directory)) != NULL) {
        struct stat before;
        int parent_fd = dirfd(directory);
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;
        if (!valid_name(entry->d_name) ||
            fstatat(parent_fd, entry->d_name, &before, AT_SYMLINK_NOFOLLOW) != 0) {
            result = 0;
            break;
        }
        if (S_ISDIR(before.st_mode)) {
            struct stat opened;
            int child_source = -1;
            int child_destination = -1;
            if (mkdirat(destination_fd, entry->d_name, 0700) != 0)
                { result = 0; break; }
            child_source = openat(parent_fd, entry->d_name,
                                  O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            child_destination = openat(destination_fd, entry->d_name,
                                       O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            if (child_source < 0 || child_destination < 0 ||
                fstat(child_source, &opened) != 0 ||
                !same_identity(&before, &opened) ||
                !copy_directory_contents(child_source, child_destination) ||
                fchmod(child_destination, opened.st_mode & 07777) != 0 ||
                fsync(child_destination) != 0) {
                if (child_source >= 0) close(child_source);
                if (child_destination >= 0) close(child_destination);
                result = 0;
                break;
            }
            close(child_source);
            close(child_destination);
        } else if (S_ISREG(before.st_mode)) {
            if (copy_file_at(parent_fd, entry->d_name, &before, destination_fd,
                             entry->d_name) == 0)
                { result = 0; break; }
        } else if (S_ISLNK(before.st_mode)) {
            if (copy_symlink_at(parent_fd, entry->d_name, &before, destination_fd,
                                entry->d_name) == 0)
                { result = 0; break; }
        } else {
            result = 0;
            break;
        }
    }
    if (errno != 0)
        result = 0;
    closedir(directory);
    return result;
}

static int copy_entry(const char *source_parent_path, const char *source_parent_key,
                      const char *source_name, const char *source_key,
                      const char *destination_parent_path,
                      const char *destination_parent_key,
                      const char *destination_name)
{
    struct stat source_info;
    struct stat source_after;
    struct stat destination_info;
    int source_parent = -1;
    int destination_parent = -1;
    int source_fd = -1;
    int destination_fd = -1;
    if (!valid_name(source_name) || !valid_name(destination_name))
        return 0;
    source_parent = open_parent(source_parent_path, source_parent_key);
    destination_parent = open_parent(destination_parent_path, destination_parent_key);
    if (source_parent < 0 || destination_parent < 0)
        goto failed;
    if (fstatat(source_parent, source_name, &source_info, AT_SYMLINK_NOFOLLOW) != 0 ||
        !same_key(&source_info, source_key) || source_info.st_nlink < 1 ||
        fstatat(destination_parent, destination_name, &destination_info,
                AT_SYMLINK_NOFOLLOW) == 0 || errno != ENOENT)
        goto failed;
    if (S_ISDIR(source_info.st_mode)) {
        if (mkdirat(destination_parent, destination_name, 0700) != 0)
            goto failed;
        source_fd = openat(source_parent, source_name,
                           O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        destination_fd = openat(destination_parent, destination_name,
                                O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (source_fd < 0 || destination_fd < 0 ||
            fstat(source_fd, &source_after) != 0 ||
            !same_identity(&source_info, &source_after) ||
            !copy_directory_contents(source_fd, destination_fd) ||
            fchmod(destination_fd, source_info.st_mode & 07777) != 0 ||
            fsync(destination_fd) != 0 ||
            fstatat(source_parent, source_name, &source_after, AT_SYMLINK_NOFOLLOW) != 0 ||
            !same_identity(&source_info, &source_after))
            goto failed;
    } else if (S_ISREG(source_info.st_mode)) {
        if (copy_file_at(source_parent, source_name, &source_info, destination_parent,
                         destination_name) == 0)
            goto failed;
    } else if (S_ISLNK(source_info.st_mode)) {
        if (copy_symlink_at(source_parent, source_name, &source_info, destination_parent,
                            destination_name) == 0)
            goto failed;
    } else {
        goto failed;
    }
    if (source_fd >= 0) close(source_fd);
    if (destination_fd >= 0) close(destination_fd);
    if (source_parent >= 0) close(source_parent);
    if (destination_parent >= 0) close(destination_parent);
    return 1;
failed:
    if (source_fd >= 0) close(source_fd);
    if (destination_fd >= 0) close(destination_fd);
    if (source_parent >= 0) close(source_parent);
    if (destination_parent >= 0) close(destination_parent);
    return 0;
}

static int format_key(const struct stat *info, char *buffer, size_t capacity)
{
    int length;
    if (info == NULL || buffer == NULL || capacity < 2)
        return 0;
    length = snprintf(buffer, capacity, "%llu:%llu",
                      (unsigned long long)info->st_dev,
                      (unsigned long long)info->st_ino);
    return length > 0 && (size_t)length < capacity;
}

static int read_owner(int lockfd, char *buffer, size_t capacity,
                      struct stat *owner_info)
{
    struct stat before;
    struct stat opened;
    struct stat after;
    int fd;
    ssize_t count;
    if (capacity < 2 || owner_info == NULL ||
        fstatat(lockfd, "owner", &before, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISREG(before.st_mode) || before.st_nlink != 1)
        return 0;
    fd = openat(lockfd, "owner", O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0 || fstat(fd, &opened) != 0 || !same_identity(&before, &opened) ||
        !S_ISREG(opened.st_mode) || opened.st_nlink != 1)
        { if (fd >= 0) close(fd); return 0; }
    count = read(fd, buffer, capacity - 1);
    if (count <= 0 || (size_t)count >= capacity)
        { close(fd); return 0; }
    buffer[count] = '\0';
    if (fstatat(lockfd, "owner", &after, AT_SYMLINK_NOFOLLOW) != 0 ||
        !same_identity(&opened, &after))
        { close(fd); return 0; }
    *owner_info = opened;
    close(fd);
    return strchr(buffer, '\0') != NULL;
}

static int lock_identity_ok(int parent_fd, const char *parent_key,
                            const char *lock_name, int lock_fd,
                            const struct stat *lock_info)
{
    struct stat parent_info;
    struct stat path_info;
    struct stat fd_info;
    return fstat(parent_fd, &parent_info) == 0 &&
           same_key(&parent_info, parent_key) &&
           fstat(lock_fd, &fd_info) == 0 && same_identity(&fd_info, lock_info) &&
           fstatat(parent_fd, lock_name, &path_info, AT_SYMLINK_NOFOLLOW) == 0 &&
           S_ISDIR(path_info.st_mode) && same_identity(&path_info, lock_info);
}

static int owner_identity_ok(int lock_fd, const struct stat *owner_info)
{
    struct stat path_info;
    return fstatat(lock_fd, "owner", &path_info, AT_SYMLINK_NOFOLLOW) == 0 &&
           S_ISREG(path_info.st_mode) && path_info.st_nlink == 1 &&
           same_identity(&path_info, owner_info);
}

static int owner_matches(const char *owner, const char *pid,
                         const char *start, const char *parent)
{
    char expected[512];
    int length;
    if (owner == NULL || pid == NULL || start == NULL || parent == NULL ||
        strpbrk(pid, "\r\n") != NULL || strpbrk(start, "\r\n") != NULL ||
        strpbrk(parent, "\r\n") != NULL)
        return 0;
    length = snprintf(expected, sizeof(expected), "pid=%s\nstart=%s\nparent=%s\n",
                      pid, start, parent);
    return length > 0 && (size_t)length < sizeof(expected) &&
           strcmp(owner, expected) == 0;
}

static int owner_pid_alive(const char *pid_text)
{
    char *end = NULL;
    long pid = strtol(pid_text, &end, 10);
    if (end == pid_text || *end != '\0' || pid <= 0 || pid > 999999999L)
        return 1;
    if (kill((pid_t)pid, 0) == 0 || errno == EPERM)
        return 1;
    return errno != ESRCH;
}

static int create_lock(const char *parent_path, const char *parent_key,
                       const char *lock_name, const char *pid,
                       const char *start, char *lock_key,
                       size_t lock_key_capacity)
{
    char owner[512];
    char existing[512];
    char existing_pid[64];
    char existing_start[128];
    char existing_parent[128];
    struct stat lock_info;
    struct stat owner_info;
    int parent_fd;
    int lock_fd = -1;
    int owner_fd = -1;
    int length;
    int made = 0;
    int owner_bound = 0;
    if (!valid_name(lock_name) || lock_key == NULL || lock_key_capacity < 2 ||
        (parent_fd = open_parent(parent_path, parent_key)) < 0)
        return 0;
    if (mkdirat(parent_fd, lock_name, 0700) != 0) {
        if (errno != EEXIST) { close(parent_fd); return 0; }
        lock_fd = openat(parent_fd, lock_name,
                         O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (lock_fd < 0 || fstat(lock_fd, &lock_info) != 0 ||
            !S_ISDIR(lock_info.st_mode) ||
            !read_owner(lock_fd, existing, sizeof(existing), &owner_info))
            { if (lock_fd >= 0) close(lock_fd); close(parent_fd); return 0; }
        if (sscanf(existing, "pid=%63[^\n]\nstart=%127[^\n]\nparent=%127[^\n]\n",
                   existing_pid, existing_start, existing_parent) == 3 &&
            owner_matches(existing, existing_pid, existing_start, existing_parent) &&
            strcmp(existing_parent, parent_key) == 0 && !owner_pid_alive(existing_pid)) {
            if (!lock_identity_ok(parent_fd, parent_key, lock_name, lock_fd, &lock_info) ||
                !owner_identity_ok(lock_fd, &owner_info) || unlinkat(lock_fd, "owner", 0) != 0 ||
                !lock_identity_ok(parent_fd, parent_key, lock_name, lock_fd, &lock_info) ||
                unlinkat(parent_fd, lock_name, AT_REMOVEDIR) != 0)
                { close(lock_fd); close(parent_fd); return 0; }
            close(lock_fd);
            close(parent_fd);
            return create_lock(parent_path, parent_key, lock_name, pid, start,
                               lock_key, lock_key_capacity);
        }
        close(lock_fd);
        close(parent_fd);
        return 0;
    }
    made = 1;
    lock_fd = openat(parent_fd, lock_name,
                     O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (lock_fd < 0 || fstat(lock_fd, &lock_info) != 0 || !S_ISDIR(lock_info.st_mode))
        goto failed;
    length = snprintf(owner, sizeof(owner), "pid=%s\nstart=%s\nparent=%s\n",
                      pid, start, parent_key);
    if (length <= 0 || (size_t)length >= sizeof(owner))
        goto failed;
    owner_fd = openat(lock_fd, "owner", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (owner_fd < 0 || fstat(owner_fd, &owner_info) != 0 ||
        !S_ISREG(owner_info.st_mode) || owner_info.st_nlink != 1)
        goto failed;
    owner_bound = 1;
    if (!write_all(owner_fd, (const unsigned char *)owner, (size_t)length) ||
        fsync(owner_fd) != 0)
        goto failed;
    close(owner_fd);
    owner_fd = -1;
    if (fsync(lock_fd) != 0 ||
        !lock_identity_ok(parent_fd, parent_key, lock_name, lock_fd, &lock_info) ||
        !owner_identity_ok(lock_fd, &owner_info) ||
        !format_key(&lock_info, lock_key, lock_key_capacity))
        goto failed;
    close(lock_fd);
    close(parent_fd);
    return 1;
failed:
    if (owner_fd >= 0)
        close(owner_fd);
    if (made && lock_fd >= 0 &&
        lock_identity_ok(parent_fd, parent_key, lock_name, lock_fd, &lock_info)) {
        if (owner_bound && owner_identity_ok(lock_fd, &owner_info))
            (void)unlinkat(lock_fd, "owner", 0);
        if (lock_identity_ok(parent_fd, parent_key, lock_name, lock_fd, &lock_info))
            (void)unlinkat(parent_fd, lock_name, AT_REMOVEDIR);
    }
    if (lock_fd >= 0)
        close(lock_fd);
    close(parent_fd);
    return 0;
}

static int release_lock(const char *parent_path, const char *parent_key,
                        const char *lock_name, const char *lock_key,
                        const char *pid, const char *start)
{
    char owner[512];
    struct stat lock_info;
    struct stat owner_info;
    int parent_fd;
    int lock_fd;
    if (!valid_name(lock_name) || (parent_fd = open_parent(parent_path, parent_key)) < 0)
        return 0;
    lock_fd = openat(parent_fd, lock_name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (lock_fd < 0 || fstat(lock_fd, &lock_info) != 0 || !S_ISDIR(lock_info.st_mode) ||
        (lock_key != NULL && lock_key[0] != '\0' && !same_key(&lock_info, lock_key)) ||
        !lock_identity_ok(parent_fd, parent_key, lock_name, lock_fd, &lock_info) ||
        !read_owner(lock_fd, owner, sizeof(owner), &owner_info) ||
        !owner_matches(owner, pid, start, parent_key)) {
        if (lock_fd >= 0) close(lock_fd);
        close(parent_fd);
        return 0;
    }
    if (!owner_identity_ok(lock_fd, &owner_info) ||
        !lock_identity_ok(parent_fd, parent_key, lock_name, lock_fd, &lock_info) ||
        unlinkat(lock_fd, "owner", 0) != 0 ||
        !lock_identity_ok(parent_fd, parent_key, lock_name, lock_fd, &lock_info) ||
        unlinkat(parent_fd, lock_name, AT_REMOVEDIR) != 0) {
        close(lock_fd);
        close(parent_fd);
        return 0;
    }
    close(lock_fd);
    close(parent_fd);
    return 1;
}

int main(int argc, char **argv)
{
    if (argc < 2)
        return 2;
    if (strcmp(argv[1], "move") == 0 && argc == 9) {
        int move_status = move_entry(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8]);
        return move_status == 1 || move_status == 2 ? 0 : 1;
    }
    if (strcmp(argv[1], "remove") == 0 && argc == 6)
        return remove_entry(argv[2], argv[3], argv[4], argv[5]) ? 0 : 1;
    if (strcmp(argv[1], "check") == 0 && argc == 6)
        return check_entry(argv[2], argv[3], argv[4], argv[5]) ? 0 : 1;
    if (strcmp(argv[1], "copy") == 0 && argc == 9)
        return copy_entry(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8]) ? 0 : 1;
    if (strcmp(argv[1], "lock") == 0 && argc == 7) {
        char lock_key[128];
        if (!create_lock(argv[2], argv[3], argv[4], argv[5], argv[6], lock_key, sizeof(lock_key)))
            return 1;
        puts(lock_key);
        return 0;
    }
    if (strcmp(argv[1], "unlock") == 0 && argc == 8)
        return release_lock(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7]) ? 0 : 1;
    return 2;
}
ATOMIC_HELPER_C
    /usr/bin/clang -std=c11 -O2 -Wall -Wextra -Werror "$ATOMIC_HELPER_SOURCE" -o "$ATOMIC_HELPER" || fail "could not build the private restore atomic helper."
    chmod 700 "$ATOMIC_HELPER"
    [[ -x "$ATOMIC_HELPER" && ! -L "$ATOMIC_HELPER" ]] || fail "private restore atomic helper is not executable."
    ATOMIC_HELPER_READY=1
}

atomic_move_path()
{
    local source="$1" source_key="$2" destination="$3" source_parent_key="$4" destination_parent_key="$5"
    local source_parent="${source:h}" destination_parent="${destination:h}"
    [[ -x "$ATOMIC_HELPER" && -n "$source_key" && -n "$source_parent_key" && -n "$destination_parent_key" ]] || return 70
    [[ "$source" == "$source_parent/${source:t}" && "$destination" == "$destination_parent/${destination:t}" ]] || return 70
    [[ "$source_parent" == "${source_parent:A}" && "$destination_parent" == "${destination_parent:A}" ]] || return 70
    path_has_symlink "$source_parent" && return 70
    path_has_symlink "$destination_parent" && return 70
    "$ATOMIC_HELPER" move "$source_parent" "$source_parent_key" "${source:t}" "$source_key" \
        "$destination_parent" "$destination_parent_key" "${destination:t}"
}

atomic_remove_path()
{
    local target="$1" target_key="$2" parent="${target:h}" name="${target:t}" parent_key="$3"
    [[ -x "$ATOMIC_HELPER" && -n "$target_key" && -n "$parent_key" ]] || return 70
    [[ "$target" == "$parent/$name" && "$parent" == "${parent:A}" ]] || return 70
    path_has_symlink "$parent" && return 70
    "$ATOMIC_HELPER" remove "$parent" "$parent_key" "$name" "$target_key"
}

atomic_check_path()
{
    local target="$1" target_key="$2" parent="${target:h}" name="${target:t}" parent_key="$3"
    [[ -x "$ATOMIC_HELPER" && -n "$target_key" && -n "$parent_key" ]] || return 70
    [[ "$target" == "$parent/$name" && "$parent" == "${parent:A}" ]] || return 70
    path_has_symlink "$parent" && return 70
    "$ATOMIC_HELPER" check "$parent" "$parent_key" "$name" "$target_key"
}

atomic_copy_path()
{
    local source="$1" source_key="$2" destination="$3" source_parent_key="$4" destination_parent_key="$5"
    local source_parent="${source:h}" destination_parent="${destination:h}"
    [[ -x "$ATOMIC_HELPER" && -n "$source_key" && -n "$source_parent_key" && -n "$destination_parent_key" ]] || return 70
    [[ "$source" == "$source_parent/${source:t}" && "$destination" == "$destination_parent/${destination:t}" ]] || return 70
    [[ "$source_parent" == "${source_parent:A}" && "$destination_parent" == "${destination_parent:A}" ]] || return 70
    path_has_symlink "$source_parent" && return 70
    path_has_symlink "$destination_parent" && return 70
    "$ATOMIC_HELPER" copy "$source_parent" "$source_parent_key" "${source:t}" "$source_key" \
        "$destination_parent" "$destination_parent_key" "${destination:t}"
}

cleanup_bootstrap_temp()
{
    local root="$TEMP_ROOT"
    local parent="$TEMP_PARENT_REAL"
    [[ -n "$root" && -n "$parent" && -n "$TEMP_PARENT_KEY" && -n "$TEMP_ROOT_KEY" ]] || return 1
    [[ "$root" == "$parent/"* && "$root" == "${root:A}" && "$parent" == "${parent:A}" ]] || return 1
    [[ "${root:t}" == altserver-macOS27-restore.* ]] || return 1
    [[ -d "$root" && ! -L "$root" && -d "$parent" && ! -L "$parent" ]] || return 1
    path_has_symlink "$root" && return 1
    path_has_symlink "$parent" && return 1
    [[ "$(stat -f '%d:%i' "$parent" 2>/dev/null || true)" == "$TEMP_PARENT_KEY" ]] || return 1
    [[ "$(stat -f '%d:%i' "$root" 2>/dev/null || true)" == "$TEMP_ROOT_KEY" ]] || return 1
    [[ "$(stat -f '%u' "$root" 2>/dev/null || true)" == "0" ]] || return 1
    [[ "$(stat -f '%Mp%Lp' "$root" 2>/dev/null || true)" == "0700" ]] || return 1
    /bin/rm -rf "$root" || return 1
    [[ ! -e "$root" && ! -L "$root" ]]
}

cleanup_restore_exit()
{
    local cleanup_status=0
    if [[ "$RESTORE_LOCK_HELD" == "1" && -x "$ATOMIC_HELPER" ]]; then
        "$ATOMIC_HELPER" unlock "$RESTORE_LOCK_PARENT_REAL" "$RESTORE_LOCK_PARENT_KEY" \
            "$RESTORE_LOCK_NAME" "$RESTORE_LOCK_KEY" "$$" "$RESTORE_LOCK_OWNER_START" >/dev/null 2>&1 || cleanup_status=1
        RESTORE_LOCK_HELD=0
    fi
    if [[ -x "$ATOMIC_HELPER" && ! -L "$ATOMIC_HELPER" && -n "$TEMP_ROOT" && -n "$TEMP_PARENT_KEY" && -n "$TEMP_ROOT_KEY" && -e "$TEMP_ROOT" ]]; then
        "$ATOMIC_HELPER" remove "$TEMP_PARENT_REAL" "$TEMP_PARENT_KEY" \
            "${TEMP_ROOT:t}" "$TEMP_ROOT_KEY" >/dev/null 2>&1 || cleanup_status=1
    elif [[ -n "$TEMP_ROOT" && -e "$TEMP_ROOT" ]]; then
        if cleanup_bootstrap_temp; then
            if [[ "$ATOMIC_HELPER_READY" != "1" ]]; then
                echo "Restore: atomic helper bootstrap failed; removed the identity-checked temporary path." >&2
            fi
        else
            cleanup_status=1
            echo "Restore: atomic helper bootstrap cleanup refused; preserving exact temporary path: $TEMP_ROOT" >&2
        fi
    fi
    if (( cleanup_status != 0 )); then
        echo "Restore: private cleanup was identity-checked but could not complete." >&2
    fi
}

if [[ "$RESTORE_DRY_RUN" == "1" ]]; then
    prepare_backup_root
    select_backup "${1:-}"
    if [[ -e "$TARGET_APP" || -L "$TARGET_APP" ]]; then
        validate_target_state "$TARGET_APP" || fail "existing target is not an approved restore-compatible AltServer state."
    fi
    echo "Dry run complete: a verified official AltServer backup is ready to restore."
    echo "No /Applications or Application Support files were changed."
    exit 0
fi

umask 077
[[ -d "/private/tmp" && ! -L "/private/tmp" ]] || fail "private temporary parent is unavailable."
[[ "$(stat -f '%u' /private/tmp 2>/dev/null || true)" == "0" ]] || fail "private temporary parent is not root-owned."
TEMP_ROOT="$(mktemp -d /private/tmp/altserver-macOS27-restore.XXXXXX)" || fail "could not create private restore staging root."
TEMP_ROOT="${TEMP_ROOT:A}"
trap 'cleanup_restore_exit' EXIT
TEMP_PARENT_REAL="${TEMP_ROOT:h}"
TEMP_PARENT_KEY="$(stat -f '%d:%i' "$TEMP_PARENT_REAL" 2>/dev/null || true)"
TEMP_ROOT_KEY="$(stat -f '%d:%i' "$TEMP_ROOT" 2>/dev/null || true)"
[[ "$TEMP_ROOT" == "${TEMP_ROOT:A}" && "$TEMP_PARENT_REAL" == "${TEMP_PARENT_REAL:A}" ]] || fail "private temporary root is not canonical."
[[ -n "$TEMP_PARENT_KEY" && -n "$TEMP_ROOT_KEY" ]] || fail "private temporary root identity is unavailable."
[[ "$(stat -f '%u' "$TEMP_ROOT" 2>/dev/null || true)" == "0" ]] || fail "private temporary root is not root-owned."
[[ "$(stat -f '%Mp%Lp' "$TEMP_ROOT" 2>/dev/null || true)" == "0700" ]] || fail "private temporary root mode is unsafe."
build_atomic_helper

[[ "$RESTORE_LOCK_PARENT_REAL" == "${RESTORE_LOCK_PARENT_REAL:A}" && -d "$RESTORE_LOCK_PARENT_REAL" && ! -L "$RESTORE_LOCK_PARENT_REAL" ]] || fail "restore lock parent is not a canonical directory."
path_has_symlink "$RESTORE_LOCK_PARENT_REAL" && fail "restore lock parent contains a symlink."
[[ "$(stat -f '%u' "$RESTORE_LOCK_PARENT_REAL" 2>/dev/null || true)" == "0" ]] || fail "restore lock parent is not root-owned."
RESTORE_LOCK_PARENT_MODE="$(stat -f '%Lp' "$RESTORE_LOCK_PARENT_REAL" 2>/dev/null || true)"
RESTORE_LOCK_PARENT_GROUP="$(stat -f '%Sg' "$RESTORE_LOCK_PARENT_REAL" 2>/dev/null || true)"
[[ "$RESTORE_LOCK_PARENT_MODE" == <-> ]] || fail "restore lock parent mode is unavailable."
(( 8#$RESTORE_LOCK_PARENT_MODE & 8#002 )) && fail "restore lock parent is world-writable."
if (( 8#$RESTORE_LOCK_PARENT_MODE & 8#020 )) && \
   [[ "$RESTORE_LOCK_PARENT_GROUP" != "wheel" && "$RESTORE_LOCK_PARENT_GROUP" != "daemon" ]]; then
    fail "restore lock parent is writable by an untrusted group."
fi
RESTORE_LOCK_PARENT_KEY="$(stat -f '%d:%i' "$RESTORE_LOCK_PARENT_REAL" 2>/dev/null || true)"
[[ -n "$RESTORE_LOCK_PARENT_KEY" ]] || fail "restore lock parent identity is unavailable."
RESTORE_LOCK_KEY="$("$ATOMIC_HELPER" lock "$RESTORE_LOCK_PARENT_REAL" "$RESTORE_LOCK_PARENT_KEY" \
    "$RESTORE_LOCK_NAME" "$$" "$RESTORE_LOCK_OWNER_START")" || fail "another AltServer transaction owns the root lock."
[[ "$RESTORE_LOCK_KEY" == <->:<-> ]] || fail "restore lock identity is invalid."
RESTORE_LOCK_HELD=1

# The fixed lock is held before any protected backup or target validation.
prepare_backup_root
select_backup "${1:-}"
backup_candidate_unchanged || fail "selected backup changed before root staging."

TARGET_PARENT_REAL="${TARGET_APP:h:A}"
TARGET_PARENT_KEY="$(stat -f '%d:%i' "$TARGET_PARENT_REAL" 2>/dev/null || true)"
[[ -d "$TARGET_PARENT_REAL" && ! -L "$TARGET_PARENT_REAL" && -n "$TARGET_PARENT_KEY" ]] || fail "target parent is not a stable directory."
path_has_symlink "$TARGET_PARENT_REAL" && fail "target parent contains a symlink."
CURRENT_PRESENT=0
TARGET_KEY=""
TARGET_HASH=""
TARGET_MAIN_HASH=""
TARGET_STATE=""
if [[ -e "$TARGET_APP" || -L "$TARGET_APP" ]]; then
    [[ -d "$TARGET_APP" && ! -L "$TARGET_APP" && "$TARGET_APP" == "${TARGET_APP:A}" ]] || fail "existing AltServer target is not a canonical directory app."
    path_has_symlink "$TARGET_APP" && fail "existing AltServer target path contains a symlink."
    TARGET_KEY="$(stat -f '%d:%i' "$TARGET_APP" 2>/dev/null || true)"
    TARGET_HASH="$(bundle_snapshot_hash "$TARGET_APP")" || fail "could not capture the current target snapshot."
    TARGET_MAIN_HASH="$(shasum -a 256 "$TARGET_APP/Contents/MacOS/AltServer" 2>/dev/null | awk '{ print $1 }' || true)"
    [[ -n "$TARGET_KEY" && -n "$TARGET_HASH" && -n "$TARGET_MAIN_HASH" ]] || fail "current target identity is unavailable."
    if validate_patched_target "$TARGET_APP"; then
        TARGET_STATE="patched"
    elif validate_target_state "$TARGET_APP"; then
        TARGET_STATE="official"
    else
        fail "existing target is neither the approved v3.7 patched app nor official AltServer 1.7.6/build94."
    fi
    CURRENT_PRESENT=1
else
    [[ ! -L "$TARGET_APP" ]] || fail "target path is a symlink."
fi

target_parent_ok()
{
    [[ -d "$TARGET_PARENT_REAL" && ! -L "$TARGET_PARENT_REAL" ]] || return 1
    [[ "$(stat -f '%d:%i' "$TARGET_PARENT_REAL" 2>/dev/null || true)" == "$TARGET_PARENT_KEY" ]] || return 1
    return 0
}

target_binding_ok()
{
    target_parent_ok || return 1
    [[ "$CURRENT_PRESENT" == "1" && -n "$TARGET_KEY" && -n "$TARGET_HASH" ]] || return 1
    [[ -d "$TARGET_APP" && ! -L "$TARGET_APP" && "$TARGET_APP" == "${TARGET_APP:A}" ]] || return 1
    [[ "$(stat -f '%d:%i' "$TARGET_APP" 2>/dev/null || true)" == "$TARGET_KEY" ]] || return 1
    [[ "$(bundle_snapshot_hash "$TARGET_APP" 2>/dev/null || true)" == "$TARGET_HASH" ]] || return 1
    atomic_check_path "$TARGET_APP" "$TARGET_KEY" "$TARGET_PARENT_KEY"
}

target_absent_ok()
{
    target_parent_ok || return 1
    [[ ! -e "$TARGET_APP" && ! -L "$TARGET_APP" ]]
}

stop_target_processes()
{
    local target_exec="$1" target_real="${1:A}" pid executable attempt remaining
    local -a matched=()
    [[ -f "$target_real" && ! -L "$target_real" ]] || return 0
    while IFS= read -r pid; do
        [[ "$pid" == <-> ]] || continue
        # A process is stopped only when lsof proves its exact executable
        # path.  A name-only ps fallback would kill an unrelated AltServer.
        executable="$(/usr/sbin/lsof -a -p "$pid" -d txt -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1 || true)"
        if [[ "$executable" == "$target_real" ]]; then
            kill -TERM "$pid" 2>/dev/null || true
            matched+=($pid)
        fi
    done < <(pgrep -x AltServer 2>/dev/null || true)
    (( ${#matched} == 0 )) && return 0
    remaining=1
    for attempt in {1..20}; do
        remaining=0
        for pid in "${matched[@]}"; do
            if kill -0 "$pid" 2>/dev/null && [[ "$(/usr/sbin/lsof -a -p "$pid" -d txt -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1 || true)" == "$target_real" ]]; then
                remaining=1
                break
            fi
        done
        (( remaining == 0 )) && break
        sleep 0.1
    done
    if (( remaining != 0 )); then
        for pid in "${matched[@]}"; do
            if kill -0 "$pid" 2>/dev/null && [[ "$(/usr/sbin/lsof -a -p "$pid" -d txt -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1 || true)" == "$target_real" ]]; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        done
    fi
}

NONCE="$(date +%s).$$.$RANDOM"
TRANSIENT="$TARGET_APP.__restore.$NONCE"
OLD_TARGET="$TARGET_APP.__old.$NONCE"
FAILED_TARGET="$TARGET_APP.__failed.$NONCE"
STAGE_ROOT="$TEMP_ROOT/stage"
STAGE_APP="$STAGE_ROOT/AltServer.app"
STAGE_METADATA="$STAGE_ROOT/metadata"
STAGE_ROOT_KEY=""
STAGE_APP_KEY=""
STAGE_METADATA_KEY=""
STAGE_METADATA_HASH=""
STAGE_APP_SNAPSHOT_HASH=""
TRANSIENT_KEY=""
OLD_TARGET_KEY=""
FAILED_TARGET_KEY=""
NEW_TARGET_KEY=""
RESTORE_TARGET_MOVED=0
RESTORE_TRANSIENT_MOVED=0
RESTORE_NEW_PUBLISHED=0
RESTORE_RECOVERY_FAILED=0
RESTORE_FAULT="${ALTSERVER_RESTORE_FAULT:-${ALTSERVER_INSTALL_FAULT:-${ALTSERVER_RELEASE_FAULT:-}}}"

restore_fault_enabled()
{
    local wanted="$1" token
    for token in ${(s:,:)RESTORE_FAULT}; do
        [[ "$token" == "$wanted" || "${token//_/-}" == "$wanted" || "${token//-/_}" == "$wanted" ]] && return 0
    done
    return 1
}

restore_path_ok()
{
    local target_path="$1"
    [[ "$target_path" == "$TARGET_APP" || "$target_path" == "$TRANSIENT" || "$target_path" == "$OLD_TARGET" || "$target_path" == "$FAILED_TARGET" ]] || return 1
    [[ "$target_path:h" == "$TARGET_PARENT_REAL" && "$target_path" == "${target_path:A}" ]] || return 1
    path_has_symlink "$target_path" && return 1
    return 0
}

restore_remove()
{
    local target_path="$1" target_key="$2"
    target_parent_ok || return 1
    restore_path_ok "$target_path" || return 1
    [[ -e "$target_path" || -L "$target_path" ]] || return 0
    atomic_remove_path "$target_path" "$target_key" "$TARGET_PARENT_KEY"
}

stage_remove()
{
    local target_path="$1" target_key="$2"
    # The helper's recursive remove operation intentionally accepts directory
    # roots only.  Metadata is private staging content and is removed with the
    # identity-bound TEMP_ROOT cleanup; only the copied app can need an early
    # recovery remove here.
    [[ "$target_path" == "$STAGE_APP" ]] || return 1
    [[ -d "$STAGE_ROOT" && ! -L "$STAGE_ROOT" && -n "$STAGE_ROOT_KEY" ]] || return 1
    [[ "$(stat -f '%d:%i' "$STAGE_ROOT" 2>/dev/null || true)" == "$STAGE_ROOT_KEY" ]] || return 1
    atomic_remove_path "$target_path" "$target_key" "$STAGE_ROOT_KEY"
}

restore_move()
{
    local phase="$1" source="$2" destination="$3" source_key="$4" source_parent_key="$5"
    target_parent_ok || return 70
    restore_path_ok "$destination" || return 70
    if [[ "$source" == "$STAGE_APP" ]]; then
        [[ "$source" == "${source:A}" && ! -L "$source" && -d "$source" ]] || return 70
        path_has_symlink "$source" && return 70
    else
        restore_path_ok "$source" || return 70
    fi
    [[ -d "$source" && ! -L "$source" && ! -e "$destination" && ! -L "$destination" ]] || return 70
    [[ -n "$source_key" && -n "$source_parent_key" ]] || return 70
    if [[ "$source" == "$TARGET_APP" ]]; then
        target_binding_ok || return 70
    elif [[ "$destination" == "$TARGET_APP" ]]; then
        target_absent_ok || return 70
    fi
    restore_fault_enabled "$phase" && return 75
    atomic_move_path "$source" "$source_key" "$destination" "$source_parent_key" "$TARGET_PARENT_KEY" || return 70
    case "$phase" in
        mv-stage-transient) TRANSIENT_KEY="$source_key"; RESTORE_TRANSIENT_MOVED=1 ;;
        mv-old-aside) OLD_TARGET_KEY="$source_key"; RESTORE_TARGET_MOVED=1 ;;
        mv-new-publish) NEW_TARGET_KEY="$source_key"; RESTORE_TRANSIENT_MOVED=0; RESTORE_NEW_PUBLISHED=1 ;;
        mv-new-aside) FAILED_TARGET_KEY="$source_key"; RESTORE_TRANSIENT_MOVED=0; RESTORE_NEW_PUBLISHED=0 ;;
        mv-old-restore) TARGET_KEY="$source_key"; RESTORE_TARGET_MOVED=0 ;;
    esac
    [[ ! -e "$source" && ! -L "$source" && -d "$destination" && ! -L "$destination" ]] || return 70
    [[ "$(stat -f '%d:%i' "$destination" 2>/dev/null || true)" == "$source_key" ]] || return 70
    return 0
}

target_new_identity_ok()
{
    target_parent_ok || return 1
    [[ -n "$NEW_TARGET_KEY" && -d "$TARGET_APP" && ! -L "$TARGET_APP" ]] || return 1
    [[ "$(stat -f '%d:%i' "$TARGET_APP" 2>/dev/null || true)" == "$NEW_TARGET_KEY" ]] || return 1
    [[ "$(bundle_snapshot_hash "$TARGET_APP" 2>/dev/null || true)" == "$STAGE_APP_SNAPSHOT_HASH" ]] || return 1
    atomic_check_path "$TARGET_APP" "$NEW_TARGET_KEY" "$TARGET_PARENT_KEY"
}

restore_report_recovery_failure()
{
    RESTORE_RECOVERY_FAILED=1
    echo "Restore: transaction recovery failed: $1" >&2
    echo "Restore: recoverable paths: target=$TARGET_APP old=$OLD_TARGET failed=$FAILED_TARGET transient=$TRANSIENT" >&2
}

restore_recover()
{
    if [[ "$RESTORE_NEW_PUBLISHED" == "1" && -e "$TARGET_APP" ]]; then
        if ! restore_move mv-new-aside "$TARGET_APP" "$FAILED_TARGET" "$NEW_TARGET_KEY" "$TARGET_PARENT_KEY"; then
            restore_report_recovery_failure "could not move the restored app aside"
        fi
    fi
    if [[ "$RESTORE_RECOVERY_FAILED" == "0" && "$RESTORE_TARGET_MOVED" == "1" ]]; then
        if ! restore_move mv-old-restore "$OLD_TARGET" "$TARGET_APP" "$OLD_TARGET_KEY" "$TARGET_PARENT_KEY"; then
            restore_report_recovery_failure "could not restore the previous app"
        fi
    fi
    if [[ "$RESTORE_RECOVERY_FAILED" == "0" && -e "$TRANSIENT" ]]; then
        if ! restore_remove "$TRANSIENT" "$TRANSIENT_KEY"; then
            restore_report_recovery_failure "could not remove the bound transient app"
        fi
    fi
    if [[ "$RESTORE_RECOVERY_FAILED" == "0" && -e "$STAGE_APP" ]]; then
        if ! stage_remove "$STAGE_APP" "$STAGE_APP_KEY"; then
            restore_report_recovery_failure "could not remove the bound private stage"
        fi
    fi
    [[ "$RESTORE_RECOVERY_FAILED" == "0" ]]
}

restore_direct()
{
    target_parent_ok || return 1
    if [[ "$CURRENT_PRESENT" == "1" ]]; then
        target_binding_ok || return 1
    else
        target_absent_ok || return 1
    fi
    [[ ! -e "$TRANSIENT" && ! -L "$TRANSIENT" && ! -e "$OLD_TARGET" && ! -L "$OLD_TARGET" && ! -e "$FAILED_TARGET" && ! -L "$FAILED_TARGET" ]] || return 1
    [[ ! -e "$STAGE_ROOT" && ! -L "$STAGE_ROOT" ]] || return 1
    mkdir "$STAGE_ROOT" || return 1
    chmod 700 "$STAGE_ROOT" || return 1
    [[ "$(stat -f '%u' "$STAGE_ROOT" 2>/dev/null || true)" == "0" && "$(stat -f '%Mp%Lp' "$STAGE_ROOT" 2>/dev/null || true)" == "0700" ]] || return 1
    STAGE_ROOT_KEY="$(stat -f '%d:%i' "$STAGE_ROOT" 2>/dev/null || true)"
    [[ -n "$STAGE_ROOT_KEY" ]] || return 1
    backup_candidate_unchanged || return 1
    if restore_fault_enabled before-copy || restore_fault_enabled before-app-copy; then
        return 1
    fi
    atomic_copy_path "$BACKUP_APP_SOURCE" "$BACKUP_APP_KEY" "$STAGE_APP" "$BACKUP_APP_PARENT_KEY" "$STAGE_ROOT_KEY" || return 1
    atomic_copy_path "$BACKUP_METADATA_SOURCE" "$BACKUP_METADATA_KEY" "$STAGE_METADATA" "$BACKUP_METADATA_PARENT_KEY" "$STAGE_ROOT_KEY" || return 1
    STAGE_APP_KEY="$(stat -f '%d:%i' "$STAGE_APP" 2>/dev/null || true)"
    STAGE_METADATA_KEY="$(stat -f '%d:%i' "$STAGE_METADATA" 2>/dev/null || true)"
    [[ -d "$STAGE_APP" && ! -L "$STAGE_APP" && -f "$STAGE_METADATA" && ! -L "$STAGE_METADATA" ]] || return 1
    [[ "$(stat -f '%u' "$STAGE_APP" 2>/dev/null || true)" == "0" && "$(stat -f '%u' "$STAGE_METADATA" 2>/dev/null || true)" == "0" ]] || return 1
    STAGE_METADATA_HASH="$(shasum -a 256 "$STAGE_METADATA" | awk '{ print $1 }')"
    STAGE_APP_SNAPSHOT_HASH="$(bundle_snapshot_hash "$STAGE_APP")" || return 1
    [[ "$STAGE_APP_SNAPSHOT_HASH" == "$BACKUP_APP_SNAPSHOT_HASH" && "$STAGE_METADATA_HASH" == "$BACKUP_METADATA_HASH" ]] || return 1
    backup_metadata_exact_ok "$STAGE_METADATA" || return 1
    xattr -cr "$STAGE_APP" 2>/dev/null || true
    backup_app_provenance_ok "$STAGE_APP" "$STAGE_APP_SNAPSHOT_HASH" || return 1
    backup_candidate_unchanged || return 1
    if restore_fault_enabled after-copy || restore_fault_enabled after-app-copy; then
        return 1
    fi
    [[ -n "$STAGE_APP_KEY" && -n "$STAGE_METADATA_KEY" ]] || return 1
    restore_move mv-stage-transient "$STAGE_APP" "$TRANSIENT" "$STAGE_APP_KEY" "$STAGE_ROOT_KEY" || return 1
    if [[ "$CURRENT_PRESENT" == "1" ]]; then
        target_binding_ok || return 1
        restore_move mv-old-aside "$TARGET_APP" "$OLD_TARGET" "$TARGET_KEY" "$TARGET_PARENT_KEY" || return 1
    fi
    target_absent_ok || return 1
    restore_move mv-new-publish "$TRANSIENT" "$TARGET_APP" "$TRANSIENT_KEY" "$TARGET_PARENT_KEY" || return 1
    if restore_fault_enabled after-new-publish || restore_fault_enabled after-new-rename; then
        return 1
    fi
    target_new_identity_ok || return 1
    validate_target_state "$TARGET_APP" || return 1
    backup_app_provenance_ok "$TARGET_APP" "$STAGE_APP_SNAPSHOT_HASH" || return 1
    [[ "$CURRENT_PRESENT" != "1" || -d "$OLD_TARGET" ]] || return 1
    if [[ "$CURRENT_PRESENT" == "1" ]]; then
        restore_fault_enabled before-old-remove && return 1
        target_new_identity_ok || return 1
        restore_remove "$OLD_TARGET" "$OLD_TARGET_KEY" || return 1
    fi
    RESTORE_TARGET_MOVED=0
    RESTORE_TRANSIENT_MOVED=0
    RESTORE_NEW_PUBLISHED=0
    return 0
}

if [[ "$CURRENT_PRESENT" == "1" ]]; then
    target_binding_ok || fail "target changed before the restore transaction."
    stop_target_processes "$TARGET_APP/Contents/MacOS/AltServer"
    target_binding_ok || fail "target changed while stopping AltServer."
else
    target_absent_ok || fail "target parent changed before the restore transaction."
fi

if ! restore_direct; then
    if [[ "$RESTORE_RECOVERY_FAILED" == "0" ]]; then
        restore_recover || true
    fi
    [[ "$RESTORE_RECOVERY_FAILED" == "0" ]] || fail "restore rollback failed; recoverable app paths were preserved."
    fail "restore failed; the previous target and any failed paths were preserved."
fi

/usr/bin/arch -arm64 /usr/bin/open -n "$TARGET_APP" >/dev/null 2>&1 || true
echo "Official AltServer 1.7.6/build94 restored; backups were preserved."
