#!/usr/bin/env bash
# Schedule the protection jobs on this computer (idempotent; re-run to update).
#   daily 21:17   sync-to-github.sh   push branches + snapshot uncommitted work to cloud-sync/*
#   daily 21:47   health-check.sh     writes ~/dev-hq/HEALTH.md
#   Sunday 22:13  backup-all.sh       encrypted bundles of every repo + restore test
#   bash pc/install-schedule.sh            # install
#   bash pc/install-schedule.sh --remove   # remove
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
jobs=("DevSync|sync-to-github.sh|DAILY|21:17" "DevHealth|health-check.sh|DAILY|21:47" "DevBackup|backup-all.sh --openmontage --verify-restore|WEEKLY /D SUN|22:13")
if command -v schtasks.exe >/dev/null 2>&1; then     # Windows (Git Bash)
  bash_exe="$(cygpath -w "$(command -v bash)")"; here_w="$(cygpath -m "$HERE")"; logs="$(cygpath -m "$HOME")/dev-hq"
  mkdir -p "$HOME/dev-hq"
  for j in "${jobs[@]}"; do IFS='|' read -r name cmd sched time <<<"$j"
    schtasks.exe //Delete //TN "$name" //F >/dev/null 2>&1 || true
    [[ "${1:-}" == --remove ]] && { echo "removed $name"; continue; }
    script="${cmd%% *}"; args=""; [[ "$cmd" == *" "* ]] && args="${cmd#* }"
    # shellcheck disable=SC2086
    schtasks.exe //Create //TN "$name" //SC ${sched%% *} $( [[ $sched == WEEKLY* ]] && echo "//D SUN" ) //ST "$time" //F \
      //TR "\"$bash_exe\" -lc \"bash '$here_w/$script' $args >> '$logs/$name.log' 2>&1\"" >/dev/null && echo "scheduled $name ($sched $time)"
  done
else                                                 # macOS / Linux: crontab
  command -v crontab >/dev/null || { echo "crontab not found: install cron (Linux) or use launchd (macOS)"; exit 1; }
  tag="# claude-toolbox"; cur="$(crontab -l 2>/dev/null | grep -v "$tag" || true)"
  if [[ "${1:-}" == --remove ]]; then printf '%s\n' "$cur" | crontab -; echo "removed"; exit 0; fi
  mkdir -p "$HOME/dev-hq"; new="$cur"
  for j in "${jobs[@]}"; do IFS='|' read -r name cmd sched time <<<"$j"
    h="${time%%:*}"; m="${time##*:}"; dow="*"; [[ $sched == WEEKLY* ]] && dow=0
    script="${cmd%% *}"; args=""; [[ "$cmd" == *" "* ]] && args="${cmd#* }"
    new+=$'\n'"$m $h * * $dow bash '$HERE/$script' $args >> '$HOME/dev-hq/$name.log' 2>&1 $tag"
  done
  printf '%s\n' "$new" | sed '/^$/d' | crontab -; crontab -l | grep "$tag"
fi
