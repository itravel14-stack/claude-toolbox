# free-scrape — free Firecrawl replacement (local headless Chromium via Playwright). Sourced by bootstrap.sh.
# No REPO: the script lives in this toolbox. Puts `free-scrape` on PATH and a skill in every project.
install() {
  if ! (cd /tmp && node -e "require('playwright')" >/dev/null 2>&1); then
    echo "  note: Playwright not found for node; on a PC run: npm install -g playwright && npx playwright install chromium"
  fi
  # Claude Code cloud containers ship Playwright + Chromium preinstalled.
}
