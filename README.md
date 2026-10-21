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
without touching your local files. Skips snapshots containing `.env`/key/secret files.
Prints folders that aren't on GitHub yet — give Claude that list to create the repos.

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
