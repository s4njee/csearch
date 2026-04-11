# CSearch NLP — Natural Language Bill Search

A standalone RAG service for semantic search over U.S. Congressional legislation, deployed to the `mars` K8s context.

---

## 1. Problem Statement

CSearch uses PostgreSQL full-text search (`tsvector` with GIN indexes) over `shorttitle` and `summary->>'Text'`. This handles keyword queries but fails on semantic queries:

- "bills that would make it harder for companies to pollute rivers"
- "legislation protecting gig workers from being classified as independent contractors"
- "what has Congress done about prescription drug prices since 2020"

A RAG pipeline combines vector similarity search with LLM-powered answer generation to handle natural language questions against the full text of 50+ years of Congressional legislation.

This is a **standalone project** — separate repo, separate namespace (`csearch-nlp`), read-only access to the existing CSearch PostgreSQL database, with its own Qdrant vector database and API surface.

---

## 2. Deployment Target

### Hardware: Single VPS (4 CPU / 8 GB RAM)

All services run on the same `worker1` node alongside existing CSearch workloads. This constrains the architecture in important ways — see Section 4 for how we size Qdrant to fit.

### K8s context: `mars`

The `mars` context is the dev/staging environment. All commands in this document assume:

```bash
kubectl config use-context mars
```

The existing CSearch infrastructure uses the `netcup` context for production. The NLP service deploys to its own namespace (`csearch-nlp`) within the same cluster but is developed and tested against `mars` first.

### Existing infrastructure (shared)

| Resource | Details |
|---|---|
| **K8s cluster** | Single node (`worker1`), context `netcup` (prod) / `mars` (dev) |
| **PostgreSQL** | `postgres:15.1`, ClusterIP `postgres-service:5432`, db `csearch`, NFS-backed 30Gi |
| **NFS server** | `10.0.0.3`, paths under `/srv/nfs/temp/` |
| **Container registry** | `10.0.0.3:30252` |
| **Container UID** | All containers run as `1000:1000` (non-root) |
| **Redis** | Existing CSearch Redis (shared, use `nlp:` key prefix) |

---

## 3. Architecture Overview

```
                    ┌─────────────────────────────┐
                    │    CSearch Frontend (Nuxt)   │
                    │    or any HTTP client         │
                    └──────────────┬──────────────┘
                                   │
                          POST /api/nlp/search
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│              csearch-nlp service (namespace: csearch-nlp)         │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                     RAG Orchestrator                        │  │
│  │                                                            │  │
│  │  1. Query classifier — extract filters, classify intent    │  │
│  │  2. Embed query (text-embedding-3-small)                   │  │
│  │  3. Retrieve from Qdrant (filtered ANN, on-disk HNSW)      │  │
│  │  4. Keyword search against PostgreSQL tsvector (parallel)   │  │
│  │  5. Reciprocal Rank Fusion to merge results                │  │
│  │  6. Cross-encoder re-rank (ms-marco-MiniLM-L-12-v2)        │  │
│  │  7. Hydrate bill metadata from PostgreSQL                  │  │
│  │  8. Stream LLM response (Claude Sonnet)                    │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Redis (shared, nlp: prefix): embedding + result + LLM cache    │
└──────────┬──────────────────┬──────────────────┬────────────────┘
           │                  │                  │
           ▼                  ▼                  ▼
    ┌────────────┐    ┌──────────────┐   ┌──────────────┐
    │ PostgreSQL  │    │   Qdrant     │   │   LLM API    │
    │ (existing,  │    │ (on-disk     │   │ (Claude via  │
    │  read-only) │    │  HNSW mode)  │   │  Anthropic)  │
    └────────────┘    └──────────────┘   └──────────────┘
           │
     read-only
           ▼
    ┌────────────┐
    │  GovInfo   │
    │ (full bill │
    │  text XML) │
    └────────────┘
```

---

## 4. Fitting Qdrant on 4 CPU / 8 GB RAM

### The constraint

With full bill text, the corpus is ~55M chunks. At 1536 dimensions with INT8 quantization, the HNSW graph + quantized vectors need ~4–6 GB of RAM. That doesn't leave room for anything else on an 8 GB machine.

### The strategy: on-disk HNSW + selective corpus + dev machine pre-build

**A) Reduce the corpus to high-value chunks (~5–10M vectors)**

Not all chunks are equally useful. Prioritize:

| Chunk type | Include? | Rationale |
|---|---|---|
| Title | Yes (all bills) | Highest signal-to-noise. ~500K chunks. |
| Summary | Yes (all bills) | Dense overview. ~1M chunks. |
| Full-text sections (latest version only) | Yes | Skip earlier drafts. Cuts versions by ~3–4x. |
| Boilerplate sections (effective date, severability, authorization of appropriations) | No | Low semantic value, wastes vector space. |
| Definitions sections | Yes | High value for "how does the bill define X" queries. |
| Actions timeline | Yes | Enables "what happened to this bill" queries. ~1.5M chunks. |
| Sponsor block | Yes | Enables "bills by [person]" queries. ~500K chunks. |

**Estimated total after filtering: ~8M chunks.** This is a 7x reduction from the naive "embed everything" approach with minimal retrieval quality loss — the dropped content (old bill versions, boilerplate) rarely matches real user queries.

**B) Run Qdrant in memory-mapped on-disk mode**

