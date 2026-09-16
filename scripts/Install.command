#!/bin/zsh

set -euo pipefail

# Never let inherited PATH entries or tool shims influence validation or the
# root transaction.  This same fixed path is used by non-root dry runs.
PATH="/usr/bin:/bin:/usr/sbin:/sbin"
export PATH
readonly PATH

INSTALL_DRY_RUN="${ALTSERVER_INSTALL_DRY_RUN:-0}"
if [[ "$INSTALL_DRY_RUN" != "1" && "$EUID" -ne 0 ]]; then
    echo "Install: actual installation requires root; rerun with: sudo ALTSERVER_INSTALL_DRY_RUN=0 $0" >&2
    exit 1
fi
if [[ "$EUID" -eq 0 && ${+ALTSERVER_INSTALL_BACKUP_ROOT} -eq 1 ]]; then
    echo "Install: root installs may only use the canonical invoking-user backup path." >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")" && pwd -P)"
PAYLOAD_ROOT=""
PAYLOAD=""
MANIFEST=""
METADATA=""
CHECKSUMS=""
PAYLOAD_ROOT_KEY=""
ZIP_NAME="AltServer-macOS27-v3.8.zip"
MANIFEST_NAME=""
METADATA_NAME="BUILD-METADATA.txt"
CHECKSUMS_NAME="CHECKSUMS-SHA256.txt"
EXPECTED_OFFICIAL_TEAM_ID="6XVY5G3U44"
EXPECTED_OFFICIAL_MAIN_SHA="d1e4188b67adbd120af597ffa11708a18cb139db9919baa5be806a129a3cf819"
EXPECTED_MAIN_TEXT_ARM64="8bc985c9a039c9553d4047943905b8785d9369e4b1598cf987f6f64c2439452e"
EXPECTED_MAIN_TEXT_X86_64="392736172869606e6a5ac677f19d5f4747018b5f75b76ea2f0b1da8ff0b43dc2"

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
BACKUP_ROOT_OVERRIDE="${ALTSERVER_INSTALL_BACKUP_ROOT:-}"
if [[ "$EUID" -eq 0 && "$INSTALL_DRY_RUN" != "1" ]]; then
    [[ ${+SUDO_USER} -eq 1 && -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]] || {
        echo "Install: actual root installs require a non-root SUDO_USER." >&2
        exit 1
    }
fi
if [[ "$EUID" -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]]; then
    [[ "$SUDO_USER" =~ '^[A-Za-z0-9._-]+$' ]] || {
        echo "Install: SUDO_USER contains an unsafe username." >&2
        exit 1
    }
    SUDO_HOME="$(/usr/bin/dscl . -read "/Users/$SUDO_USER" NFSHomeDirectory 2>/dev/null |
        /usr/bin/awk 'NF == 2 && $1 == "NFSHomeDirectory:" { value=$2; count++ } END { if (count == 1) print value }' || true)"
    [[ -n "$SUDO_HOME" && "$SUDO_HOME" == /* && "$SUDO_HOME" == "${SUDO_HOME:A}" &&
       -d "$SUDO_HOME" && ! -L "$SUDO_HOME" && "${SUDO_HOME:t}" == "$SUDO_USER" ]] || {
        echo "Install: SUDO_USER home is not a canonical expected user home." >&2
        exit 1
    }
    path_has_symlink "$SUDO_HOME" && {
        echo "Install: SUDO_USER home contains a symlink." >&2
        exit 1
    }
    HOME_PATH="$SUDO_HOME"
fi
[[ -n "$HOME_PATH" && "$HOME_PATH" == /* && "$HOME_PATH" == "${HOME_PATH:A}" &&
   -d "$HOME_PATH" && ! -L "$HOME_PATH" ]] || {
    echo "Install: HOME is unavailable or not absolute." >&2
    exit 1
}
path_has_symlink "$HOME_PATH" && {
    echo "Install: HOME contains a symlink." >&2
    exit 1
}
if [[ "$EUID" -ne 0 ]]; then
    home_mode="$(stat -f '%Lp' "$HOME_PATH" 2>/dev/null || true)"
    home_owner="$(stat -f '%u' "$HOME_PATH" 2>/dev/null || true)"
    [[ "$home_mode" == <-> && "$home_owner" == "$EUID" ]] || {
        echo "Install: non-root HOME is not owned by the invoking user." >&2
        exit 1
    }
    (( 8#$home_mode & 8#022 )) && {
        echo "Install: non-root HOME is writable by an untrusted group." >&2
        exit 1
    }
fi
DEFAULT_BACKUP_ROOT="$HOME_PATH/Library/Application Support/AltServer-macOS27-Fix/Backups"
BACKUP_ROOT="$DEFAULT_BACKUP_ROOT"
if [[ -n "$BACKUP_ROOT_OVERRIDE" ]]; then
    if [[ "$EUID" -eq 0 || "$INSTALL_DRY_RUN" != "1" ]]; then
        echo "Install: backup overrides are restricted to non-root dry runs." >&2
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
        echo "Install: non-root dry-run backup override must be canonical." >&2
        exit 1
    }
    path_has_symlink "$BACKUP_ROOT_OVERRIDE" && {
        echo "Install: non-root dry-run backup override contains a symlink." >&2
        exit 1
    }
    [[ "$BACKUP_ROOT_OVERRIDE" == "$DEFAULT_BACKUP_ROOT" ||
       ("$BACKUP_ROOT_OVERRIDE" == "$HOME_PATH"/.altserver-install-*/Backups &&
        "$fixture_name" =~ '^\.altserver-install-[A-Za-z0-9._-]+$' && "$fixture_mode" == "0700" &&
        -d "$fixture_dir" && ! -L "$fixture_dir" && "$fixture_owner" == "$EUID" &&
        ((! -e "$BACKUP_ROOT_OVERRIDE" && ! -L "$BACKUP_ROOT_OVERRIDE") ||
         (-d "$BACKUP_ROOT_OVERRIDE" && ! -L "$BACKUP_ROOT_OVERRIDE" &&
          "$fixture_root_mode" == "0700" && "$fixture_root_owner" == "$EUID"))) ]] || {
        echo "Install: non-root dry-run backup override must be a canonical private HOME fixture." >&2
        exit 1
    }
    BACKUP_ROOT="$BACKUP_ROOT_OVERRIDE"
fi
TARGET_APP="/Applications/AltServer.app"
TEMP_ROOT="$(mktemp -d "/private/tmp/altserver-macOS27-install.XXXXXX")"
TEMP_ROOT="${TEMP_ROOT:A}"
TEMP_PARENT_REAL="${TEMP_ROOT:h}"
TEMP_PARENT_KEY="$(stat -f '%d:%i' "$TEMP_PARENT_REAL" 2>/dev/null || true)"
TEMP_ROOT_KEY="$(stat -f '%d:%i' "$TEMP_ROOT" 2>/dev/null || true)"
TEMP_ROOT_OWNER="$(stat -f '%u' "$TEMP_ROOT" 2>/dev/null || true)"
TEMP_ROOT_MODE="$(stat -f '%Mp%Lp' "$TEMP_ROOT" 2>/dev/null || true)"
[[ "$TEMP_ROOT" == "${TEMP_ROOT:A}" && "$TEMP_PARENT_REAL" == "${TEMP_PARENT_REAL:A}" ]] || {
    echo "Install: private temporary root is not canonical." >&2
    exit 1
}
[[ -n "$TEMP_PARENT_KEY" && -n "$TEMP_ROOT_KEY" && "$TEMP_ROOT_MODE" == "0700" ]] || {
    echo "Install: private temporary root identity or mode is unsafe." >&2
    exit 1
}
if [[ "$INSTALL_DRY_RUN" != "1" && ( "$EUID" -ne 0 || "$TEMP_ROOT_OWNER" != "0" ) ]]; then
    echo "Install: actual installation requires a root-owned private temporary root." >&2
    exit 1
fi
ATOMIC_HELPER=""
INSTALL_LOCK_NAME=".AltServer-install.lock"
INSTALL_LOCK_OWNER_START="$(date -u +%s)"
INSTALL_LOCK_HELD=0
INSTALL_LOCK_PARENT_REAL="/private/var/run"
INSTALL_LOCK_PARENT_KEY=""
INSTALL_LOCK_KEY=""
trap 'cleanup_install_exit' EXIT

fail()
{
    echo "Install: $1" >&2
    exit 1
}

