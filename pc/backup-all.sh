#!/usr/bin/env bash
# Secondary backup of EVERY GitHub repo (all branches, tags, full history, LFS objects),
# independent of GitHub. Read-only toward GitHub and your working folders.
#
#   bash pc/backup-all.sh                    # mirror + bundle + encrypt every repo
#   bash pc/backup-all.sh --openmontage      # also archive OpenMontage productions (no renders)
#   bash pc/backup-all.sh --openmontage --with-renders
#   bash pc/backup-all.sh --verify-restore   # after backing up, restore one repo into a temp dir and compare
#
# Layout under $BACKUP_HOME (default ~/dev-backups):
#   mirrors/<owner>/<repo>.git          bare mirror, updated incrementally (fast)
#   archives/YYYY-MM-DD/<owner>__<repo>.bundle.gpg   encrypted git bundle (+ .sha256)
#   archives/YYYY-MM-DD/MANIFEST.tsv    repo, refs, head, bundle sha256
#   last-backup.json                    status read by repo-audit.sh / health-check.sh
#
# Encryption: gpg --symmetric AES256 with the passphrase in $BACKUP_PASSFILE
# (default ~/.config/dev-backup/passphrase, chmod 600). KEEP A COPY OF THE PASSPHRASE IN
# YOUR PASSWORD MANAGER — without it the archives cannot be restored.
# Off-site copy: set BACKUP_RCLONE_REMOTE (e.g. "b2:my-bucket/dev-backups" or
# "gdrive:dev-backups") and install rclone; encrypted archives are copied there.
#
# Sources: every repo `gh repo list` returns (needs `gh auth login`), or BACKUP_REPOS
# (space-separated clone URLs) to back up specific repos.
set -uo pipefail

BACKUP_HOME="${BACKUP_HOME:-$HOME/dev-backups}"
PASSFILE="${BACKUP_PASSFILE:-$HOME/.config/dev-backup/passphrase}"
KEEP="${BACKUP_KEEP:-14}"           # dated archive folders to keep locally
OM_PROJECTS="${OPENMONTAGE_PROJECTS_DIR:-$HOME/tools/openmontage/projects}"
do_om=0; with_renders=0; verify=0
for a in "$@"; do case "$a" in
  --openmontage) do_om=1 ;; --with-renders) with_renders=1 ;; --verify-restore) verify=1 ;;
  *) echo "unknown option $a"; exit 2 ;; esac; done

day="$(date +%F)"; ARCH="$BACKUP_HOME/archives/$day"
mkdir -p "$BACKUP_HOME/mirrors" "$ARCH"
umask 077

if [[ ! -s "$PASSFILE" ]]; then
  mkdir -p "$(dirname "$PASSFILE")"
  head -c 32 /dev/urandom | base64 | tr -d '\n=' > "$PASSFILE"; chmod 600 "$PASSFILE"
  echo "created backup passphrase: $PASSFILE"
  echo "  >>> copy it into your password manager NOW (cat it once, privately). Without it, archives are unrecoverable."
fi
encrypt() { gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-file "$PASSFILE" --symmetric --cipher-algo AES256 -o "$2" "$1"; }
decrypt() { gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-file "$PASSFILE" -d -o "$2" "$1"; }

if [[ -n "${BACKUP_REPOS:-}" ]]; then
  read -r -a urls <<<"$BACKUP_REPOS"
else
  command -v gh >/dev/null && gh auth status >/dev/null 2>&1 || { echo "gh is not authenticated: run gh auth login (or set BACKUP_REPOS)"; exit 1; }
  mapfile -t urls < <(gh repo list --limit 1000 --json url --jq '.[].url + ".git"')
  # gh's credential helper lets plain git clone private repos over HTTPS.
  gh auth setup-git >/dev/null 2>&1 || true
fi

ok=(); failed=(); printf 'repo\trefs\thead\tbundle_sha256\n' > "$ARCH/MANIFEST.tsv"
for url in "${urls[@]}"; do
  slug="$(sed -nE 's#.*[:/]([^/]+/[^/]+)$#\1#p' <<<"${url%.git}")"; [[ -n "$slug" ]] || slug="$(basename "${url%.git}")"
  mirror="$BACKUP_HOME/mirrors/$slug.git"; flat="${slug//\//__}"
  echo "== $slug"
  if [[ -d "$mirror" ]]; then
    git -C "$mirror" remote update --prune >/dev/null 2>&1 || { echo "  FAILED: fetch"; failed+=("$slug"); continue; }
  else
    mkdir -p "$(dirname "$mirror")"
    git clone --quiet --mirror "$url" "$mirror" 2>/dev/null || { echo "  FAILED: clone"; failed+=("$slug"); continue; }
  fi
  if git -C "$mirror" lfs ls-files --all >/dev/null 2>&1 && [[ -n "$(git -C "$mirror" lfs ls-files --all 2>/dev/null)" ]]; then
    git -C "$mirror" lfs fetch --all --quiet 2>/dev/null && echo "  lfs: objects fetched"
  fi
  refs="$(git -C "$mirror" for-each-ref | wc -l | tr -d ' ')"
  if [[ "$refs" == 0 ]]; then echo "  empty repo (nothing to bundle)"; ok+=("$slug"); printf '%s\t0\t-\t-\n' "$slug" >> "$ARCH/MANIFEST.tsv"; continue; fi
  tmp="$ARCH/$flat.bundle"
  git -C "$mirror" bundle create --quiet "$tmp" --all 2>/dev/null && git bundle verify --quiet "$tmp" >/dev/null 2>&1 \
    || { echo "  FAILED: bundle/verify"; rm -f "$tmp"; failed+=("$slug"); continue; }
  # LFS objects are not inside bundles: archive them next to it when present.
  if [[ -d "$mirror/lfs/objects" ]]; then tar -C "$mirror" -cf "$ARCH/$flat.lfs.tar" lfs/objects && encrypt "$ARCH/$flat.lfs.tar" "$ARCH/$flat.lfs.tar.gpg" && rm -f "$ARCH/$flat.lfs.tar"; fi
  encrypt "$tmp" "$tmp.gpg" || { echo "  FAILED: encrypt"; rm -f "$tmp"; failed+=("$slug"); continue; }
  rm -f "$tmp"
  sum="$(sha256sum "$tmp.gpg" | cut -d' ' -f1)"; echo "$sum  $flat.bundle.gpg" > "$tmp.gpg.sha256"
  printf '%s\t%s\t%s\t%s\n' "$slug" "$refs" "$(git -C "$mirror" rev-parse --short HEAD 2>/dev/null)" "$sum" >> "$ARCH/MANIFEST.tsv"
  echo "  ok: $refs refs -> $(du -h "$tmp.gpg" | cut -f1)"; ok+=("$slug")
