#!/usr/bin/env bash
# Scaffold a new tool:  bash add-tool.sh <name> <github-url>
# Then edit tools/<name>/tool.sh (install steps) and tools/<name>/skill/SKILL.md,
# run `bash bootstrap.sh <name>`, and commit + push the toolbox.
set -euo pipefail
name="${1:?usage: add-tool.sh <name> <github-url>}"; url="${2:?github url required}"
dir="$(cd "$(dirname "$0")" && pwd)/tools/$name"
[[ -e "$dir" ]] && { echo "tools/$name already exists"; exit 1; }
mkdir -p "$dir/skill"
git ls-remote "$url" HEAD | cut -f1 > "$dir/PIN"
cat > "$dir/tool.sh" <<T
# $name — sourced by bootstrap.sh. install() runs inside the clone (\$DEST).
REPO=$url

install() {
  # Put the project's documented install steps here, e.g.:
  #   uv sync            (pyproject.toml / uv.lock)
  #   npm install        (package.json)
  #   pip install -e .   (setup.py)
  :
}
T
cat > "$dir/skill/SKILL.md" <<S
---
name: $name
description: TODO one sentence — what $name does and when Claude should use it, from any repository.
---

# $name

Installed at \`~/tools/$name\` (source: $url, pinned in claude-toolbox/tools/$name/PIN).
Run it from any repo with: TODO exact verified command.

## When to use
TODO

## How to run
TODO (verified commands only; note any API keys via env vars, never in repos)
S
echo "created tools/$name (pinned $(cut -c1-7 "$dir/PIN")). Edit tool.sh + skill/SKILL.md, then: bash bootstrap.sh $name"
