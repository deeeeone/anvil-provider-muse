#!/bin/sh
# Starts the local muse-ai-api proxy on 127.0.0.1 only. Anvil passes the
# muse.ai sign-in it captured as ANVIL_PROVIDER_COOKIES, a JSON object of
# {"cookieName": "value"}, which is written in the Playwright storage-state
# shape the upstream reads. Session files stay in state/ inside this folder.
set -eu

cd "$(dirname "$0")"

ROOT=$(pwd)
STATE="$ROOT/state"
UPSTREAM="$ROOT/upstream"
PORT="${PORT:-38787}"

if [ ! -x "$UPSTREAM/node_modules/.bin/tsx" ]; then
  echo "start: upstream is not set up yet; run setup first." >&2
  exit 1
fi

mkdir -p "$STATE"

if [ -n "${ANVIL_PROVIDER_COOKIES:-}" ]; then
  ANVIL_STATE_FILE="$STATE/storage_state.json" \
  ANVIL_RAW_COOKIES="$ANVIL_PROVIDER_COOKIES" \
  node -e '
    const fs = require("fs");
    let map;
    try { map = JSON.parse(process.env.ANVIL_RAW_COOKIES); }
    catch (e) { console.error("start: ANVIL_PROVIDER_COOKIES is not valid JSON"); process.exit(1); }
    const cookies = Object.entries(map)
      .filter(([name, value]) => typeof value === "string" && value !== "")
      .map(([name, value]) => ({
        name, value, domain: "muse.ai", path: "/",
        expires: -1, httpOnly: true, secure: true, sameSite: "Lax",
      }));
    fs.writeFileSync(process.env.ANVIL_STATE_FILE,
      JSON.stringify({ cookies, origins: [] }, null, 2), { mode: 0o600 });
    console.error("start: wrote " + cookies.length + " muse.ai cookie(s) to state/");
  '
fi

# Upstream reads these paths relative to its own folder unless told otherwise.
export MUSE_PROXY_HOST=127.0.0.1
export MUSE_PROXY_PORT="$PORT"
export MUSE_PROXY_MODEL="${MUSE_PROXY_MODEL:-muse-spark}"
export MUSE_SESSION_PATH="$STATE/session.json"
export MUSE_STORAGE_STATE_PATH="$STATE/storage_state.json"
export MUSE_SESSIONS_STORE_PATH="$STATE/sessions-store.json"

# Match the request timezone and browser fingerprint to this Mac.
TZ_NAME=$(readlink /etc/localtime 2>/dev/null | sed 's#.*/zoneinfo/##' || true)
export MUSE_TZ="${TZ_NAME:-UTC}"
export MUSE_PLATFORM='"macOS"'
export MUSE_UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/154.0.0.0 Safari/537.36"

cd "$UPSTREAM"
exec node_modules/.bin/tsx index.ts
