# Paste into claude.ai/code -> environment -> Edit -> Setup script.
# Runs at the start of every cloud session, whatever repo is open.
git clone --quiet --depth 1 https://github.com/itravel14-stack/claude-toolbox.git ~/tools/claude-toolbox \
  || git -C ~/tools/claude-toolbox pull --quiet --ff-only
bash ~/tools/claude-toolbox/bootstrap.sh || true
