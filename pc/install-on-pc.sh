#!/usr/bin/env bash
# One-time setup on your PC so EVERY local Claude Code session (CLI, VS Code, desktop app)
# loads Adrian's standing notes (free-scrape, no Firecrawl, ClipEngine agents).
# Run in Git Bash:
#   curl -fsSL https://raw.githubusercontent.com/itravel14-stack/claude-toolbox/main/pc/install-on-pc.sh | bash
# Safe to re-run any time (updates the toolbox and the notes).
set -uo pipefail
TB="$HOME/tools/claude-toolbox"
if [[ -d "$TB/.git" ]]; then git -C "$TB" pull --quiet --ff-only; else git clone --quiet --depth 1 https://github.com/itravel14-stack/claude-toolbox.git "$TB"; fi
bash "$TB/bootstrap.sh" free-scrape karpathy-guidelines
if ! (cd "$TEMP" 2>/dev/null || cd /tmp; node -e "require('playwright')" >/dev/null 2>&1); then
  echo "Installing Playwright (one time, for free-scrape)..."
  npm install -g playwright && npx playwright install chromium
fi
echo
echo "Done. Always-loaded notes: $HOME/.claude/CLAUDE.md"
echo "Restart Claude Code / the Claude desktop app so new sessions pick them up."