done

if [[ $do_om -eq 1 && -d "$OM_PROJECTS" ]]; then
  echo "== OpenMontage productions ($OM_PROJECTS)"
  ex=(); [[ $with_renders -eq 0 ]] && ex=(--exclude='*.mp4' --exclude='*.mov' --exclude='*.webm' --exclude='*.wav' --exclude='*.mp3' --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='corpus')
  tar -C "$(dirname "$OM_PROJECTS")" "${ex[@]}" -cf "$ARCH/openmontage-projects.tar" "$(basename "$OM_PROJECTS")" \
    && encrypt "$ARCH/openmontage-projects.tar" "$ARCH/openmontage-projects.tar.gpg" && rm -f "$ARCH/openmontage-projects.tar" \
    && echo "  ok: $(du -h "$ARCH/openmontage-projects.tar.gpg" | cut -f1) ($([[ $with_renders -eq 1 ]] && echo with || echo without) media)" \
    || failed+=("openmontage-projects")
fi

verified="not run"
if [[ $verify -eq 1 && ${#ok[@]} -gt 0 ]]; then
  pick="$(awk -F'\t' 'NR>1 && $2>0 {print $1; exit}' "$ARCH/MANIFEST.tsv")"
  if [[ -n "$pick" ]]; then
    t="$(mktemp -d)"; f="${pick//\//__}"
    decrypt "$ARCH/$f.bundle.gpg" "$t/r.bundle" && git clone --quiet --mirror "$t/r.bundle" "$t/restored.git" 2>/dev/null
    a="$(git -C "$BACKUP_HOME/mirrors/$pick.git" for-each-ref --format='%(objectname) %(refname)' refs/heads refs/tags | sort)"
    b="$(git -C "$t/restored.git" for-each-ref --format='%(objectname) %(refname)' refs/heads refs/tags | sort)"
    if [[ -n "$a" && "$a" == "$b" ]] && git -C "$t/restored.git" fsck --no-progress >/dev/null 2>&1; then
      verified="ok: $pick restored from encrypted bundle, all branches/tags identical, fsck clean"
    else verified="FAILED for $pick"; failed+=("restore-test:$pick"); fi
    rm -rf "$t"
  fi
  echo "restore test: $verified"
fi

if [[ -n "${BACKUP_RCLONE_REMOTE:-}" ]]; then
  if command -v rclone >/dev/null && rclone copy "$ARCH" "$BACKUP_RCLONE_REMOTE/$day" --exclude '*.bundle' 2>&1 | tail -2; then
    rclone check "$ARCH" "$BACKUP_RCLONE_REMOTE/$day" --one-way --exclude '*.bundle' >/dev/null 2>&1 && offsite="ok: $BACKUP_RCLONE_REMOTE/$day" || { offsite="FAILED check"; failed+=("offsite"); }
  else offsite="FAILED (rclone missing or copy failed)"; failed+=("offsite"); fi
else offsite="not configured"; fi

# Retention: keep the newest $KEEP dated folders.
ls -1d "$BACKUP_HOME"/archives/????-??-?? 2>/dev/null | sort | head -n -"$KEEP" | xargs -r rm -rf

repos_json="$(printf '"%s",' "${ok[@]:-}")"; failed_json="$(printf '"%s",' "${failed[@]:-}")"
printf '{"date":"%s","archive":"%s","ok_count":%d,"failed_count":%d,"ok":[%s],"failed":[%s],"restore_test":"%s","offsite":"%s","size":"%s"}\n' \
  "$(date '+%F %T')" "$ARCH" "${#ok[@]}" "${#failed[@]}" "${repos_json%,}" "${failed_json%,}" "$verified" "$offsite" "$(du -sh "$BACKUP_HOME" | cut -f1)" \
  | sed 's/\[""\]/[]/g' > "$BACKUP_HOME/last-backup.json"
echo
echo "backed up: ${#ok[@]}   failed: ${#failed[@]} ${failed[*]:-}   off-site: $offsite"
echo "status: $BACKUP_HOME/last-backup.json"
[[ ${#failed[@]} -eq 0 ]]