# All filesystem mutations below the release-validation boundary go through
# this small descriptor-relative helper.  It is compiled in the private
# installer directory and is also the binary used by the administrator path;
# the two paths therefore have one rename/remove/lock contract.
build_atomic_helper()
{
    local source="$TEMP_ROOT/.altserver-atomic.c"
    ATOMIC_HELPER="$TEMP_ROOT/.altserver-atomic"
    cat > "$source" <<'ATOMIC_HELPER_C'
#define _DARWIN_C_SOURCE
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/stdio.h>
#include <fcntl.h>
#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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
        !S_ISREG(opened.st_mode) || opened.st_nlink != 1) {
        if (fd >= 0)
            close(fd);
        return 0;
    }
    count = read(fd, buffer, capacity - 1);
    if (count <= 0 || (size_t)count >= capacity) {
        close(fd);
        return 0;
    }
    buffer[count] = '\0';
    if (fstatat(lockfd, "owner", &after, AT_SYMLINK_NOFOLLOW) != 0 ||
        !same_identity(&opened, &after)) {
        close(fd);
        return 0;
    }
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
    while ((entry = readdir(directory)) != NULL) {
        struct stat before;
        struct stat opened;
        struct stat after;
        int child_fd = -1;
        int file_fd = -1;
        int directory_fd_for_entry = dirfd(directory);
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;
        if (!valid_name(entry->d_name) ||
            fstatat(directory_fd_for_entry, entry->d_name, &before,
                    AT_SYMLINK_NOFOLLOW) != 0) {
            closedir(directory);
            return 0;
        }
        if (S_ISDIR(before.st_mode)) {
            int tree_ok;
            child_fd = openat(directory_fd_for_entry, entry->d_name,
                              O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            if (child_fd < 0 || fstat(child_fd, &opened) != 0 ||
                !same_identity(&before, &opened) || !S_ISDIR(opened.st_mode) ||
                fchflags(child_fd, 0) != 0) {
                if (child_fd >= 0)
                    close(child_fd);
                closedir(directory);
                return 0;
            }
            tree_ok = remove_tree_fd(child_fd, &opened);
            child_fd = -1;
            if (!tree_ok) {
                closedir(directory);
                return 0;
            }
            if (fstatat(directory_fd_for_entry, entry->d_name, &after,
                        AT_SYMLINK_NOFOLLOW) != 0 ||
                !same_identity(&before, &after) || !S_ISDIR(after.st_mode) ||
                unlinkat(directory_fd_for_entry, entry->d_name, AT_REMOVEDIR) != 0) {
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
            file_fd = openat(directory_fd_for_entry, entry->d_name,
                             O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
            if (file_fd < 0 || fstat(file_fd, &opened) != 0 ||
                !same_identity(&before, &opened) || !S_ISREG(opened.st_mode) ||
                fchflags(file_fd, 0) != 0) {
                if (file_fd >= 0)
                    close(file_fd);
                closedir(directory);
                return 0;
            }
            close(file_fd);
            file_fd = -1;
        }
        if (fstatat(directory_fd_for_entry, entry->d_name, &after,
                    AT_SYMLINK_NOFOLLOW) != 0 || !same_identity(&before, &after) ||
            (S_ISREG(before.st_mode) && !same_identity(&opened, &after)) ||
            unlinkat(directory_fd_for_entry, entry->d_name, 0) != 0) {
            closedir(directory);
            return 0;
        }
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
    if (!remove_tree_fd(child_fd, &opened) ||
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
                     RENAME_EXCL) != 0 ||
        fstatat(destination_parent, destination_name, &destination_info,
                AT_SYMLINK_NOFOLLOW) != 0 || !same_key(&destination_info, source_key) ||
        fstatat(source_parent, source_name, &source_info, AT_SYMLINK_NOFOLLOW) == 0 ||
        errno != ENOENT) {
        if (!same_parent)
            close(destination_parent);
        close(source_parent);
        return 0;
    }
    if (!same_parent)
        close(destination_parent);
    close(source_parent);
    return 1;
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

static int write_all(int fd, const char *buffer, size_t length)
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
    int made = 0;
    int owner_bound = 0;
    int length;
    if (!valid_name(lock_name) || lock_key == NULL || lock_key_capacity < 2 ||
        (parent_fd = open_parent(parent_path, parent_key)) < 0)
        return 0;
    if (mkdirat(parent_fd, lock_name, 0700) != 0) {
        if (errno != EEXIST) {
            close(parent_fd);
            return 0;
        }
        lock_fd = openat(parent_fd, lock_name,
                         O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (lock_fd < 0 || fstat(lock_fd, &lock_info) != 0 ||
            !S_ISDIR(lock_info.st_mode) ||
            !read_owner(lock_fd, existing, sizeof(existing), &owner_info)) {
            if (lock_fd >= 0)
                close(lock_fd);
            close(parent_fd);
            return 0;
        }
        if (sscanf(existing, "pid=%63[^\n]\nstart=%127[^\n]\nparent=%127[^\n]\n",
                   existing_pid, existing_start, existing_parent) == 3 &&
            owner_matches(existing, existing_pid, existing_start, existing_parent) &&
            strcmp(existing_parent, parent_key) == 0 &&
            !owner_pid_alive(existing_pid)) {
            if (!lock_identity_ok(parent_fd, parent_key, lock_name, lock_fd,
                                  &lock_info) || !owner_identity_ok(lock_fd, &owner_info) ||
                unlinkat(lock_fd, "owner", 0) != 0 ||
                !lock_identity_ok(parent_fd, parent_key, lock_name, lock_fd,
                                  &lock_info) ||
                unlinkat(parent_fd, lock_name, AT_REMOVEDIR) != 0) {
                close(lock_fd);
                close(parent_fd);
                return 0;
            }
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
    if (lock_fd < 0 || fstat(lock_fd, &lock_info) != 0 ||
        !S_ISDIR(lock_info.st_mode))
        goto failed;
    length = snprintf(owner, sizeof(owner), "pid=%s\nstart=%s\nparent=%s\n",
                      pid, start, parent_key);
    if (length <= 0 || (size_t)length >= sizeof(owner))
        goto failed;
    owner_fd = openat(lock_fd, "owner",
                      O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (owner_fd < 0 || fstat(owner_fd, &owner_info) != 0 ||
        !S_ISREG(owner_info.st_mode) || owner_info.st_nlink != 1) {
        if (owner_fd >= 0)
            close(owner_fd);
        owner_fd = -1;
        goto failed;
    }
    owner_bound = 1;
    if (!write_all(owner_fd, owner, (size_t)length) || fsync(owner_fd) != 0) {
        close(owner_fd);
        owner_fd = -1;
        goto failed;
    }
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
        if (owner_bound && owner_identity_ok(lock_fd, &owner_info) &&
            unlinkat(lock_fd, "owner", 0) == 0 &&
            lock_identity_ok(parent_fd, parent_key, lock_name, lock_fd, &lock_info))
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
    if (!valid_name(lock_name) ||
        (parent_fd = open_parent(parent_path, parent_key)) < 0)
        return 0;
    lock_fd = openat(parent_fd, lock_name,
                     O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (lock_fd < 0 || fstat(lock_fd, &lock_info) != 0 ||
        !S_ISDIR(lock_info.st_mode) ||
        (lock_key != NULL && lock_key[0] != '\0' && !same_key(&lock_info, lock_key)) ||
        !lock_identity_ok(parent_fd, parent_key, lock_name, lock_fd, &lock_info) ||
        !read_owner(lock_fd, owner, sizeof(owner), &owner_info) ||
        !owner_matches(owner, pid, start, parent_key)) {
        if (lock_fd >= 0)
            close(lock_fd);
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
    if (strcmp(argv[1], "move") == 0 && argc == 9)
        return move_entry(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8]) ? 0 : 1;
    if (strcmp(argv[1], "remove") == 0 && argc == 6)
        return remove_entry(argv[2], argv[3], argv[4], argv[5]) ? 0 : 1;
    if (strcmp(argv[1], "check") == 0 && argc == 6)
        return check_entry(argv[2], argv[3], argv[4], argv[5]) ? 0 : 1;
    if (strcmp(argv[1], "lock") == 0 && argc == 7) {
        char lock_key[128];
        if (!create_lock(argv[2], argv[3], argv[4], argv[5], argv[6],
                         lock_key, sizeof(lock_key)))
            return 1;
        puts(lock_key);
        return 0;
    }
    if (strcmp(argv[1], "unlock") == 0 && argc == 8)
        return release_lock(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7]) ? 0 : 1;
    if (strcmp(argv[1], "unlock") == 0 && argc == 7)
        return release_lock(argv[2], argv[3], argv[4], "", argv[5], argv[6]) ? 0 : 1;
    return 2;
}
ATOMIC_HELPER_C
    /usr/bin/clang -std=c11 -O2 -Wall -Wextra -Werror "$source" -o "$ATOMIC_HELPER" || fail "could not build the private atomic installer helper."
    chmod 700 "$ATOMIC_HELPER"
}

atomic_move_path()
{
    local source="$1"
    local source_key="$2"
    local destination="$3"
    local source_parent_key="$4"
    local destination_parent_key="$5"
    local source_parent="${source:h}"
    local destination_parent="${destination:h}"
    local source_name="${source:t}"
    local destination_name="${destination:t}"
    [[ -x "$ATOMIC_HELPER" ]] || return 70
    [[ -n "$source_parent_key" && -n "$destination_parent_key" ]] || return 70
    [[ "$source" == "$source_parent/$source_name" && "$destination" == "$destination_parent/$destination_name" ]] || return 70
    [[ "$source_parent" == "${source_parent:A}" && "$destination_parent" == "${destination_parent:A}" ]] || return 70
    path_has_symlink "$source_parent" && return 70
    path_has_symlink "$destination_parent" && return 70
    "$ATOMIC_HELPER" move "$source_parent" "$source_parent_key" "$source_name" "$source_key" \
        "$destination_parent" "$destination_parent_key" "$destination_name"
}

atomic_remove_path()
{
    local target="$1"
    local target_key="$2"
    local parent="${target:h}"
    local name="${target:t}"
    local parent_key="$3"
    [[ -x "$ATOMIC_HELPER" ]] || return 70
    [[ -n "$parent_key" ]] || return 70
    [[ "$target" == "$parent/$name" && "$parent" == "${parent:A}" ]] || return 70
    path_has_symlink "$parent" && return 70
    "$ATOMIC_HELPER" remove "$parent" "$parent_key" "$name" "$target_key"
}

atomic_check_path()
{
    local target="$1"
    local target_key="$2"
    local parent="${target:h}"
    local name="${target:t}"
    local parent_key="$3"
    [[ -x "$ATOMIC_HELPER" ]] || return 70
    [[ -n "$parent_key" ]] || return 70
    [[ "$target" == "$parent/$name" && "$parent" == "${parent:A}" ]] || return 70
    path_has_symlink "$parent" && return 70
    "$ATOMIC_HELPER" check "$parent" "$parent_key" "$name" "$target_key"
}

write_metadata_file()
{
    python3 - "$1" "${@:2}" <<'PY'
import os
import stat
import sys

path = sys.argv[1]
lines = sys.argv[2:]
parent = os.path.dirname(path)
name = os.path.basename(path)
if not parent or not name or "/" in name or name in (".", ".."):
    raise SystemExit("unsafe metadata path")
parent_fd = os.open(parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
try:
    parent_info = os.fstat(parent_fd)
    if not stat.S_ISDIR(parent_info.st_mode) or parent_info.st_nlink < 1:
        raise SystemExit("unsafe metadata parent")
    fd = os.open(
        name,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
        0o600,
        dir_fd=parent_fd,
    )
    try:
        data = ("\n".join(lines) + "\n").encode("utf-8")
        view = memoryview(data)
        while view:
            count = os.write(fd, view)
            if count <= 0:
                raise SystemExit("metadata write failed")
            view = view[count:]
        os.fsync(fd)
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or stat.S_IMODE(info.st_mode) != 0o600:
            raise SystemExit("metadata identity or mode is unsafe")
        if os.geteuid() == 0 and info.st_uid != 0:
            raise SystemExit("metadata is not root-owned")
    finally:
        os.close(fd)
finally:
    os.close(parent_fd)
PY
}

cleanup_install_exit()
{
    local cleanup_status=0
    if [[ "$INSTALL_LOCK_HELD" == "1" ]]; then
        if [[ -x "$ATOMIC_HELPER" ]]; then
            "$ATOMIC_HELPER" unlock "$INSTALL_LOCK_PARENT_REAL" "$INSTALL_LOCK_PARENT_KEY" \
                "$INSTALL_LOCK_NAME" "$INSTALL_LOCK_KEY" "$$" "$INSTALL_LOCK_OWNER_START" >/dev/null 2>&1 || cleanup_status=1
        else
            cleanup_status=1
        fi
        INSTALL_LOCK_HELD=0
    fi
    # The helper is itself inside TEMP_ROOT; unlinking an executing Mach-O is
    # safe, while the bound parent/root identities prevent attacker-path cleanup.
    if [[ -e "$TEMP_ROOT" ]]; then
        if [[ -x "$ATOMIC_HELPER" ]]; then
            "$ATOMIC_HELPER" remove "$TEMP_PARENT_REAL" "$TEMP_PARENT_KEY" \
                "${TEMP_ROOT:t}" "$TEMP_ROOT_KEY" >/dev/null 2>&1 || cleanup_status=1
        else
            cleanup_status=1
            echo "Install: atomic helper unavailable; preserving private temporary root: $TEMP_ROOT" >&2
        fi
    fi
    if (( cleanup_status != 0 )); then
        echo "Install: private cleanup was identity-checked but could not complete." >&2
    fi
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

validate_lc_uuid()
{
    extract_lc_uuid "$1" >/dev/null
}

validate_component_metadata()
{
    # build_release.sh canonicalizes UUIDs to lowercase; metadata accepts only
    # that form while SHA-256 fields remain lowercase hex without normalization.
    local helper="$APP/Contents/Frameworks/AltServerAnisetteHelper"
    local dylib="$APP/Contents/Frameworks/AltServerAnisetteFix.dylib"
    local helper_uuid dylib_uuid
    helper_uuid="$(extract_lc_uuid "$helper")" || return 1
    dylib_uuid="$(extract_lc_uuid "$dylib")" || return 1
    python3 - "$METADATA" "$helper" "$dylib" "$helper_uuid" "$dylib_uuid" <<'PY'
import hashlib
import os
import re
import stat
import sys

metadata_path, helper_path, dylib_path, helper_uuid, dylib_uuid = sys.argv[1:]
uuid_pattern = re.compile(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}")
sha_pattern = re.compile(r"[0-9a-f]{64}")
required = {"HelperSHA256", "HelperUUID", "DylibSHA256", "DylibUUID"}

def read_regular(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise SystemExit("metadata component is not a private regular file")
        chunks = []
        while True:
            chunk = os.read(fd, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
        after = os.fstat(fd)
        if (after.st_dev, after.st_ino, after.st_size) != (info.st_dev, info.st_ino, info.st_size):
            raise SystemExit("metadata component changed during verification")
        return b"".join(chunks)
    finally:
        os.close(fd)

def sha256_file(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise SystemExit("component is not a private regular file")
        digest = hashlib.sha256()
        while True:
            chunk = os.read(fd, 1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
        after = os.fstat(fd)
        if (after.st_dev, after.st_ino, after.st_size) != (info.st_dev, info.st_ino, info.st_size):
            raise SystemExit("component changed during hash verification")
        return digest.hexdigest()
    finally:
        os.close(fd)

metadata = {}
for line in read_regular(metadata_path).decode("utf-8").splitlines():
    if not line.strip():
        continue
    if "=" not in line:
        raise SystemExit("malformed build metadata line")
    key, value = line.split("=", 1)
    if key in required:
        if key in metadata:
            raise SystemExit(f"duplicate build metadata field: {key}")
        metadata[key] = value
if set(metadata) != required:
    missing = sorted(required - set(metadata))
    raise SystemExit("missing exact build metadata fields: " + ",".join(missing))

for key in ("HelperSHA256", "DylibSHA256"):
    if sha_pattern.fullmatch(metadata[key]) is None:
        raise SystemExit(f"{key} must be lowercase hexadecimal SHA-256")
for key in ("HelperUUID", "DylibUUID"):
    value = metadata[key]
    if uuid_pattern.fullmatch(value) is None:
        raise SystemExit(f"{key} must be lowercase canonical UUID")
    if not any(byte != 0 for byte in bytes.fromhex(value.replace("-", ""))):
        raise SystemExit(f"{key} must not be all zeroes")

actual = {
    "HelperSHA256": sha256_file(helper_path),
    "HelperUUID": helper_uuid,
    "DylibSHA256": sha256_file(dylib_path),
    "DylibUUID": dylib_uuid,
}
for key, expected in actual.items():
    if metadata[key] != expected:
        raise SystemExit(f"build metadata {key} does not match the immutable payload")
PY
}

process_executable_path()
{
    local pid="$1"
    local executable
    executable="$(/usr/sbin/lsof -a -p "$pid" -d txt -Fn 2>/dev/null | /usr/bin/sed -n 's/^n//p' | /usr/bin/head -n 1 || true)"
    if [[ -n "$executable" ]]; then
        print -r -- "$executable"
        return 0
    fi
    /bin/ps -p "$pid" -o comm= 2>/dev/null | /usr/bin/sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | /usr/bin/head -n 1
}

stop_target_processes()
{
    local target_exec="$1"
    local target_real="${target_exec:A}"
    local pid executable attempt remaining
    local -a matched=()
    [[ -f "$target_real" && ! -L "$target_real" ]] || return 0
    while IFS= read -r pid; do
        [[ "$pid" == <-> ]] || continue
        executable="$(process_executable_path "$pid")"
        if [[ "$executable" == "$target_real" ]]; then
            /bin/kill -TERM "$pid" 2>/dev/null || true
            matched+=($pid)
        fi
    done < <(/usr/bin/pgrep -x AltServer 2>/dev/null || true)
    (( ${#matched} == 0 )) && return 0
    remaining=1
    for attempt in {1..20}; do
        remaining=0
        for pid in "${matched[@]}"; do
            if /bin/kill -0 "$pid" 2>/dev/null && [[ "$(process_executable_path "$pid")" == "$target_real" ]]; then
                remaining=1
                break
            fi
        done
        (( remaining == 0 )) && break
        /bin/sleep 0.1
    done
    if (( remaining != 0 )); then
        for pid in "${matched[@]}"; do
            if /bin/kill -0 "$pid" 2>/dev/null && [[ "$(process_executable_path "$pid")" == "$target_real" ]]; then
                /bin/kill -KILL "$pid" 2>/dev/null || true
            fi
        done
    fi
}

# Compile before any release/target handling so the same root-owned binary also
# owns EXIT cleanup; dry-run may use its user-owned validation copy, but never
# invokes it across a privilege boundary.
build_atomic_helper

bundle_snapshot_hash()
{
    python3 - "$1" <<'PY'
import hashlib
import os
import stat
import sys

root = os.path.abspath(sys.argv[1])
digest = hashlib.sha256()
entries = [("", root)]
for directory, dirnames, filenames in os.walk(root, topdown=True, followlinks=False):
    dirnames.sort()
    filenames.sort()
    for name in dirnames + filenames:
        path = os.path.join(directory, name)
        relative = os.path.relpath(path, root).replace(os.sep, "/")
        entries.append((relative, path))
for relative, path in sorted(entries):
    mode = os.lstat(path).st_mode
    digest.update(relative.encode("utf-8", "surrogateescape"))
    digest.update(b"\0")
    digest.update(f"{stat.S_IMODE(mode):04o}".encode("ascii"))
    digest.update(b"\0")
    if stat.S_ISLNK(mode):
        digest.update(b"L\0")
        digest.update(os.readlink(path).encode("utf-8", "surrogateescape"))
    elif stat.S_ISREG(mode):
        digest.update(b"F\0")
        with open(path, "rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
    elif stat.S_ISDIR(mode):
        digest.update(b"D\0")
    else:
        raise SystemExit("unsupported bundle entry")
    digest.update(b"\0")
print(digest.hexdigest())
PY
}

macho_text_hash()
{
    python3 - "$1" "$2" <<'PY'
import hashlib
import re
import subprocess
import sys

path, architecture = sys.argv[1:]
try:
    result = subprocess.run(
        ["otool", "-arch", architecture, "-s", "__TEXT", "__text", path],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
except (OSError, subprocess.CalledProcessError) as error:
    detail = getattr(error, "stderr", "") or str(error)
    raise SystemExit(f"cannot inspect __TEXT,__text ({detail.strip()})")

data = bytearray()
for line in result.stdout.splitlines():
    fields = line.split()
    if len(fields) < 2 or not re.fullmatch(r"[0-9A-Fa-f]+", fields[0]):
        continue
    for word in fields[1:]:
        if re.fullmatch(r"[0-9A-Fa-f]{2,16}", word) and len(word) % 2 == 0:
            data.extend(bytes.fromhex(word))
if not data:
    raise SystemExit("empty __TEXT,__text section")
print(hashlib.sha256(data).hexdigest())
PY
}

main_arch_texts_match()
{
    local payload_main="$1"
    local official_main="$2"
    local architecture payload_hash official_hash
    for architecture in arm64 x86_64; do
        payload_hash="$(macho_text_hash "$payload_main" "$architecture")" || return 1
        official_hash="$(macho_text_hash "$official_main" "$architecture")" || return 1
        [[ -n "$payload_hash" && "$payload_hash" == "$official_hash" ]] || return 1
    done
}

payload_main_texts_official()
{
    local payload_main="$1"
    [[ "$(macho_text_hash "$payload_main" arm64)" == "$EXPECTED_MAIN_TEXT_ARM64" ]] || return 1
    [[ "$(macho_text_hash "$payload_main" x86_64)" == "$EXPECTED_MAIN_TEXT_X86_64" ]]
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

backup_record_shape_ok()
{
    local record="$1"
    local entry entry_name count=0
    [[ -d "$record" && ! -L "$record" ]] || return 1
    [[ "$record" == "${record:A}" ]] || return 1
    path_has_symlink "$record" && return 1
    while IFS= read -r -d '' entry; do
        entry_name="${entry:t}"
        case "$entry_name" in
            AltServer.app|metadata) ;;
            *) return 1 ;;
        esac
        [[ "$entry" == "$record/$entry_name" && ! -L "$entry" ]] || return 1
        count=$((count + 1))
    done < <(find -P "$record" -mindepth 1 -maxdepth 1 -print0)
    (( count == 2 )) || return 1
    [[ -d "$record/AltServer.app" && ! -L "$record/AltServer.app" ]] || return 1
    [[ -f "$record/metadata" && ! -L "$record/metadata" ]] || return 1
    [[ "$record/AltServer.app" == "${record}/AltServer.app" && "$record/metadata" == "${record}/metadata" ]] || return 1
    path_has_symlink "$record/AltServer.app" && return 1
    path_has_symlink "$record/metadata" && return 1
    return 0
}

BACKUP_ROOT_KEY=""
BACKUP_STAGE_ROOT=""
BACKUP_FINAL_RECORD=""
BACKUP_STAGE_KEY=""
BACKUP_FINAL_KEY=""
BACKUP_RECORD_PUBLISHED=0
BACKUP_RECOVERY_FAILED=0
BACKUP_FAULT="${ALTSERVER_BACKUP_FAULT:-}"

backup_fault_enabled()
{
    local wanted="$1"
    local token
    for token in ${(s:,:)BACKUP_FAULT}; do
        [[ "$token" == "$wanted" || "${token//_/-}" == "$wanted" || "${token//-/_}" == "$wanted" ]] && return 0
    done
    return 1
}

backup_root_ok()
{
    local mode owner home_owner
    [[ -d "$BACKUP_ROOT" && ! -L "$BACKUP_ROOT" ]] || return 1
    [[ "$BACKUP_ROOT" == "${BACKUP_ROOT:A}" ]] || return 1
    path_has_symlink "$BACKUP_ROOT" && return 1
    [[ -n "$BACKUP_ROOT_KEY" ]] || return 1
    [[ "$(stat -f '%d:%i' "$BACKUP_ROOT" 2>/dev/null || true)" == "$BACKUP_ROOT_KEY" ]] || return 1
    mode="$(stat -f '%Lp' "$BACKUP_ROOT" 2>/dev/null || true)"
    [[ "$mode" == <-> ]] || return 1
    (( 8#$mode & 8#022 )) && return 1
    owner="$(stat -f '%u' "$BACKUP_ROOT" 2>/dev/null || true)"
    home_owner="$(stat -f '%u' "$HOME_PATH" 2>/dev/null || true)"
    [[ "$owner" == "0" || ( -n "$home_owner" && "$owner" == "$home_owner" ) ]] || return 1
    return 0
}

prepare_backup_root()
{
    local home_real="${HOME_PATH:A}"
    local backup_parent="${BACKUP_ROOT:h}"
    local expected_backup_root="$HOME_PATH/Library/Application Support/AltServer-macOS27-Fix/Backups"
    [[ -n "$HOME_PATH" && "$HOME_PATH" == "$home_real" ]] || fail "HOME must be a canonical path for backup storage."
    path_has_symlink "$HOME_PATH" && fail "HOME contains a symlink; backup storage is unsafe."
    if [[ "$EUID" -eq 0 ]]; then
        [[ -z "$BACKUP_ROOT_OVERRIDE" && "$BACKUP_ROOT" == "$expected_backup_root" ]] ||
            fail "root installs may only use the canonical invoking-user backup path."
    else
        [[ "$INSTALL_DRY_RUN" == "1" && "$BACKUP_ROOT" == "$expected_backup_root" ]] ||
            fail "backup preparation is restricted to the canonical backup path."
    fi
    [[ "$BACKUP_ROOT" == "${BACKUP_ROOT:A}" ]] || fail "backup path aliases through a symlink."
    path_has_symlink "$BACKUP_ROOT" && fail "backup path contains a symlink."
    [[ "$backup_parent" == "${backup_parent:A}" ]] || fail "backup parent aliases through a symlink."
    path_has_symlink "$backup_parent" && fail "backup parent contains a symlink."
    [[ "$EUID" -eq 0 ]] || fail "backup root preparation is root-only."
    BACKUP_ROOT_KEY="$(python3 - "$BACKUP_ROOT" "$HOME_PATH" <<'PY'
import os
import stat
import sys

path = os.path.abspath(sys.argv[1])
home = os.path.abspath(sys.argv[2])
if not path or os.path.realpath(path) != path:
    raise SystemExit("backup root is not canonical")
if not home or os.path.realpath(home) != home:
    raise SystemExit("backup home is not canonical")
expected = os.path.join(
    home, "Library", "Application Support", "AltServer-macOS27-Fix", "Backups"
)
if path != expected:
    raise SystemExit("backup root is not the canonical invoking-user default")
try:
    home_owner = os.stat(home, follow_symlinks=False).st_uid
except OSError as error:
    raise SystemExit(f"backup home cannot be inspected: {error}")
parts = [part for part in path.split(os.sep) if part]
if not parts:
    raise SystemExit("backup root path is empty")
flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
fd = os.open(os.sep, flags)
final_created = False
try:
    for part in parts:
        if part in (".", "..") or "/" in part or "\\" in part:
            raise SystemExit("unsafe backup root component")
        created = False
        try:
            child = os.open(part, flags, dir_fd=fd)
        except FileNotFoundError:
            try:
                os.mkdir(part, 0o700, dir_fd=fd)
            except FileExistsError:
                pass
            else:
                created = True
            child = os.open(part, flags, dir_fd=fd)
        info = os.fstat(child)
        if not stat.S_ISDIR(info.st_mode) or info.st_nlink < 1:
            os.close(child)
            raise SystemExit("backup root component is not a directory")
        mode = stat.S_IMODE(info.st_mode)
        if created:
            if mode != 0o700:
                os.close(child)
                raise SystemExit("new backup root component is not private")
        elif mode & 0o022:
            os.close(child)
            raise SystemExit("existing backup root component is writable by an untrusted group")
        if child == fd:
            os.close(child)
            raise SystemExit("backup root descriptor alias")
        os.close(fd)
        fd = child
        final_created = created
    info = os.fstat(fd)
    if not stat.S_ISDIR(info.st_mode) or info.st_nlink < 1:
        raise SystemExit("backup root ownership or type is unsafe")
    mode = stat.S_IMODE(info.st_mode)
    if mode & 0o022:
        raise SystemExit("backup root is writable by an untrusted group")
    if final_created and mode != 0o700:
        raise SystemExit("new backup root is not private")
    if info.st_uid not in (0, home_owner):
        raise SystemExit("existing backup root owner is not the invoking user")
    # Existing hierarchy entries are descriptor-validated only; no chmod is
    # applied to them.  Only components created above receive mode 0700.
    # Enumerate through the bound descriptor to establish the content boundary
    # while preserving every existing backup entry.
    for name in os.listdir(fd):
        if name in (".", "..") or "/" in name or "\\" in name:
            raise SystemExit("unsafe backup entry name")
    print(f"{info.st_dev}:{info.st_ino}")
finally:
    os.close(fd)
PY
)" || fail "could not create or securely migrate the root-owned backup root."
    [[ -n "$BACKUP_ROOT_KEY" ]] || fail "backup root identity is unavailable."
    backup_root_ok || fail "backup root changed during setup."
}

backup_path_ok()
{
    local target_path="$1"
    [[ "$target_path" == "$BACKUP_ROOT"/* ]] || return 1
    [[ "$target_path" == "${target_path:A}" ]] || return 1
    path_has_symlink "$target_path" && return 1
    return 0
}

backup_remove_path()
{
    local target_path="$1"
    local expected_key="${2:-}"
    backup_root_ok || return 1
    backup_path_ok "$target_path" || return 1
    [[ -e "$target_path" || -L "$target_path" ]] || return 0
    [[ -n "$expected_key" ]] || return 1
    atomic_remove_path "$target_path" "$expected_key" "$BACKUP_ROOT_KEY"
}

backup_publish_recover()
{
    backup_root_ok || {
        BACKUP_RECOVERY_FAILED=1
        echo "Install: backup recovery blocked by backup-root identity change; preserving paths: stage=$BACKUP_STAGE_ROOT record=$BACKUP_FINAL_RECORD" >&2
        return 1
    }
    if [[ "$BACKUP_RECORD_PUBLISHED" == "1" && ( -e "$BACKUP_FINAL_RECORD" || -L "$BACKUP_FINAL_RECORD" ) ]]; then
        if ! backup_remove_path "$BACKUP_FINAL_RECORD" "$BACKUP_FINAL_KEY"; then
            BACKUP_RECOVERY_FAILED=1
        fi
    fi
    if [[ -n "$BACKUP_STAGE_ROOT" && ( -e "$BACKUP_STAGE_ROOT" || -L "$BACKUP_STAGE_ROOT" ) ]]; then
        if ! backup_remove_path "$BACKUP_STAGE_ROOT" "$BACKUP_STAGE_KEY"; then
            BACKUP_RECOVERY_FAILED=1
        fi
    fi
    if [[ "$BACKUP_RECOVERY_FAILED" == "1" ]]; then
        echo "Install: backup publish recovery failed; recoverable paths: stage=$BACKUP_STAGE_ROOT record=$BACKUP_FINAL_RECORD" >&2
        return 1
    fi
    return 0
}

publish_backup_pair()
{
    local source_app="$1"
    local stamp serial stage_app stage_meta stage_key stage_app_key stage_meta_key source_key record_key current_hash stage_app_snapshot_hash stage_meta_hash final_app_snapshot_hash final_meta_hash
    BACKUP_STAGE_KEY=""
    BACKUP_FINAL_KEY=""
    backup_root_ok || return 1
    [[ -d "$source_app" && ! -L "$source_app" ]] || return 1
    [[ "$source_app" == "${source_app:A}" ]] || return 1
    path_has_symlink "$source_app" && return 1
    target_binding_ok || return 1
    stamp="$(date -u +%Y%m%dT%H%M%SZ).$$.$RANDOM"
    serial=0
    BACKUP_FINAL_RECORD="$BACKUP_ROOT/AltServer-$stamp.backup"
    while [[ -e "$BACKUP_FINAL_RECORD" || -L "$BACKUP_FINAL_RECORD" ]]; do
        serial=$((serial + 1))
        BACKUP_FINAL_RECORD="$BACKUP_ROOT/AltServer-$stamp-$serial.backup"
    done
    BACKUP_STAGE_ROOT="$BACKUP_ROOT/.AltServer-backup-stage.$stamp"
    while [[ -e "$BACKUP_STAGE_ROOT" || -L "$BACKUP_STAGE_ROOT" ]]; do
        serial=$((serial + 1))
        BACKUP_STAGE_ROOT="$BACKUP_ROOT/.AltServer-backup-stage.$stamp-$serial"
    done
    backup_path_ok "$BACKUP_STAGE_ROOT" || return 1
    mkdir "$BACKUP_STAGE_ROOT" || return 1
    chmod 700 "$BACKUP_STAGE_ROOT" || return 1
    backup_root_ok || return 1
    [[ "$BACKUP_STAGE_ROOT" == "${BACKUP_STAGE_ROOT:A}" && ! -L "$BACKUP_STAGE_ROOT" ]] || return 1
    path_has_symlink "$BACKUP_STAGE_ROOT" && return 1
    [[ "$(stat -f '%u' "$BACKUP_STAGE_ROOT" 2>/dev/null || true)" == "0" ]] || return 1
    [[ "$(stat -f '%Mp%Lp' "$BACKUP_STAGE_ROOT" 2>/dev/null || true)" == "0700" ]] || return 1
    stage_key="$(stat -f '%d:%i' "$BACKUP_STAGE_ROOT" 2>/dev/null || true)"
    [[ -n "$stage_key" ]] || return 1
    BACKUP_STAGE_KEY="$stage_key"
    stage_app="$BACKUP_STAGE_ROOT/AltServer.app"
    stage_meta="$BACKUP_STAGE_ROOT/metadata"
    backup_root_ok || return 1
    [[ "$(stat -f '%d:%i' "$BACKUP_STAGE_ROOT" 2>/dev/null || true)" == "$stage_key" ]] || return 1
    if backup_fault_enabled before-ditto || backup_fault_enabled before-app-copy; then
        return 1
    fi
    [[ ! -e "$stage_app" && ! -L "$stage_app" ]] || return 1
    ditto --noextattr --noqtn "$source_app" "$stage_app" || return 1
    target_binding_ok || return 1
    backup_root_ok || return 1
    [[ "$(stat -f '%d:%i' "$BACKUP_STAGE_ROOT" 2>/dev/null || true)" == "$stage_key" ]] || return 1
    target_binding_ok || return 1
    [[ -d "$stage_app" && ! -L "$stage_app" ]] || return 1
    [[ "$(stat -f '%u' "$stage_app" 2>/dev/null || true)" == "0" ]] || return 1
    codesign --verify --deep --strict "$stage_app" >/dev/null 2>&1 || return 1
    current_hash="$(shasum -a 256 "$stage_app/Contents/MacOS/AltServer" | awk '{ print $1 }')"
    [[ -n "$current_hash" ]] || return 1
    required_executable_modes_ok "$stage_app" || return 1
    stage_app_key="$(stat -f '%d:%i' "$stage_app" 2>/dev/null || true)"
    [[ -n "$stage_app_key" ]] || return 1
    stage_app_snapshot_hash="$(bundle_snapshot_hash "$stage_app")" || return 1
    [[ -n "$stage_app_snapshot_hash" ]] || return 1
    backup_root_ok || return 1
    [[ "$(stat -f '%d:%i' "$BACKUP_STAGE_ROOT" 2>/dev/null || true)" == "$stage_key" ]] || return 1
    [[ ! -e "$stage_meta" && ! -L "$stage_meta" ]] || return 1
    write_metadata_file "$stage_meta" \
        'FormatVersion=1' \
        'BundleIdentifier=com.rileytestut.AltServer' \
        'BundleShortVersion=1.7.6' \
        'BundleVersion=94' \
        "MainExecutableSHA256=$current_hash" \
        'Signature=Preserved-before-v3.8-install' || return 1
    backup_root_ok || return 1
    [[ -f "$stage_meta" && ! -L "$stage_meta" ]] || return 1
    [[ "$(wc -l < "$stage_meta" | tr -d '[:space:]')" == "6" ]] || return 1
    grep -Fqx 'FormatVersion=1' "$stage_meta" || return 1
    grep -Fqx 'BundleIdentifier=com.rileytestut.AltServer' "$stage_meta" || return 1
    grep -Fqx 'BundleShortVersion=1.7.6' "$stage_meta" || return 1
    grep -Fqx 'BundleVersion=94' "$stage_meta" || return 1
    grep -Fqx "MainExecutableSHA256=$current_hash" "$stage_meta" || return 1
    grep -Fqx 'Signature=Preserved-before-v3.8-install' "$stage_meta" || return 1
    stage_meta_key="$(stat -f '%d:%i' "$stage_meta" 2>/dev/null || true)"
    [[ -n "$stage_meta_key" ]] || return 1
    stage_meta_hash="$(shasum -a 256 "$stage_meta" | awk '{ print $1 }')"
    [[ -n "$stage_meta_hash" ]] || return 1
    backup_root_ok || return 1
    [[ "$(stat -f '%d:%i' "$BACKUP_STAGE_ROOT" 2>/dev/null || true)" == "$stage_key" ]] || return 1
    backup_record_shape_ok "$BACKUP_STAGE_ROOT" || return 1
    [[ "$(stat -f '%d:%i' "$stage_app" 2>/dev/null || true)" == "$stage_app_key" ]] || return 1
    [[ "$(stat -f '%d:%i' "$stage_meta" 2>/dev/null || true)" == "$stage_meta_key" ]] || return 1
    [[ "$(shasum -a 256 "$stage_app/Contents/MacOS/AltServer" | awk '{ print $1 }')" == "$current_hash" ]] || return 1
    [[ "$(bundle_snapshot_hash "$stage_app")" == "$stage_app_snapshot_hash" ]] || return 1
    [[ "$(shasum -a 256 "$stage_meta" | awk '{ print $1 }')" == "$stage_meta_hash" ]] || return 1
    [[ ! -e "$BACKUP_FINAL_RECORD" && ! -L "$BACKUP_FINAL_RECORD" ]] || return 1
    backup_path_ok "$BACKUP_FINAL_RECORD" || return 1
    if backup_fault_enabled before-record-publish || backup_fault_enabled before-app-publish || backup_fault_enabled before-meta-publish; then
        return 1
    fi
    source_key="$(stat -f '%d:%i' "$BACKUP_STAGE_ROOT" 2>/dev/null || true)"
    [[ -n "$source_key" ]] || return 1
    backup_root_ok || return 1
    target_binding_ok || return 1
    atomic_move_path "$BACKUP_STAGE_ROOT" "$source_key" "$BACKUP_FINAL_RECORD" \
        "$BACKUP_ROOT_KEY" "$BACKUP_ROOT_KEY" || return 1
    BACKUP_RECORD_PUBLISHED=1
    backup_root_ok || return 1
    [[ ! -e "$BACKUP_STAGE_ROOT" && ! -L "$BACKUP_STAGE_ROOT" ]] || return 1
    [[ -d "$BACKUP_FINAL_RECORD" && ! -L "$BACKUP_FINAL_RECORD" ]] || return 1
    [[ -d "$BACKUP_FINAL_RECORD/AltServer.app" && ! -L "$BACKUP_FINAL_RECORD/AltServer.app" ]] || return 1
    [[ -f "$BACKUP_FINAL_RECORD/metadata" && ! -L "$BACKUP_FINAL_RECORD/metadata" ]] || return 1
    backup_record_shape_ok "$BACKUP_FINAL_RECORD" || return 1
    record_key="$(stat -f '%d:%i' "$BACKUP_FINAL_RECORD" 2>/dev/null || true)"
    [[ -n "$record_key" && "$record_key" == "$source_key" ]] || return 1
    BACKUP_FINAL_KEY="$record_key"
    [[ "$(stat -f '%d:%i' "$BACKUP_FINAL_RECORD/AltServer.app" 2>/dev/null || true)" == "$stage_app_key" ]] || return 1
    [[ "$(stat -f '%d:%i' "$BACKUP_FINAL_RECORD/metadata" 2>/dev/null || true)" == "$stage_meta_key" ]] || return 1
    [[ "$(shasum -a 256 "$BACKUP_FINAL_RECORD/AltServer.app/Contents/MacOS/AltServer" | awk '{ print $1 }')" == "$current_hash" ]] || return 1
    final_app_snapshot_hash="$(bundle_snapshot_hash "$BACKUP_FINAL_RECORD/AltServer.app")" || return 1
    [[ "$final_app_snapshot_hash" == "$stage_app_snapshot_hash" ]] || return 1
    final_meta_hash="$(shasum -a 256 "$BACKUP_FINAL_RECORD/metadata" | awk '{ print $1 }')"
    [[ "$final_meta_hash" == "$stage_meta_hash" ]] || return 1
    codesign --verify --deep --strict "$BACKUP_FINAL_RECORD/AltServer.app" >/dev/null 2>&1 || return 1
    if backup_fault_enabled after-record-publish || backup_fault_enabled after-app-publish || backup_fault_enabled after-meta-publish; then
        return 1
    fi
    BACKUP_APP="$BACKUP_FINAL_RECORD/AltServer.app"
    BACKUP_META="$BACKUP_FINAL_RECORD/metadata"
    return 0
}

validate_official_target()
{
    local app="$1"
    local plist="$app/Contents/Info.plist"
    local main="$app/Contents/MacOS/AltServer"
    local details team hash arches
    [[ -d "$app" && ! -L "$app" && "$app" == "${app:A}" ]] || return 1
    path_has_symlink "$app" && return 1
    [[ -f "$plist" && -f "$main" ]] || return 1
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist" 2>/dev/null || true)" == "com.rileytestut.AltServer" ]] || return 1
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist" 2>/dev/null || true)" == "1.7.6" ]] || return 1
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist" 2>/dev/null || true)" == "94" ]] || return 1
    arches="$(lipo -archs "$main" 2>/dev/null || true)"
    [[ " $arches " == *" arm64 "* && " $arches " == *" x86_64 "* ]] || return 1
    details="$(codesign --display --verbose=4 "$app" 2>&1)" || return 1
    [[ "$details" == *"Authority=Developer ID Application:"* ]] || return 1
    team="$(printf '%s\n' "$details" | awk -F= '/^TeamIdentifier=/{ print $2; exit }')"
    [[ "$team" == "$EXPECTED_OFFICIAL_TEAM_ID" ]] || return 1
    hash="$(shasum -a 256 "$main" | awk '{ print $1 }')"
    [[ "$hash" == "$EXPECTED_OFFICIAL_MAIN_SHA" ]] || return 1
    main_arch_texts_match "$MAIN" "$main" || return 1
    required_executable_modes_ok "$app" || return 1
    codesign --verify --deep --strict "$app" >/dev/null 2>&1 || return 1
    spctl_assess "$app" >/dev/null 2>&1 || return 1
    xcrun stapler validate "$app" >/dev/null 2>&1 || return 1
    return 0
}

TARGET_BIND_KEY=""
TARGET_BIND_TYPE=""
TARGET_BIND_BUNDLE_HASH=""
TARGET_PARENT_REAL=""
TARGET_PARENT_KEY=""

capture_target_parent()
{
    local raw_parent="${TARGET_APP:h}"
    [[ "$raw_parent" == "${raw_parent:A}" ]] || return 1
    TARGET_PARENT_REAL="$raw_parent"
    [[ -d "$TARGET_PARENT_REAL" && ! -L "$TARGET_PARENT_REAL" ]] || return 1
    [[ "$TARGET_PARENT_REAL" == "${TARGET_PARENT_REAL:A}" ]] || return 1
    path_has_symlink "$TARGET_PARENT_REAL" && return 1
    TARGET_PARENT_KEY="$(stat -f '%d:%i' "$TARGET_PARENT_REAL" 2>/dev/null || true)"
    [[ -n "$TARGET_PARENT_KEY" ]] || return 1
    [[ "$(stat -f '%d:%i' "$TARGET_PARENT_REAL" 2>/dev/null || true)" == "$TARGET_PARENT_KEY" ]]
}

capture_target_binding()
{
    local key type
    capture_target_parent || return 1
    [[ -d "$TARGET_APP" && ! -L "$TARGET_APP" && "$TARGET_APP" == "${TARGET_APP:A}" ]] || return 1
    path_has_symlink "$TARGET_APP" && return 1
    key="$(stat -f '%d:%i' "$TARGET_APP" 2>/dev/null || true)"
    type="$(stat -f '%HT' "$TARGET_APP" 2>/dev/null || true)"
    [[ -n "$key" && -n "$type" ]] || return 1
    TARGET_BIND_KEY="$key"
    TARGET_BIND_TYPE="$type"
    [[ "$TARGET_BIND_TYPE" == "Directory" || "$TARGET_BIND_TYPE" == "directory" ]] || return 1
    TARGET_BIND_BUNDLE_HASH="$(bundle_snapshot_hash "$TARGET_APP")" || return 1
    [[ -n "$TARGET_BIND_BUNDLE_HASH" ]] || return 1
    target_binding_ok
}

target_parent_identity_ok()
{
    [[ -n "$TARGET_PARENT_REAL" && -n "$TARGET_PARENT_KEY" ]] || return 1
    [[ -d "$TARGET_PARENT_REAL" && ! -L "$TARGET_PARENT_REAL" ]] || return 1
    [[ "$TARGET_PARENT_REAL" == "${TARGET_PARENT_REAL:A}" ]] || return 1
    path_has_symlink "$TARGET_PARENT_REAL" && return 1
    [[ "$(stat -f '%d:%i' "$TARGET_PARENT_REAL" 2>/dev/null || true)" == "$TARGET_PARENT_KEY" ]]
}

target_binding_ok()
{
    target_parent_identity_ok || return 1
    [[ -n "$TARGET_BIND_KEY" && -n "$TARGET_BIND_TYPE" ]] || return 1
    [[ -d "$TARGET_APP" && ! -L "$TARGET_APP" && "$TARGET_APP" == "${TARGET_APP:A}" ]] || return 1
    path_has_symlink "$TARGET_APP" && return 1
    [[ "$(stat -f '%d:%i' "$TARGET_APP" 2>/dev/null || true)" == "$TARGET_BIND_KEY" ]] || return 1
    [[ "$(stat -f '%HT' "$TARGET_APP" 2>/dev/null || true)" == "$TARGET_BIND_TYPE" ]] || return 1
    [[ -n "$TARGET_BIND_BUNDLE_HASH" ]] || return 1
    [[ "$(bundle_snapshot_hash "$TARGET_APP" 2>/dev/null || true)" == "$TARGET_BIND_BUNDLE_HASH" ]]
}

target_absent_ok()
{
    target_parent_identity_ok || return 1
    [[ ! -e "$TARGET_APP" && ! -L "$TARGET_APP" ]]
}

safe_layout_file()
{
    local layout_root="$1"
    local candidate="$2"
    [[ -f "$candidate" && ! -L "$candidate" ]] || return 1
    [[ "$candidate" == "$layout_root"/* ]] || return 1
    [[ "$candidate" == "${candidate:A}" ]] || return 1
    path_has_symlink "$candidate" && return 1
    return 0
}

manifest_name_for()
{
    local layout_root="$1"
    local canonical="$layout_root/AltServer-macOS27-v3.8.executables.txt"
    [[ -e "$canonical" || -L "$canonical" ]] || return 1
    safe_layout_file "$layout_root" "$canonical" || return 1
    print -r -- "${canonical:t}"
}

layout_complete()
{
    local layout_root="$1"
    local selected_manifest
    local entry entry_name
    [[ -d "$layout_root" && ! -L "$layout_root" ]] || return 1
    [[ "$layout_root" == "${layout_root:A}" ]] || return 1
    path_has_symlink "$layout_root" && return 1
    safe_layout_file "$layout_root" "$layout_root/$ZIP_NAME" || return 1
    safe_layout_file "$layout_root" "$layout_root/$METADATA_NAME" || return 1
    safe_layout_file "$layout_root" "$layout_root/$CHECKSUMS_NAME" || return 1
    selected_manifest="$(manifest_name_for "$layout_root")" || return 1
    if [[ "$layout_root" == "$ROOT/Payload" || "$layout_root" == "$ROOT" ]]; then
        while IFS= read -r -d '' entry; do
            entry_name="${entry:t}"
            case "$entry_name" in
                "$ZIP_NAME"|"$METADATA_NAME"|"$CHECKSUMS_NAME"|"$selected_manifest") ;;
                Install.command) [[ "$layout_root" == "$ROOT" ]] || return 1 ;;
                *) return 1 ;;
            esac
        done < <(find -P "$layout_root" -mindepth 1 -maxdepth 1 -print0)
    fi
    print -r -- "$selected_manifest"
}

resolve_layout()
{
    local payload_dir="$ROOT/Payload"
    local candidate
    local flat_any=0
    local packaged_any=0
    local flat_manifest
    local packaged_manifest
    local -a flat_candidates=(
        "$ROOT/$ZIP_NAME"
        "$ROOT/$METADATA_NAME"
        "$ROOT/$CHECKSUMS_NAME"
        "$ROOT/AltServer-macOS27-v3.8.executables.txt"
    )
    local -a packaged_candidates=(
        "$payload_dir/$ZIP_NAME"
        "$payload_dir/$METADATA_NAME"
        "$payload_dir/$CHECKSUMS_NAME"
        "$payload_dir/AltServer-macOS27-v3.8.executables.txt"
    )

    for candidate in "${flat_candidates[@]}"; do
        if [[ -e "$candidate" || -L "$candidate" ]]; then
            flat_any=1
            break
        fi
    done
    if [[ -e "$payload_dir" || -L "$payload_dir" ]]; then
        packaged_any=1
        [[ -d "$payload_dir" && ! -L "$payload_dir" ]] || fail "Payload directory must be a canonical directory."
        [[ "$payload_dir" == "${payload_dir:A}" ]] || fail "Payload directory aliases through a symlink."
        path_has_symlink "$payload_dir" && fail "Payload directory contains a symlink."
    fi
    for candidate in "${packaged_candidates[@]}"; do
        if [[ -e "$candidate" || -L "$candidate" ]]; then
            packaged_any=1
            break
        fi
    done

    (( flat_any || packaged_any )) || fail "release layout is missing."
    (( ! (flat_any && packaged_any) )) || fail "release contains both or partial flat and Payload layouts."
    if (( flat_any )); then
        flat_manifest="$(layout_complete "$ROOT")" || fail "flat release layout is incomplete or unsafe."
        PAYLOAD_ROOT="$ROOT"
        MANIFEST_NAME="$flat_manifest"
    else
        packaged_manifest="$(layout_complete "$payload_dir")" || fail "packaged Payload layout is incomplete or unsafe."
        PAYLOAD_ROOT="$payload_dir"
        MANIFEST_NAME="$packaged_manifest"
    fi
    [[ "$PAYLOAD_ROOT" == "${PAYLOAD_ROOT:A}" ]] || fail "selected release root aliases through a symlink."
    PAYLOAD_ROOT_KEY="$(stat -f '%d:%i' "$PAYLOAD_ROOT" 2>/dev/null || true)"
    [[ -n "$PAYLOAD_ROOT_KEY" ]] || fail "selected release root identity is unavailable."
    PAYLOAD="$PAYLOAD_ROOT/$ZIP_NAME"
    MANIFEST="$PAYLOAD_ROOT/$MANIFEST_NAME"
    METADATA="$PAYLOAD_ROOT/$METADATA_NAME"
    CHECKSUMS="$PAYLOAD_ROOT/$CHECKSUMS_NAME"
    safe_layout_file "$PAYLOAD_ROOT" "$PAYLOAD" || fail "release ZIP path is unsafe."
    safe_layout_file "$PAYLOAD_ROOT" "$MANIFEST" || fail "release manifest path is unsafe."
    safe_layout_file "$PAYLOAD_ROOT" "$METADATA" || fail "release metadata path is unsafe."
    safe_layout_file "$PAYLOAD_ROOT" "$CHECKSUMS" || fail "release checksum path is unsafe."
}

copy_release_inputs()
{
    local source_root="$1"
    local source_root_key="$2"
    local destination_root="$3"
    local zip_name="$4"
    local manifest_name="$5"
    local metadata_name="$6"
    local checksums_name="$7"
    mkdir "$destination_root" || return 1
    chmod 700 "$destination_root" || return 1
    python3 - "$source_root" "$source_root_key" "$destination_root" \
        "$zip_name" "$manifest_name" "$metadata_name" "$checksums_name" <<'PY'
import hashlib
import os
import stat
import sys
from pathlib import PurePosixPath

source_root = sys.argv[1]
source_key = sys.argv[2]
destination_root = sys.argv[3]
names = sys.argv[4:]
checksums_name = names[3]
if os.path.realpath(source_root) != source_root:
    raise SystemExit("release root is not canonical")
if not os.path.isdir(destination_root) or os.path.islink(destination_root):
    raise SystemExit("private release directory is unsafe")
destination_root_fd = os.open(
    destination_root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
)
destination_root_info = os.fstat(destination_root_fd)
if not stat.S_ISDIR(destination_root_info.st_mode):
    os.close(destination_root_fd)
    raise SystemExit("private release directory is not a directory")

def identity(info):
    return (
        info.st_dev,
        info.st_ino,
        stat.S_IFMT(info.st_mode),
        info.st_nlink,
        info.st_size,
        getattr(info, "st_mtime_ns", int(info.st_mtime * 1000000000)),
        getattr(info, "st_ctime_ns", int(info.st_ctime * 1000000000)),
    )

root_fd = os.open(source_root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
try:
    root_info = os.fstat(root_fd)
    if (str(root_info.st_dev) + ":" + str(root_info.st_ino)) != source_key:
        raise SystemExit("release root changed before immutable copy")
    if not stat.S_ISDIR(root_info.st_mode) or root_info.st_nlink < 1:
        raise SystemExit("release root is not a directory")

    copied_hashes = {}
    for name in names:
        path_name = PurePosixPath(name)
        if (not name or path_name.is_absolute() or len(path_name.parts) != 1 or
                path_name.parts[0] != name or name in (".", "..") or "/" in name or "\\" in name):
            raise SystemExit("unsafe release input name")
        pre = os.stat(name, dir_fd=root_fd, follow_symlinks=False)
        if not stat.S_ISREG(pre.st_mode) or pre.st_nlink != 1:
            raise SystemExit("release input is not a private regular file")
        source_fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=root_fd)
        try:
            opened = os.fstat(source_fd)
            if identity(opened) != identity(pre) or opened.st_nlink != 1:
                raise SystemExit("release input changed while opening")
            destination_fd = os.open(
                name,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                0o600,
                dir_fd=destination_root_fd,
            )
            digest = hashlib.sha256()
            try:
                while True:
                    chunk = os.read(source_fd, 1024 * 1024)
                    if not chunk:
                        break
                    digest.update(chunk)
                    view = memoryview(chunk)
                    while view:
                        written = os.write(destination_fd, view)
                        if written <= 0:
                            raise SystemExit("release input copy failed")
                        view = view[written:]
                os.fsync(destination_fd)
                destination_info = os.fstat(destination_fd)
                if (not stat.S_ISREG(destination_info.st_mode) or destination_info.st_nlink != 1 or
                        destination_info.st_size != opened.st_size):
                    raise SystemExit("private release copy identity is invalid")
            finally:
                os.close(destination_fd)

            after = os.stat(name, dir_fd=root_fd, follow_symlinks=False)
            if identity(after) != identity(opened) or after.st_nlink != 1:
                raise SystemExit("release input changed during immutable copy")
            # Re-open through the original directory descriptor.  This catches
            # a same-size source replacement even when timestamps were forged.
            verify_fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=root_fd)
            try:
                verify_info = os.fstat(verify_fd)
                if identity(verify_info) != identity(opened):
                    raise SystemExit("release input was replaced after copy")
                verify_hash = hashlib.sha256()
                while True:
                    chunk = os.read(verify_fd, 1024 * 1024)
                    if not chunk:
                        break
                    verify_hash.update(chunk)
                if verify_hash.hexdigest() != digest.hexdigest():
                    raise SystemExit("release input bytes changed during copy")
            finally:
                os.close(verify_fd)
            copied_hashes[name] = digest.hexdigest()
        finally:
            os.close(source_fd)
    if (str(os.fstat(root_fd).st_dev) + ":" + str(os.fstat(root_fd).st_ino)) != source_key:
        raise SystemExit("release root changed after immutable copy")
    path_root_info = os.stat(source_root, follow_symlinks=False)
    if identity(path_root_info)[:3] != identity(root_info)[:3]:
        raise SystemExit("release root path was replaced after immutable copy")
    if identity(os.fstat(destination_root_fd))[:3] != identity(destination_root_info)[:3]:
        raise SystemExit("private release directory changed during immutable copy")
finally:
    os.close(root_fd)
    os.close(destination_root_fd)

checksum_path = os.path.join(destination_root, checksums_name)
entries = {}
checksum_fd = os.open(checksum_path, os.O_RDONLY | os.O_NOFOLLOW)
try:
    checksum_info = os.fstat(checksum_fd)
    if not stat.S_ISREG(checksum_info.st_mode) or checksum_info.st_nlink != 1:
        raise SystemExit("private checksum copy is not a regular file")
    checksum_bytes = bytearray()
    while True:
        chunk = os.read(checksum_fd, 1024 * 1024)
        if not chunk:
            break
        checksum_bytes.extend(chunk)
finally:
    os.close(checksum_fd)
for line in bytes(checksum_bytes).decode("utf-8").splitlines():
    if not line.strip():
        continue
    fields = line.split()
    if len(fields) != 2 or not all(c in "0123456789abcdefABCDEF" for c in fields[0]) or len(fields[0]) != 64:
        raise SystemExit("invalid copied checksum line")
    relative = PurePosixPath(fields[1])
    if relative.is_absolute() or len(relative.parts) != 1 or relative.parts[0] != fields[1] or "\\" in fields[1]:
        raise SystemExit("unsafe copied checksum path")
    if fields[1] in entries:
        raise SystemExit("duplicate copied checksum path")
    entries[fields[1]] = fields[0].lower()
expected = set(names[:3])
if set(entries) != expected:
    raise SystemExit("copied checksum set does not bind the selected release layout")
for name, declared in entries.items():
    if copied_hashes.get(name) != declared:
        raise SystemExit("copied release bytes do not match the declared checksum")
PY
}

RELEASE_COPY_ROOT_KEY=""
RELEASE_PAYLOAD_KEY=""
RELEASE_MANIFEST_KEY=""
RELEASE_METADATA_KEY=""
RELEASE_CHECKSUMS_KEY=""
RELEASE_SNAPSHOT_FROZEN=0

capture_release_snapshot()
{
    RELEASE_COPY_ROOT_KEY="$(stat -f '%d:%i' "$RELEASE_COPY_ROOT" 2>/dev/null || true)"
    RELEASE_PAYLOAD_KEY="$(stat -f '%d:%i' "$PAYLOAD" 2>/dev/null || true)"
    RELEASE_MANIFEST_KEY="$(stat -f '%d:%i' "$MANIFEST" 2>/dev/null || true)"
    RELEASE_METADATA_KEY="$(stat -f '%d:%i' "$METADATA" 2>/dev/null || true)"
    RELEASE_CHECKSUMS_KEY="$(stat -f '%d:%i' "$CHECKSUMS" 2>/dev/null || true)"
    [[ -n "$RELEASE_COPY_ROOT_KEY" && -n "$RELEASE_PAYLOAD_KEY" && -n "$RELEASE_MANIFEST_KEY" &&
       -n "$RELEASE_METADATA_KEY" && -n "$RELEASE_CHECKSUMS_KEY" ]]
}

release_snapshot_ok()
{
    local file_path key index
    local -a paths=("$PAYLOAD" "$MANIFEST" "$METADATA" "$CHECKSUMS")
    local -a keys=("$RELEASE_PAYLOAD_KEY" "$RELEASE_MANIFEST_KEY" "$RELEASE_METADATA_KEY" "$RELEASE_CHECKSUMS_KEY")
    [[ -d "$RELEASE_COPY_ROOT" && ! -L "$RELEASE_COPY_ROOT" ]] || return 1
    [[ "$RELEASE_COPY_ROOT" == "${RELEASE_COPY_ROOT:A}" ]] || return 1
    [[ "$(stat -f '%d:%i' "$RELEASE_COPY_ROOT" 2>/dev/null || true)" == "$RELEASE_COPY_ROOT_KEY" ]] || return 1
    [[ "$(stat -f '%Mp%Lp' "$RELEASE_COPY_ROOT" 2>/dev/null || true)" == "0700" ]] || return 1
    if [[ "$EUID" -eq 0 ]]; then
        [[ "$(stat -f '%u' "$RELEASE_COPY_ROOT" 2>/dev/null || true)" == "0" ]] || return 1
    fi
    for index in {1..4}; do
        file_path="${paths[$index]}"
        key="${keys[$index]}"
        [[ -f "$file_path" && ! -L "$file_path" ]] || return 1
        [[ "$(stat -f '%d:%i' "$file_path" 2>/dev/null || true)" == "$key" ]] || return 1
        [[ "$(stat -f '%Mp%Lp' "$file_path" 2>/dev/null || true)" == "0600" ]] || return 1
        [[ "$(stat -f '%u' "$file_path" 2>/dev/null || true)" == "$EUID" ]] || return 1
        [[ "$(stat -f '%l' "$file_path" 2>/dev/null || true)" == "1" ]] || return 1
    done
    return 0
}

freeze_release_snapshot()
{
    release_snapshot_ok || return 1
    if [[ "$EUID" -eq 0 ]]; then
        chflags uchg "$PAYLOAD" "$MANIFEST" "$METADATA" "$CHECKSUMS" || return 1
        RELEASE_SNAPSHOT_FROZEN=1
    fi
    release_snapshot_ok
}

[[ "$(uname -m)" == "arm64" ]] || fail "Apple Silicon arm64 host required."
TRANSLATED="$(sysctl -in sysctl.proc_translated 2>/dev/null || true)"
[[ "$TRANSLATED" != "1" ]] || fail "Rosetta-translated execution is not supported."

resolve_layout

SOURCE_PAYLOAD_ROOT="$PAYLOAD_ROOT"
SOURCE_PAYLOAD_ROOT_KEY="$PAYLOAD_ROOT_KEY"
RELEASE_COPY_ROOT="$TEMP_ROOT/release"
copy_release_inputs "$SOURCE_PAYLOAD_ROOT" "$SOURCE_PAYLOAD_ROOT_KEY" "$RELEASE_COPY_ROOT" \
    "$ZIP_NAME" "$MANIFEST_NAME" "$METADATA_NAME" "$CHECKSUMS_NAME" || \
    fail "release inputs changed or could not be copied into the private installer directory."
PAYLOAD_ROOT="$RELEASE_COPY_ROOT"
PAYLOAD="$PAYLOAD_ROOT/$ZIP_NAME"
MANIFEST="$PAYLOAD_ROOT/$MANIFEST_NAME"
METADATA="$PAYLOAD_ROOT/$METADATA_NAME"
CHECKSUMS="$PAYLOAD_ROOT/$CHECKSUMS_NAME"
PAYLOAD_ROOT_KEY="$(stat -f '%d:%i' "$PAYLOAD_ROOT" 2>/dev/null || true)"
[[ -n "$PAYLOAD_ROOT_KEY" ]] || fail "private release root identity is unavailable."
capture_release_snapshot || fail "private release snapshot identity is unavailable."
release_snapshot_ok || fail "private release snapshot is not root-owned and immutable-safe."

validate_checksums()
{
    python3 - "$CHECKSUMS" "$PAYLOAD_ROOT" "$ZIP_NAME" "$MANIFEST_NAME" "$METADATA_NAME" <<'PY'
import hashlib
import os
import re
import stat
import sys
from pathlib import Path, PurePosixPath

checksum_file = Path(sys.argv[1])
root = Path(sys.argv[2])
if root.resolve() != root or checksum_file.parent != root:
    raise SystemExit("private checksum layout is not canonical")
expected_names = set(sys.argv[3:])
entries = {}
checksum_fd = os.open(str(checksum_file), os.O_RDONLY | os.O_NOFOLLOW)
try:
    checksum_info = os.fstat(checksum_fd)
    if not stat.S_ISREG(checksum_info.st_mode) or checksum_info.st_nlink != 1:
        raise SystemExit("checksum file is not a private regular file")
    checksum_bytes = bytearray()
    while True:
        chunk = os.read(checksum_fd, 1024 * 1024)
        if not chunk:
            break
        checksum_bytes.extend(chunk)
    if os.fstat(checksum_fd).st_ino != checksum_info.st_ino:
        raise SystemExit("checksum file changed during verification")
finally:
    os.close(checksum_fd)
for line in bytes(checksum_bytes).decode("utf-8").splitlines():
    if not line.strip():
        continue
    fields = line.split()
    if len(fields) != 2:
        raise SystemExit("invalid checksum line")
    digest, relative = fields
    if not re.fullmatch(r"[0-9a-fA-F]{64}", digest):
        raise SystemExit("invalid checksum digest")
    path = PurePosixPath(relative)
    if path.is_absolute() or ".." in path.parts or "\\" in relative or relative != path.as_posix():
        raise SystemExit("unsafe checksum path")
    if relative in entries:
        raise SystemExit("duplicate checksum path")
    entries[relative] = digest.lower()

if set(entries) != expected_names:
    raise SystemExit("unexpected or missing checksum entries")
for relative, expected in entries.items():
    target = root / relative
    if target.parent != root:
        raise SystemExit("checksum target is outside selected release root")
    fd = os.open(str(target), os.O_RDONLY | os.O_NOFOLLOW)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise SystemExit("checksum target is not a private regular file")
        digest = hashlib.sha256()
        while True:
            chunk = os.read(fd, 1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
        after = os.fstat(fd)
        if (after.st_dev, after.st_ino, after.st_size) != (info.st_dev, info.st_ino, info.st_size):
            raise SystemExit("checksum target changed during verification")
        actual = digest.hexdigest()
    finally:
        os.close(fd)
    if actual != expected:
        raise SystemExit("release checksum verification failed")
PY
}

release_snapshot_ok || fail "release snapshot changed before checksum verification."
validate_checksums || fail "release checksum verification failed."
release_snapshot_ok || fail "release snapshot changed during checksum verification."

grep -Fqx 'FormatVersion=1' "$METADATA" || fail "unsupported release metadata."
grep -Fqx 'ReleaseVersion=1.0.9' "$METADATA" || fail "wrong release version."
grep -Fqx 'PatchVersion=v3.8' "$METADATA" || fail "wrong patch version."
grep -Fqx 'BaseBundleIdentifier=com.rileytestut.AltServer' "$METADATA" || fail "wrong official bundle metadata."
grep -Fqx 'BaseVersion=1.7.6' "$METADATA" || fail "wrong official version metadata."
grep -Fqx 'BaseBuild=94' "$METADATA" || fail "wrong official build metadata."
grep -Fqx 'PatchedIPA=Not-included' "$METADATA" || fail "release must not contain a patched IPA."
release_snapshot_ok || fail "release snapshot changed before extraction."
freeze_release_snapshot || fail "could not freeze the root-owned release snapshot."
release_snapshot_ok || fail "frozen release snapshot identity changed."

# Validate every ZIP name and symlink before invoking Apple's extractor.  This
# keeps /usr/bin/unzip inside the temporary directory even for a hostile ZIP.
python3 - "$PAYLOAD" <<'PY'
import os
import stat
import sys
import zipfile
from pathlib import PurePosixPath

seen = set()
with zipfile.ZipFile(sys.argv[1]) as archive:
    for info in archive.infolist():
        name = info.filename
        clean = name.rstrip("/")
        if name in seen or clean in seen:
            raise SystemExit("duplicate ZIP entry")
        seen.add(name)
        seen.add(clean)
        path = PurePosixPath(clean)
        if not clean or path.is_absolute() or ".." in path.parts or "\\" in name:
            raise SystemExit("unsafe ZIP path")
        if clean != "AltServer.app" and not clean.startswith("AltServer.app/"):
            raise SystemExit("unexpected ZIP root")
        if any(part == "__MACOSX" or part.startswith("._") for part in path.parts):
            raise SystemExit("AppleDouble ZIP entry")
        mode = (info.external_attr >> 16) & 0xffff
        file_type = stat.S_IFMT(mode)
        if file_type not in (0, stat.S_IFREG, stat.S_IFDIR, stat.S_IFLNK):
            raise SystemExit("unsupported ZIP special file type")
        if file_type == stat.S_IFLNK:
            target = archive.read(info).decode("utf-8")
            target_path = PurePosixPath(target)
            if target_path.is_absolute() or ".." in target_path.parts or "\\" in target:
                raise SystemExit("unsafe ZIP symlink")
PY

/usr/bin/unzip -q "$PAYLOAD" -d "$TEMP_ROOT" || fail "payload extraction failed."
APP="$TEMP_ROOT/AltServer.app"
[[ -d "$APP" && ! -L "$APP" ]] || fail "payload app is missing."
PLIST="$APP/Contents/Info.plist"
MAIN="$APP/Contents/MacOS/AltServer"
[[ -f "$PLIST" && -f "$MAIN" ]] || fail "payload app is incomplete."

plist_value()
{
    /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null || true
}

[[ "$(plist_value CFBundleIdentifier)" == "com.rileytestut.AltServer" ]] || fail "payload bundle identifier is not official."
[[ "$(plist_value CFBundleShortVersionString)" == "1.7.6-macOS27-v3.8" ]] || fail "payload version is not v3.8."
[[ "$(plist_value CFBundleVersion)" == "94" ]] || fail "payload build is not 94."
[[ "$(plist_value LSEnvironment:DYLD_INSERT_LIBRARIES)" == "@executable_path/../Frameworks/AltServerAnisetteFix.dylib" ]] || fail "relative anisette environment is missing."
ARCHES="$(lipo -archs "$MAIN" 2>/dev/null || true)"
[[ " $ARCHES " == *" arm64 "* && " $ARCHES " == *" x86_64 "* ]] || fail "payload AltServer must remain universal."
payload_main_texts_official "$MAIN" || fail "payload AltServer __TEXT,__text does not match the approved official per-architecture identity."
[[ -f "$APP/Contents/Frameworks/AltServerAnisetteHelper" ]] || fail "anisette helper is missing."
DYLIB="$APP/Contents/Frameworks/AltServerAnisetteFix.dylib"
[[ -f "$DYLIB" && ! -L "$DYLIB" ]] || fail "anisette fix dylib is missing or is a symlink."
path_has_symlink "$DYLIB" && fail "anisette fix dylib path contains a symlink."
[[ "$(lipo -archs "$DYLIB" 2>/dev/null || true)" == "arm64" ]] || fail "anisette fix dylib must be arm64-only."
[[ "$(lipo -archs "$APP/Contents/Frameworks/AltServerAnisetteHelper" 2>/dev/null || true)" == "arm64" ]] || fail "anisette helper must be arm64-only."
[[ -n "$(shasum -a 256 "$DYLIB" | awk '{ print $1 }')" ]] || fail "anisette fix dylib hash is unavailable."
[[ -n "$(shasum -a 256 "$APP/Contents/Frameworks/AltServerAnisetteHelper" | awk '{ print $1 }')" ]] || fail "anisette helper hash is unavailable."
if find -P "$APP" \( -path '*AltSign-Dynamic.framework' -o -name '*.ipa' -o -name '*.mobileprovision' -o -name 'embedded.provisionprofile' \) -print -quit | /usr/bin/grep -q .; then
    fail "payload contains a forbidden dynamic AltSign, IPA, or provisioning profile."
fi

EMBEDDED_MANIFEST="$APP/Contents/Resources/AltServer-macOS27-v3.8.executables.txt"
[[ -f "$EMBEDDED_MANIFEST" ]] || fail "embedded executable manifest is missing."
cmp -s "$MANIFEST" "$EMBEDDED_MANIFEST" || fail "executable manifest mismatch."

python3 - "$APP" "$EMBEDDED_MANIFEST" <<'PY'
import os
import stat
import sys
from pathlib import Path, PurePosixPath

root = Path(sys.argv[1])
manifest = Path(sys.argv[2])
expected = {}
for line in manifest.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    fields = line.split(" ", 1)
    if len(fields) != 2 or len(fields[0]) != 4 or any(c not in "01234567" for c in fields[0]):
        raise SystemExit("invalid executable manifest line")
    relative = fields[1]
    path = PurePosixPath(relative)
    if path.is_absolute() or ".." in path.parts or "\\" in relative or relative in expected:
        raise SystemExit("unsafe or duplicate executable manifest path")
    expected[relative] = int(fields[0], 8)

for path in sorted(root.rglob("*")):
    relative = path.relative_to(root).as_posix()
    if relative.startswith("__MACOSX/") or relative.startswith("._") or "/._" in relative:
        raise SystemExit("AppleDouble path")
    if path.is_symlink():
        target = os.readlink(path)
        target_path = PurePosixPath(target)
        if target_path.is_absolute() or ".." in target_path.parts or "\\" in target or not path.exists():
            raise SystemExit("unsafe or dangling symlink")

for relative, mode in expected.items():
    path = root / relative
    if not path.is_file() or path.is_symlink() or mode & 0o111 == 0:
        raise SystemExit("manifest entry is not a regular executable")
    if stat.S_IMODE(os.lstat(path).st_mode) != mode:
        raise SystemExit("payload executable mode differs from the signed manifest")
    os.chmod(path, mode)
    if stat.S_IMODE(os.lstat(path).st_mode) != mode:
        raise SystemExit("manifest mode could not be applied")

actual = {}
for path in sorted(root.rglob("*")):
    if path.is_symlink() or not path.is_file():
        continue
    mode = stat.S_IMODE(os.lstat(path).st_mode)
    if mode & 0o111:
        actual[path.relative_to(root).as_posix()] = mode
if actual != expected:
    raise SystemExit("finite executable manifest does not match payload")
PY

required_executable_modes_ok "$APP" || fail "payload executable modes are unsafe."
PAYLOAD_BUNDLE_HASH="$(bundle_snapshot_hash "$APP")" || fail "payload bundle snapshot could not be computed."
[[ -n "$PAYLOAD_BUNDLE_HASH" ]] || fail "payload bundle snapshot is empty."
xattr -cr "$APP" 2>/dev/null || true
codesign --verify --deep --strict "$APP" >/dev/null 2>&1 || fail "payload signature verification failed."
PAYLOAD_SIGNATURE_DETAILS="$(codesign --display --verbose=4 "$APP" 2>&1)" || fail "payload signature provenance could not be inspected."
if [[ "$PAYLOAD_SIGNATURE_DETAILS" != *"Signature=adhoc"* ]]; then
    [[ "$PAYLOAD_SIGNATURE_DETAILS" == *"Authority=Developer ID Application:"* ]] || fail "payload is not signed by the approved Developer ID authority."
    [[ "$(printf '%s\n' "$PAYLOAD_SIGNATURE_DETAILS" | awk -F= '/^TeamIdentifier=/{ print $2; exit }')" == "$EXPECTED_OFFICIAL_TEAM_ID" ]] || fail "payload signing team is not the approved official team."
fi
validate_lc_uuid "$DYLIB" || fail "anisette fix dylib must contain exactly one valid nonzero LC_UUID; this payload is not installable on macOS 27."
validate_lc_uuid "$APP/Contents/Frameworks/AltServerAnisetteHelper" || fail "anisette helper must contain exactly one valid nonzero LC_UUID; this payload is not installable on macOS 27."
release_snapshot_ok || fail "release snapshot changed before install decision."
validate_component_metadata || fail "BUILD-METADATA helper/dylib SHA-256 and UUID bindings are missing, malformed, or do not match the immutable payload."

if [[ "$INSTALL_DRY_RUN" == "1" ]]; then
    echo "Dry run complete: v3.8 payload, checksums, manifest, and signature verified."
    echo "No /Applications or Application Support files were changed."
    exit 0
fi

# Serialize the whole target transaction before reading provenance.  The
# helper's mkdir-at lock records owner PID/start/parent identity and refuses an
# active or unverifiable lock; only a validated dead owner is recoverable.
capture_target_parent || fail "target parent is not a canonical stable directory."
INSTALL_PARENT_REAL="$TARGET_PARENT_REAL"
INSTALL_PARENT_KEY="$TARGET_PARENT_KEY"
[[ "$INSTALL_LOCK_PARENT_REAL" == "${INSTALL_LOCK_PARENT_REAL:A}" &&
   -d "$INSTALL_LOCK_PARENT_REAL" && ! -L "$INSTALL_LOCK_PARENT_REAL" ]] ||
    fail "the root-owned lock parent is not a canonical stable directory."
path_has_symlink "$INSTALL_LOCK_PARENT_REAL" && fail "the root-owned lock parent contains a symlink."
[[ "$(stat -f '%u' "$INSTALL_LOCK_PARENT_REAL" 2>/dev/null || true)" == "0" ]] ||
    fail "the installer lock parent is not root-owned."
INSTALL_LOCK_PARENT_MODE="$(stat -f '%Lp' "$INSTALL_LOCK_PARENT_REAL" 2>/dev/null || true)"
INSTALL_LOCK_PARENT_GROUP="$(stat -f '%Sg' "$INSTALL_LOCK_PARENT_REAL" 2>/dev/null || true)"
[[ "$INSTALL_LOCK_PARENT_MODE" == <-> ]] || fail "the installer lock parent mode is unavailable."
if (( 8#$INSTALL_LOCK_PARENT_MODE & 2 )); then
    fail "the installer lock parent is world-writable."
fi
if (( 8#$INSTALL_LOCK_PARENT_MODE & 20 )) && [[ "$INSTALL_LOCK_PARENT_GROUP" != "wheel" ]]; then
    fail "the installer lock parent is group-writable by an untrusted group."
fi
INSTALL_LOCK_PARENT_KEY="$(stat -f '%d:%i' "$INSTALL_LOCK_PARENT_REAL" 2>/dev/null || true)"
[[ -n "$INSTALL_LOCK_PARENT_KEY" ]] || fail "the installer lock parent identity is unavailable."
INSTALL_LOCK_KEY="$("$ATOMIC_HELPER" lock "$INSTALL_LOCK_PARENT_REAL" "$INSTALL_LOCK_PARENT_KEY" \
    "$INSTALL_LOCK_NAME" "$$" "$INSTALL_LOCK_OWNER_START")" || \
    fail "another installer owns the root lock, or the existing lock is not safely stale."
[[ "$INSTALL_LOCK_KEY" == <->:<-> ]] || fail "the installer lock identity is invalid."
INSTALL_LOCK_HELD=1

# Validate the current app before making a recoverable backup.  The target is
# exact and is never replaced by a broad glob or an unverified directory.
CURRENT_PRESENT=0
if [[ -e "$TARGET_APP" || -L "$TARGET_APP" ]]; then
    [[ -d "$TARGET_APP" && ! -L "$TARGET_APP" ]] || fail "existing AltServer target is not a directory app."
    validate_official_target "$TARGET_APP" || fail "existing target is not the approved official AltServer 1.7.6/build94 provenance."
    capture_target_binding || fail "approved target identity could not be bound."
    CURRENT_PRESENT=1
    stop_target_processes "$TARGET_APP/Contents/MacOS/AltServer"
    target_binding_ok || fail "target changed while stopping AltServer."
else
    target_absent_ok || fail "target parent changed while checking for AltServer."
fi

BACKUP_APP=""
BACKUP_META=""
if [[ "$CURRENT_PRESENT" == "1" ]]; then
    prepare_backup_root
    if ! publish_backup_pair "$TARGET_APP"; then
        if ! backup_publish_recover; then
            fail "backup publish failed and recovery paths were preserved; inspect the reported paths."
        fi
        fail "could not publish an atomic verified backup pair; existing backups were preserved."
    fi
fi

NONCE="$(date +%s).$$"
TRANSIENT="$TARGET_APP.__v38.$NONCE"
OLD_TARGET="$TARGET_APP.__old.$NONCE"
FAILED_TARGET="$TARGET_APP.__failed.$NONCE"
TARGET_EXEC="$TARGET_APP/Contents/MacOS/AltServer"
STAGE_PARENT="$TEMP_ROOT/install-stage"
STAGE_APP="$STAGE_PARENT/AltServer.app"
STAGE_PARENT_KEY=""
STAGE_KEY=""
TRANSIENT_KEY=""
OLD_TARGET_KEY=""
FAILED_TARGET_KEY=""
NEW_TARGET_KEY=""
INSTALL_FAULT="${ALTSERVER_INSTALL_FAULT:-${ALTSERVER_RELEASE_FAULT:-}}"
INSTALL_TARGET_MOVED=0
INSTALL_TRANSIENT_MOVED=0
INSTALL_RECOVERY_FAILED=0

install_fault_enabled()
{
    local wanted="$1"
    local token
    for token in ${(s:,:)INSTALL_FAULT}; do
        [[ "$token" == "$wanted" || "${token//_/-}" == "$wanted" || "${token//-/_}" == "$wanted" ]] && return 0
    done
    return 1
}

install_parent_ok()
{
    [[ -d "$INSTALL_PARENT_REAL" && ! -L "$INSTALL_PARENT_REAL" ]] || return 1
    [[ "$INSTALL_PARENT_REAL" == "${INSTALL_PARENT_REAL:A}" ]] || return 1
    path_has_symlink "$INSTALL_PARENT_REAL" && return 1
    [[ "$(stat -f '%d:%i' "$INSTALL_PARENT_REAL" 2>/dev/null || true)" == "$INSTALL_PARENT_KEY" ]] || return 1
    return 0
}

install_path_ok()
{
    local target_path="$1"
    [[ "$target_path" == "$TARGET_APP" || "$target_path" == "$TRANSIENT" || "$target_path" == "$OLD_TARGET" || "$target_path" == "$FAILED_TARGET" ]] || return 1
    [[ "$target_path:h" == "$INSTALL_PARENT_REAL" && "$target_path" == "${target_path:A}" ]] || return 1
    path_has_symlink "$target_path" && return 1
    return 0
}

install_remove()
{
    local target_path="$1"
    local expected_key="${2:-}"
    install_parent_ok || return 1
    install_path_ok "$target_path" || return 1
    [[ -e "$target_path" || -L "$target_path" ]] || return 0
    [[ -n "$expected_key" ]] || return 1
    atomic_remove_path "$target_path" "$expected_key" "$INSTALL_PARENT_KEY"
}

install_move()
{
    local phase="$1"
    local source="$2"
    local destination="$3"
    local source_key="$4"
    local source_parent_key destination_parent_key
    install_parent_ok || return 70
    if [[ "$source" != "$STAGE_APP" ]]; then
        install_path_ok "$source" || return 70
    else
        [[ "$source" == "${source:A}" && ! -L "$source" ]] || return 70
        path_has_symlink "$source" && return 70
    fi
    install_path_ok "$destination" || return 70
    [[ -d "$source" && ! -L "$source" ]] || return 70
    [[ ! -e "$destination" && ! -L "$destination" ]] || return 70
    [[ -n "$source_key" ]] || return 70
    if [[ "$source" == "$STAGE_APP" ]]; then
        source_parent_key="$STAGE_PARENT_KEY"
    else
        source_parent_key="$INSTALL_PARENT_KEY"
    fi
    destination_parent_key="$INSTALL_PARENT_KEY"
    [[ -n "$source_parent_key" && -n "$destination_parent_key" ]] || return 70
    [[ "$(stat -f '%d:%i' "$source" 2>/dev/null || true)" == "$source_key" ]] || return 70
    if install_fault_enabled "$phase"; then
        return 75
    fi
    if [[ "$source" == "$TARGET_APP" ]]; then
        [[ "$source_key" == "$TARGET_BIND_KEY" ]] || return 70
        target_binding_ok || return 70
    elif [[ "$destination" == "$TARGET_APP" ]]; then
        target_absent_ok || return 70
    fi
    atomic_move_path "$source" "$source_key" "$destination" \
        "$source_parent_key" "$destination_parent_key" || return 70
    case "$phase" in
        mv-stage-transient) TRANSIENT_KEY="$source_key" ;;
        mv-old-aside) INSTALL_TARGET_MOVED=1; OLD_TARGET_KEY="$source_key" ;;
        mv-new-publish) INSTALL_TRANSIENT_MOVED=1; NEW_TARGET_KEY="$source_key" ;;
        mv-new-aside) INSTALL_TRANSIENT_MOVED=0; FAILED_TARGET_KEY="$source_key" ;;
        mv-old-restore) INSTALL_TARGET_MOVED=0; TARGET_BIND_KEY="$source_key" ;;
    esac
    install_parent_ok || return 70
    [[ ! -e "$source" && ! -L "$source" ]] || return 70
    [[ -d "$destination" && ! -L "$destination" ]] || return 70
    [[ "$(stat -f '%d:%i' "$destination" 2>/dev/null || true)" == "$source_key" ]] || return 70
    return 0
}

target_new_identity_ok()
{
    install_parent_ok || return 1
    [[ -n "$NEW_TARGET_KEY" && -d "$TARGET_APP" && ! -L "$TARGET_APP" ]] || return 1
    [[ "$TARGET_APP" == "${TARGET_APP:A}" ]] || return 1
    path_has_symlink "$TARGET_APP" && return 1
    [[ "$(stat -f '%d:%i' "$TARGET_APP" 2>/dev/null || true)" == "$NEW_TARGET_KEY" ]] || return 1
    atomic_check_path "$TARGET_APP" "$NEW_TARGET_KEY" "$INSTALL_PARENT_KEY"
}

install_report_recovery_failure()
{
    INSTALL_RECOVERY_FAILED=1
    echo "Install: transaction recovery failed: $1" >&2
    echo "Install: recoverable paths: target=$TARGET_APP old=$OLD_TARGET failed=$FAILED_TARGET transient=$TRANSIENT" >&2
}

install_recover()
{
    if [[ "$INSTALL_TRANSIENT_MOVED" == "1" ]]; then
        if install_move mv-new-aside "$TARGET_APP" "$FAILED_TARGET" "$NEW_TARGET_KEY"; then
            INSTALL_TRANSIENT_MOVED=0
        else
            install_report_recovery_failure "could not move the new app aside"
        fi
    fi
    if [[ "$INSTALL_RECOVERY_FAILED" == "0" && "$INSTALL_TARGET_MOVED" == "1" ]]; then
        if install_move mv-old-restore "$OLD_TARGET" "$TARGET_APP" "$OLD_TARGET_KEY"; then
            INSTALL_TARGET_MOVED=0
        else
            install_report_recovery_failure "could not restore the previous app"
        fi
    fi
    if [[ "$INSTALL_RECOVERY_FAILED" == "0" && ( -e "$FAILED_TARGET" || -L "$FAILED_TARGET" ) ]]; then
        if install_remove "$FAILED_TARGET" "$FAILED_TARGET_KEY"; then
            :
        else
            install_report_recovery_failure "could not remove the failed app; it was preserved"
        fi
    fi
    if [[ "$INSTALL_RECOVERY_FAILED" == "0" && ( -e "$TRANSIENT" || -L "$TRANSIENT" ) ]]; then
        if install_remove "$TRANSIENT" "$TRANSIENT_KEY"; then
            :
        else
            install_report_recovery_failure "could not remove the staged app; it was preserved"
        fi
    fi
    [[ "$INSTALL_RECOVERY_FAILED" == "0" ]]
}

install_direct()
{
    install_parent_ok || return 1
    target_absent_ok || [[ "$CURRENT_PRESENT" == "1" ]] || return 1
    [[ ! -e "$TRANSIENT" && ! -L "$TRANSIENT" && ! -e "$OLD_TARGET" && ! -L "$OLD_TARGET" && ! -e "$FAILED_TARGET" && ! -L "$FAILED_TARGET" ]] || return 1
    [[ ! -e "$STAGE_APP" && ! -L "$STAGE_APP" ]] || return 1
    mkdir "$STAGE_PARENT" || return 1
    chmod 700 "$STAGE_PARENT" || return 1
    [[ "$(stat -f '%u' "$STAGE_PARENT" 2>/dev/null || true)" == "0" ]] || return 1
    [[ "$(stat -f '%Mp%Lp' "$STAGE_PARENT" 2>/dev/null || true)" == "0700" ]] || return 1
    STAGE_PARENT_KEY="$(stat -f '%d:%i' "$STAGE_PARENT" 2>/dev/null || true)"
    [[ -n "$STAGE_PARENT_KEY" ]] || return 1
    ditto --noextattr --noqtn "$APP" "$STAGE_APP" 2>/dev/null || return 1
    [[ -d "$STAGE_APP" && ! -L "$STAGE_APP" ]] || return 1
    STAGE_KEY="$(stat -f '%d:%i' "$STAGE_APP" 2>/dev/null || true)"
    [[ -n "$STAGE_KEY" ]] || return 1
    [[ "$(stat -f '%d:%i' "$STAGE_PARENT" 2>/dev/null || true)" == "$STAGE_PARENT_KEY" ]] || return 1
    [[ "$(bundle_snapshot_hash "$STAGE_APP")" == "$PAYLOAD_BUNDLE_HASH" ]] || return 1
    xattr -cr "$STAGE_APP" 2>/dev/null || return 1
    codesign --verify --deep --strict "$STAGE_APP" >/dev/null 2>&1 || return 1
    install_move mv-stage-transient "$STAGE_APP" "$TRANSIENT" "$STAGE_KEY" || return 1
    if [[ "$CURRENT_PRESENT" == "1" ]]; then
        target_binding_ok || return 1
        install_move mv-old-aside "$TARGET_APP" "$OLD_TARGET" "$TARGET_BIND_KEY" || return 1
    fi
    target_absent_ok || return 1
    install_move mv-new-publish "$TRANSIENT" "$TARGET_APP" "$TRANSIENT_KEY" || return 1
    if install_fault_enabled after-new-rename || install_fault_enabled after-new-publish; then
        return 1
    fi
    target_new_identity_ok || return 1
    codesign --verify --deep --strict "$TARGET_APP" >/dev/null 2>&1 || {
        return 1
    }
    target_new_identity_ok || return 1
    [[ "$CURRENT_PRESENT" != "1" ]] || target_new_identity_ok || return 1
    if [[ "$CURRENT_PRESENT" == "1" ]] && ! install_remove "$OLD_TARGET" "$OLD_TARGET_KEY"; then
        install_report_recovery_failure "could not remove the previous app backup; it was preserved"
        return 1
    fi
    OLD_TARGET_KEY=""
    INSTALL_TARGET_MOVED=0
    INSTALL_TRANSIENT_MOVED=0
    return 0
}

if [[ "$CURRENT_PRESENT" == "1" ]]; then
    target_binding_ok || fail "target changed before transaction start."
    stop_target_processes "$TARGET_EXEC"
    target_binding_ok || fail "target changed while preparing the transaction."
else
    target_absent_ok || fail "target parent changed before transaction start."
fi
if ! install_direct; then
    if [[ "$INSTALL_RECOVERY_FAILED" == "0" ]]; then
        install_recover || true
    fi
    [[ "$INSTALL_RECOVERY_FAILED" == "0" ]] || fail "installation rollback failed; recoverable app paths were preserved."
    if [[ -e "$STAGE_APP" || -L "$STAGE_APP" ]]; then
        [[ -n "$STAGE_KEY" ]] || fail "unbound private staging path was preserved after direct install failure."
        atomic_remove_path "$STAGE_APP" "$STAGE_KEY" "$STAGE_PARENT_KEY" || fail "could not clear the bound private staging path."
    fi
    fail "installation failed; rollback paths were preserved and no administrator fallback is attempted."
fi

codesign --verify --deep --strict "$TARGET_APP" >/dev/null 2>&1 || fail "installed AltServer failed strict signature verification."
/usr/bin/arch -arm64 /usr/bin/open -n "$TARGET_APP" >/dev/null 2>&1 || true
echo "Installed official AltServer 1.7.6/build94 with the v3.8 anisette fix."
