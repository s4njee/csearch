# CSearch — Ambitious Ideas

**North star:** evolve CSearch from a *congressional search engine* into a **legislative
intelligence platform** — the fastest, most trustworthy way for journalists, researchers,
staffers, and citizens to understand what Congress is doing and why.

These are big swings, not polish items (those live in `TODO.md`). Each is grounded in what
already exists: hybrid retrieval (RRF keyword + vector), ~2.8M pgvector embeddings, the
Rust+GovInfo scraper, the `nlp` pipeline, the RAG `query.py`, and the Nuxt frontend.

---

## 1. AI-native legislative intelligence
*Builds directly on the embeddings + hybrid retrieval + RAG you already run.*

- **Conversational legislative analyst.** Full RAG chat over bills, votes, and members with
  inline citations: *"How has Congress addressed PFAS contamination since 2015?"* → a grounded
  answer linking the exact bills and roll-call votes. Extends `query.py` into a first-class
  product surface with streaming answers and "show your sources."
- **Multi-level bill summaries.** Auto-generate ELI5 / standard / expert / "what changed since
  the last version" summaries per bill, cached and embedded. A reading-level toggle in the UI
  makes dense legislative text accessible without losing rigor.
- **Semantic alerts ("legislative radar").** A user subscribes to a *natural-language* topic
  ("offshore wind permitting reform"); a nightly job embeds new/changed bills and pushes matches
  via email / RSS / webhook. Turns one-shot search into continuous monitoring — the killer
  feature for staffers and advocacy groups.
- **"Explain this vote."** An LLM narrates what a roll-call vote actually did, who crossed party
  lines, and what was at stake — grounded in the vote record + linked bill. Demystifies the part
  of Congress people understand least.
- **Bill lineage & semantic diff.** Detect text reuse across bills and congresses (companion
  bills, reintroductions, language lifted from prior legislation) via embedding similarity +
  structural diffing. Surfaces "this 'new' bill is 80% a 2019 bill that died in committee."

## 2. Data & coverage moonshots
*Depth and breadth that competitors don't have.*

- **Full-text ingestion.** Chunk + embed the *complete bill text*, not just titles/summaries —
  plus committee reports, CRS reports, the Congressional Record, and hearing transcripts.
  Transforms retrieval quality and unlocks "find the clause, not just the bill."
- **Follow-the-influence linking.** Connect bills to FEC campaign finance, lobbying disclosures
  (LDA), and news coverage. "Who funded the sponsors of this bill, and who lobbied on it?"
- **U.S. Code citation graph.** Parse bill cross-references to the U.S. Code and build a citation
  graph: *"which bills amend 42 USC § 300f?"* Legislation becomes navigable as a knowledge graph.
- **State legislatures.** Point the same pipeline at state-level bills (e.g. OpenStates) for
  federated, cross-jurisdiction search — a genuinely national legislative search engine.
- **Near-real-time pipeline.** Move from nightly batch to streaming ingestion so new bills and
  votes appear within minutes of GovInfo/Congress.gov updates.

## 3. Analytics & modeling
*Turn the corpus into insight, not just retrieval.*

- **Legislator embeddings & ideology maps.** Learn vote-based and text-based legislator
  embeddings; render interactive 2D ideology/topic maps (a learned, continuously-updated take on
  DW-NOMINATE). Cluster members, spot coalitions, track drift over a career.
- **Passage-probability model.** Predict a bill's odds of advancing/passing from sponsorship,
  committee assignment, cosponsor velocity, and historical analogs — with the analogs shown.
- **Whip-count / vote prediction.** Predict how individual members will vote on upcoming
  legislation, with confidence and the signals driving it.
- **Topic trend intelligence.** Track how legislative attention to topics shifts over time, by
  chamber and party — a "Google Trends for Congress."

## 4. Platform & ecosystem
*Make CSearch infrastructure others build on.*

- **Public API + MCP server.** Expose CSearch as a developer API *and* a Model Context Protocol
  server so LLM agents (Claude, etc.) can query U.S. legislation as a first-class tool. Very high
  leverage given the unique, well-structured corpus.
- **Personalized dashboards.** Saved searches, watched bills/members, custom alert rules, and
  exportable briefings tailored to journalists, researchers, and advocacy orgs.
- **Embeddable widgets + browser extension.** Drop-in bill/vote cards for newsrooms; an extension
  that annotates any news article with the bills and votes it references.
- **Open data + self-hostable.** Package the whole stack (scraper → embeddings → hybrid search)
  as a reproducible, open release so others can run their own instance or audit the methodology.

## 5. Engineering ambition
*Cost, quality, and rigor at scale.*

- **Open / self-hosted embedding models.** Swap `text-embedding-3-small` for a self-hosted open
  model to cut OpenAI cost at 2.8M+ vectors; A/B against the current model via the eval harness
  before any cutover.
- **Learned reranking.** Add a cross-encoder reranker on top of RRF, and grow `eval_set.json`
  from a handful of queries to a real benchmark so retrieval gains are *measured*, not assumed.
- **Multi-vector / late-interaction retrieval.** Explore ColBERT-style late interaction for
  clause-level precision on long bill text.
- **Continuous eval & regression gates.** Treat retrieval quality like a test suite: golden
  queries, recall/MRR dashboards, and CI gates that block regressions (the eval harness is the
  seed of this).

---

### Highest leverage to start
If picking three to prove the vision quickly:
1. **Conversational analyst with citations** — showcases the embeddings + hybrid retrieval you
   already shipped.
2. **Semantic alerts** — turns search into a recurring-value product.
3. **Public API + MCP server** — minimal new modeling, maximal reach, and rides today's agent wave.
