/**
 * csearch-api-cache — KV-backed stale-while-revalidate proxy in front of api.csearch.org.
 *
 * Strategy:
 *   - GET requests are cached by path + sorted query string.
 *   - Fresh window (< 5 min): serve from KV, no origin call.
 *   - Stale window (5 min – 24 h): serve from KV, kick off background revalidate.
 *   - Beyond 24 h or KV miss: fetch synchronously, cache on success.
 *   - Origin failure with stale entry available: serve stale.
 *   - Non-GET / non-2xx / Cache-Control: no-store passthrough; never cached.
 */

interface Env {
  CACHE: KVNamespace;
  ORIGIN: string;
}

const FRESH_SECONDS = 5 * 60;
const STALE_SECONDS = 24 * 60 * 60;
// KV expiry — keeps entries reachable for the full stale window plus a small grace.
const KV_TTL_SECONDS = STALE_SECONDS + 60 * 60;

interface CachedEntry {
  status: number;
  headers: Record<string, string>;
  body: string;
  fetchedAt: number;
}

function cacheKey(url: URL): string {
  const params = [...url.searchParams.entries()].sort(([a], [b]) => a.localeCompare(b));
  const qs = params.map(([k, v]) => `${k}=${v}`).join("&");
  return qs ? `${url.pathname}?${qs}` : url.pathname;
}

function originUrl(env: Env, url: URL): string {
  const target = new URL(env.ORIGIN);
  target.pathname = url.pathname;
  target.search = url.search;
  return target.toString();
}

function cleanHeaders(src: Headers): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of src.entries()) {
    const key = k.toLowerCase();
    if (key === "set-cookie" || key === "transfer-encoding" || key === "connection" || key === "content-length") continue;
    out[key] = v;
  }
  return out;
}

function entryToResponse(entry: CachedEntry, state: "HIT" | "STALE"): Response {
  const headers = new Headers(entry.headers);
  headers.set("X-Cache", state);
  headers.set("X-Cache-Age", String(Math.max(0, Math.floor((Date.now() - entry.fetchedAt) / 1000))));
  return new Response(entry.body, { status: entry.status, headers });
}

async function buildEntry(res: Response): Promise<CachedEntry> {
  return {
    status: res.status,
    headers: cleanHeaders(res.headers),
    body: await res.text(),
    fetchedAt: Date.now(),
  };
}

function shouldCache(res: Response): boolean {
  if (res.status < 200 || res.status >= 300) return false;
  const cc = res.headers.get("cache-control");
  if (cc && /no-store|private/i.test(cc)) return false;
  return true;
}

async function revalidate(env: Env, url: URL, key: string): Promise<void> {
  try {
    const res = await fetch(originUrl(env, url));
    if (!shouldCache(res)) return;
    const entry = await buildEntry(res);
    await env.CACHE.put(key, JSON.stringify(entry), { expirationTtl: KV_TTL_SECONDS });
  } catch (err) {
    console.error("revalidate error", { key, err: String(err) });
  }
}

// The origin sets `Access-Control-Allow-Origin: *` only when a request carries an
// Origin header. Because this Worker caches by path+query (not Origin) and may fill
// the cache from header-less requests (e.g. the SSG build), a cached GET response can
// lack that header — which would break browser requests on a HIT. The origin's CORS
// policy is a static wildcard, so re-assert it here for any browser (Origin-bearing)
// GET so cached hits stay CORS-valid.
function applyCors(res: Response, req: Request): Response {
  if (req.headers.get("Origin")) {
    res.headers.set("Access-Control-Allow-Origin", "*");
  }
  return res;
}

export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(req.url);

    // Non-GET requests bypass the cache entirely. POST /search/semantic is the
    // notable example — it's user-specific embedding work and not safe to SWR.
    if (req.method !== "GET") {
      return fetch(originUrl(env, url), req);
    }

    const key = cacheKey(url);
    const raw = await env.CACHE.get(key);

    if (raw) {
      let entry: CachedEntry | null = null;
      try {
        entry = JSON.parse(raw) as CachedEntry;
      } catch {
        // Corrupt entry — fall through to origin.
      }
      if (entry) {
        const ageSeconds = (Date.now() - entry.fetchedAt) / 1000;
        if (ageSeconds < FRESH_SECONDS) {
          return applyCors(entryToResponse(entry, "HIT"), req);
        }
        if (ageSeconds < STALE_SECONDS) {
          ctx.waitUntil(revalidate(env, url, key));
          return applyCors(entryToResponse(entry, "STALE"), req);
        }
      }
    }

    // Miss (or expired): fetch synchronously.
    let res: Response;
    try {
      res = await fetch(originUrl(env, url));
    } catch (err) {
      // Origin unreachable — last-ditch stale fallback.
      if (raw) {
        try {
          const entry = JSON.parse(raw) as CachedEntry;
          return applyCors(entryToResponse(entry, "STALE"), req);
        } catch {
          // fall through
        }
      }
      return new Response("Bad Gateway", { status: 502 });
    }

    if (shouldCache(res)) {
      const entry = await buildEntry(res.clone());
      ctx.waitUntil(env.CACHE.put(key, JSON.stringify(entry), { expirationTtl: KV_TTL_SECONDS }));
    }

    const headers = new Headers(res.headers);
    headers.set("X-Cache", "MISS");
    return applyCors(new Response(res.body, { status: res.status, headers }), req);
  },
} satisfies ExportedHandler<Env>;