```yaml
# Qdrant collection config: vectors and HNSW index live on SSD,
# OS page cache handles hot segments in RAM
vectors:
  content:
    size: 1536
    distance: Cosine
    on_disk: true          # vectors on SSD, not RAM

hnsw_config:
  on_disk: true            # HNSW graph index on SSD too
  m: 16
  ef_construct: 100        # lower than default 200 to save memory
  payload_m: 16

quantization_config:
  scalar:
    type: int8
    quantile: 0.99
    always_ram: true        # only the quantized vectors stay in RAM (~1.2GB for 8M vectors)
```

At 8M vectors with INT8 quantization in RAM and everything else on disk:

| Component | Memory |
|---|---|
| Quantized vectors (8M × 1536 × 1 byte) | ~1.2 GB |
| HNSW graph metadata (on-disk, page-cached) | ~0.5 GB hot set |
| Qdrant process overhead | ~0.3 GB |
| **Total Qdrant** | **~2 GB** |

That leaves ~6 GB for the OS, PostgreSQL, the NLP API, the cross-encoder model, and Redis. Comfortable.

**Expected query latency:** ~100–200ms (vs. ~30–50ms with full in-RAM index). For a search application, this is fine.

**C) Use a dev machine for heavy batch operations**

The initial corpus embedding and any re-embedding jobs are CPU and memory intensive. Run these on your dev machine, not on the VPS.

```bash
# On dev machine: run the embedding pipeline, pointing at the VPS Qdrant
# via kubectl port-forward or direct NodePort

kubectl --context mars port-forward svc/qdrant 6333:6333 -n csearch-nlp &

export QDRANT_HOST=localhost
export QDRANT_PORT=6333
export PG_CONNECTION_STRING="postgresql://csearch_readonly:...@152.53.120.31:5432/csearch"

python -m csearch_nlp.pipeline batch --workers 4 --congress-range 93-118
```

The batch pipeline streams vectors to Qdrant over the port-forward. The dev machine does the heavy lifting (XML parsing, chunking, embedding API calls), and only the final vectors get sent to the VPS. After the initial batch, nightly incremental syncs are light enough to run on the VPS itself.

---

## 5. Full-Text Data Acquisition

### Source: GovInfo Bulk Data

Full bill text is available from the U.S. Government Publishing Office:

```
https://www.govinfo.gov/bulkdata/BILLS/{congress}/{billtype}/
```

Each bill is available in XML with section headers, amendment markers, and structural metadata.

### Fetcher design

```
┌──────────────┐     ┌────────────────┐     ┌──────────────────┐
│ PostgreSQL    │────▶│ Full-text       │────▶│ NFS storage      │
│ (read-only)  │     │ fetcher         │     │ /srv/nfs/temp/   │
│              │     │                 │     │   nlp-fulltext/  │
│ SELECT billid│     │ 1. Check cache  │     │   {congress}/    │
│ WHERE no     │     │ 2. Fetch XML    │     │   {type}/        │
│ fulltext     │     │    from GovInfo │     │   {bill}.xml     │
└──────────────┘     │ 3. Parse + store│     └──────────────────┘
                     └────────────────┘
```

**Storage:** NFS volume on `10.0.0.3` at `/srv/nfs/temp/nlp-fulltext/` — same NFS server as the existing congress data. Estimated ~15–20 GB for all bill XML.

**Bill versions:** Embed only the **latest available version** of each bill (enrolled > engrossed > reported > introduced). This cuts the full-text chunk count by ~3–4x compared to embedding all versions, with minimal recall loss since users almost always care about the current state of a bill.

**Rate limiting:** GovInfo at ~10 requests/second with exponential backoff. Full bulk fetch ~3–5 hours from a dev machine with good bandwidth.

---

## 6. Qdrant Deployment on Mars

### Namespace

```yaml
# k8s/csearch-nlp/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: csearch-nlp
```

### Persistent Volume (NFS-backed, matching existing pattern)

```yaml
# k8s/csearch-nlp/qdrant-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: qdrant-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  nfs:
    server: 10.0.0.3
    path: /srv/nfs/temp/qdrant
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: qdrant-pvc
  namespace: csearch-nlp
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 50Gi
```

### Full-text cache PV

```yaml
# k8s/csearch-nlp/fulltext-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nlp-fulltext-pv
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  nfs:
    server: 10.0.0.3
    path: /srv/nfs/temp/nlp-fulltext
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nlp-fulltext-pvc
  namespace: csearch-nlp
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 20Gi
```

### Qdrant StatefulSet

```yaml
# k8s/csearch-nlp/qdrant-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: qdrant
  namespace: csearch-nlp
spec:
  serviceName: qdrant
  replicas: 1
  selector:
    matchLabels:
      app: qdrant
  template:
    metadata:
      labels:
        app: qdrant
    spec:
      nodeSelector:
        node: worker1
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
        - name: qdrant
          image: qdrant/qdrant:v1.12.1
          ports:
            - name: rest
              containerPort: 6333
            - name: grpc
              containerPort: 6334
          volumeMounts:
            - name: qdrant-storage
              mountPath: /qdrant/storage
          resources:
            requests:
              memory: "1.5Gi"
              cpu: "500m"
            limits:
              memory: "2Gi"
              cpu: "1"
          env:
            - name: QDRANT__SERVICE__GRPC_PORT
              value: "6334"
          livenessProbe:
            httpGet:
              path: /healthz
              port: 6333
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /readyz
              port: 6333
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:
        - name: qdrant-storage
          persistentVolumeClaim:
            claimName: qdrant-pvc
```

### Qdrant Service

```yaml
# k8s/csearch-nlp/qdrant-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: qdrant
  namespace: csearch-nlp
spec:
  selector:
    app: qdrant
  ports:
    - name: rest
      port: 6333
      targetPort: 6333
    - name: grpc
      port: 6334
      targetPort: 6334
  type: ClusterIP
```

