/**
 * csearch-api-cache — KV-backed stale-while-revalidate proxy in front of api.csearch.org.
 *
 * Strategy:
 *   - GET requests are cached by domain + data version + path + sorted query string.
 *   - Data versions come from the origin /cache-version endpoint. Fresh
 *     versions are reused immediately; stale versions are used without
 *     blocking the response while a background refresh updates the contract.
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
const VERSION_TTL_SECONDS = 60;
const VERSION_STALE_SECONDS = 24 * 60 * 60;
const VERSION_CACHE_KEY = "__csearch_cache_versions__";
// KV expiry — keeps entries reachable for the full stale window plus a small grace.
const KV_TTL_SECONDS = STALE_SECONDS + 60 * 60;
const VERSION_KV_TTL_SECONDS = 7 * 24 * 60 * 60;

interface CachedEntry {
  status: number;
  headers: Record<string, string>;
  body: string;
  fetchedAt: number;
}

interface CacheVersions {
  bills_version?: string | null;
  votes_version?: string | null;
  explore_version?: string | null;
  semantic_version?: string | null;
}

interface StoredCacheVersions {
  fetchedAt: number;
  versions: CacheVersions;
}

type CacheDomain = "bills" | "votes" | "explore" | "semantic" | "general";

let memoryVersions: StoredCacheVersions | null = null;

function cacheKey(url: URL): string {
  const params = [...url.searchParams.entries()].sort(([a], [b]) => a.localeCompare(b));
  const qs = params.map(([k, v]) => `${k}=${v}`).join("&");
  return qs ? `${url.pathname}?${qs}` : url.pathname;
}

function versionedCacheKey(baseKey: string, domain: CacheDomain, version: string): string {
  return `${domain}:${version}:${baseKey}`;
}

function originUrl(env: Env, url: URL): string {
  const target = new URL(env.ORIGIN);
  target.pathname = url.pathname;
  target.search = url.search;
  return target.toString();
}

function originPath(env: Env, path: string): string {
  const target = new URL(env.ORIGIN);
  target.pathname = path;
  target.search = "";
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

function entryToResponse(entry: CachedEntry, state: "HIT" | "STALE", domain: CacheDomain, version: string): Response {
  const headers = new Headers(entry.headers);
  headers.set("X-Cache", state);
  headers.set("X-Cache-Age", String(Math.max(0, Math.floor((Date.now() - entry.fetchedAt) / 1000))));
  headers.set("X-Cache-Domain", domain);
  headers.set("X-Data-Version", version);
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

function cacheDomain(url: URL): CacheDomain {
  const path = url.pathname;
  if (path.startsWith("/votes")) return "votes";
  if (path.startsWith("/search/semantic")) return "semantic";
  if (path.startsWith("/explore")) return "explore";
  if (
    path.startsWith("/latest")
    || path.startsWith("/bills")
    || path.startsWith("/search")
    || path.startsWith("/committees")
    || path.startsWith("/members")
    || path.startsWith("/representatives")
  ) {
    return "bills";
  }
  return "general";
}

function newestVersion(...values: Array<string | null | undefined>): string | null {
  const present = values.filter((value): value is string => Boolean(value));
  if (present.length === 0) return null;
  return present.sort().at(-1) ?? null;
}

function versionForDomain(versions: CacheVersions | null, domain: CacheDomain): string {
  if (!versions) return "unversioned";
  if (domain === "bills") return versions.bills_version || "bills-unversioned";
  if (domain === "votes") return versions.votes_version || "votes-unversioned";
  if (domain === "explore") return versions.explore_version || newestVersion(versions.bills_version, versions.votes_version) || "explore-unversioned";
  if (domain === "semantic") return versions.semantic_version || "semantic-unversioned";
  return newestVersion(
    versions.bills_version,
    versions.votes_version,
    versions.explore_version,
    versions.semantic_version,
  ) || "general-unversioned";
}

function cachedVersionsFresh(stored: StoredCacheVersions | null): stored is StoredCacheVersions {
  return Boolean(stored && (Date.now() - stored.fetchedAt) / 1000 < VERSION_TTL_SECONDS);
}

function cachedVersionsUsable(stored: StoredCacheVersions | null): stored is StoredCacheVersions {
  return Boolean(stored && (Date.now() - stored.fetchedAt) / 1000 < VERSION_STALE_SECONDS);
}

async function readStoredVersions(env: Env): Promise<StoredCacheVersions | null> {
  if (cachedVersionsUsable(memoryVersions)) {
    return memoryVersions;
  }

  const raw = await env.CACHE.get(VERSION_CACHE_KEY);
  if (!raw) return null;

  try {
    const stored = JSON.parse(raw) as StoredCacheVersions;
    if (cachedVersionsUsable(stored)) {
      memoryVersions = stored;
      return stored;
    }
  } catch {
    // Corrupt entry — fall through to origin.
  }

  return null;
}

async function refreshCacheVersions(env: Env): Promise<CacheVersions | null> {
  try {
    const res = await fetch(originPath(env, "/cache-version"), {
      headers: { "Cache-Control": "no-store" },
    });
    if (!res.ok) return null;
    const versions = await res.json() as CacheVersions;
    const stored = { fetchedAt: Date.now(), versions };
    memoryVersions = stored;
    await env.CACHE.put(VERSION_CACHE_KEY, JSON.stringify(stored), { expirationTtl: VERSION_KV_TTL_SECONDS });
    return versions;
  } catch (err) {
    console.error("cache-version fetch error", { err: String(err) });
    return null;
  }
}

async function cacheVersions(env: Env, ctx: ExecutionContext): Promise<CacheVersions | null> {
  const stored = await readStoredVersions(env);
  if (stored) {
    if (!cachedVersionsFresh(stored)) {
      ctx.waitUntil(refreshCacheVersions(env));
    }
    return stored.versions;
  }

  // Cold start with no version contract anywhere: block once so the first fill
  // uses the right versioned key. Future requests can use stale metadata.
  return await refreshCacheVersions(env);
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

    // Operational freshness probes are intentionally uncached and should not
    // spend an extra origin request fetching the version contract.
    if (url.pathname === "/freshness" || url.pathname === "/cache-version") {
      return fetch(originUrl(env, url), req);
    }

    const domain = cacheDomain(url);
    const versions = await cacheVersions(env, ctx);
    const dataVersion = versionForDomain(versions, domain);
    const key = versionedCacheKey(cacheKey(url), domain, dataVersion);
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
          return applyCors(entryToResponse(entry, "HIT", domain, dataVersion), req);
        }
        if (ageSeconds < STALE_SECONDS) {
          ctx.waitUntil(revalidate(env, url, key));
          return applyCors(entryToResponse(entry, "STALE", domain, dataVersion), req);
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
          return applyCors(entryToResponse(entry, "STALE", domain, dataVersion), req);
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
    headers.set("X-Cache-Domain", domain);
    headers.set("X-Data-Version", dataVersion);
    return applyCors(new Response(res.body, { status: res.status, headers }), req);
  },
} satisfies ExportedHandler<Env>;
