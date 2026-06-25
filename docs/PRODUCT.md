# Product Surface

CSearch exposes several ways to ask questions of the congressional corpus.
Without a shared model they blur together — users don't know when to browse,
search, or use Explore, and the API drifts into a pile of overlapping endpoints.
This document defines five product verbs and maps each to the routes and UI that
serve it. New work (vote embeddings, generated answers, saved searches) should
slot into one of these verbs.

_Last verified against code: 2026-05-30._

## The five verbs

| Verb | User intent | API surface | UI |
| --- | --- | --- | --- |
| **Browse** | "Show me what's recent / filtered" | `GET /latest/{billtype}`, `GET /votes/{chamber}` | latest lists, vote lists |
| **Find** | "Take me to this exact thing" | `GET /bills/{type}/{congress}/{number}`, `GET /bills/bynumber/{n}`, `GET /members/{bioguide}`, `GET /committees/{code}`, `GET /representatives/{zip}` | direct lookups |
| **Search** | "What's relevant to this topic/phrase?" | `GET /search/{type}/{filter}` (keyword/fuzzy), `POST /search/semantic` (vector) | search box |
| **Analyze** | "Show me a curated metric/chart" | `GET /explore`, `GET /explore/{query}` | Explore page |
| **Answer** | "Answer my question with citations" | *(not yet shipped)* | — |

## Search routing

Search is the verb most prone to sprawl, so routing is explicit. The classifier
in [`backend/api/src/csearch_api/routing.py`](../backend/api/src/csearch_api/routing.py)
decides per query:

- **exact** — a bill citation like `HR 42` → direct lookup, **no OpenAI call**.
  Implemented inside `POST /search/semantic` (it short-circuits) and reusable by
  the frontend.
- **keyword** — short or quoted queries → full-text/fuzzy (`search_bills`).
- **semantic** — natural-language policy questions → vector retrieval, and
  eventually hybrid (keyword + vector RRF, see `csearch_api.hybrid`).

Choosing the cheapest surface that serves the intent both improves exactness and
bounds OpenAI spend.

## Answer (RAG) — deliberately not shipped yet

Generated answers come last, and only after retrieval quality is *measured*
(see [`backend/nlp/eval`](../backend/nlp/eval)). When added, the answer route must:

- return citations: source bill ids and quoted evidence spans,
- support an explicit "insufficient evidence" response,
- enforce the same length cap, rate limit, and cost guardrails as semantic search,
- be evaluated against the eval set before traffic is switched.

## Roadmap alignment

- **Vote embeddings** extend **Search** (and later **Answer**) to votes. The
  `nlp.vote_*` tables and the upserter `--mode votes` path already exist behind a
  measured API contract.
- **Saved searches** extend **Browse**/**Search** with persistence.
- **Hybrid ranking** is an internal improvement to **Search**, gated on the eval
  harness showing a recall/MRR win without a latency regression.
