# Evaluation checklist: where each criterion is met

| Criterion | Evidence |
| --- | --- |
| Need in one sentence | README, first paragraph |
| Trigger fireable on demand | Workflow 12: *Manual Test Run* → *Sample Telegram Update* (saved payload next to the real Telegram Trigger); workflows 09 and 11 have manual triggers; 12 TEST |
| Architecture diagram, data on each arrow | [architecture.md](architecture.md) |
| Diagram matches workflow; level and cut line | [architecture.md](architecture.md), first two paragraphs |
| docker-compose.yml: n8n + ≥1 service | `docker-compose.yml`: n8n + Postgres |
| Named volumes survive down/up | `n8n_data`, `postgres_data` |
| Image versions pinned | `n8nio/n8n:2.43.7`, `postgres:16.4-alpine` |
| .env.example, .env ignored, encryption key via env | `.env.example`, `.gitignore`, `N8N_ENCRYPTION_KEY` in compose |
| Fresh clone starts; DB healthcheck | `pg_isready` healthcheck; n8n `depends_on: service_healthy` |
| Workflows exported as JSON | `workflows/` via `scripts/export-workflows.ps1` |
| No secrets in Git; .gitignore | Export script secret check; credentials only by name |
| Feature branch merged / tag v1.0 | `feature/documentation` merged; tag `v1.0` |
| Message trigger (Telegram) | Workflow 12 *Telegram Trigger* |
| API with stored credential | OpenRouter (06), Telegram Bot API (12, 05), Postgres (07) |
| If or Set node | *Owner Only?*, *Button Tap?* (12); *Any Qualified Candidates?* (10); *Any Public Internships?* (09) |
| Code node with real logic | Scoring (02, 10), command parser *Plan Action* (12), validation (06) |
| Router/Switch ≥2 reachable paths | *Route to Engine* (5 outputs), *Pick Buttons* (12 outputs) |
| Database for persistence | Postgres `bait_recommendations` (07) |
| AI node with system prompt | 06 *Basic LLM Chain* system message |
| Sub-workflow with defined inputs | 10 trigger declares `job`, `candidates`, `allSynthetic`; 12 and 11 map them |
| Retry on every external call | HTTP (12, 09), LLM chain (06), Postgres (07), all Telegram nodes: retry on, 3 tries, 1–2 s |
| Error workflow with name + URL | 05, linked in Settings of every workflow; alert text contains both |
| Invalid input → usage message | Unknown command → menu + "Sorry, I did not understand…"; bad weights → example usage |
| Idempotent | `update_id` dedupe (12); Postgres upsert (07); notifications only on status change |
| AI output validated + fallback | 06 *Validate AI Explanation* → error output → fallback text in 12 |
| Failure triggered live | `/drill` → 09 calls a non-existent board → retries → safe reply + 05 alert |
| State across runs | Static data (student, posting, weights, applications); Postgres `times_saved`, `first_saved` read back |
| Readable reply | *Render Messages* builds cards, bars and lists; no raw JSON |
