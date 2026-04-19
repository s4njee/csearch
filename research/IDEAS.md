# Ideas to make csearch interesting for non-political visitors

The site today is a serious research tool: search bills, look up votes, drill into members and committees. That's great for policy nerds, journalists, and hill staff — but a casual visitor who doesn't care about politics has no reason to stay past the landing page. This doc collects ideas for lowering the activation energy and giving that visitor something to click, share, or come back for.

The data we already have is richer than the current UI suggests: 130+ years of bills, every roll-call vote since the 101st Congress, member biographies, committee rosters, plus NLP embeddings of the full bill text. Most ideas below reuse what's already in Postgres — no new ingest required.

---

## 1. Discovery / serendipity

Casual users don't know what to search for. Give them something to stumble into.

- **Bill of the day** — random public law on the landing page. Short title, 2-sentence AI summary (we have embeddings already, adding a summary field is cheap), link to full text. Rotates daily. Shareable URL.
- **"Weird bills" gallery** — curated or auto-surfaced bills with unusually short/long titles, strange subjects (post office renamings, commemorative coins, national X day resolutions), or single-sponsor bills that went nowhere. Congress produces a *lot* of absurd legislation and nobody sees it.
- **Shuffle button** on every list page. One click → a random bill/vote/member. No decision required from the user.
- **"On this day in Congress"** — bills introduced, votes taken, or members sworn in on today's date across all years. Rotates naturally with the calendar; good for daily return traffic.

## 2. Humanize the data

Bills and roll-call vote IDs feel like spreadsheet rows. People engage with stories and faces.

- **Member profile upgrades** — photo (congress.gov has them), home state, years served, a timeline band showing when they were in office relative to major historical events, "most common co-sponsors" (friend graph). Turn a bioguide page into something resembling a sports player card.
- **"Who represents you?"** — zip-code or address lookup → current House + Senate members with their recent votes. This is the single most common question non-political people have about Congress and we already have the data to answer it.
- **Longest-serving, youngest-ever, firsts** — superlative lists. People love superlatives. First woman in X committee, longest filibuster, oldest sitting member, etc.

## 3. Make votes visual

Roll-call votes are currently a tabular wall. Charts are more fun and more shareable.

- **Vote breakdown as a hemicycle** (the half-circle seating chart you see on Wikipedia for parliament votes). We already have `VoteBreakdownChart.client.vue` — extend it. Color by party, hover for member name.
- **"How close was this vote?"** — a margin visualization for every vote. Surfaces dramatic near-ties and unanimous votes as equally interesting endpoints.
- **Party unity / crossover highlights** — the explore query `party-line-crossovers` already exists; put it on the landing page as "Members who broke with their party this month." This is politically neutral and genuinely interesting as social data.

## 4. Pop-culture / comedy hooks

- **Named-after-a-person bills** — surface all the "Jessica's Law" / "[Name] Act" bills. Click through to the story behind the name. Also a natural place for a search like "bills named after athletes / celebrities / victims".
- **Commemorative resolutions gallery** — National Peanut Butter Day, etc. These are usually H.Res. and S.Res. Already in the data, just need a filter.
- **Post office renamings map** — there are literally thousands of bills that only rename a post office. Plot them on a US map. Silly, but it's the kind of thing people tweet.
- **Unusually short bills** — one-sentence bills. A fun scroll. Contrast with...
- **Unusually long bills** — ordered by word count. "The longest bill ever passed by Congress was X pages" is a reliable trivia hit.

## 5. Personalization / "about me"

Quizzes and personal-relevance features dominate viral traffic. Most of these are one-screen features built on existing data.

- **"Which member of Congress are you?"** — short quiz (10 policy positions) → closest-matching member by voting record. Shareable result card.
- **"A bill from the year you were born"** — enter a birth year, get a notable bill from that Congress. We have coverage back to 1873.
- **Saved searches / email digest** — let users follow a topic (e.g. "student loans") and get a weekly email when new matching bills move. Turns drive-by traffic into returning users. Requires auth infra we don't currently have — bigger lift.

## 6. Semantic search, dressed for casual users

We have bill embeddings sitting in `nlp.bill_embeddings` but the current UX is "search box → results list," which is the same affordance every other site has.

- **"Find bills that sound like this"** — paste any text (a news article, a tweet, a paragraph from a book) and get the top semantically similar bills. This is a killer demo that costs us ~one embedding call per query.
- **"Bills like this one"** — a related-bills rail on every bill page. People browse Wikipedia through "see also"; bills deserve the same.
- **Topic clusters** — cluster the embeddings and surface the clusters as browsable topic pages ("guns," "crypto," "veterans"). Turns semantic search into editorial browsing without hand-curation.

## 7. Shareability

Every feature above needs a "send this to a friend" path. None of the current pages have good OG image generation or compact shareable summaries.

- **Per-bill OG card** — generate a PNG with the bill number, short title, sponsor, and status. Served at `/og/bill/:id.png`. Makes every link shared in Slack/iMessage look good.
- **Permalink-friendly explore queries** — the explore page already has parameterized queries; make sure every run produces a URL that reproduces the result so people can share "look at this weird thing I found."

## 8. Low-effort data journalism

Once a week or month, pick a number from the DB and turn it into a blurb on the landing page. Examples:

- "Congress has passed N post office renaming bills this year."
- "The average bill in the current Congress is N pages long, up from M a decade ago."
- "X% of roll-call votes this month were along party lines."

These write themselves from SQL and give the site the feel of something alive rather than a static search index.

---

## Priority suggestion

If we want the biggest casual-visitor lift for the least engineering:

1. **"Who represents you?" zip-code lookup** (1–2 days, leverages existing member data, answers the #1 non-political-person question about Congress).
2. **Bill of the day + On this day in Congress** on the landing page (1 day, pure SQL + cron).
3. **"Find bills that sound like this"** semantic paste box (1 day, reuses existing embedding pipeline, genuinely novel demo).
4. **OG images per bill/vote/member** (1–2 days, unlocks organic sharing for everything else).

Everything else in this doc builds on those four.
