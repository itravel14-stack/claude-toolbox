#!/usr/bin/env bash
# Push every local project on this PC to GitHub so cloud sessions can reach it.
# Run in Git Bash:  bash ~/tools/claude-toolbox/pc/sync-to-github.sh [folders...]
# Default folders: C:/Dev/*, Desktop/*, Desktop/ObsidianVault.
#
# Safe by design:
#  - never changes your checked-out branch, index, or files
#  - uncommitted work (incl. new files, minus .gitignore) is pushed as a snapshot
#    commit to branch  cloud-sync/<your-branch>  (merge it in a cloud session or locally)
#  - committed-but-unpushed branches are pushed as-is (no force)
#  - snapshots containing secret-looking files (.env, *.pem, *key*, *secret*) are skipped
#  - folders that aren't git repos or have no GitHub remote are only listed
set -uo pipefail

if [[ $# -gt 0 ]]; then roots=("$@"); else
  roots=(/c/Dev/*/ "$HOME"/Desktop/*/)
fi

synced=(); skipped=(); nogit=()
secret_re='(^|/)(\.env(\..*)?|.*\.pem|.*\.key|.*secret.*|.*api[-_]?keys?.*|id_rsa.*)$'

for dir in "${roots[@]}"; do
  dir="${dir%/}"; [[ -d "$dir" ]] || continue
  name="$(basename "$dir")"
  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then nogit+=("$dir (not a git repo)"); continue; fi
  [[ -z "$(git -C "$dir" rev-parse --show-cdup)" ]] || continue   # only repo roots
  remote="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
  [[ "$remote" == *github.com* ]] || { nogit+=("$dir (no GitHub remote)"); continue; }

  echo "== $name"
  git -C "$dir" -c push.negotiate=false push --quiet origin --all 2>&1 | sed 's/^/  /' || true

  branch="$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo detached)"
  # Snapshot via a throwaway index: your real index and working tree are untouched.
  tmp_index="$(mktemp -u)"
  cp "$(git -C "$dir" rev-parse --absolute-git-dir)/index" "$tmp_index" 2>/dev/null || true
  tree="$(GIT_INDEX_FILE="$tmp_index" git -C "$dir" add -A && GIT_INDEX_FILE="$tmp_index" git -C "$dir" write-tree)"
  rm -f "$tmp_index"
  [[ -n "$tree" ]] || { echo "  SKIPPED: could not snapshot working tree"; skipped+=("$name"); continue; }
  if [[ "$tree" == "$(git -C "$dir" rev-parse 'HEAD^{tree}' 2>/dev/null)" ]]; then
    echo "  clean"; synced+=("$name"); continue
  fi
  bad="$(git -C "$dir" diff --name-only "HEAD" "$tree" 2>/dev/null | grep -iE "$secret_re" || true)"
  if [[ -n "$bad" ]]; then
    echo "  SKIPPED snapshot: secret-looking files would be pushed:"; echo "$bad" | sed 's/^/    /'
    echo "  add them to .gitignore, then re-run"; skipped+=("$name"); continue
  fi
  commit="$(git -C "$dir" commit-tree "$tree" -p HEAD -m "cloud-sync snapshot of $branch $(date '+%Y-%m-%d %H:%M')")"
  [[ -n "$commit" ]] || { echo "  SKIPPED: snapshot commit failed"; skipped+=("$name"); continue; }
  # --force only ever rewrites this script's own cloud-sync/* snapshot branch.
  if git -C "$dir" -c push.negotiate=false push --quiet --force origin "$commit:refs/heads/cloud-sync/$branch"; then
    echo "  uncommitted work -> branch cloud-sync/$branch"; synced+=("$name")
  else skipped+=("$name"); fi
done

echo
echo "synced:  ${#synced[@]}  ${synced[*]:-}"
echo "skipped: ${#skipped[@]}  ${skipped[*]:-}"
if [[ ${#nogit[@]} -gt 0 ]]; then
  echo "not on GitHub yet (tell Claude this list and it will create the repos):"
  printf '  %s\n' "${nogit[@]}"
fi
