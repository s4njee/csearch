<script setup lang="ts">
// Default document title + suffix template. Pages set their own title via
// useSeoMeta({ title }); this appends "· CSearch" and falls back to "CSearch".
useHead({
  titleTemplate: title => (title ? `${title} · CSearch` : 'CSearch'),
  htmlAttrs: { lang: 'en' },
})

// Site-wide social-card defaults; per-page title/description come from usePageSeo.
useSeoMeta({
  ogSiteName: 'CSearch',
  ogType: 'website',
  ogImage: 'https://csearch.org/android-chrome-512x512.png',
  twitterCard: 'summary',
})
</script>

<template>
  <UApp>
    <noscript>
      <iframe
        src="https://www.googletagmanager.com/ns.html?id=GTM-MSWX7P9"
        height="0"
        width="0"
        style="display: none; visibility: hidden"
      />
    </noscript>

    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </UApp>
</template>
