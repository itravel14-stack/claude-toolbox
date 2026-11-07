# OpenMontage (calesthio) — agentic video production (pipelines + Remotion/HyperFrames + Backlot).
# Sourced by bootstrap.sh. install() runs inside the clone (DEST). ONE central install;
# other repos use it through the `openmontage` command and the global skill, never a copy.
REPO=https://github.com/calesthio/OpenMontage.git
DEST="${OPENMONTAGE_HOME:-$TOOLS_HOME/openmontage}"

install() {
  for t in make node npm ffmpeg; do command -v "$t" >/dev/null || { echo "  missing prerequisite: $t"; return 1; }; done
  if [[ -x .venv/bin/python || -x .venv/Scripts/python.exe ]] && [[ -d remotion-composer/node_modules ]]; then
    echo "  setup: kept existing .venv + remotion-composer/node_modules"
  else
    make setup >"$DEST/.toolbox-setup.log" 2>&1 || { echo "  make setup failed: see $DEST/.toolbox-setup.log"; return 1; }
    echo "  setup: make setup ok (log: $DEST/.toolbox-setup.log)"
  fi
  seed_remotion_browser
  # .env holds API keys: created by make setup from .env.example, never committed, never overwritten.
  [[ -f .env ]] && chmod 600 .env
  git check-ignore -q .env || { echo "  .env is NOT git-ignored"; return 1; }
  git check-ignore -q projects/ || { echo "  projects/ is NOT git-ignored"; return 1; }
}

# Cloud containers block Remotion's Chrome download (remotion.media). Point Remotion's own
# cache at the pre-installed Playwright headless shell instead. No-op on a PC, or once
# Remotion has downloaded its browser itself.
seed_remotion_browser() {
  local hs; hs="$(ls -d /opt/pw-browsers/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell 2>/dev/null | tail -1)"
  [[ -n "$hs" && "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || return 0
  local cache=remotion-composer/node_modules/.remotion/chrome-headless-shell
  [[ -x "$cache/linux64/chrome-headless-shell-linux64/chrome-headless-shell" ]] && return 0
  curl -sfI --max-time 10 https://remotion.media >/dev/null 2>&1 && return 0
  local ver; ver="$(cd remotion-composer && node -p "require('./node_modules/@remotion/renderer/dist/browser/get-chrome-download-url.js').TESTED_VERSION" 2>/dev/null)" || return 0
  mkdir -p "$cache/linux64/chrome-headless-shell-linux64"
  ln -sf "$hs" "$cache/linux64/chrome-headless-shell-linux64/chrome-headless-shell"
  printf '%s' "$ver" > "$cache/VERSION"
  echo "  remotion: using pre-installed headless shell ($hs)"
}
