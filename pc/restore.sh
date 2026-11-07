#!/usr/bin/env bash
# Restore projects onto a new/rebuilt computer or into a scratch folder. Never touches an
# existing folder: refuses if the destination exists.
#
#   bash pc/restore.sh github <owner/repo> [dest]          # clone from GitHub, all branches
#   bash pc/restore.sh github-all [root]                    # clone every repo you own into root (default ~/Dev)
#   bash pc/restore.sh bundle <archive.bundle.gpg> [dest]  # restore from an encrypted backup bundle
#   bash pc/restore.sh list                                 # list dated backup archives
set -euo pipefail
BACKUP_HOME="${BACKUP_HOME:-$HOME/dev-backups}"
PASSFILE="${BACKUP_PASSFILE:-$HOME/.config/dev-backup/passphrase}"
mode="${1:-}"; shift || true
fresh() { [[ ! -e "$1" ]] || { echo "refusing: $1 already exists (choose another destination)"; exit 1; }; }
track_all() {  # create local branches for every remote branch, without changing the checkout
  git -C "$1" for-each-ref --format='%(refname:strip=3)' refs/remotes/origin | grep -vx HEAD | while read -r b; do
    git -C "$1" show-ref --quiet "refs/heads/$b" || git -C "$1" branch --quiet --track "$b" "origin/$b"; done
}
case "$mode" in
  github)
    repo="${1:?owner/repo}"; dest="${2:-$HOME/Dev/$(basename "$repo")}"; fresh "$dest"
    gh repo clone "$repo" "$dest" -- --quiet && track_all "$dest"
    git -C "$dest" lfs pull 2>/dev/null || true
    echo "restored $repo -> $dest ($(git -C "$dest" branch | wc -l | tr -d ' ') branches)" ;;
  github-all)
    root="${1:-$HOME/Dev}"; mkdir -p "$root"
    gh repo list --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner' | while read -r r; do
      d="$root/$(basename "$r")"; [[ -e "$d" ]] && { echo "skip $r ($d exists)"; continue; }
      gh repo clone "$r" "$d" -- --quiet && track_all "$d" && echo "ok $r"; done ;;
  bundle)
    src="${1:?path to .bundle.gpg}"; name="$(basename "$src" .bundle.gpg)"; dest="${2:-$PWD/${name##*__}}"; fresh "$dest"
    [[ -f "$src.sha256" ]] && (cd "$(dirname "$src")" && sha256sum -c --quiet "$(basename "$src").sha256")
    t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
    gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$PASSFILE" -d -o "$t/r.bundle" "$src"
    git bundle verify --quiet "$t/r.bundle" >/dev/null 2>&1
    git clone --quiet "$t/r.bundle" "$dest" && track_all "$dest"
    lfs="${src%.bundle.gpg}.lfs.tar.gpg"
    if [[ -f "$lfs" ]]; then gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$PASSFILE" -d -o "$t/l.tar" "$lfs" && mkdir -p "$dest/.git" && tar -C "$dest/.git" -xf "$t/l.tar" && git -C "$dest" lfs checkout 2>/dev/null || true; fi
    echo "restored -> $dest. Its origin points at the bundle; reconnect GitHub with:"
    echo "  git -C \"$dest\" remote set-url origin https://github.com/<owner>/<repo>.git" ;;
  list) ls -1d "$BACKUP_HOME"/archives/*/ 2>/dev/null | while read -r d; do echo "$d  $(($(wc -l < "$d/MANIFEST.tsv")-1)) repos  $(du -sh "$d" | cut -f1)"; done ;;
  *) sed -n '2,9p' "$0"; exit 2 ;;
esac