---

## 7. NLP API Deployment on Mars

### Secrets

```yaml
# k8s/csearch-nlp/secrets.yaml (template — apply manually, do not commit real values)
apiVersion: v1
kind: Secret
metadata:
  name: csearch-nlp-secrets
  namespace: csearch-nlp
type: Opaque
stringData:
  pg-connection-string: "postgresql://postgres:postgres@postgres-service.default.svc.cluster.local:5432/csearch"
  embedding-api-key: "sk-..."
  llm-api-key: "sk-ant-..."
```

Note: The PG connection uses `postgres-service.default.svc.cluster.local` to reach the existing PostgreSQL in the `default` namespace from the `csearch-nlp` namespace.

### ConfigMap

```yaml
# k8s/csearch-nlp/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: csearch-nlp-config
  namespace: csearch-nlp
data:
  QDRANT_HOST: "qdrant.csearch-nlp.svc.cluster.local"
  QDRANT_PORT: "6333"
  QDRANT_COLLECTION: "bill_chunks"
  EMBEDDING_MODEL: "text-embedding-3-small"
  LLM_MODEL: "claude-sonnet-4-6"
  RAG_VECTOR_TOP_K: "40"
  RAG_RERANK_TOP_K: "10"
  RAG_SCORE_THRESHOLD: "0.35"
  RRF_K: "60"
  REDIS_URL: "redis://redis-service.default.svc.cluster.local:6379/1"
  CACHE_EMBEDDING_TTL: "86400"
  CACHE_SEARCH_TTL: "3600"
  CACHE_LLM_TTL: "3600"
  FULLTEXT_CACHE_DIR: "/data/fulltext"
  GOVINFO_RATE_LIMIT: "10"
```

### API Deployment

```yaml
# k8s/csearch-nlp/nlp-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: csearch-nlp-api
  namespace: csearch-nlp
spec:
  replicas: 1                    # single replica on 4CPU/8GB VPS
  selector:
    matchLabels:
      app: csearch-nlp-api
  template:
    metadata:
      labels:
        app: csearch-nlp-api
    spec:
      nodeSelector:
        node: worker1
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
      containers:
        - name: api
          image: 10.0.0.3:30252/csearch-nlp:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 8000
          envFrom:
            - configMapRef:
                name: csearch-nlp-config
          env:
            - name: PG_CONNECTION_STRING
              valueFrom:
                secretKeyRef:
                  name: csearch-nlp-secrets
                  key: pg-connection-string
            - name: EMBEDDING_API_KEY
              valueFrom:
                secretKeyRef:
                  name: csearch-nlp-secrets
                  key: embedding-api-key
            - name: LLM_API_KEY
              valueFrom:
                secretKeyRef:
                  name: csearch-nlp-secrets
                  key: llm-api-key
          volumeMounts:
            - name: fulltext-cache
              mountPath: /data/fulltext
          resources:
            requests:
              memory: "1Gi"
              cpu: "500m"
            limits:
              memory: "2Gi"
              cpu: "1"
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 10
            periodSeconds: 10
      volumes:
        - name: fulltext-cache
          persistentVolumeClaim:
            claimName: nlp-fulltext-pvc
```

### API Service

```yaml
# k8s/csearch-nlp/nlp-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: csearch-nlp-api
  namespace: csearch-nlp
spec:
  selector:
    app: csearch-nlp-api
  ports:
    - port: 8000
      targetPort: 8000
  type: ClusterIP
```

### Nightly Sync CronJob

```yaml
# k8s/csearch-nlp/nlp-sync-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: csearch-nlp-sync
  namespace: csearch-nlp
spec:
  schedule: "30 0 * * *"          # 00:30 daily, after goscraper finishes at midnight
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          nodeSelector:
            node: worker1
          securityContext:
            runAsUser: 1000
            runAsGroup: 1000
          containers:
            - name: nlp-sync
              image: 10.0.0.3:30252/csearch-nlp:latest
              imagePullPolicy: Always
              command: ["python", "-m", "csearch_nlp.pipeline", "sync"]
              envFrom:
                - configMapRef:
                    name: csearch-nlp-config
              env:
                - name: PG_CONNECTION_STRING
                  valueFrom:
                    secretKeyRef:
                      name: csearch-nlp-secrets
                      key: pg-connection-string
                - name: EMBEDDING_API_KEY
                  valueFrom:
                    secretKeyRef:
                      name: csearch-nlp-secrets
                      key: embedding-api-key
              volumeMounts:
                - name: fulltext-cache
                  mountPath: /data/fulltext
              resources:
                requests:
                  memory: "512Mi"
                  cpu: "250m"
                limits:
                  memory: "1Gi"
                  cpu: "500m"
          volumes:
            - name: fulltext-cache
              persistentVolumeClaim:
                claimName: nlp-fulltext-pvc
          restartPolicy: OnFailure
```

---

## 8. Qdrant Collection Setup

After deploying Qdrant, create the collection. Run this from your dev machine via port-forward:

```bash
kubectl --context mars port-forward svc/qdrant 6333:6333 -n csearch-nlp
```

