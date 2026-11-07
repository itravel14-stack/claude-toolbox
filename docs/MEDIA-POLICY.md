# Where files go (video & media projects)

GitHub limits (docs.github.com, checked 2026-11-07): files over **100 MiB are blocked** (warning
at 50 MiB); repositories should stay well under **10 GB**; pushes are capped at 2 GB. Git LFS on
GitHub Free: **10 GB storage + 10 GB bandwidth/month**, up to 2 GB per file; over quota, LFS pushes
or downloads stop until next month unless you add a budget.

| File type | Where | Why |
|---|---|---|
| Source code, configs (no secrets), docs, pipeline plans, scripts, OpenMontage `project.json`/checkpoints | Git (GitHub) | small, diffable, needs history |
| `.env`, keys, certificates, tokens | Nowhere in git — password manager + local `.env` | anything committed stays in history forever |
| Small images/icons (< 1 MB) | Git | fine as-is |
| Brand assets, voice-overs, music beds, short clips (1–100 MB) you re-use | Git LFS (`templates/media-project/.gitattributes`) | versioned without bloating clones |
| Final deliverable renders | Git LFS only if they must ship with the repo; otherwise external storage (B2/Drive) with the link in the README | each re-render adds a full copy to history |
| Raw footage, generated video takes, intermediate renders | External storage only (`raw/` is ignored) | large, regenerable or archival |
| OpenMontage `projects/` | Stays in `~/tools/openmontage/projects` (git-ignored upstream); backed up by `backup-all.sh --openmontage [--with-renders]`; export finals with `openmontage export <id>` | keeps the central install clean |
| Licensed audio/stock | External storage + license file in git | licenses may forbid redistribution in repos |
| `node_modules/`, `.venv/`, caches, temp files | Local only (ignored) | regenerable from lockfiles |

Set up a media repo:
```bash
cp ~/tools/claude-toolbox/templates/media-project/.gitignore ~/tools/claude-toolbox/templates/media-project/.gitattributes .
git lfs install && git add .gitignore .gitattributes && git commit -m "media policy"
```
Find what is bloating a repo: `git rev-list --objects --all | git cat-file --batch-check='%(objectsize) %(rest)' | sort -rn | head -20`.
Moving existing large files out of history requires rewriting history (`git lfs migrate import`):
that is a force-push — only with explicit approval, after a verified backup.
