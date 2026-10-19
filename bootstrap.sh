#!/usr/bin/env bash
# Installs every tool in tools/*/ once, globally, for all Claude Code projects:
#   source repo  -> $TOOLS_HOME/<name>         (default ~/tools/<name>)
#   commands     -> ~/.local/bin/              (from tools/<name>/bin/*)
#   skill        -> ~/.claude/skills/<name>/   (from tools/<name>/skill/)
# Idempotent. Never re-clones, resets, or overwrites an existing checkout or config.
#
#   bash bootstrap.sh              # all tools
#   bash bootstrap.sh vimax foo    # only these
set -uo pipefail

TOOLBOX_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_HOME="${TOOLS_HOME:-$HOME/tools}"
BIN_DIR="$HOME/.local/bin"
SKILLS_DIR="$HOME/.claude/skills"
export TOOLBOX_HOME TOOLS_HOME
mkdir -p "$TOOLS_HOME" "$BIN_DIR" "$SKILLS_DIR"

link_bin() {  # Git Bash makes copies instead of symlinks; wrappers don't depend on either.
  local src="$1" dst="$BIN_DIR/$(basename "$1")"
  if [[ -e "$dst" && ! -L "$dst" ]] && ! grep -q "claude-toolbox" "$dst" 2>/dev/null && ! cmp -s "$src" "$dst"; then
    echo "  skip bin: $dst exists and is not from the toolbox"; return
  fi
  chmod +x "$src"; rm -f "$dst"
  ln -s "$src" "$dst" 2>/dev/null || cp "$src" "$dst"
}

install_skill() {
  local src="$1" dst="$SKILLS_DIR/$2"
  mkdir -p "$dst"
  if [[ -f "$dst/SKILL.md" ]] && ! cmp -s "$src/SKILL.md" "$dst/SKILL.md"; then
    cp "$dst/SKILL.md" "$dst/SKILL.md.bak.$(date +%s)"
  fi
  cp -R "$src/." "$dst/"
}

install_tool() {
  local dir="$TOOLBOX_HOME/tools/$1"
  [[ -f "$dir/tool.sh" ]] || { echo "unknown tool: $1"; return 1; }
  (
    set -e
    NAME="$1"; REPO=""; PIN=""; DEST=""; TOOL_DIR="$dir"
    [[ -f "$dir/PIN" ]] && PIN="$(tr -d '[:space:]' < "$dir/PIN")"
    install() { :; }
    # shellcheck source=/dev/null
    source "$dir/tool.sh"
    DEST="${DEST:-$TOOLS_HOME/$NAME}"
    echo "== $NAME"
    if [[ -n "$REPO" ]]; then
      if [[ -d "$DEST/.git" ]]; then
        echo "  repo: kept $DEST @ $(git -C "$DEST" rev-parse --short HEAD)"
      else
        git clone --quiet "$REPO" "$DEST"
        [[ -n "$PIN" ]] && git -C "$DEST" checkout --quiet -B main "$PIN"
        echo "  repo: cloned $REPO @ $(git -C "$DEST" rev-parse --short HEAD)"
      fi
    fi
    export DEST TOOL_DIR
    (cd "${DEST:-$dir}" 2>/dev/null || cd "$dir"; install)
    if [[ -d "$dir/bin" ]]; then for f in "$dir"/bin/*; do link_bin "$f"; done; fi
    [[ -f "$dir/skill/SKILL.md" ]] && install_skill "$dir/skill" "$NAME" && echo "  skill: $SKILLS_DIR/$NAME"
    echo "  ok"
  )
}

names=("$@")
if [[ ${#names[@]} -eq 0 ]]; then
  for d in "$TOOLBOX_HOME"/tools/*/; do names+=("$(basename "$d")"); done
fi

failed=()
for n in "${names[@]}"; do install_tool "$n"; [[ $? -eq 0 ]] || failed+=("$n"); done  # not `||`: it would disable set -e inside
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "add to PATH: export PATH=\"$BIN_DIR:\$PATH\"" ;; esac
if [[ ${#failed[@]} -gt 0 ]]; then echo "FAILED: ${failed[*]}"; exit 1; fi
echo "all tools installed. Restart Claude Code if a new skill doesn't show up."
