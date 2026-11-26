# Muse (on device) for Anvil

Talk to Meta's **Muse Spark** model, the one behind the muse.ai agent, from Anvil. This plugin runs [manishkumar1601/muse-ai-api](https://github.com/manishkumar1601/muse-ai-api) on your Mac. That project is a small local proxy that speaks the OpenAI API and forwards your chats to muse.ai using your own Meta account.

## Install

1. In Anvil, open **Settings → Provider → Add provider → From GitHub**.
2. Paste `https://github.com/deeeeone/anvil-provider-muse` and confirm.
3. Click **Sign in…** and log in to muse.ai with your Meta account.
4. Pick a `muse-web/…` model, for example `muse-web/muse-spark`.

**Needs:** Node 22 or newer, and git. The first setup downloads the upstream project and its npm packages, including `cycletls`, which ships a small native helper. This takes a few seconds on a fast connection.

## What it does

| File | Purpose |
|---|---|
| `setup.sh` | Clones the upstream project at a pinned commit and installs its npm packages into `upstream/`, then applies three small fixes (below). |
| `start.sh` | Writes your muse.ai sign-in from Anvil into `state/`, then starts the proxy on `127.0.0.1:38787`. |
| `patches/scrape-vm.ts` | Replaces the upstream's VM scraper, which looks for a page format muse.ai no longer uses. |
| `anvil-provider.json` | Tells Anvil where the proxy lives, how to sign in, and which model to offer. |

Everything the plugin creates (the upstream copy, session files and logs) stays inside this folder. Your home directory is not touched.

## Fixes applied to the upstream

muse.ai changed after the pinned upstream commit, so `setup.sh` patches three things in `upstream/`:

- **cycletls helper path.** cycletls starts its helper through the shell without quoting the path, which fails in folders with spaces such as `~/Library/Application Support`. It now starts the helper directly.
- **VM address.** The signed-in page now carries your VM's address as escaped JSON (`gatewayUrl`), not `activeGatewayUrl`. `patches/scrape-vm.ts` reads both.
- **Same-origin headers.** muse.ai answers 403 to session requests that lack the `Sec-Fetch-*` headers every browser sends with its own requests. The session requests now include them.

## Where your data goes

Your prompts go from Anvil to the proxy on your Mac (`127.0.0.1:38787`), and from there to muse.ai, which is run by Meta. Nothing else receives them. The proxy listens on localhost only, so other machines on your network cannot use it.

## Good to know

- This is an **unofficial, reverse-engineered client**. It can break whenever Meta updates muse.ai, and then the fix has to come from the upstream project.
- Using it may go against Meta's terms of service, and your account could be limited. Use an account you are prepared to risk.
- Meta's official Model API at [dev.meta.ai](https://dev.meta.ai/) is the supported route to the same model.
- The muse.ai session is created from your `hatch_sess` cookie and renewed automatically. If requests fail with sign-in errors, use **Sign in…** again.
- The proxy's log is `.anvil-server.log` in this folder. Session files live in `state/`, which is git-ignored.

## License

The plugin's own files are MIT licensed, see [LICENSE](LICENSE). The upstream project, muse-ai-api by manishkumar1601, is also MIT licensed. It is downloaded during setup at a pinned commit rather than copied into this repository.
