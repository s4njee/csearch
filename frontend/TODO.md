# CSearch frontend — polish backlog

Post-redesign polish items. Roughly ordered by impact within each section.
`P1` = high impact / low effort, `P2` = worthwhile, `P3` = nice-to-have / larger.

---

## SEO & metadata
The prerender model is built for crawlability, so this is the highest-value area.

- [x] **P1 Per-page titles** — `app.vue` sets a `%s · CSearch` template; every page sets its own title via `useSeoMeta` (bill title, vote question, member/committee name, list headings).
- [x] **P1 Meta descriptions** per page via `useSeoMeta`.
- [x] **P2 Open Graph / Twitter cards** — `composables/usePageSeo.ts` mirrors title/description to og + twitter; global og defaults (site name, type, image, `summary` card) in `app.vue`. (Per-bill dynamic OG images still a future nice-to-have.)
- [x] **P2 `robots.txt` + `sitemap.xml`** — static files in `public/` listing the prerendered list routes.
- [ ] **P2 Canonical URLs** (and decide trailing-slash canonical form — see Performance).
- [ ] **P3 JSON-LD structured data** for bills/votes (schema.org) for richer search results.

## Robustness & error handling
- [x] **P1 Custom `error.vue`** — themed 404/500 page (header/nav, green accent, "Back to bills" via `clearError`).
- [ ] **P1 Hydration mismatch warnings** — list pages prerender then refetch live, logging mismatches every load. Either accept (documented) or fetch list data client-only (`server: false`) to silence cleanly.
- [x] **P2 Consistent error UI + retry** — bill/vote/committee/member detail errors now show `UAlert` + a "Try again" button (`useAsyncData` refresh).
- [ ] **P2 Invalid-id handling** — bill/vote/member detail with bad params should render the themed error/empty state, not a bare message.
- [ ] **P3 Detail pages are SPA shells** (bill/vote/member) — blank to crawlers, brief loading flash for users. Edge SSR or prerender popular ones (the bigger item noted in `nuxt.config.ts`).

## UX & interaction
- [x] **P1 "Refine results (1 active)"** — Chamber excluded from `activeFacetCount`; reads "Optional filters" until a real filter is set.
- [x] **P1 Skeleton loading** — `components/SkeletonCard.vue` wired into votes/committees/member/representatives/bill-detail/vote-detail loading states.
- [x] **P1 Active nav highlighting** — nav items match by route prefix (`layouts/default.vue`), so detail pages keep their section highlighted.
- [x] **P2 Result count** — "N results" line shown above the bills and votes result grids.
- [ ] **P2 Sort-direction toggle** — newest/oldest flip was removed with the strip; add a compact one in the Refine panel.
- [x] **P2 "Clear all filters"** button in the bills + votes Refine panels (shown when filters are active).
- [ ] **P2 Mobile nav** wraps to two rows; a compact menu/drawer under a breakpoint is cleaner. (`layouts/default.vue`)
- [ ] **P3 Search affordances** — `/` to focus search, button `:loading` state while fetching, restore bill-number quick lookup that lived on the old landing page.
- [ ] **P3 Scroll-to-top** on pagination change; optional back-to-top button on long lists.
- [ ] **P3 Page transitions** — subtle fade / View Transitions API on navigation (respect `prefers-reduced-motion`).

## Visual consistency
- [ ] **P1 Unify the greens** — result badges use Tailwind `success` green while buttons use the brand/brighter green. Pick one green token so they match. (`assets/css/main.css`, `composables/useFormatters.ts`)
- [x] **P2 Vote *detail* result badge** — now single-line (`whitespace-nowrap`), with the action row wrapping on small screens. (`pages/votes/[voteid].vue`)
- [x] **P2 Number formatting** — `formatNumber` (Intl.NumberFormat) applied to cosponsor/vote/member/committee counts.
- [ ] **P3 Card header pattern** — some cards use the `#header` slot, others inline headers; standardize.
- [ ] **P3 Relative dates** — optional "3 days ago" alongside absolute dates. (`composables/useFormatters.ts`)

## Accessibility
- [ ] **P1 Color contrast audit** — `text-muted` / `text-dimmed` on pure black; verify WCAG AA, especially the small uppercase eyebrows.
- [ ] **P2 Focus-visible states** — ensure keyboard focus rings are clearly visible on the square/dark theme (links, cards, selects).
- [x] **P2 Icon-only controls** — brand link + primary nav now have `aria-label`s. (External-link buttons already carry text labels.)
- [x] **P2 Skip-to-content link** — added in `layouts/default.vue` (targets `<main id="main">`).
- [ ] **P3 `prefers-reduced-motion`** honored once transitions are added.

## Performance
- [ ] **P2 Plotly is heavy** (`plotly.js-dist-min`). It's `.client`-only, but lazy-load on the explore/vote pages, or swap the few bar charts for a lighter lib.
- [ ] **P2 Trailing-slash hop** — nav links to `/bills/hr` 308-redirect to `/bills/hr/` in prod. Point links at the trailing-slash form (or set `trailingSlash` config) to avoid the extra hop.
- [ ] **P3 Cache headers** — tune Cloudflare cache rules for the prerendered HTML (currently `max-age=0, must-revalidate`).
- [ ] **P3 Lighthouse pass** — verify LCP/CLS, confirm self-hosted fonts (via `@nuxt/fonts`) and preconnects are optimal.

## Content
- [x] **P2 Footer** — site footer in `layouts/default.vue` with attribution + data-freshness stamp.
- [x] **P2 Surface data freshness** — footer shows "Data updated …" from the API `/freshness` endpoint.
- [ ] **P3 About / API docs page** — the old landing's endpoint catalog is gone; a small `/about` or docs page could replace it.
- [ ] **P3 Empty-state design** — icon + helpful copy + "clear filters" action instead of plain text.

## Code health
- [x] **P1 Remove dead code** — removed `withSummaries`, `withPolicyArea`, `totalCosponsors`, `semanticScoreLabel`, `semanticRankTone` (bills list), `resultClass` (votes list), and `voteResultClass` (`composables/useFormatters.ts`).
- [x] **P2 Tidy `as any` casts** — added `position` to `VoteRecord`; removed the member-page casts. (One benign `data.value as any` remains in `representatives.vue` for an alternate API key shape.)
- [ ] **P3 Consistent select sentinel** — the `ANY` empty-value workaround is duplicated across pages; extract a small `useAnySelect` helper.

## Tooling / CI
- [ ] **P2 Type-check in CI** — run `nuxi typecheck` (and lint) on PRs.
- [ ] **P2 Lint/format config** — ensure ESLint + formatting are wired and enforced.
- [ ] **P3 Tests** — component tests (Vitest) for the filter logic and a Playwright smoke test (load each route, redirect works, search returns results).
- [ ] **P3 Commit the redesign** — the deployed build is from the uncommitted working tree on the `redesign` branch; commit and open a PR to `main`.
