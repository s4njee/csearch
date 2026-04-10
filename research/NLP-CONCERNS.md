# NLP Pre-Deployment Concerns and Answers

Resolve these before starting Phase 0. They are ordered by impact — the first few will block you, the rest are design decisions that affect cost and architecture.

### P0 — Blockers (must decide before any deployment)

**1. Is ArgoCD installed and configured on the mars context?**
The `argocd/` directory exists in the repo but is empty — no applications are configured. You need a running ArgoCD instance on the cluster that can watch your git repo. If ArgoCD isn't installed yet, you'll need to deploy it first (or use the `argocd` Helm chart). Verify with:
```bash
kubectl --context mars get pods -n argocd
argocd app list
```
If ArgoCD isn't there, the entire GitOps workflow described in Section 15 won't work and you'd fall back to manual `kubectl apply`. Decide now.

Answer: Argo manifests are in the argo folder and should point to deployments in the k8s folder.

**2. Does the mars context point to the same cluster as netcup, or a separate one?**
The plan assumes mars and netcup are contexts within the same K8s cluster (same `worker1` node, same NFS server at `10.0.0.3`). If mars is a separate cluster or a separate VPS, the NFS paths, PG cross-namespace DNS, and registry URL all need to change. Confirm this before writing any manifests.

Answer: Mars is a separate cluster running on local hardware. Netcup is my prod environment and is running on a different VPS. 

**3. Is there a read-only PostgreSQL user?**
The plan uses `postgres:postgres` (the superuser) for the NLP service's PG connection. This works but is risky — a bug in the NLP service could accidentally write to or drop tables in the `csearch` database. Create a read-only user before deploying:
```sql
CREATE ROLE csearch_readonly WITH LOGIN PASSWORD '<strong-password>';
GRANT CONNECT ON DATABASE csearch TO csearch_readonly;
GRANT USAGE ON SCHEMA public TO csearch_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO csearch_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO csearch_readonly;
```
Then use this user in the NLP service's connection string.

Answer: This postgres user has not been created. You can include this in the implementation plan.

**4. Where does the csearch-nlp repo live?**
The ArgoCD Application needs a `repoURL`. Options: a new standalone GitHub repo (e.g., `github.com/<your-org>/csearch-nlp`), or a subdirectory within the existing csearch-updater-root monorepo. If it's a subdirectory, adjust the ArgoCD `source.path` to `csearch-nlp/k8s/` rather than `k8s/`. This also affects whether the Dockerfile, Python code, and K8s manifests live in one repo or two.

Answer: Let's make a new repo for this project. Add to implementation plan.

### P1 — Important (decide before Phase 1)

**5. NFS performance for Qdrant storage.**
Qdrant's on-disk HNSW mode does random reads against the storage volume. NFS adds ~1–2ms per read vs. local SSD. At low query volumes (< 100 queries/minute) this is fine — you'll see ~150–200ms search latency instead of ~30–50ms. But if NFS performance is poor on your setup (check with a simple `dd` benchmark on the mount), consider using a `hostPath` volume on `worker1` instead. The tradeoff: hostPath is faster but ties Qdrant to a specific node's disk and doesn't survive node replacement.

Answer: Hostpath is fine. Dev server will be running this on an ssd. Will discuss prod deployment later.

**6. Embedding API key budget and rate limits.**
The batch ingest calls the OpenAI embedding API ~550K times (8M chunks / ~15 chunks per request). At 3K RPM that's ~3 hours. Confirm your OpenAI account's rate limit tier — a free tier or Tier 1 account has lower RPM limits that would stretch this to 10+ hours. Also confirm you're comfortable with the ~$32 one-time embedding cost and ~$6/month ongoing.

Answer: Can we use ollama and do the embedding locally? I have a 3090 GPU and the new qwen3.5 models look promising.  Otherwise discuss OpenAI API costs and rate limits for their new models such as 5.4mini and 5.4nano.

**7. LLM API key and cost ceiling.**
Claude Sonnet at 10K queries/day costs ~$720/month. Even with Haiku routing and caching (bringing it to ~$115/month), this is the largest recurring cost. Decide now: are you starting with a hard rate limit (e.g., 100 queries/day = ~$3.50/month), or is the full 10K/day target realistic for launch? This affects whether you need API authentication before exposing the endpoint.

Answer: I am going to be running this locally only. So I will evalute costs during testing.


### P2 — Design decisions (decide before Phase 2)

**8. API authentication strategy.**
The NLP endpoint is ClusterIP (internal only) by default, so only services within the cluster can reach it. This is safe for now. But once you wire it into the frontend (which faces the internet), unauthenticated users can indirectly trigger LLM calls. Options, from simplest to most robust:
- No auth, rely on frontend rate limiting (simplest, leaky)
- API key in header, shared between frontend and NLP service (simple, prevents external abuse)
- Per-user rate limiting via the existing CSearch auth (if any)
- IP-based rate limiting at the Ingress/LoadBalancer level

Answer: No auth is fine for now since we are deploying locally. Add note for prod deployment to reinvestigate this.

**9. Separate repo or monorepo?**
Keeping `csearch-nlp` as a subdirectory of `csearch-updater-root` (this repo) is simpler for ArgoCD — one repo to configure. But it mixes a Rust/Node project with a Python project, and CI/CD pipelines get more complex. A standalone repo is cleaner but means ArgoCD watches two repos and the projects share no code. Given that the NLP service is read-only and has no code dependencies on the existing CSearch backend, a standalone repo is the cleaner choice.

Answer: Let's make a new repo for this project. Add to implementation plan.

**10. Redis: shared or dedicated?**
Sharing the existing CSearch Redis with an `nlp:` prefix is the simplest option and uses no additional memory. The risk: if the NLP cache grows large or a bug floods Redis, it could affect the existing CSearch keyword search cache. A dedicated Redis instance (128MB, tiny pod) in the `csearch-nlp` namespace eliminates this risk at the cost of one more thing to deploy. For a dev/staging deployment on mars, shared is fine. Revisit for production.

Answer: Let's use the existing Redis for now. Add note for prod deployment to reinvestigate this.

### P3 — Future scope (decide anytime)

**11. Vote data in Qdrant?**
Embedding vote records enables "how did [senator] vote on [topic]" queries. Adds ~2M vectors (~25% increase). Worth including once the core pipeline is validated, but doesn't need to be decided now.

Answer: Yes I want to include this. Add to implementation plan.

**12. External exposure.**
To make the NLP search available outside the cluster (e.g., for a public API or for the frontend served via CloudFront to call directly), you'll need either a LoadBalancer service, an Ingress controller, or a reverse proxy through the existing Fastify backend. This requires authentication (P2 item 8) to be solved first.

Answer: No external exposure for now. Add note for prod deployment to reinvestigate this.

**13. Multi-version bill text.**
The current plan embeds only the latest version of each bill. Embedding all versions (introduced, reported, engrossed, enrolled) would enable queries like "what language was in the original bill but removed in committee." This adds ~15M vectors and pushes against the VPS memory budget. Save for a future scale-up.

Answer: Add this to future scope. I do want this, but it is beyond current scope of getting an MVP.
