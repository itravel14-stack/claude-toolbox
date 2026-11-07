# Backup architecture and recovery

Three layers. GitHub is the primary cloud copy; the other two exist so GitHub is never the only one.

```
 your PC (C:/Dev/*, Desktop/*)            GitHub (private repos)              secondary copy
 ─────────────────────────────            ──────────────────────              ──────────────
 work in progress ── daily 21:17 ───────► every branch + tag                  ~/dev-backups/ (PC disk)
   sync-to-github.sh                       cloud-sync/<branch> snapshots ──►   encrypted git bundles
   (commits never touch your files;                                          weekly, restore-tested
    secrets/oversized files blocked)       repo-health.yml (Actions) ──────►  + rclone off-site (B2/Drive)
                                            daily audit → issue on problems     + optional Actions mirror
 health-check.sh daily 21:47 → ~/dev-hq/HEALTH.md (everything needing your attention)
```

| Layer | What | How often | Script |
|---|---|---|---|
| 1. Primary | All branches and tags pushed to GitHub; uncommitted work snapshotted to `cloud-sync/<branch>` (your checkout, index, and files are never changed) | daily | `pc/sync-to-github.sh` |
| 2. Secondary (local) | Mirror of every repo you own → `git bundle --all` → AES-256 gpg → `~/dev-backups/archives/<date>/`, 14 kept, one restored and compared each run. LFS objects archived alongside. OpenMontage productions archived (plans always, renders with `--with-renders`) | weekly (Sunday) | `pc/backup-all.sh --openmontage --verify-restore` |
| 3. Off-site | Same encrypted archives copied with `rclone` to cloud object storage (set `BACKUP_RCLONE_REMOTE`), and/or the GitHub Actions mirror | weekly / daily | `backup-all.sh`, `github-actions/repo-health.yml` |
| Monitor | Uncommitted/unpushed work, folders not in git, tracked secrets, files >50 MB, backup age/failures/restore test, off-site status, disk space, Dependabot alerts | daily | `pc/health-check.sh`, `repo-health.yml` |

Install the schedule once: `bash ~/tools/claude-toolbox/pc/install-schedule.sh` (Windows Task
Scheduler from Git Bash; cron on macOS/Linux).

## Why these choices

- **Snapshot branches, not auto-commits to your branch.** Automatic commits onto `main` would push
  half-finished or secret work. `cloud-sync/<branch>` is a review mechanism: the work is safe in
  the cloud, and you (or Claude) merge it deliberately. The sync refuses snapshots that contain
  `.env`/key/secret files, key-like content (`sk-…`, `AKIA…`, `ghp_…`, private keys), or files
  over GitHub's 100 MB limit, and says why.
- **Git bundles + gpg** keep full history, all branches and tags in one verifiable file per repo,
  restorable with plain `git clone`. Encryption keeps private code private on any storage.
- **Off-site storage — recommended: Backblaze B2** (~$6/TB-month, first 10 GB free, S3-compatible,
  rclone-native). Google Drive (15 GB free) also works via rclone. Your current repos total
  ≈1.3 GB on GitHub (Nov 2026), so bundles fit comfortably in either free tier at first.
- **GitHub Actions artifacts are not used for storage**: private-repo artifact storage on GitHub
  Free is 500 MB, smaller than your largest repo.

## Secrets

- Backup passphrase: `~/.config/dev-backup/passphrase` (created on first run, chmod 600).
  **Copy it into your password manager.** Without it the encrypted archives cannot be opened.
- `.env` files are correctly excluded from git, which also means they are **not** in any git
  backup. Keep every project's keys in a password manager (1Password/Bitwarden secure notes);
  `repo-audit.sh` lists ignored secret files that exist only on your PC.
- GitHub auth: `gh auth login` (browser OAuth, token in the OS credential store). The Actions
  watchdog uses a fine-grained, read-only PAT scoped to your repos.

## Recovery runbook

**New or replaced computer**
1. Install Git (with Git Bash on Windows), GitHub CLI, Node 18+, Python 3.10+, FFmpeg, Claude Code.
2. `gh auth login`
3. `git clone https://github.com/itravel14-stack/claude-toolbox.git ~/tools/claude-toolbox && bash ~/tools/claude-toolbox/bootstrap.sh`
4. `bash ~/tools/claude-toolbox/pc/restore.sh github-all C:/Dev` — every repo, every branch.
5. Restore keys from your password manager into each project's `.env` (and `~/tools/openmontage/.env`).
6. Per project: reinstall dependencies (`npm install`, `uv sync`/`pip install -r requirements.txt`).
7. `bash ~/tools/claude-toolbox/pc/install-schedule.sh`

**A project folder was deleted** — `bash pc/restore.sh github <owner/repo> C:/Dev/<name>`.
Uncommitted work from before the deletion is on the `cloud-sync/<branch>` branch (up to 24 h old):
`git checkout cloud-sync/main -- .` inside the restored folder, then commit.

**Important files were overwritten** — inside the repo: `git log -- <file>` then
`git restore --source=<commit> -- <file>`; for uncommitted work use `cloud-sync/<branch>`.

**A GitHub repository is corrupted, deleted, or history was force-pushed** —
`bash pc/restore.sh list`, pick a date, then
`bash pc/restore.sh bundle ~/dev-backups/archives/<date>/<owner>__<repo>.bundle.gpg /tmp/<repo>-restored`.
Inspect it, then push it to a **new** private repo (or back, after you decide — never force-push
without reviewing what it overwrites). If the PC is also gone, pull the archive from the off-site
remote first: `rclone copy <remote>/<date> ./restore-<date>`.

**OpenMontage productions** — `gpg -d ~/dev-backups/archives/<date>/openmontage-projects.tar.gpg | tar -x -C ~/tools/openmontage`.

Test a restore any time (never into a production folder):
`bash pc/backup-all.sh --verify-restore` restores one repo into a temp dir and compares every ref.
