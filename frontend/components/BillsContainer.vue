<template>
  <NavBar class="text-center" />
  <SearchBar @fetchSQL="searchfunc" />

  <div class="billsContainer flex justify-center">
    <div class="w-full max-w-5xl mx-auto px-4">
      <h1
        id="category"
        class="text-white text-center text-2xl font-light mb-6 mt-4 tracking-tight"
      >
        {{ billTitles[category] }}
      </h1>
      <h2 v-if="!loading && bills.length == 0" id="noResults">
        No results found
      </h2>
      <h2 v-if="loading" id="loading">Loading ...</h2>
      <transition-group tag="ul" name="billList" id="billsArray">
        <Bill
          v-if="!loading"
          v-for="bill in bills"
          :key="bill.billid"
          :congress="bill.congress"
          :bill-type="bill.billtype"
          :bill-number="bill.billnumber"
          :official-title="bill.officialtitle"
          :bill-summary="bill.summary"
          :action-items="bill.actions"
          :sponsors="bill.sponsors"
          :cosponsors="bill.cosponsors"
          :billid="bill.billid"
          :votes="bill.votes"
        />
      </transition-group>
    </div>
  </div>
</template>

<script setup>
import NavBar from "~/components/NavBar.vue";
import SearchBar from "~/components/SearchBar.vue";
import Bill from "~/components/Bill.vue";
import { useRoute } from "vue-router";
import { ref, watch } from "vue";

// The browser can override this at runtime via /runtime-config.js, so the same
// image can be reused across clusters without rebuilding for each API target.
const API_SERVER = useApiBase();
const route = useRoute();

const loading = ref(false);
const category = ref(route.params.category || "s");
const bills = ref([]);
const query = ref(typeof route.query.query === "string" ? route.query.query : "");
const searchFilter = ref(
  typeof route.query.sort === "string" ? route.query.sort : "relevance"
);

const billTitles = {
  s: "S",
  sconres: "S.Con.Res",
  sjres: "S.J.Res",
  sres: "S.Res",
  hr: "H.R.",
  hconres: "H.Con.Res",
  hjres: "H.J.Res",
  hres: "H.Res",
};

async function latestCategory(categoryValue) {
  category.value = categoryValue;
  loading.value = true;
  const response = await fetch(`${API_SERVER}/latest/${category.value}`);
  bills.value = await response.json();
  loading.value = false;
}

async function fetchBills() {
  loading.value = true;
  const response = await fetch(
    `${API_SERVER}/search/${category.value}/${searchFilter.value}?query=${encodeURIComponent(query.value)}`
  );
  bills.value = await response.json();
  loading.value = false;
}

async function loadResults() {
  if (query.value.trim() === "") {
    await latestCategory(category.value);
  } else {
    await fetchBills();
  }
}

function searchfunc(queryValue, searchFilterValue) {
  query.value = queryValue;
  searchFilter.value = searchFilterValue;
  fetchBills();
}

watch(
  () => [route.params.category, route.query.query, route.query.sort],
  async ([newCategory, newQuery, newSort]) => {
    category.value = newCategory || "s";
    query.value = typeof newQuery === "string" ? newQuery : "";
    searchFilter.value = typeof newSort === "string" ? newSort : "relevance";
    await loadResults();
  },
  { immediate: true }
);
</script>
<style scoped>
#loading,
#noResults {
  text-align: center;
  color: var(--text-muted);
  font-size: 0.82rem;
  text-transform: uppercase;
  letter-spacing: 0.1em;
}

#billsArray {
  display: grid;
  grid-template-columns: 50% 50%;
  list-style: none;
  text-align: left;
  column-gap: 1px;
  align-items: self-start;
}

.billList-enter-from {
  opacity: 0;
}

.billList-enter-active {
  transition: opacity 0.2s ease-out;
}

.billList-enter-to {
  opacity: 1;
}

.billList-leave-from {
  opacity: 1;
}

.billList-leave-active {
  transition: opacity 0.2s ease-out;
}

.billList-leave-to {
  opacity: 0;
}

@media (max-width: 900px) {
  #billsArray {
    grid-template-columns: 1fr;
  }
}
</style>