```python
from qdrant_client import QdrantClient
from qdrant_client.models import (
    VectorParams, Distance, PayloadSchemaType,
    ScalarQuantization, ScalarQuantizationConfig, ScalarType,
    HnswConfigDiff, OptimizersConfigDiff,
)

client = QdrantClient(host="localhost", port=6333)

client.create_collection(
    collection_name="bill_chunks",
    vectors_config={
        "content": VectorParams(
            size=1536,
            distance=Distance.COSINE,
            on_disk=True,
        )
    },
    hnsw_config=HnswConfigDiff(
        on_disk=True,
        m=16,
        ef_construct=100,
        payload_m=16,
    ),
    quantization_config=ScalarQuantization(
        scalar=ScalarQuantizationConfig(
            type=ScalarType.INT8,
            quantile=0.99,
            always_ram=True,
        )
    ),
    optimizers_config=OptimizersConfigDiff(
        indexing_threshold=20000,
    ),
)

# Payload indexes for filtered search
client.create_payload_index("bill_chunks", "billid", PayloadSchemaType.KEYWORD)
client.create_payload_index("bill_chunks", "congress", PayloadSchemaType.INTEGER)
client.create_payload_index("bill_chunks", "billtype", PayloadSchemaType.KEYWORD)
client.create_payload_index("bill_chunks", "year", PayloadSchemaType.INTEGER)
client.create_payload_index("bill_chunks", "chunk_type", PayloadSchemaType.KEYWORD)
```

### Point structure

```json
{
  "id": "hr1234-118-summary-0",
  "vector": {"content": [0.023, -0.041, ...]},
  "payload": {
    "billid": "hr1234-118",
    "billnumber": "1234",
    "billtype": "hr",
    "congress": 118,
    "year": 2023,
    "chunk_type": "fulltext_section",
    "chunk_index": 0,
    "chunk_text": "[H.R. 1234, 118th Congress] Section 3: Definitions — For purposes of this Act...",
    "section_title": "Definitions",
    "shorttitle": "Veterans Medical Debt Relief Act",
    "sponsors": ["Rep. Smith, John [D-CA-12]"]
  }
}
```

---

## 9. Embedding Strategy

### What to embed (filtered for VPS constraints)

| Chunk type | Source | Est. chunks | Include? |
|---|---|---|---|
| Title | `shorttitle` + `officialtitle` | ~500K | Yes |
| Summary | `summary->>'Text'` | ~1M | Yes |
| Full-text sections (latest version, substantive only) | GovInfo XML `<section>` | ~5M | Yes |
| Definitions | GovInfo XML `<definitions-section>` | ~500K | Yes |
| Actions timeline | `actions[]` grouped by stage | ~1.5M | Yes |
| Sponsor block | `sponsors` + `cosponsors` | ~500K | Yes |
| Boilerplate sections | Effective date, severability, etc. | ~3M | **No** |
| Older bill versions | Introduced/reported if enrolled exists | ~15M | **No** |

**Total: ~8M chunks.**

### Chunking rules

1. **Preserve XML section boundaries.** Never split mid-section if < 512 tokens.
2. **Split long sections** at `<paragraph>` or `<subsection>` elements, 64-token overlap.
3. **Prepend bill context** to every chunk: `"[H.R. 1234, 118th Congress] Section 3: Definitions — "` so the embedding model has bill-level context even for isolated chunks.
4. **Skip boilerplate.** Filter out sections matching: "effective date", "severability", "authorization of appropriations", "short title" (the title chunk already covers this).
5. **Definitions get their own chunks** — semantically distinct, high value.

### Embedding model

**`text-embedding-3-small`** (1536 dimensions, $0.02/1M tokens).

Initial batch cost for 8M chunks at ~200 tokens avg: **~$32**. Negligible.

### Batch embedding from dev machine

The initial ingest is CPU-light but I/O-heavy (API calls + Qdrant writes). Run it from your dev machine:

```bash
# Terminal 1: port-forward Qdrant
kubectl --context mars port-forward svc/qdrant 6333:6333 -n csearch-nlp

# Terminal 2: port-forward PostgreSQL (or use the LoadBalancer IP)
kubectl --context mars port-forward svc/postgres-service 5432:5432

# Terminal 3: run the batch pipeline
cd csearch-nlp/
export QDRANT_HOST=localhost
export QDRANT_PORT=6333
export PG_CONNECTION_STRING="postgresql://postgres:postgres@localhost:5432/csearch"
export EMBEDDING_API_KEY="sk-..."
export FULLTEXT_CACHE_DIR="./data/fulltext"

# Embed all congresses, 4 parallel workers (one per congress batch)
python -m csearch_nlp.pipeline batch \
  --workers 4 \
  --congress-range 93-118 \
  --batch-size 100
```

**Estimated time:** ~4–6 hours (dominated by embedding API rate limits at 3K RPM). The dev machine handles chunking and API calls; only the final vectors stream to the VPS Qdrant over the port-forward.

After the initial batch, the nightly CronJob on the VPS handles incremental updates (~100 new bills/day = ~10K chunks = 2 minutes).

---

## 10. Retrieval Pipeline

### Query flow

