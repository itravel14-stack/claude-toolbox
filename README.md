# claude-toolbox

Install a GitHub tool once; every repo and every Claude Code session can use it.
No repo ever vendors a tool, its dependencies, or its keys.

```
claude-toolbox/                    (this repo, cloned to ~/tools/claude-toolbox)
  bootstrap.sh                     installs every tool below (idempotent)
  add-tool.sh                      scaffolds a new tool
  setup-script.sh                  paste into the cloud environment's Setup script
  tools/<name>/
    tool.sh                        REPO=<github url> + install() steps
    PIN                            pinned commit (reproducible installs)
    bin/*                          commands -> ~/.local/bin
    skill/SKILL.md                 Claude Code skill -> ~/.claude/skills/<name>
```

Installed layout: source in `~/tools/<name>`, commands on PATH, skills global.
Claude Code loads `~/.claude/skills/*` in every project, so every repo sees every tool.

## Your PC (once)

Git Bash on Windows, or any bash on macOS/Linux/WSL:
```bash
git clone https://github.com/itravel14-stack/claude-toolbox.git ~/tools/claude-toolbox
bash ~/tools/claude-toolbox/bootstrap.sh
```
Restart Claude Code. Re-run `bootstrap.sh` after pulling the toolbox to pick up new tools.

## Cloud sessions (claude.ai/code), every repo

Cloud containers start empty, so the environment's **Setup script** installs the toolbox
for every session regardless of which repo is open: claude.ai/code → environment menu →
Edit → Setup script → paste `setup-script.sh`. Put tool API keys in the same
environment's environment variables (e.g. `VIMAX_LLM_API_KEY`), never in a repo.

New sessions start from a cached snapshot and skip the script until its text changes
(or ~7 days pass). After adding or updating a tool, bump `toolbox-rev` in `setup-script.sh`
and re-paste it, or new sessions keep the old toolbox.

## Move everything on the PC to GitHub (so cloud sessions can reach it)

```bash
bash ~/tools/claude-toolbox/pc/sync-to-github.sh            # scans C:/Dev/* and Desktop/*
bash ~/tools/claude-toolbox/pc/sync-to-github.sh "C:/path/a" "C:/path/b"   # or specific folders
```
Pushes every branch, and snapshots uncommitted work to a `cloud-sync/<branch>` branch
without touching your local files. Skips snapshots containing `.env`/key/secret files, key-like content, or files >95 MB.
Prints folders that aren't on GitHub yet — give Claude that list to create the repos.

## Protect every project (GitHub + encrypted secondary backup)

Full design and recovery runbook: [docs/BACKUP-ARCHITECTURE.md](docs/BACKUP-ARCHITECTURE.md).
Media/large files: [docs/MEDIA-POLICY.md](docs/MEDIA-POLICY.md). On the PC (Git Bash, after `gh auth login`):

```bash
bash ~/tools/claude-toolbox/pc/repo-audit.sh                         # read-only inventory -> ~/dev-hq/INVENTORY.md
bash ~/tools/claude-toolbox/pc/backup-all.sh --openmontage --verify-restore   # encrypted bundles of every repo
bash ~/tools/claude-toolbox/pc/install-schedule.sh                   # daily sync + health, weekly backup
bash ~/tools/claude-toolbox/pc/health-check.sh                       # what needs attention -> ~/dev-hq/HEALTH.md
bash ~/tools/claude-toolbox/pc/restore.sh github-all C:/Dev          # new computer: restore everything
```
Cloud watchdog (runs when the PC is off): copy [github-actions/repo-health.yml](github-actions/repo-health.yml)
into a **private** repo's `.github/workflows/` and add the `AUDIT_TOKEN` secret (instructions in the file).

## Add a tool

```bash
cd ~/tools/claude-toolbox
bash add-tool.sh <name> https://github.com/<owner>/<repo>.git   # pins current HEAD
# edit tools/<name>/tool.sh   -> the project's documented install steps
# edit tools/<name>/skill/SKILL.md -> when to use it + verified commands
# optional: tools/<name>/bin/<cmd> wrapper that cd's into ~/tools/<name>
bash bootstrap.sh <name>
git add tools/<name> && git commit -m "Add <name>" && git push
```
Or ask Claude Code in any repo: "add <github url> to my toolbox".

## Update a tool

`git -C ~/tools/<name> fetch && git -C ~/tools/<name> log --oneline HEAD..origin/HEAD`,
review, then merge, re-run `bootstrap.sh <name>`, and write the new commit to `tools/<name>/PIN`.
Nothing auto-updates. Existing checkouts and local configs are never overwritten.

## Tools

| Tool | Source | Command | Docs |
|---|---|---|---|
| vimax | HKUDS/ViMax | `vimax` | [tools/vimax/README.md](tools/vimax/README.md) |
| rea | morluto/rea (npm `rea-agents`) | `rea` + MCP `rea` | [tools/rea/README.md](tools/rea/README.md) |
| karpathy-guidelines | multica-ai/andrej-karpathy-skills | skill `karpathy-guidelines` | [upstream](https://github.com/multica-ai/andrej-karpathy-skills) |
| moneyprinterturbo | harry0703/MoneyPrinterTurbo | skill `moneyprinterturbo-video` | [tools/moneyprinterturbo/README.md](tools/moneyprinterturbo/README.md) |
| openmontage | calesthio/OpenMontage | `openmontage` + skill `openmontage` | [tools/openmontage/README.md](tools/openmontage/README.md) |

## free-scrape
Free Firecrawl replacement: `free-scrape <url> [--scroll N] [--links] [--json]`. Renders pages in local headless Chromium (Playwright). Installs a `free-scrape` command and a skill that tells Claude to use it instead of Firecrawl in every project. On a PC, Playwright needs `npm install -g playwright && npx playwright install chromium` once.
