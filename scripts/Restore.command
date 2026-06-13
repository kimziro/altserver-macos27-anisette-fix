#!/bin/zsh

set -euo pipefail

BACKUP_ROOT="$HOME/Library/Application Support/AltServer-macOS27-Fix/Backups"
TEMP_ROOT="$(mktemp -d /private/tmp/altserver-restore.XXXXXX)"
trap 'rm -rf "$TEMP_ROOT"' EXIT

echo "AltServer restore"
echo

if [[ ! -d "$BACKUP_ROOT" ]]; then
    echo "No AltServer backup was found."
    echo "Install the official AltServer manually from:"
    echo "https://altstore.io"
    if [[ -t 0 ]]; then
        read -k 1 "?Press any key to close."
    fi
    exit 1
fi

BACKUP=""
while IFS= read -r candidate; do
    VERSION="$(/usr/libexec/PlistBuddy \
        -c 'Print :CFBundleShortVersionString' \
        "$candidate/Contents/Info.plist" 2>/dev/null || true)"
    if [[ -n "$VERSION" && "$VERSION" != *"-macOS27-"* ]] \
        && codesign --verify --deep --strict "$candidate" 2>/dev/null; then
        BACKUP="$candidate"
        break
    fi
done < <(find "$BACKUP_ROOT" -maxdepth 1 -type d -name 'AltServer-*.app' \
    -print | sort -r)

if [[ -z "$BACKUP" ]]; then
    echo "No valid official AltServer backup was found."
    echo "Install the official AltServer manually from:"
    echo "https://altstore.io"
    if [[ -t 0 ]]; then
        read -k 1 "?Press any key to close."
    fi
    exit 1
fi

APP="$TEMP_ROOT/AltServer.app"
ditto --noextattr --noqtn "$BACKUP" "$APP"
codesign --verify --deep --strict "$APP"
killall AltServer 2>/dev/null || true

if rm -rf /Applications/AltServer.app 2>/dev/null \
    && ditto --noextattr --noqtn "$APP" /Applications/AltServer.app 2>/dev/null; then
    :
else
    STAGED="$TEMP_ROOT/AltServer-staged.app"
    ditto --noextattr --noqtn "$APP" "$STAGED"
    osascript - "$STAGED" <<'APPLESCRIPT'
on run argv
    set stagedPath to item 1 of argv
    do shell script "/bin/rm -rf /Applications/AltServer.app && " & ¬
        "/usr/bin/ditto --noextattr --noqtn " & quoted form of stagedPath & ¬
        " /Applications/AltServer.app && " & ¬
        "/usr/sbin/chown -R root:wheel /Applications/AltServer.app" ¬
        with administrator privileges
end run
APPLESCRIPT
fi

xattr -cr /Applications/AltServer.app
codesign --verify --deep --strict /Applications/AltServer.app
open -n /Applications/AltServer.app

echo
echo "Official AltServer restored from the local backup."
echo "The V3 identity file was preserved and may be deleted manually."
echo
if [[ -t 0 ]]; then
    read -k 1 "?Press any key to close."
fi