```
User: "bills that ban stock trading by members of Congress"
                            │
                            ▼
                ┌───────────────────────┐
                │  1. Query classifier   │
                │                       │
                │  LLM call (Haiku) or  │
                │  regex heuristics:    │
                │  - extract: congress, │
                │    billtype, year     │
                │  - clean query text   │
                └───────────┬───────────┘
                            │
               query + filters
                            │
                            ▼
         ┌──────────────────┴──────────────────┐
         │              parallel                │
         ▼                                     ▼
┌─────────────────┐                  ┌──────────────────┐
│ 2a. Embed query  │                  │ 2b. PG keyword   │
│ text-embedding-  │                  │ search (existing │
│ 3-small          │                  │ tsvector/GIN)    │
│ → [1536-dim]     │                  │ → top 20 billids │
└────────┬────────┘                  └────────┬─────────┘
         │                                     │
         ▼                                     │
┌─────────────────┐                            │
│ 3. Qdrant search │                            │
│ top_k=40         │                            │
│ + payload filters│                            │
│ → 40 chunks      │                            │
└────────┬────────┘                            │
         │                                     │
         └──────────────┬──────────────────────┘
                        │
                        ▼
              ┌───────────────────┐
              │ 4. Reciprocal     │
              │    Rank Fusion    │
              │    (k=60)         │
              │    → top 40 merged│
              └─────────┬─────────┘
                        │
                        ▼
              ┌───────────────────┐
              │ 5. Cross-encoder   │
              │    re-rank         │
              │    ms-marco-       │
              │    MiniLM-L-12-v2  │
              │    → top 10 bills  │
              └─────────┬─────────┘
                        │
                        ▼
              ┌───────────────────┐
              │ 6. Hydrate from PG│
              │    (bill metadata,│
              │    sponsors, etc.) │
              └─────────┬─────────┘
                        │
                        ▼
              ┌───────────────────┐
              │ 7. Build prompt +  │
              │    stream Claude   │
              │    Sonnet response │
              └────────────────────┘
```

### Reciprocal Rank Fusion

RRF is rank-based rather than score-based, so it merges Qdrant cosine similarity and PG ts_rank without needing to calibrate their scales:

```python
def reciprocal_rank_fusion(ranked_lists, k=60):
    scores = {}
    for ranked_list in ranked_lists:
        for rank, (doc_id, _score) in enumerate(ranked_list):
            if doc_id not in scores:
                scores[doc_id] = 0
            scores[doc_id] += 1.0 / (k + rank + 1)
    return sorted(scores.items(), key=lambda x: x[1], reverse=True)
```

### Cross-encoder re-ranking

Not optional. At 8M chunks, the bi-encoder retrieval returns near-misses that need filtering. The cross-encoder reads (query, chunk) pairs jointly for much more accurate relevance scoring.

**Model:** `cross-encoder/ms-marco-MiniLM-L-12-v2` (~130MB, runs on CPU)
**Latency:** ~80ms for 40 pairs on the VPS
**Memory:** ~500MB under load

```python
from sentence_transformers import CrossEncoder

reranker = CrossEncoder("cross-encoder/ms-marco-MiniLM-L-12-v2")

def rerank(query, chunks, top_k=10):
    pairs = [(query, c["chunk_text"]) for c in chunks]
    scores = reranker.predict(pairs)
    ranked = sorted(zip(chunks, scores), key=lambda x: x[1], reverse=True)
    return ranked[:top_k]
```

---

## 11. Generation Layer

### LLM

**Claude Sonnet** as default. With full bill text excerpts in context, the LLM has rich material to synthesize. Per-query context: ~5–10K tokens (10 bills × 1–3 matched chunks each + metadata).

### Prompt template

```
You are a Congressional research assistant for CSearch. Answer the user's
question using ONLY the bill information provided below.

Rules:
- Cite specific bill numbers (e.g., H.R. 1234, S. 567) for every claim.
- Quote relevant statutory language when it directly answers the question.
- If multiple bills address the topic, compare their approaches.
- If the retrieved bills don't fully answer the question, say so. Never
  fabricate bill numbers or legislative text.
- Note each bill's current status (introduced, passed committee, enacted, etc.).

## Retrieved Bills

{{#each bills}}
### {{this.billtype_display}} {{this.billnumber}} — {{this.congress}}th Congress
**Title:** {{this.shorttitle || this.officialtitle}}
**Introduced:** {{this.introducedat}}
**Status:** {{this.current_status}}
**Sponsors:** {{this.sponsor_display}}

#### Relevant Sections
{{#each this.matched_chunks}}
> {{this.chunk_text}}
_({{this.section_title}})_

{{/each}}

#### Summary
{{this.summary_text}}

{{/each}}

## Question
{{query}}
```

### Streaming SSE

```
POST /api/nlp/search
Content-Type: application/json
Accept: text/event-stream

{"query": "...", "filters": {"congress": null, "year_range": [2020, 2026]}}
```

```
event: sources
data: {"bills": [{billid, billnumber, billtype, shorttitle, congress, score}...]}

event: token
data: {"text": "Several bills have been introduced..."}

event: done
data: {"usage": {"input_tokens": 8420, "output_tokens": 312}}
```

---

## 12. Caching

Use the existing CSearch Redis with an `nlp:` key prefix:

| Layer | Key | TTL | Saves |
|---|---|---|---|
| Query embedding | `nlp:emb:{sha256(query)}` | 24h | ~100ms + API cost |
| Qdrant + RRF results | `nlp:vec:{sha256(query)}:{filter_hash}` | 1h | ~200ms (on-disk Qdrant) |
| Re-ranked results | `nlp:rank:{sha256(query)}:{point_ids}` | 1h | ~80ms (cross-encoder) |
| LLM response | `nlp:llm:{sha256(query)}:{bill_ids}` | 1h | ~2–5s + LLM cost |
| Bill metadata | `nlp:bill:{billid}` | 6h | PG round-trip |

Cache is critical with on-disk Qdrant. Repeated queries hit Redis (~1ms) instead of disk-backed HNSW (~150ms).

---

## 13. Project Structure

