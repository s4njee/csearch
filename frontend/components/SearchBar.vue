<template>
  <div class="searchbar-shell">
    <div class="searchbar-card">
      <div class="search-input-wrap">
        <input
          v-model="query"
          v-on:keyup.enter="fetchSQL(query, searchFilter)"
          id="search"
          class="search-input"
          placeholder="Search within this bill category"
        />
      </div>
      <div id="radioButtons" class="search-options">
        <label>
          <input
            type="radio"
            id="relevance"
            value="relevance"
            v-model="searchFilter"
            v-on:change="fetchSQL(query, searchFilter)"
          />
          <span>Relevance</span>
        </label>
        <label>
          <input
            type="radio"
            id="date"
            value="date"
            v-model="searchFilter"
            v-on:change="fetchSQL(query, searchFilter)"
          />
          <span>Date</span>
        </label>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: "Search.vue",
  data() {
    return {
      searchFilter: "relevance",
      query: "",
    };
  },
  mounted() {
    const route = this.$route;
    this.query = typeof route.query.query === "string" ? route.query.query : "";
    this.searchFilter =
      typeof route.query.sort === "string" ? route.query.sort : "relevance";
  },
  watch: {
    '$route.query': {
      handler(query) {
        this.query = typeof query.query === "string" ? query.query : "";
        this.searchFilter =
          typeof query.sort === "string" ? query.sort : "relevance";
      },
      deep: true,
    },
  },
  methods: {
    fetchSQL(query, searchFilter) {
      this.$emit("fetchSQL", query, searchFilter);
    },
  },
};
</script>

<style scoped>
.searchbar-shell {
  display: flex;
  justify-content: center;
  margin: 0.5rem 0;
  padding: 0 1rem;
}

.searchbar-card {
  width: min(100%, 1040px);
  display: flex;
  gap: 0.75rem;
  align-items: center;
  padding: 0.75rem;
  background: var(--bg-panel);
  border: 1px solid var(--border-soft);
}

.search-input-wrap {
  flex: 1;
}

.search-input {
  width: 100%;
  border: 1px solid var(--border-soft);
  border-radius: 0;
  background: var(--bg-panel-strong);
  color: var(--text-main);
  padding: 0.7rem 0.75rem;
}

.search-input:focus {
  outline: none;
  border-color: var(--accent-primary);
}

.search-options {
  display: flex;
  gap: 0.75rem;
  flex-wrap: wrap;
  text-align: left;
  font-size: 0.82rem;
  color: var(--text-muted);
}

.search-options label {
  display: flex;
  align-items: center;
  gap: 0.3rem;
}

@media (max-width: 720px) {
  .searchbar-card {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>
