// Replaces upstream src/bootstrap/scrape-vm.ts (anvil-provider-muse).
// muse.ai no longer inlines `"activeGatewayUrl":"wss://…"` in the page. The signed-in page now carries the
// VM in its server data as escaped JSON: \"vmName\":\"<uuid>\",\"gatewayUrl\":\"wss://<uuid>.metaaivm.com/\".
// Accept both shapes, escaped or not, and prefer the vmName stated next to the gateway.
const Q = String.raw`\\?"`;
const URL_RE = String.raw`(wss:\/\/([a-f0-9-]{36})\.metaaivm\.com\/?)`;
const PAIR = new RegExp(`${Q}vmName${Q}\\s*:\\s*${Q}([a-f0-9-]{36})${Q}\\s*,\\s*${Q}gatewayUrl${Q}\\s*:\\s*${Q}${URL_RE}${Q}`);
const GATEWAY = new RegExp(`${Q}(?:activeGatewayUrl|gatewayUrl)${Q}\\s*:\\s*${Q}${URL_RE}${Q}`);

export function scrapeVmFromHtml(html: string): { vmId: string; gatewayUrl: string } | null {
  const pair = html.match(PAIR);
  if (pair) return { vmId: pair[1]!, gatewayUrl: pair[2]! };
  const m = html.match(GATEWAY);
  if (!m) return null;
  return { vmId: m[2]!, gatewayUrl: m[1]! };
}
