# Workflows, node by node (level 3)

Files are in [`../workflows`](../workflows). Credentials appear in the JSON only by name and id;
their secrets are encrypted inside n8n with `N8N_ENCRYPTION_KEY`.

---

## 12: Telegram controller (`12-telegram-controller.json`)

The entry point. One execution = one Telegram update (a typed message or a button tap).

| # | Node | Type | What it does |
| --- | --- | --- | --- |
| 1 | Telegram Trigger | Telegram Trigger | Webhook registered with Telegram for `message` and `callback_query` updates. Credential: *Telegram account* (bot token). |
| 1b | Manual Test Run → Sample Telegram Update | Manual Trigger + Code | Saved test payload (`/start` from the owner chat) so the whole flow can be fired on demand without a phone. |
| 2 | Normalize Update | Code | Turns a message or a button tap into one shape `{chatId, input, isButton, queryId}`. Checks the owner chat id. **Idempotency:** remembers the last 200 `update_id`s in workflow static data; a re-delivered update is marked `duplicate`. |
| 3 | Owner Only? | If | Continues only if `authorized` (owner chat, non-empty, not duplicate). Otherwise the run ends silently. |
| 4 | Button Tap? → Answer Button Tap | If + Telegram | For button taps, answers the callback so the button stops spinning. Retry 3×. |
| 5 | GET Demo Catalogue - 01 | HTTP Request | Calls workflow 01's webhook. Retry 3×, 1 s apart, 10 s timeout; error output → Safe Failure Reply. |
| 6 | Plan Action | Code | The "brain": maps commands (`/start`, `/matches`, `/recruiter skills=60 …`, `/drill`) and button data (`cm`, `cw:JOB`, `ca:JOB`, `rp:JOB`, `rw:s`…) to a verb. Validates arguments (weights must sum to 100, values 0–100) and keeps **state across runs** in static data: chosen student, chosen posting, recruiter weights/threshold, applications, notification history. Unknown input → `home` + usage note. |
| 7 | Route to Engine | Switch | Routes by `engine`: `match` → 02 then 07, `ai` → 02 then 06, `live` → 09, `recruit` → 10, fallback (menus, profile, apply) → straight to rendering. |
| 8 | Match Candidate / Match for AI - SELECT 02 | Execute Workflow | Calls workflow 02 and waits. Error output → Render Messages, which shows a safe message. |
| 9 | Save Top 3 - SELECT 07 | Execute Workflow | Saves the top 3 in Postgres. If it fails, scores are still shown ("Saving was unavailable…"). |
| 10 | Explain with AI - SELECT 06 | Execute Workflow | AI explanation; if 06 throws, the reply says the AI is unavailable and scores still stand. |
| 11 | Live Internships - SELECT 09 | Execute Workflow | Real public listings; failure path used by `/drill`. |
| 12 | Rank Applicants - SELECT 10 | Execute Workflow | **Defined inputs** `job`, `candidates`, `allSynthetic` mapped explicitly. |
| 13 | Render Messages | Code | Builds human-readable replies (cards, score bars, explanations, recruiter stats, QuickChart chart URL, notification texts) as a list of messages, each tagged with the button set `kb` it needs. No raw JSON reaches the user. |
| 14 | Safe Failure Reply | Code | Generic, secret-free message when the catalogue or planning fails. |
| 15 | Send One at a Time | Loop Over Items (Split in Batches) | Sends messages in order, one per loop, so Telegram shows them in sequence. |
| 16 | Pick Buttons | Switch (12 outputs) | Chooses the Telegram node with the right inline keyboard for this message. |
| 17 | Send … (11 nodes) | Telegram | `sendMessage` with an inline keyboard, or `sendPhoto` for the chart. Retry 3×; on error continue so one failed message does not stop the loop. |

## 01: Synthetic catalogue API

| Node | Type | What it does |
| --- | --- | --- |
| GET /bait-demo-catalogue-v1 | Webhook | Read-only HTTP endpoint inside n8n. |
| Prepare Synthetic Catalogue | Code | Returns 3 fictional students, 12 fictional internships, 3 recruiter postings and their applicant pools. `allSynthetic: true` is the contract flag every engine checks. |
| Respond with Demo JSON | Respond to Webhook | Sends the JSON with HTTP 200. |

## 02: Candidate-to-jobs matching engine (sub-workflow)

