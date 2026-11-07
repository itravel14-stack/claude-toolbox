#!/usr/bin/env bash
# Read-only audit of every project: GitHub repos (via `gh`) + local folders.
# Writes a Markdown inventory and a JSON status file; changes nothing anywhere.
#
#   bash pc/repo-audit.sh                       # scan default roots, write ~/dev-hq/
#   bash pc/repo-audit.sh C:/Dev D:/Work        # scan these roots (each child folder)
#   AUDIT_OUT=/some/dir bash pc/repo-audit.sh   # write elsewhere
#
# Default roots: C:/Dev, ~/Desktop, ~/Documents, ~/Projects, ~/src, ~/code, ~/dev.
# Needs: git; `gh auth login` for the GitHub side (skipped with a warning otherwise).
# Never prints file contents: secret findings are reported as paths only.
set -uo pipefail

OUT="${AUDIT_OUT:-$HOME/dev-hq}"
mkdir -p "$OUT"
MD="$OUT/INVENTORY.md"; JSON="$OUT/audit-status.json"
LARGE_MB="${LARGE_MB:-50}"
now="$(date '+%Y-%m-%d %H:%M')"

if [[ $# -gt 0 ]]; then roots=("$@"); else
  roots=(/c/Dev "$HOME/Desktop" "$HOME/Documents" "$HOME/Projects" "$HOME/src" "$HOME/code" "$HOME/dev")
fi
secret_re='(^|/)(\.env(\.[^/]*)?|[^/]*\.pem|[^/]*\.p12|[^/]*\.pfx|[^/]*\.key|id_rsa[^/]*|id_ed25519[^/]*|credentials(\.json)?|service[-_]account[^/]*\.json|[^/]*secret[^/]*)$'
safe_re='\.(example|sample|template|dist)$'

# ---------- GitHub side ----------
declare -A GH_VIS=() GH_URL=() GH_ARCH=() GH_PUSHED=() GH_SIZE=() GH_DESC=() GH_LANG=()
gh_ok=0
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  gh_ok=1
  while IFS=$'\t' read -r name vis arch pushed size url lang desc; do
    GH_VIS[$name]=$vis; GH_ARCH[$name]=$arch; GH_PUSHED[$name]=$pushed; GH_SIZE[$name]=$size
    GH_URL[$name]=$url; GH_LANG[$name]=$lang; GH_DESC[$name]=$desc
  done < <(gh repo list --limit 1000 --json nameWithOwner,visibility,isArchived,pushedAt,diskUsage,url,primaryLanguage,description \
            --jq '.[] | [.nameWithOwner, .visibility, .isArchived, .pushedAt, .diskUsage, .url, (.primaryLanguage.name // "-"), ((.description // "-") | gsub("[\t\n|]"; " "))] | @tsv')
else
  echo "warning: gh not authenticated — GitHub-only repos will not be listed (run: gh auth login)" >&2
fi

# ---------- local side ----------
rows=(); problems=(); seen=(); json_items=()
add_problem() { problems+=("- **$1** — $2"); }

scan_repo() {
  local dir="$1" name remote slug branch last dirty ahead behind sync backup upstream
  name="$(basename "$dir")"
  remote="$(git -C "$dir" config --get remote.origin.url 2>/dev/null || true)"   # raw URL (no insteadOf)
  slug="$(sed -nE 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?/?$#\1#p' <<<"$remote")"
  branch="$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo detached)"
  last="$(git -C "$dir" log -1 --format='%cd %h' --date=short 2>/dev/null || echo 'no commits')"
  dirty="$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  git -C "$dir" fetch --quiet --all --prune 2>/dev/null || true   # read-only for the working tree
  upstream="$(git -C "$dir" rev-parse --abbrev-ref '@{u}' 2>/dev/null || true)"
  if [[ -n "$upstream" ]]; then
    read -r behind ahead < <(git -C "$dir" rev-list --left-right --count "$upstream...HEAD" 2>/dev/null || echo "? ?")
  else ahead="no upstream"; behind="-"; fi
  # Commits on ANY local branch not on ANY remote branch:
  local unpushed_all; unpushed_all="$(git -C "$dir" log --branches --not --remotes --oneline 2>/dev/null | wc -l | tr -d ' ')"

  if [[ -z "$remote" ]]; then sync="NO REMOTE"; add_problem "$dir" "no git remote: exists only on this computer"
  elif [[ -z "$slug" ]]; then sync="non-GitHub remote"; add_problem "$dir" "remote is not GitHub ($remote)"
  elif [[ $gh_ok -eq 1 && -z "${GH_URL[$slug]+x}" ]]; then sync="REMOTE MISSING"; add_problem "$dir" "origin $slug not found in your GitHub account (renamed, deleted, or another owner)"
  elif [[ "$unpushed_all" != 0 ]]; then sync="UNPUSHED ($unpushed_all)"; add_problem "$dir" "$unpushed_all commit(s) on local branches not on GitHub"
  elif [[ "$dirty" != 0 ]]; then sync="UNCOMMITTED ($dirty)"; add_problem "$dir" "$dirty uncommitted change(s)"
  elif [[ "$behind" != "-" && "$behind" != 0 ]]; then sync="behind $behind"
  else sync="in sync"; fi

  # Tracked secret-looking files (paths only) and large tracked files.
  local secrets large ignored_secrets
  secrets="$(git -C "$dir" ls-files 2>/dev/null | grep -iE "$secret_re" | grep -viE "$safe_re" | head -5 | tr '\n' ' ')"
  [[ -n "$secrets" ]] && add_problem "$dir" "secret-looking files are TRACKED by git: $secrets(rotate the credentials; deleting the file does not remove it from history)"
  large="$(git -C "$dir" ls-files -z 2>/dev/null | (cd "$dir" && xargs -0 -r du -m 2>/dev/null) | awk -v m="$LARGE_MB" '$1>=m {print $2" ("$1"MB)"}' | head -5 | tr '\n' ' ')"
  [[ -n "$large" ]] && add_problem "$dir" "tracked files >= ${LARGE_MB}MB (move to Git LFS/external storage): $large"
  ignored_secrets="$(git -C "$dir" ls-files --others --ignored --exclude-standard 2>/dev/null | grep -iE "$secret_re" | grep -viE "$safe_re" | head -5 | tr '\n' ' ')"
  [[ -n "$ignored_secrets" ]] && add_problem "$dir" "ignored secret files exist only on this PC (correctly not on GitHub — keep a copy in your password manager): $ignored_secrets"
  [[ -f "$dir/.gitignore" ]] || add_problem "$dir" "no .gitignore"

  backup="GitHub"; [[ -z "$slug" ]] && backup="NONE"
  [[ -n "$slug" && -f "$BACKUP_STATUS" ]] && grep -q "\"$slug\"" "$BACKUP_STATUS" && backup="GitHub + encrypted bundle"
  local url="${remote:--}" vis="?"
  if [[ -n "$slug" && -n "${GH_URL[$slug]+x}" ]]; then url="${GH_URL[$slug]}"; vis="${GH_VIS[$slug]}"; fi
  rows+=("| ${slug:-$name} | $url | $vis | \`$dir\` | $branch | $last | $dirty | $ahead | $sync | $backup |")
  json_items+=("{\"repo\":\"${slug:-$name}\",\"dir\":\"$dir\",\"sync\":\"$sync\",\"dirty\":$dirty,\"unpushed\":$unpushed_all}")
  [[ -n "$slug" ]] && seen+=("$slug")
}

BACKUP_STATUS="${BACKUP_HOME:-$HOME/dev-backups}/last-backup.json"
nogit=()
for root in "${roots[@]}"; do
  [[ -d "$root" ]] || continue
  for dir in "$root"/*/; do
    dir="${dir%/}"; [[ -d "$dir" ]] || continue
    case "$(basename "$dir")" in node_modules|.*|'$RECYCLE.BIN') continue ;; esac
    if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 && [[ -z "$(git -C "$dir" rev-parse --show-cdup)" ]]; then
      scan_repo "$dir"
    elif find "$dir" -maxdepth 2 \( -name package.json -o -name pyproject.toml -o -name requirements.txt -o -name '*.py' -o -name '*.html' -o -name '*.ts' -o -name '*.js' -o -name Cargo.toml -o -name go.mod \) -print -quit 2>/dev/null | grep -q .; then
      nogit+=("$dir")
    fi
  done
done

# GitHub repos with no local clone
noclone=()
if [[ $gh_ok -eq 1 ]]; then
  for slug in "${!GH_URL[@]}"; do
    printf '%s\n' "${seen[@]:-}" | grep -qxF "$slug" || noclone+=("$slug")
  done
fi

{
  echo "# Project inventory"
  echo
  echo "Generated $now by \`claude-toolbox/pc/repo-audit.sh\` (read-only). No credentials are recorded here."
  echo
  echo "## Problems needing attention (${#problems[@]})"
  echo
  if [[ ${#problems[@]} -eq 0 ]]; then echo "None."; else printf '%s\n' "${problems[@]}"; fi
  if [[ ${#nogit[@]} -gt 0 ]]; then
    echo; echo "## Code folders NOT under git (exist only on this computer) (${#nogit[@]})"; echo
    echo "Ask Claude to create a **private** repo for each one you want kept (nothing is created without your approval)."
    echo; printf -- '- `%s`\n' "${nogit[@]}"
  fi
  echo; echo "## Local repositories (${#rows[@]})"; echo
  echo "| Repository | GitHub URL | Visibility | Local folder | Branch | Last commit | Uncommitted | Unpushed (vs upstream) | Sync status | Backup |"
  echo "|---|---|---|---|---|---|---|---|---|---|"
  [[ ${#rows[@]} -gt 0 ]] && printf '%s\n' "${rows[@]}"
  if [[ $gh_ok -eq 1 ]]; then
    echo; echo "## All GitHub repositories (${#GH_URL[@]})"; echo
    echo "| Repository | Visibility | Archived | Last push | Size (MB) | Language | Local clone | Description |"
    echo "|---|---|---|---|---|---|---|---|"
    for slug in $(printf '%s\n' "${!GH_URL[@]}" | sort -f); do
      local_clone="yes"; printf '%s\n' "${noclone[@]:-}" | grep -qxF "$slug" && local_clone="**no** (cloud only)"
      size_mb=$(( ${GH_SIZE[$slug]:-0} / 1024 ))
      flag=""; (( size_mb >= 1024 )) && flag=" ⚠"
      echo "| [$slug](${GH_URL[$slug]}) | ${GH_VIS[$slug]} | ${GH_ARCH[$slug]} | ${GH_PUSHED[$slug]%%T*} | ${size_mb}${flag} | ${GH_LANG[$slug]} | $local_clone | ${GH_DESC[$slug]} |"
    done
  fi
} > "$MD"

printf '{"generated":"%s","problems":%d,"not_in_git":%d,"repos":[%s]}\n' "$now" "${#problems[@]}" "${#nogit[@]}" "$(IFS=,; echo "${json_items[*]:-}")" > "$JSON"
echo "inventory: $MD"
echo "problems:  ${#problems[@]}   folders not in git: ${#nogit[@]}   local repos: ${#rows[@]}   GitHub repos: ${#GH_URL[@]}"