```
csearch-nlp/
├── pyproject.toml
├── Dockerfile
├── docker-compose.yml              # Local dev: Qdrant + Redis + API
│
├── csearch_nlp/
│   ├── __init__.py
│   ├── config.py                   # Env vars, model names, thresholds
│   │
│   ├── api/
│   │   ├── server.py               # FastAPI app
│   │   ├── routes.py               # POST /api/nlp/search, GET /health
│   │   └── models.py               # Pydantic request/response schemas
│   │
│   ├── rag/
│   │   ├── orchestrator.py         # Main pipeline
│   │   ├── query_classifier.py     # Filter extraction, intent classification
│   │   ├── embedder.py             # Embedding API wrapper
│   │   ├── retriever.py            # Qdrant + PG keyword search
│   │   ├── reranker.py             # Cross-encoder
│   │   ├── fusion.py               # Reciprocal Rank Fusion
│   │   ├── hydrator.py             # PG bill metadata fetch
│   │   ├── prompt_builder.py       # LLM prompt construction
│   │   └── generator.py            # Claude streaming client
│   │
│   ├── pipeline/
│   │   ├── __main__.py             # CLI: batch / sync / reembed
│   │   ├── fetcher.py              # GovInfo XML downloader
│   │   ├── chunker.py              # XML-aware section splitter
│   │   ├── batcher.py              # Embedding API batcher
│   │   ├── upserter.py             # Qdrant upsert
│   │   └── tracker.py              # Sync state (which bills are embedded)
│   │
│   └── cache/
│       └── redis_cache.py
│
├── k8s/
│   ├── namespace.yaml
│   ├── qdrant-pv.yaml
│   ├── qdrant-statefulset.yaml
│   ├── qdrant-service.yaml
│   ├── fulltext-pv.yaml
│   ├── nlp-deployment.yaml
│   ├── nlp-service.yaml
│   ├── nlp-sync-cronjob.yaml
│   ├── configmap.yaml
│   └── secrets.yaml                # Template only
│
└── tests/
    ├── test_chunker.py
    ├── test_retriever.py
    ├── test_fusion.py
    └── eval/
        ├── eval_queries.json       # 100+ queries with expected bills
        └── run_eval.py             # recall@10, MRR
```

