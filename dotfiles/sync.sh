#!/usr/bin/env bash
# Symlink every file under dotfiles/ into the matching path in $HOME.
# Idempotent. Safe to re-run. Called manually for first-time bootstrap and
# automatically from .zshrc on shell startup.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$HOME/.cache/dotfiles-sync.manifest"

quiet=0
if [[ "${1:-}" == "--quiet" ]]; then
  quiet=1
fi

# Verbose state line (e.g. "Linked:", "Backed up:", "Removed orphan:").
# Suppressed entirely in --quiet mode.
log() {
  if (( quiet )); then
    return 0
  fi
  printf '%s\n' "$1"
}

# Always-emitted warning. Goes to stderr in quiet mode, stdout otherwise.
warn() {
  if (( quiet )); then
    printf '%s\n' "$1" >&2
  else
    printf '%s\n' "$1"
  fi
}

ok() {
  if (( quiet )); then
    return 0
  fi
  printf 'OK: %s\n' "$1"
}

is_excluded() {
  local rel="$1"
  case "$rel" in
    sync.sh|README.md|.DS_Store) return 0 ;;
    .git|.git/*) return 0 ;;
    *.bak.*) return 0 ;;
    */.DS_Store) return 0 ;;
  esac
  return 1
}

mkdir -p "$(dirname "$MANIFEST")"
manifest_new="$(mktemp "$MANIFEST.new.XXXXXX")"
trap 'rm -f "$manifest_new"' EXIT

status=0

while IFS= read -r -d '' src; do
  rel="${src#"$DOTFILES_DIR"/}"
  if is_excluded "$rel"; then
    continue
  fi

  dest="$HOME/$rel"
  dest_dir="$(dirname "$dest")"
  mkdir -p "$dest_dir"

  printf '%s\n' "$dest" >> "$manifest_new"

  if [[ -L "$dest" ]]; then
    current="$(readlink "$dest")"
    if [[ "$current" == "$src" ]]; then
      ok "$dest"
      continue
    fi
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    backup="$dest.bak.$(date +%Y%m%d%H%M%S).$$"
    if mv "$dest" "$backup"; then
      log "Backed up: $dest -> $backup"
    else
      warn "WARN: failed to back up $dest, skipping"
      status=1
      continue
    fi
  fi

  if ln -s "$src" "$dest"; then
    log "Linked: $dest -> $src"
  else
    warn "WARN: failed to link $dest"
    status=1
  fi
done < <(find "$DOTFILES_DIR" -type f -print0)

# Remove symlinks that the previous run created but this run no longer owns
# (i.e. the source dotfile was deleted or renamed). Only touch symlinks that
# still point into $DOTFILES_DIR; user-managed files at the same path are
# left alone.
if [[ -f "$MANIFEST" ]]; then
  while IFS= read -r oldpath; do
    [[ -z "$oldpath" ]] && continue
    if grep -qxF "$oldpath" "$manifest_new"; then
      continue
    fi
    if [[ -L "$oldpath" ]]; then
      target="$(readlink "$oldpath")"
      case "$target" in
        "$DOTFILES_DIR"/*)
          if rm "$oldpath"; then
            log "Removed orphan: $oldpath -> $target"
          else
            warn "WARN: failed to remove orphan $oldpath"
            status=1
          fi
          ;;
      esac
    fi
  done < "$MANIFEST"
fi

mv "$manifest_new" "$MANIFEST"

# Non-zero on any per-file failure so .zshrc auto-sync skips touching the stamp
# and retries on the next shell startup.
exit $status
