#!/usr/bin/env bash
# One report of everything that needs attention. Read-only. Run daily (install-schedule.sh).
#   bash pc/health-check.sh   -> ~/dev-hq/HEALTH.md, exit 1 if anything needs attention
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${AUDIT_OUT:-$HOME/dev-hq}"; BACKUP_HOME="${BACKUP_HOME:-$HOME/dev-backups}"
MAX_AGE_DAYS="${MAX_BACKUP_AGE_DAYS:-8}"; MIN_FREE_GB="${MIN_FREE_GB:-20}"
mkdir -p "$OUT"; issues=()

bash "$HERE/repo-audit.sh" "$@" >/dev/null 2>"$OUT/.audit.err" || issues+=("repo audit failed: $(tail -1 "$OUT/.audit.err")")
if [[ -f "$OUT/audit-status.json" ]]; then
  p="$(jq -r .problems "$OUT/audit-status.json" 2>/dev/null || echo '?')"; n="$(jq -r .not_in_git "$OUT/audit-status.json" 2>/dev/null || echo 0)"
  [[ "$p" != 0 ]] && issues+=("$p repository problem(s) — see INVENTORY.md")
  [[ "$n" != 0 ]] && issues+=("$n code folder(s) are not in git at all")
fi
grep -q 'gh not authenticated' "$OUT/.audit.err" 2>/dev/null && issues+=("GitHub CLI is not logged in (gh auth login)")

st="$BACKUP_HOME/last-backup.json"
if [[ ! -f "$st" ]]; then issues+=("no secondary backup has ever run (bash pc/backup-all.sh --verify-restore)")
else
  age=$(( ( $(date +%s) - $(date -r "$st" +%s) ) / 86400 ))
  (( age > MAX_AGE_DAYS )) && issues+=("last backup is $age days old")
  f="$(jq -r .failed_count "$st")"; [[ "$f" != 0 ]] && issues+=("last backup had $f failure(s): $(jq -r '.failed|join(", ")' "$st")")
  [[ "$(jq -r .restore_test "$st")" == ok* ]] || issues+=("last backup has no verified restore test")
  [[ "$(jq -r .offsite "$st")" == ok* ]] || issues+=("off-site copy: $(jq -r .offsite "$st")")
fi
free_gb="$(df -Pk "$BACKUP_HOME" 2>/dev/null | awk 'NR==2 {print int($4/1048576)}')"
[[ -n "$free_gb" ]] && (( free_gb < MIN_FREE_GB )) && issues+=("backup disk has only ${free_gb}GB free")

# Dependabot alerts (needs Dependabot alerts enabled per repo; repos without it are skipped).
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  while read -r r; do
    c="$(gh api "repos/$r/dependabot/alerts?state=open&per_page=100" --jq 'length' 2>/dev/null)" || continue
    [[ "$c" =~ ^[0-9]+$ && "$c" -gt 0 ]] && issues+=("$r: $c open Dependabot security alert(s)")
  done < <(gh repo list --limit 1000 --no-archived --json nameWithOwner --jq '.[].nameWithOwner')
fi

{ echo "# Dev health — $(date '+%F %H:%M')"; echo
  if [[ ${#issues[@]} -eq 0 ]]; then echo "All clear: repos in sync, backup fresh + restore-verified."; else printf -- '- %s\n' "${issues[@]}"; fi
  echo; echo "Details: INVENTORY.md · backup status: $st"; } > "$OUT/HEALTH.md"
cat "$OUT/HEALTH.md"
[[ ${#issues[@]} -eq 0 ]]
