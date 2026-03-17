<template>
  <div class="shell">
    <noscript>
      <iframe
        src="https://www.googletagmanager.com/ns.html?id=GTM-MSWX7P9"
        height="0"
        width="0"
        style="display: none; visibility: hidden"
      />
    </noscript>

    <header class="app-nav">
      <NuxtLink to="/" class="app-nav__brand">
        <span class="app-nav__brand-mark">CS</span>
        <span>
          <strong>CSearch</strong>
          <small>Congress API console</small>
        </span>
      </NuxtLink>

      <nav class="app-nav__links" aria-label="Primary">
        <NuxtLink to="/">Overview</NuxtLink>
        <NuxtLink to="/bills/hr">Bills</NuxtLink>
        <NuxtLink :to="{ path: '/votes', query: { chamber: 'senate' } }">Votes</NuxtLink>
        <NuxtLink to="/explore">Explore</NuxtLink>
      </nav>
    </header>

    <NuxtPage />
  </div>
</template>

<style>
html,
body,
#__nuxt {
  min-height: 100%;
}

body {
  margin: 0;
}

.shell {
  min-height: 100vh;
  position: relative;
}

.app-nav {
  width: min(1200px, calc(100% - 2rem));
  margin: 0 auto;
  padding: 1.2rem 0 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.app-nav__brand {
  display: inline-flex;
  align-items: center;
  gap: 0.75rem;
  color: var(--text-main);
}

.app-nav__brand:hover {
  color: #fff;
}

.app-nav__brand strong,
.app-nav__brand small {
  display: block;
}

.app-nav__brand strong {
  font-size: 0.8rem;
  letter-spacing: 0.2em;
  text-transform: uppercase;
}

.app-nav__brand small {
  margin-top: 0.1rem;
  color: var(--text-muted);
  font-size: 0.7rem;
}

.app-nav__brand-mark {
  width: 2rem;
  height: 2rem;
  display: inline-grid;
  place-items: center;
  border: 1px solid var(--accent-primary);
  background: transparent;
  color: var(--accent-primary);
  font-weight: 700;
  font-size: 0.72rem;
}

.app-nav__links {
  display: flex;
  align-items: center;
  gap: 0;
  flex-wrap: wrap;
}

.app-nav__links a {
  padding: 0.5rem 0.8rem;
  border: 1px solid var(--border-soft);
  color: var(--text-muted);
  background: transparent;
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  margin-left: -1px;
}

.app-nav__links a:first-child {
  margin-left: 0;
}

.app-nav__links a.router-link-active,
.app-nav__links a:hover {
  color: #000;
  border-color: var(--accent-primary);
  background: var(--accent-primary);
}

@media (max-width: 760px) {
  .app-nav {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
