<template>
  <div class="flex justify-center">
    <div id="navbar">
      <div class="sectionSwitch mb-3">
        <NuxtLink to="/" :class="{ activeSection: !isVotesPage }">Bills</NuxtLink>
        <span class="divider">·</span>
        <NuxtLink :to="{ path: '/votes', query: { chamber: voteChamber } }" :class="{ activeSection: isVotesPage }">Votes</NuxtLink>
      </div>

      <template v-if="isVotesPage">
        <h6 class="navbarHeader font-bold">Chamber:</h6>
        &nbsp;
        <NuxtLink :to="{ path: '/votes', query: { chamber: 'senate', ...(searchQuery ? { q: searchQuery } : {}) } }" class="link--senate">Senate</NuxtLink>
        |
        <NuxtLink :to="{ path: '/votes', query: { chamber: 'house', ...(searchQuery ? { q: searchQuery } : {}) } }" class="link--house">House</NuxtLink>
      </template>

      <template v-else>
        <h6 class="navbarHeader navbarHeader--senate font-bold">Senate:</h6>
        &nbsp;
        <NuxtLink to="/bills/s" class="link--senate">s</NuxtLink>
        |
        <NuxtLink to="/bills/sconres" class="link--senate">sconres</NuxtLink>
        |
        <NuxtLink to="/bills/sjres" class="link--senate">sjres</NuxtLink>
        |
        <NuxtLink to="/bills/sres" class="link--senate">sres</NuxtLink>
        <br/>
        <h6 class="navbarHeader navbarHeader--house font-bold">House:</h6>
        &nbsp;
        <NuxtLink to="/bills/hr" class="link--house">hr</NuxtLink>
        |
        <NuxtLink to="/bills/hconres" class="link--house">hconres</NuxtLink>
        |
        <NuxtLink to="/bills/hjres" class="link--house">hjres</NuxtLink>
        |
        <NuxtLink to="/bills/hres" class="link--house">hres</NuxtLink>
      </template>
    </div>
  </div>
</template>

<script setup>
const route = useRoute();

const isVotesPage = computed(() => route.path.startsWith('/votes'));
const voteChamber = computed(() => {
  const raw = typeof route.query.chamber === 'string' ? route.query.chamber.toLowerCase() : 'senate';
  return raw === 'house' ? 'house' : 'senate';
});
const searchQuery = computed(() => typeof route.query.q === 'string' ? route.query.q : '');
</script>

<style scoped>
.navbarHeader {
  color: var(--accent-dim);
  display: inline;
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.12em;
}

.navbarHeader--senate {
  color: var(--accent-senate);
}

.navbarHeader--house {
  color: var(--accent-house);
}

#navbar a {
  color: var(--text-muted);
  text-decoration: none;
  font-size: 0.82rem;
}

#navbar a:hover {
  color: var(--accent-house);
  text-decoration: underline;
  text-underline-offset: 2px;
}

#navbar .link--senate {
  color: rgba(79, 142, 247, 0.75);
}

#navbar .link--senate:hover {
  color: var(--accent-house);
}

#navbar .link--house {
  color: rgba(224, 82, 82, 0.75);
}

#navbar .link--house:hover {
  color: var(--accent-house);
}

.sectionSwitch {
  color: var(--text-muted);
  font-size: 0.82rem;
  text-transform: uppercase;
  letter-spacing: 0.12em;
}

.divider {
  margin: 0 0.4rem;
}

.activeSection {
  font-weight: 700;
  color: var(--accent-primary) !important;
}

.router-link-active {
  font-weight: bold;
  color: var(--accent-primary) !important;
}
</style>
