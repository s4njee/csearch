<template>
  <li class="mb-6">
    <div class="billVoteContainer">
      <a
        v-bind:href="
          'https://www.govtrack.us/congress/bills/' +
          congress +
          '/' +
          billType +
          billNumber
        "
        class="billLink"
      >
        <h2 class="billTitle">{{ officialTitle }}</h2>
      </a>
    </div>

    <p v-html="billSummary.Text" class="billSummary text-white text-xs" />
    <div v-if="bigSummary">
      <button
        v-if="collapsed && billSummary.Text"
        @click="loadFullSummary"
        class="expandBtn"
      >
        Expand +
      </button>
      <button
        v-else-if="!collapsed && billSummary.Text"
        @click="collapseSummary"
        class="expandBtn"
      >
        Collapse -
      </button>
    </div>
    <hr class="horizontalRule" />
    <div class="text-white">
      <table class="actionItemTable">
        <h5 class="actionItemHeader font-bold">Action items</h5>
        <Actionitems
          v-for="action in actionItems"
          :acted-at="action.ActedAt"
          :action-text="action.Text"
        ></Actionitems>
      </table>
      <div class="detailsGrid">
        <table class="sponsorTable">
          <h5 class="sponsorHeader font-bold">Sponsors</h5>
          <Sponsors
            v-for="sponsor in sponsors"
            :sponsor-name="sponsor.Name"
          ></Sponsors>
        </table>
        <table class="cosponsorTable">
          <h5 class="cosponsorHeader font-bold">Cosponsors</h5>
          <Cosponsors
            v-for="cosponsor in cosponsors"
            :cosponsor-name="cosponsor.Name"
          ></Cosponsors>
        </table>
      </div>
    </div>
  </li>
</template>

<script>
import Actionitems from "~/components/Actionitems.vue";
import Sponsors from "~/components/Sponsors.vue";
import Cosponsors from "~/components/Cosponsors.vue";

export default {
  components: { Actionitems, Sponsors, Cosponsors },
  props: [
    "congress",
    "billType",
    "billNumber",
    "officialTitle",
    "billSummary",
    "actionItems",
    "sponsors",
    "cosponsors",
    "billid",
    "votes",
  ],
  data() {
    return {
      collapsed: false,
      bigSummary: false,
    };
  },
  methods: {
    loadFullSummary() {
      this.collapsed = false;
      this.displayedSummary = this.billSummary.Text;
    },
    collapseSummary() {
      this.collapsed = true;
      this.displayedSummary = this.billSummary.Text.substring(0, 600);
    },
  },
};
</script>

<style>
.billVoteContainer {
  display: flex;
}

.detailsGrid {
  display: grid;
  grid-template-columns: 50% 50%;
  list-style: none;
  text-align: left;
  column-gap: 0.5em;
  align-items: self-start;
}

.billTitle {
  padding-bottom: 0;
  font-size: 1.1em;
  font-weight: 400;
  line-height: 1.3;
}

.billLink h2 {
  margin-bottom: 0;
}

.billSummary {
  margin-top: 0.25em;
  margin-bottom: 0.25em;
  color: var(--text-muted);
}

.billSummary p {
  margin-top: 0;
  margin-bottom: 0;
}

.billSummary p + p {
  margin-top: 0;
  color: var(--text-muted);
}

.billLink {
  color: var(--text-main);
  text-decoration: none;
}

.billLink:hover {
  color: var(--accent-house);
  text-decoration: underline;
  text-underline-offset: 2px;
}

.expandBtn {
  background: transparent;
  border: 1px solid var(--border-soft);
  color: var(--text-muted);
  padding: 0.3rem 0.6rem;
  cursor: pointer;
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.1em;
}

.expandBtn:hover {
  border-color: var(--accent-primary);
  color: var(--accent-primary);
}

.actionItemTable tr td {
  display: block;
  text-align: left;
  vertical-align: top;
  font-size: 11px;
  padding-left: 0;
}

.actionItemDate {
  margin-bottom: -1px;
  padding-bottom: 0;
  font-weight: bold;
}

.actionItemText {
  padding-top: 0;
  padding-bottom: 2px;
  color: var(--text-muted);
}

.actionItemHeader,
.sponsorHeader,
.cosponsorHeader {
  margin-top: 0.25em;
  margin-bottom: -0.25em;
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--accent-dim);
}

.sponsorTable tr td,
.cosponsorTable tr td {
  display: block;
  text-align: left;
  vertical-align: top;
  font-size: 11px;
  padding-left: 0;
}

.horizontalRule {
  margin: 8px 20% 0 20%;
  border: none;
  border-top: 1px solid var(--border-soft);
}
</style>
