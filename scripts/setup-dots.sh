#!/usr/bin/env bash
#
# Install / verify dotfiles.
#
# Idempotent by design. For every tracked item:
#   missing            -> install it
#   identical to repo  -> report OK, touch nothing
#   differs from repo  -> report WHY and leave it alone unless --force
#
# The old version renamed whatever was there to <name>_old and copied over the
# top on every run. That silently accumulated 83 ~/.config/nvim_old.N
# directories and gave no way to tell an intentional local edit from drift.
#
# A manifest at ~/.local/share/dev-setup/manifest records the hash of each item
# as installed, which is what lets us distinguish:
#   REPO-NEWER  you still have exactly what this repo last installed, and the
#               repo has since moved on -- safe to update
#   LOCAL-EDIT  the file matches neither the repo nor what we installed, so
#               someone changed it by hand -- never clobbered without --force
#
# Written for bash 3.2 (macOS system bash).

set -uo pipefail

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
REPO=$( cd "$parent_path/.." ; pwd -P )

DOTS="$REPO/dots"
BIN_SRC="$REPO/custom_setup_bin"
BIN_DEST="$HOME/.local/custom_setup_bin"
STATE_DIR="$HOME/.local/share/dev-setup"
MANIFEST="$STATE_DIR/manifest"

FORCE=0
CHECK=0
ONLY=""

# generated/runtime files that live alongside config but are not config
EXCLUDES=( '.DS_Store' 'lazy-lock.json' 'tags' '.luarc.json' 'test.sh' )

usage() {
    cat <<USAGE
usage: setup-dots.sh [--check] [--force]

  (no flags)  install anything missing; report anything that differs
  --check     report only; change nothing
  --force     also overwrite items that differ (one timestamped backup is kept)
  --only P    restrict to items whose name contains P (repeatable-safe substring)

Items that differ are never overwritten without --force. Combine --force with
--only to apply one item at a time, e.g.
  ./scripts/setup-dots.sh --force --only .tmux.conf
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --force) FORCE=1 ;;
        --check|--dry-run) CHECK=1 ;;
        --only) shift; ONLY="${1:-}" ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

[ -d "$DOTS" ] || { echo "no dots/ directory at $DOTS" >&2; exit 1; }
mkdir -p "$STATE_DIR"
touch "$MANIFEST"

# ── hashing ──────────────────────────────────────────────────────────────────
# Directories hash as the hash of their sorted per-file hashes, so a tree can
# be compared as a single value. Generated files are excluded or every nvim
# comparison would report a spurious difference from lazy-lock.json.
hash_path() {
    local p="$1"
    if [ -d "$p" ]; then
        local find_args=()
        local e
        for e in "${EXCLUDES[@]}"; do
            find_args+=( -not -name "$e" )
        done
        ( cd "$p" 2>/dev/null && \
          find . -type f "${find_args[@]}" -print 2>/dev/null \
            | LC_ALL=C sort \
            | while IFS= read -r f; do shasum -a 256 "$f" 2>/dev/null; done \
            | shasum -a 256 | cut -d' ' -f1 )
    elif [ -e "$p" ]; then
        shasum -a 256 "$p" 2>/dev/null | cut -d' ' -f1
    else
        echo ""
    fi
}

manifest_get() {
    awk -F'\t' -v k="$1" '$1==k {print $2; exit}' "$MANIFEST"
}

manifest_set() {
    local key="$1" val="$2" tmp
    tmp=$(mktemp)
    awk -F'\t' -v k="$key" '$1!=k' "$MANIFEST" > "$tmp" 2>/dev/null
    printf '%s\t%s\n' "$key" "$val" >> "$tmp"
    LC_ALL=C sort -o "$MANIFEST" "$tmp"
    rm -f "$tmp"
}

BACKUP_ROOT=""
backup_of() {
    local dest="$1"
    if [ -z "$BACKUP_ROOT" ]; then
        BACKUP_ROOT="$STATE_DIR/backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_ROOT"
    fi
    local rel="${dest#$HOME/}"
    mkdir -p "$BACKUP_ROOT/$(dirname "$rel")"
    cp -R "$dest" "$BACKUP_ROOT/$rel"
    echo "$BACKUP_ROOT/$rel"
}

install_item() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    [ -e "$dest" ] && rm -rf "$dest"
    cp -R "$src" "$dest"
}

n_new=0; n_ok=0; n_updated=0; n_drift=0; n_blocked=0; n_untracked=0; n_skipped=0

