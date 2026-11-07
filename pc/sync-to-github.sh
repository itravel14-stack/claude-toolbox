#!/usr/bin/env bash
# Push every local project on this PC to GitHub so cloud sessions can reach it.
# Run in Git Bash:  bash ~/tools/claude-toolbox/pc/sync-to-github.sh [folders...]
# Default folders: C:/Dev/*, Desktop/*.
#
# Safe by design:
#  - never changes your checked-out branch, index, or files
#  - uncommitted work (incl. new files, minus .gitignore) is pushed as a snapshot
#    commit to branch  cloud-sync/<your-branch>  (merge it in a cloud session or locally)
#  - committed-but-unpushed branches are pushed as-is (no force)
#  - snapshots containing secret-looking files (.env, *.pem, *key*, *secret*) or key-like
#    content (sk-..., AKIA..., ghp_..., private keys), or files >95MB, are skipped
#  - folders that aren't git repos or have no GitHub remote are only listed
set -uo pipefail

if [[ $# -gt 0 ]]; then roots=("$@"); else
  roots=(/c/Dev/*/ "$HOME"/Desktop/*/)
fi

synced=(); skipped=(); nogit=()
content_re='(sk-(ant|proj|or-v1)-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|sk_live_[0-9a-zA-Z]{20,}|-----BEGIN ([A-Z]+ )?PRIVATE KEY-----)'
secret_re='(^|/)(\.env(\..*)?|.*\.pem|.*\.key|.*secret.*|.*api[-_]?keys?.*|id_rsa.*)$'

for dir in "${roots[@]}"; do
  dir="${dir%/}"; [[ -d "$dir" ]] || continue
  name="$(basename "$dir")"
  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then nogit+=("$dir (not a git repo)"); continue; fi
  [[ -z "$(git -C "$dir" rev-parse --show-cdup)" ]] || continue   # only repo roots
  remote="$(git -C "$dir" config --get remote.origin.url 2>/dev/null || true)"
  [[ "$remote" == *github.com* ]] || { nogit+=("$dir (no GitHub remote)"); continue; }

  echo "== $name"
  git -C "$dir" -c push.negotiate=false push --quiet origin --all 2>&1 | sed 's/^/  /' || true
  git -C "$dir" -c push.negotiate=false push --quiet origin --tags 2>&1 | sed 's/^/  /' || true

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
  # Content scan of the snapshot diff: refuse if it adds anything that looks like a live key.
  leak="$(git -C "$dir" diff "HEAD" "$tree" 2>/dev/null | grep -E '^\+' | grep -cE "$content_re" || true)"
  if [[ "$leak" != 0 ]]; then
    echo "  SKIPPED snapshot: $leak added line(s) look like API keys/tokens/private keys (not shown)"
    echo "  move them to .env (git-ignored), then re-run"; skipped+=("$name"); continue
  fi
  big="$(git -C "$dir" diff --name-only "HEAD" "$tree" 2>/dev/null | while read -r f; do [[ -f "$dir/$f" ]] && s=$(du -m "$dir/$f" | cut -f1) && (( s >= 95 )) && echo "$f (${s}MB)"; done)"
  if [[ -n "$big" ]]; then
    echo "  SKIPPED snapshot: files over GitHub's 100MB limit:"; echo "$big" | sed 's/^/    /'
    echo "  track them with Git LFS or move them to external storage (docs/MEDIA-POLICY.md)"; skipped+=("$name"); continue
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
