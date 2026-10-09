#!/usr/bin/env bash
#
# Restore dotfiles from a backup taken by setup-dots.sh --force.
#
# This script NEVER deletes a backup. Reverting takes a fresh backup of the
# current state first, so a revert is itself revertible.
#
# Legacy <name>_old directories left behind by the pre-2026 setup script are
# also listed, because they are the only copy of some much older configs.

set -uo pipefail

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
STATE_DIR="$HOME/.local/share/dev-setup"
MANIFEST="$STATE_DIR/manifest"

usage() {
    cat <<USAGE
usage: revert-dots.sh --list
       revert-dots.sh --show <backup>
       revert-dots.sh --restore <backup> [--only P]

  --list              every available backup, newest first
  --show <backup>     what a backup contains, and how it differs from now
  --restore <backup>  copy that backup's files back over the live ones
  --only P            restrict a restore to items whose path contains P

<backup> is either a full path or just the timestamp (e.g. 20261007-165449).
Nothing is ever deleted; a restore backs up the current state first.
USAGE
}

resolve_backup() {
    local b="$1"
    [ -d "$b" ] && { echo "$b"; return 0; }
    [ -d "$STATE_DIR/$b" ] && { echo "$STATE_DIR/$b"; return 0; }
    [ -d "$STATE_DIR/backup-$b" ] && { echo "$STATE_DIR/backup-$b"; return 0; }
    return 1
}

MODE=""; TARGET=""; ONLY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) MODE=list ;;
        --show) MODE=show; shift; TARGET="${1:-}" ;;
        --restore) MODE=restore; shift; TARGET="${1:-}" ;;
        --only) shift; ONLY="${1:-}" ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

[ -n "$MODE" ] || { usage >&2; exit 2; }

if [ "$MODE" = list ]; then
    echo "dev-setup backups (newest first):"
    found=0
    for d in $(ls -dt "$STATE_DIR"/backup-* 2>/dev/null); do
        found=1
        n=$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')
        printf '  %-28s %2s file(s)   %s\n' "$(basename "$d")" "$n" \
            "$(find "$d" -type f 2>/dev/null | sed "s|$d/||" | tr '\n' ' ')"
    done
    [ "$found" -eq 0 ] && echo "  (none yet -- they are created by setup-dots.sh --force)"
    echo
    echo "legacy backups from the old setup script (never auto-removed):"
    c=$(ls -d "$HOME"/.config/*_old* 2>/dev/null | wc -l | tr -d ' ')
    [ "$c" -gt 0 ] && printf '  %s  ~/.config/*_old*  (%s)\n' "$c dirs" \
        "$(du -shc "$HOME"/.config/*_old* 2>/dev/null | tail -1 | cut -f1)"
    for p in "$HOME"/config_old "$HOME"/.tmux.conf_old "$HOME"/.fcs-command_old "$HOME"/.fcs-languages_old; do
        [ -e "$p" ] && printf '  %s\n' "${p/#$HOME/~}"
    done
    echo
    echo "git revert point: $(git -C "$parent_path/.." describe --tags --exact-match pre-tmux-persistence 2>/dev/null || echo 'tag pre-tmux-persistence')"
    exit 0
fi

[ -n "$TARGET" ] || { echo "need a backup name; see --list" >&2; exit 2; }
BK=$(resolve_backup "$TARGET") || { echo "no such backup: $TARGET" >&2; exit 1; }

if [ "$MODE" = show ]; then
    echo "backup: ${BK/#$HOME/~}"
    find "$BK" -type f 2>/dev/null | while IFS= read -r f; do
        rel="${f#$BK/}"
        live="$HOME/$rel"
        if [ ! -e "$live" ]; then st="live file MISSING"
        elif cmp -s "$f" "$live"; then st="identical to live"
        else st="DIFFERS from live"; fi
        printf '  %-46s %s\n' "~/$rel" "$st"
    done
    exit 0
fi

# ── restore ──────────────────────────────────────────────────────────────────
echo "restoring from ${BK/#$HOME/~}"
SAFETY="$STATE_DIR/backup-$(date +%Y%m%d-%H%M%S)-prerevert"
n=0
while IFS= read -r f; do
    rel="${f#$BK/}"
    [ -n "$ONLY" ] && case "$rel" in *"$ONLY"*) ;; *) continue ;; esac
    live="$HOME/$rel"
    # back up the current state so the revert is itself revertible
    if [ -e "$live" ]; then
        mkdir -p "$SAFETY/$(dirname "$rel")"
        cp -R "$live" "$SAFETY/$rel"
    fi
    mkdir -p "$(dirname "$live")"
    rm -rf "$live"
    cp -R "$f" "$live"
    # drop the manifest entry so setup-dots re-evaluates this item honestly
    if [ -f "$MANIFEST" ]; then
        tmp=$(mktemp)
        awk -F'\t' -v k="~/$rel" '$1!=k' "$MANIFEST" > "$tmp" && mv "$tmp" "$MANIFEST"
    fi
    printf '  restored  ~/%s\n' "$rel"
    n=$((n+1))
done < <(find "$BK" -type f 2>/dev/null)

echo
echo "restored $n file(s)"
[ -d "$SAFETY" ] && echo "pre-revert state saved to ${SAFETY/#$HOME/~}"
echo "reload with: tmux source-file ~/.tmux.conf ; exec zsh -l"
