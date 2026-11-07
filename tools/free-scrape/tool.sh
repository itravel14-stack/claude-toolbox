# free-scrape — free Firecrawl replacement (local headless Chromium via Playwright). Sourced by bootstrap.sh.
# No REPO: the script lives in this toolbox. Puts `free-scrape` on PATH and a skill in every project.
install() {
  if ! (cd /tmp && node -e "require('playwright')" >/dev/null 2>&1); then
    echo "  note: Playwright not found for node; on a PC run: npm install -g playwright && npx playwright install chromium"
  fi
  # Claude Code cloud containers ship Playwright + Chromium preinstalled.
  # Always-loaded user memory: replace our marked block in ~/.claude/CLAUDE.md (other content untouched).
  local mem="$HOME/.claude/CLAUDE.md"; mkdir -p "$HOME/.claude"; touch "$mem"
  sed -i '/<!-- claude-toolbox:free-scrape:start -->/,/<!-- claude-toolbox:free-scrape:end -->/d' "$mem"
  cat "$TOOL_DIR/claude-memory.md" >> "$mem"
  echo "  memory: $mem"
}
