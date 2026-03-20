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
            crawlLinks: false,
            routes: ['/', '/votes', '/explore', '/bills/hr', '/bills/s', '/bills/hres', '/bills/sres', '/bills/hjres', '/bills/sjres', '/bills/hconres', '/bills/sconres', '/committees'],
        }
    }
})
