// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
    compatibilityDate: '2024-11-01',
    srcDir: '.',
    devtools: {enabled: true},
    // app: {
    //     cdnURL: 'https://csearch.org/'
    // },
    css: ['~/assets/css/main.css'],
    app: {
        head: {
            title: 'CSearch',
            link: [
                {
                    rel: 'preconnect',
                    href: 'https://fonts.googleapis.com',
                },
                {
                    rel: 'preconnect',
                    href: 'https://fonts.gstatic.com',
                    crossorigin: '',
                },
                {
                    rel: 'stylesheet',
                    href: 'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap',
                },
            ],
            script: [
                {
                    src: '/runtime-config.js',
                },
            ],
        },
    },
    runtimeConfig: {
        public: {
            // This provides a server-side/default API origin for local dev and static generation.
            API_SERVER: process.env.NUXT_API_SERVER || 'https://api.csearch.org',
        }
    },
    postcss: {
        plugins: {
            tailwindcss: {},
            autoprefixer: {},
        },
    },
    routeRules: {
        '/api/**': {
            proxy: process.env.PROXY_API || 'http://localhost:3000/**'
        }
    },
    nitro: {
        prerender: {
            // ── Render model policy (§6 docs/CRITICISMS2.md) ──────────────────────
            //
            // CSearch uses a deliberate SSG/SPA hybrid:
            //
            //  PRERENDERED (listed below):
            //    - Top-level list routes (/, /votes, /explore, /representatives,
            //      /committees, and each /bills/<type> index).
            //    - These are static HTML at build time.  Freshness = last Pages deploy.
            //      They are crawlable and indexable by search engines.
            //    - Build is triggered by GitHub Actions on schedule + scraper hook.
            //
            //  CLIENT-RENDERED (SPA fallback — all other routes):
            //    - Bill detail pages  /bills/<type>/<congress>/<number>
            //    - Vote detail pages  /votes/<id>
            //    - Member pages       /members/<bioguide_id>
            //    - These are empty shells to a crawler (no HTML content at build time).
            //    - Freshness = live API data fetched on first client-side render.
            //    - SEO trade-off is accepted: detail pages are reached via links
            //      from the prerendered list pages, so they surface indirectly.
            //
            // To change this model, evaluate edge SSR (Worker + Nitro) or full
            // prerender with event-driven rebuild (see FINDINGS.md §3).
            // ──────────────────────────────────────────────────────────────────────
            crawlLinks: false,
            routes: [
                // Public landing + top-level lists (SSG — crawlable)
                '/',
                '/votes',
                '/explore',
                '/representatives',
                '/committees',
                // Bill list pages, one per bill type (SSG — crawlable)
                '/bills/hr',
                '/bills/s',
                '/bills/hres',
                '/bills/sres',
                '/bills/hjres',
                '/bills/sjres',
                '/bills/hconres',
                '/bills/sconres',
            ],
        }
    }
})
