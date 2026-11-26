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

# cycletls starts its helper through /bin/sh with the path unquoted, which breaks in any folder
# with a space in it, such as Anvil's "~/Library/Application Support". Start it without a shell.
echo "setup: patching cycletls to start its helper without a shell ..."
node -e '
  const fs = require("fs");
  const f = "node_modules/cycletls/dist/index.js";
  const src = fs.readFileSync(f, "utf8");
  const from = /shell: process\.platform !== "win32",/;
  if (src.includes("shell: false, // anvil-provider-muse")) process.exit(0);
  if (!from.test(src)) { console.error("setup: cycletls changed; the spawn patch no longer applies"); process.exit(1); }
  fs.writeFileSync(f, src.replace(from, "shell: false, // anvil-provider-muse"));
'

# muse.ai moved the VM address into escaped server data; the upstream scraper only knows the old key.
echo "setup: installing the updated VM scraper ..."
cp ../patches/scrape-vm.ts src/bootstrap/scrape-vm.ts

# muse.ai refuses POSTs that don't look same-origin (403). Browsers send these headers on their own.
echo "setup: adding same-origin headers to the session requests ..."
node -e '
  const fs = require("fs");
  const f = "src/bootstrap/session.ts";
  const src = fs.readFileSync(f, "utf8");
  const mark = "// anvil-provider-muse: same-origin";
  if (src.includes(mark)) process.exit(0);
  const from = "\"Content-Type\": \"application/json\",";
  if (src.split(from).length !== 2) { console.error("setup: session.ts changed; the header patch no longer applies"); process.exit(1); }
  fs.writeFileSync(f, src.replace(from, from + " " + mark + "\n        \"Sec-Fetch-Site\": \"same-origin\", \"Sec-Fetch-Mode\": \"cors\", \"Sec-Fetch-Dest\": \"empty\", \"Accept\": \"*/*\","));
'

SHORT=$(git rev-parse --short "$COMMIT")
echo "setup: muse-ai-api ready at $SHORT"
