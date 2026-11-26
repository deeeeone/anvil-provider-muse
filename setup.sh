#!/bin/sh
# Downloads the upstream muse-ai-api project at a pinned commit and installs
# its npm packages. Runs once from the plugin folder (Anvil runs it again only
# when this plugin's spec or this script changes).
set -eu

UPSTREAM_URL="https://github.com/manishkumar1601/muse-ai-api.git"
COMMIT="59354925f3b291a9549b8f5c4f04c23f2f178f29"

cd "$(dirname "$0")"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "setup: '$1' is required but was not found. $2" >&2
    exit 1
  fi
}
need git "Install Xcode Command Line Tools (xcode-select --install)."
need node "Install Node 22 or newer (https://nodejs.org or brew install node)."
need npm "npm comes with Node 22 or newer."

NODE_MAJOR=$(node -p 'process.versions.node.split(".")[0]')
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "setup: Node 22 or newer is required (found $(node -v))." >&2
  exit 1
fi

if [ ! -d upstream/.git ]; then
  echo "setup: downloading muse-ai-api into upstream/ ..."
  rm -rf upstream
  git clone --quiet "$UPSTREAM_URL" upstream
fi

echo "setup: checking out pinned commit $COMMIT ..."
git -C upstream fetch --quiet origin
git -C upstream checkout --force --quiet "$COMMIT"

echo "setup: installing npm packages ..."
cd upstream
npm ci --omit=dev --no-audit --no-fund --loglevel=error

SHORT=$(git rev-parse --short "$COMMIT")
echo "setup: muse-ai-api ready at $SHORT"
