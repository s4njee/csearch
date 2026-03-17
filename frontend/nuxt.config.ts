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
        },
    },
    runtimeConfig: {
        public: {
            API_SERVER: process.env.NUXT_API_SERVER,
        }
    },
    postcss: {
        plugins: {
            tailwindcss: {},
            autoprefixer: {},
        },
    },

})