### Dockerfile

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Install system deps for lxml and sentence-transformers
RUN apt-get update && apt-get install -y --no-install-recommends \
    libxml2-dev libxslt1-dev gcc g++ && \
    rm -rf /var/lib/apt/lists/*

COPY pyproject.toml .
RUN pip install --no-cache-dir .

# Pre-download the cross-encoder model at build time
RUN python -c "from sentence_transformers import CrossEncoder; CrossEncoder('cross-encoder/ms-marco-MiniLM-L-12-v2')"

COPY csearch_nlp/ csearch_nlp/

USER 1000:1000
EXPOSE 8000

CMD ["uvicorn", "csearch_nlp.api.server:app", "--host", "0.0.0.0", "--port", "8000"]
```

Build and push:

```bash
docker build -t 10.0.0.3:30252/csearch-nlp:latest .
docker push 10.0.0.3:30252/csearch-nlp:latest
```

---

## 14. Memory Budget on the VPS

| Process | Requests | Limits | Notes |
|---|---|---|---|
| PostgreSQL (existing) | ~1 GB | ~2 GB | Existing workload, unchanged |
| Qdrant | 1.5 GB | 2 GB | INT8 quantized vectors in RAM, HNSW on disk |
| csearch-nlp API | 1 GB | 2 GB | Includes cross-encoder model (~500MB) |
| Redis (existing) | ~256 MB | ~512 MB | Shared, NLP adds ~50MB for caches |
| CSearch scraper (CronJob) | 1 CPU | 1.5 CPU | Only runs at midnight, memory freed when done |
| OS + K8s overhead | ~512 MB | — | kubelet, kernel, etc. |
| **Total (steady state)** | **~4.3 GB** | **~7 GB** | Fits in 8 GB with headroom |

The midnight CronJob (goscraper) overlaps briefly with the NLP sync CronJob (00:30). Both are short-lived and bursty. The NLP sync is lightweight (~512MB) and should complete before the scraper's peak memory usage.

---

## 15. ArgoCD Deployment (Mars Context)

All infrastructure is deployed via ArgoCD on the `mars` context. Manual `kubectl apply` is only used for one-time bootstrapping (namespace, NFS directories, ArgoCD Application resource itself).

### ArgoCD Application

```yaml
# argocd/applications/csearch-nlp.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: csearch-nlp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<your-org>/csearch-nlp.git  # or the monorepo URL
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: csearch-nlp
  syncPolicy:
    automated:
      prune: true               # remove resources deleted from git
      selfHeal: true            # revert manual drift
    syncOptions:
      - CreateNamespace=true    # ArgoCD creates csearch-nlp namespace
      - PruneLast=true          # delete old resources after new ones are healthy
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 1m
```

This tells ArgoCD: "watch the `k8s/` directory of the csearch-nlp repo, sync everything in it to the `csearch-nlp` namespace, auto-prune removed resources, auto-heal drift."

### What ArgoCD manages vs. what it doesn't

| Resource | Managed by ArgoCD? | Notes |
|---|---|---|
| Namespace (`csearch-nlp`) | Yes | `CreateNamespace=true` in syncOptions |
| Qdrant StatefulSet + Service | Yes | Synced from `k8s/qdrant-statefulset.yaml`, `k8s/qdrant-service.yaml` |
| NLP API Deployment + Service | Yes | Synced from `k8s/nlp-deployment.yaml`, `k8s/nlp-service.yaml` |
| NLP Sync CronJob | Yes | Synced from `k8s/nlp-sync-cronjob.yaml` |
| ConfigMap | Yes | Synced from `k8s/configmap.yaml` |
| PVs and PVCs | Yes | Synced from `k8s/qdrant-pv.yaml`, `k8s/fulltext-pv.yaml` |
| **Secrets** | **No** | Applied manually once. Secrets should not live in git. |
| **NFS directories** | **No** | Created manually on `10.0.0.3` once. |
| **Qdrant collection** | **No** | Created via Python script once after Qdrant is running. |
| **Batch embedding** | **No** | Run from dev machine. Not a K8s resource. |

### Secrets handling

Secrets are excluded from ArgoCD sync. Apply them manually once, and they persist across syncs:

```bash
# One-time: create the secret directly
kubectl --context mars create secret generic csearch-nlp-secrets \
  -n csearch-nlp \
  --from-literal=pg-connection-string="postgresql://postgres:postgres@postgres-service.default.svc.cluster.local:5432/csearch" \
  --from-literal=embedding-api-key="sk-..." \
  --from-literal=llm-api-key="sk-ant-..."
```

To prevent ArgoCD from pruning the secret (since it's not in git), add a label:

```bash
kubectl --context mars label secret csearch-nlp-secrets \
  -n csearch-nlp \
  argocd.argoproj.io/managed-by=manual
```

Alternatively, if you later adopt Sealed Secrets or External Secrets Operator, the sealed/external secret manifest _can_ live in git and be ArgoCD-managed.

### k8s/ directory layout (what ArgoCD syncs)

```
k8s/
├── namespace.yaml              # only needed if not using CreateNamespace
├── configmap.yaml
├── qdrant-pv.yaml
├── qdrant-statefulset.yaml
├── qdrant-service.yaml
├── fulltext-pv.yaml
├── nlp-deployment.yaml
├── nlp-service.yaml
└── nlp-sync-cronjob.yaml
```

Every file in this directory is applied by ArgoCD. To deploy a change: commit to `main`, ArgoCD detects the diff and syncs.

### Image update flow

When you build and push a new image:

```bash
# Build and push
docker build -t 10.0.0.3:30252/csearch-nlp:v0.2.0 .
docker push 10.0.0.3:30252/csearch-nlp:v0.2.0

# Update the image tag in k8s/nlp-deployment.yaml
# (change image: 10.0.0.3:30252/csearch-nlp:latest → :v0.2.0)

# Commit and push
git add k8s/nlp-deployment.yaml
git commit -m "deploy csearch-nlp v0.2.0"
git push

# ArgoCD auto-syncs within ~3 minutes (default poll interval)
# Or force immediate sync:
argocd app sync csearch-nlp
```

Use explicit version tags (`:v0.1.0`, `:v0.2.0`) instead of `:latest` for ArgoCD deployments. This makes rollbacks trivial — just revert the commit — and ArgoCD can detect the diff.

---

## 16. Step-by-Step Implementation

### Phase 0 — Bootstrap (Day 1)

These are one-time manual steps for the `mars` dev cluster before ArgoCD takes over.

```bash
# 1. Prepare dev SSD paths (HostPath storage)
mkdir -p /mnt/data/qdrant
mkdir -p /mnt/data/nlp-fulltext
chown 1000:1000 /mnt/data/qdrant /mnt/data/nlp-fulltext

# 2. Create the standalone csearch-nlp repo
cd ~/Documents/projects/
mkdir csearch-nlp && cd csearch-nlp
git init

# 3. Create read-only PostgreSQL role
# Replace with your actual Postgres superuser connection string or exec into pod:
kubectl --context mars exec -it svc/postgres-service -- psql -U postgres -d csearch -c "
CREATE ROLE csearch_readonly WITH LOGIN PASSWORD 'strong-pass';
GRANT CONNECT ON DATABASE csearch TO csearch_readonly;
GRANT USAGE ON SCHEMA public TO csearch_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO csearch_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO csearch_readonly;
"

# 4. Apply the ArgoCD Application resource (pointing to the new csearch-nlp repo)
kubectl --context mars apply -f argo/applications/csearch-nlp.yaml
argocd app wait csearch-nlp

# 5. Create secrets (not in git)
# For local Ollama dev, the LLM / Embedding API keys can be dummy values
kubectl --context mars create secret generic csearch-nlp-secrets \
  -n csearch-nlp \
  --from-literal=pg-connection-string="postgresql://csearch_readonly:strong-pass@postgres-service.default.svc.cluster.local:5432/csearch" \
  --from-literal=embedding-api-key="ollama-local" \
  --from-literal=llm-api-key="ollama-local"

kubectl --context mars label secret csearch-nlp-secrets \
  -n csearch-nlp \
  argocd.argoproj.io/managed-by=manual

# 6. Verify Qdrant is running and create the collection
kubectl --context mars -n csearch-nlp get pods
kubectl --context mars port-forward svc/qdrant 6333:6333 -n csearch-nlp
# (run Python script from Section 8)
```

### Phase 1 — Data pipeline (Week 1–2)

Build the Python pipeline in the new `csearch-nlp` repository, using **local Ollama embeddings (nomic-embed-text or mxbai-embed-large)** and integrating both bills and votes (~10M chunks).

```bash
# 1. Point the pipeline to your local Ollama instance (GPU 3090)
export OLLAMA_HOST="http://localhost:11434"
export EMBEDDING_MODEL="nomic-embed-text"

# 2. Fetch full bill + vote data
python -m csearch_nlp.pipeline fetch --congress-range 93-118 --include-votes

# 3. Chunk the XML & JSON
python -m csearch_nlp.pipeline chunk --congress-range 93-118 --skip-boilerplate --include-votes

# 4. Embed and push to Qdrant using Local GPU
kubectl --context mars port-forward svc/qdrant 6333:6333 -n csearch-nlp &
python -m csearch_nlp.pipeline batch \
  --workers 4 \
  --congress-range 93-118 \
  --batch-size 100 \
  --use-ollama

# 5. Verify
python -c "
from qdrant_client import QdrantClient
c = QdrantClient('localhost', port=6333)
print(c.get_collection('bill_chunks'))
print(c.get_collection('vote_chunks'))
"
# Expect ~10M points
```

### Phase 2 — API service (Week 2–3)

```bash
# 1. Build and push the Docker image
docker build -t 10.0.0.3:30252/csearch-nlp:v0.1.0 .
docker push 10.0.0.3:30252/csearch-nlp:v0.1.0

# 2. Update k8s/nlp-deployment.yaml with the image tag
# 3. Commit and push — ArgoCD deploys automatically

# 4. Test via port-forward
kubectl --context mars port-forward svc/csearch-nlp-api 8000:8000 -n csearch-nlp

curl -X POST http://localhost:8000/api/nlp/search \
  -H "Content-Type: application/json" \
  -d '{"query": "bills about banning stock trading by members of Congress"}'
```

### Phase 3 — Nightly sync (Week 3)

The CronJob is already deployed by ArgoCD (from `k8s/nlp-sync-cronjob.yaml`). Test it manually:

```bash
kubectl --context mars create job --from=cronjob/csearch-nlp-sync test-sync -n csearch-nlp
kubectl --context mars -n csearch-nlp logs job/test-sync -f
```

### Phase 4 — Frontend integration (Week 4)

The API is accessible within the cluster at `csearch-nlp-api.csearch-nlp.svc.cluster.local:8000`. Wire it into the CSearch Nuxt frontend or have the Fastify backend proxy to it.

### Phase 5 — Evaluation (Ongoing)

```bash
python -m csearch_nlp.tests.eval.run_eval \
  --endpoint http://localhost:8000/api/nlp/search \
  --queries tests/eval/eval_queries.json \
  --metrics recall@10,mrr
```

---

## 17. Cost Estimates

### One-time

| Item | Cost |
|---|---|
| Batch embedding (10M chunks) | $0 (Ollama Local) |
| Full-text XML download | Free (GovInfo is public) |
| Storage for Qdrant | Local SSD |

### Monthly recurring (at ~10K queries/day)

| Item | Cost |
|---|---|
| Query embeddings | $0 (Ollama Local) |
| LLM calls  | $0 (Ollama Local) |
| Incremental embedding | $0 (Ollama Local) |
| **Compute** | **Existing Dev Server (mars, local GPU)** |

### Cost optimization

- Move to production (`netcup`) will require evaluation of local vs API tokens for embedding and LLM.
- For Local Dev, cost is purely hardware footprint constraint (zero API calls).

---

## 18. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Qdrant on-disk latency spikes under cold cache | Redis caching absorbs repeated queries. Pre-warm Qdrant after restart by running top-100 queries. |
| VPS memory pressure when CronJobs overlap | NLP sync CronJob has low limits (1 GB). Goscraper runs at midnight, NLP sync at 00:30 — stagger avoids peak overlap. |
| GovInfo bulk download throttled or down | Cache all XML locally. Retry with backoff. |
| LLM hallucinates bill numbers | Validate every cited bill ID against the retrieved set in post-processing. Strip uncitable claims. |

---

## 19. Next Steps and Follow-Up Questions

The implementation plan has been updated! Moving to a local RTX 3090 running `ollama` with `hostPath` SSD volumes will drastically simplify the constraints and drop your monthly API cost footprint for local testing directly to zero. Since we're rolling this out to local dev (`mars`), there's no need to limit things behind API authentication right now, use the main `Redis` cache instance, and we get to ingest historical vote data seamlessly using the local embeddings.

### New Follow-Up Questions

1. **Ollama Deployment and K8s Networking:**
   Since you have Ollama on your local machine (with the RTX 3090), how is Ollama running? Is it running as a native host process, or on Docker/Kubernetes inside the `mars` cluster?
   *Why this matters:* The K8s pods running the Python API will need network access to Ollama (typically `http://host.docker.internal:11434` or a local K8s service `ollama.default.svc.cluster.local:11434`). We'll need to know its endpoint for standard configuration inside the API.

2. **Model Selection for Embeddings and LLM:**
   You mentioned potentially using `Qwen2.5`. For embedding vs LLM generation, we'll need to pull different dedicated models, typically:
   - **Embedding:** `nomic-embed-text` (8192 context size) or `mxbai-embed-large` for dense retrieval vector spaces.
   - **Generation/LLM:** `qwen2.5:7b` or `llama3.1:8b`
   Have you experimented with `nomic-embed-text` for creating embeddings locally, or does `qwen2.5` have an embedding counterpart you want to stick with?

3. **Standalone Pipeline CI/CD and Dockerization:**
   We are kicking off the new `csearch-nlp` repo locally to separate concerns. Because we're no longer using Netcup for Dev, are there plans to connect this new repo eventually to a git server (GitHub/GitLab) so that ArgoCD on the `mars` context can sync directly from it? Argo requires the files to be committed to an accessible upstream Git repository, otherwise we just use manual `kubectl apply` commands on `mars`.

4. **Production Postgres Replication vs Cloud:**
   Given the prod environment (`netcup`) is on a separate remote VPS, when it's time to roll this into production later on, we'll need `csearch-nlp` on `netcup` to read the Database. The NLP Qdrant DB there will have to either recreate its local indexing (expensive API or GPU if Netcup lacks it) or sync snapshots. Do you want to figure out that syncing strategy now, or wait until the initial Pipeline architecture stabilizes on Local?