process() {
    local src="$1" dest="$2" label="$3"
    local hs hd hm
    if [ -n "$ONLY" ]; then
        case "$label" in
            *"$ONLY"*) ;;
            *) n_skipped=$((n_skipped+1)); return ;;
        esac
    fi
    hs=$(hash_path "$src")
    hd=$(hash_path "$dest")
    hm=$(manifest_get "$label")

    if [ ! -e "$dest" ]; then
        if [ "$CHECK" -eq 1 ]; then
            printf '  %-10s %s\n' 'NEW' "$label"
        else
            install_item "$src" "$dest"
            manifest_set "$label" "$hs"
            printf '  %-10s %s\n' 'INSTALLED' "$label"
        fi
        n_new=$((n_new+1)); return
    fi

    if [ "$hs" = "$hd" ]; then
        # already correct; record the hash if we had not tracked it before
        [ -n "$hm" ] || manifest_set "$label" "$hs"
        printf '  %-10s %s\n' 'OK' "$label"
        n_ok=$((n_ok+1)); return
    fi

    # differs -- decide whether it is our own stale install or a hand edit
    local why
    if [ -z "$hm" ]; then
        # We have no record of ever installing this, so we genuinely cannot
        # tell whether the difference is a hand edit or just a stale install
        # predating the manifest. Say so rather than guessing.
        why='UNTRACKED'
    elif [ "$hd" = "$hm" ]; then
        why='REPO-NEWER'
    else
        why='LOCAL-EDIT'
    fi

    if [ "$FORCE" -eq 1 ] && [ "$CHECK" -eq 0 ]; then
        local b
        b=$(backup_of "$dest")
        install_item "$src" "$dest"
        manifest_set "$label" "$hs"
        printf '  %-10s %s  (was %s; backup: %s)\n' 'UPDATED' "$label" "$why" "${b#$HOME/}"
        n_updated=$((n_updated+1)); return
    fi

    case "$why" in
        REPO-NEWER)
            printf '  %-10s %s  -- matches our last install; repo moved on, safe to update\n' "$why" "$label"
            n_drift=$((n_drift+1)) ;;
        UNTRACKED)
            printf '  %-10s %s  -- differs, never tracked; compare before applying\n' "$why" "$label"
            n_untracked=$((n_untracked+1)) ;;
        *)
            printf '  %-10s %s  -- edited outside the repo; NOT touched\n' "$why" "$label"
            n_blocked=$((n_blocked+1)) ;;
    esac
}

echo "dev-setup: dotfiles"
[ "$CHECK" -eq 1 ] && echo "(check mode -- nothing will be changed)"

# ── $HOME-level dotfiles (everything in dots/ except .config) ────────────────
for src in "$DOTS"/.* "$DOTS"/*; do
    [ -e "$src" ] || continue
    name=$(basename "$src")
    case "$name" in
        .|..|.config) continue ;;
        '*') continue ;;
    esac
    process "$src" "$HOME/$name" "~/$name"
done

# ── ~/.config entries ────────────────────────────────────────────────────────
if [ -d "$DOTS/.config" ]; then
    for src in "$DOTS"/.config/*; do
        [ -e "$src" ] || continue
        name=$(basename "$src")
        process "$src" "$HOME/.config/$name" "~/.config/$name"
    done
fi

# ── ~/.zshrc hook ────────────────────────────────────────────────────────────
# ~/.zshrc is the user's own file (PATH, env, tool init) and is NEVER replaced.
# We only ensure one guarded source line is present, because macOS /etc/zshrc
# resets HISTFILE/HISTSIZE/SAVEHIST after ~/.zprofile -- ~/.zshrc is the first
# place those values survive.
ensure_zshrc_hook() {
    local rc="$HOME/.zshrc"
    local marker='# >>> dev-setup >>>'
    if [ -f "$rc" ] && grep -qF "$marker" "$rc"; then
        printf '  %-10s %s\n' 'OK' '~/.zshrc hook'
        n_ok=$((n_ok+1))
        return
    fi
    if [ "$CHECK" -eq 1 ]; then
        printf '  %-10s %s\n' 'NEW' '~/.zshrc hook'
        n_new=$((n_new+1))
        return
    fi
    {
        printf '\n%s\n' "$marker"
        printf '%s\n' '[ -f "$HOME/.dev-setup.zsh" ] && source "$HOME/.dev-setup.zsh"'
        printf '%s\n' '# <<< dev-setup <<<'
    } >> "$rc"
    printf '  %-10s %s\n' 'INSTALLED' '~/.zshrc hook'
    n_new=$((n_new+1))
}

if [ -z "$ONLY" ] || case "~/.zshrc hook" in *"$ONLY"*) true ;; *) false ;; esac; then
    echo "dev-setup: shell hook"
    ensure_zshrc_hook
fi

# ── runtime scripts on PATH ──────────────────────────────────────────────────
if [ -d "$BIN_SRC" ]; then
    echo "dev-setup: bin"
    mkdir -p "$BIN_DEST"
    for src in "$BIN_SRC"/*; do
        [ -e "$src" ] || continue
        name=$(basename "$src")
        process "$src" "$BIN_DEST/$name" "bin/$name"
    done
    chmod -R +x "$BIN_DEST" 2>/dev/null
fi

echo
echo "installed=$n_new  ok=$n_ok  updated=$n_updated  repo-newer=$n_drift  untracked=$n_untracked  local-edit=$n_blocked  skipped=$n_skipped"
[ -n "$BACKUP_ROOT" ] && echo "backups: ${BACKUP_ROOT#$HOME/}"
echo "manifest: ${MANIFEST#$HOME/}"

if [ "$n_drift" -gt 0 ] || [ "$n_blocked" -gt 0 ] || [ "$n_untracked" -gt 0 ]; then
    echo
    echo "Nothing differing was overwritten. Review with:"
    echo "  diff -ru ~/<item> $DOTS/<item>"
    echo "Then apply one at a time with:"
    echo "  ./scripts/setup-dots.sh --force --only <name>"
    exit 3
fi
exit 0