| Node | Type | What it does |
| --- | --- | --- |
| Called by Parent Workflow | Execute Workflow Trigger | Entry point when another workflow calls it. |
| Validate API Contract | Code | Throws if data is not synthetic or the candidate is incomplete (schema check). |
| Hard Eligibility Gate | Code | Degree rule: high school 1 < bachelor 2 < master 3 < PhD 4. Lower than required → excluded with a reason. |
| Score and Rank Eligible Jobs | Code | Score = 40 × share of required skills + 30 × min(years / required years, 1) + 30 education. Sorted, ties broken by job id. |
| Build Deterministic Reply | Code | Plain-text summary (used by tests and older flows). |

## 06: AI explanation (sub-workflow)

| Node | Type | What it does |
| --- | --- | --- |
| Called by Matching Controller | Execute Workflow Trigger | Receives `candidate` and `top3`. |
| Prepare Grounded AI Prompt | Code | Builds the user prompt from the engine's facts only, and records the expected titles and scores. |
| Basic LLM Chain | AI: LLM Chain | **System prompt:** the model only explains scores decided by code, never changes or invents titles, scores or skills, exactly three numbered lines. Retry 3×, 2 s apart. |
| OpenRouter Free Model | AI: Chat Model (sub-node) | Model `openrouter/free`. Credential: *OpenRouter BAIT Valid Key* (API key). |
| Validate AI Explanation | Code | **Output validation:** length between 130 and 1800 characters, and every expected job title and `NN/100` score must appear. Otherwise it throws, so the controller uses the fallback path. |

## 07: Persist recommendations (sub-workflow)

| Node | Type | What it does |
| --- | --- | --- |
| Called with Ranked Jobs | Execute Workflow Trigger | Receives the matching result. |
| Prepare 3 Persistent Records | Code | One item per top-3 job, with `recordKey = candidateId::jobId`. |
| Upsert into Postgres | Postgres (Execute Query) | Parameterised `INSERT … ON CONFLICT (record_key) DO UPDATE … times_saved + 1 RETURNING …`. Same input twice → same row, no duplicate. Retry 3×. Credential: *BAIT Project Postgres*. |
| Return Original Shortlist | Code | Returns the shortlist plus `persistedRows`, `timesSaved`, `firstSaved` (read back from earlier runs). |

## 09: Live public internship feed (sub-workflow + manual test)

| Node | Type | What it does |
| --- | --- | --- |
| Manual Trigger / Called by Another Workflow | Triggers | Run by hand or from 12. |
| GET Public Greenhouse Jobs | HTTP Request | Public, no-credential API. Retry 3×. If called with `simulateFailure` (from `/drill`) it uses a board that does not exist, which returns HTTP 404. |
| Verify Public API Shape | Code | Throws if there is no `jobs` array. |
| Normalize Internship Evidence | Code | Keeps intern/co-op titles, strips HTML, counts which of the student's skills the description mentions. No score is given (requirements not verified). |
| Any Public Internships? | If | Branches to the review or "no openings" fallback. |
| Produce Real Jobs Review / No Openings Fallback | Code | Text summary. |

## 10: Recruiter ranking engine (sub-workflow with defined inputs)

| Node | Type | What it does |
| --- | --- | --- |
| Called by Recruiter Controller | Execute Workflow Trigger | **Defined inputs:** `job` (object), `candidates` (array), `allSynthetic` (boolean). |
| Validate Recruiter Data Contract | Code | Rejects anything not synthetic or incomplete. |
| Reject Ineligible Candidates | Code | Degree gate. |
| Weighted Candidate Scoring | Code | Recruiter-configurable weights (must sum to 100) and threshold. Education: meets the minimum = 75 %, exceeds it = 100 %. |
| Any Qualified Candidates? | If | Shortlist or fallback. |
| Build Ranked Recruiter Shortlist / No Qualified Candidates Fallback | Code | Text summary. |

## 11: Recruiter ranking manual test

Manual trigger → seed 12 fictional applicants → call 10 with defined inputs → **Check Ranking and
Eligibility Results**: every applicant scored or excluded exactly once, plus a regression check
(with default settings RC001 must rank first and RC003 must be excluded).

## 05: Error capture (error workflow)

| Node | Type | What it does |
| --- | --- | --- |
| Error Trigger | Error Trigger | Fires when any workflow that names 05 as its *Error Workflow* (Settings) fails. |
| Summarize Failure | Code | Workflow name, failed node, error message (300 characters max), execution URL. No secrets. |
| Send Alert to Owner | Telegram | Sends the alert to the owner chat. Retry 3×. |

## 12 TEST: controller without Telegram sends

Copy of 12 whose Telegram send nodes are No-Op nodes and whose trigger is a manual trigger with a
fake update. Used for regression tests without messaging anyone.
