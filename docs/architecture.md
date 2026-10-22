# Architecture

**Level of this diagram:** level 2, *containers and workflows*. Each box is either an external
service, a Docker container, or one n8n workflow. The nodes inside each workflow are documented
in [workflows.md](workflows.md) (level 3).

**Cut line (system boundary):** everything inside the dashed box runs in this repository's
Docker Compose stack on the laptop (n8n + Postgres). Everything outside it is a third-party
service reached over HTTPS: Telegram, ngrok, Greenhouse, OpenRouter and QuickChart. The
synthetic catalogue (workflow 01) is *inside* the boundary on purpose: no real BAIT data
crosses the cut line.

```mermaid
flowchart LR
  user([Student / recruiter<br/>Telegram app])
  tg[[Telegram Bot API]]
  ngrok[[ngrok HTTPS tunnel]]
  gh[[Greenhouse public jobs API]]
  or[[OpenRouter LLM API]]
  qc[[QuickChart image API]]

  subgraph SYS["SYSTEM BOUNDARY: docker compose stack (cut line)"]
    direction LR
    w12["12 Telegram controller<br/>(trigger, router, sender)"]
    w01["01 Synthetic catalogue API<br/>(webhook)"]
    w02["02 Matching engine<br/>(sub-workflow)"]
    w07["07 Persist recommendations<br/>(sub-workflow)"]
    w06["06 AI explanation<br/>(sub-workflow)"]
    w09["09 Live public feed<br/>(sub-workflow)"]
    w10["10 Recruiter ranking<br/>(sub-workflow)"]
    w05["05 Error capture<br/>(error workflow)"]
    pg[("Postgres 16<br/>bait_recommendations")]
  end

  user -- "typed command or button tap" --> tg
  tg -- "update JSON: chat id, text / callback_data, update_id" --> ngrok
  ngrok -- "POST webhook to localhost:5678" --> w12
  w12 -- "GET /webhook/bait-demo-catalogue-v1" --> w01
  w01 -- "JSON: personas, 12 jobs, applicant pools" --> w12
  w12 -- "candidate + jobs" --> w02
  w02 -- "top3, allScored, excluded" --> w12
  w12 -- "candidate + top3" --> w07
  w07 -- "INSERT ... ON CONFLICT (8 params)" --> pg
  pg -- "RETURNING times_saved, first_saved" --> w07
  w07 -- "shortlist + persistedRows, timesSaved" --> w12
  w12 -- "candidate + top3" --> w06
  w06 -- "system + user prompt" --> or
  or -- "3-line explanation text" --> w06
  w06 -- "validated message or error" --> w12
  w12 -- "student skills (+ simulateFailure on /drill)" --> w09
  w09 -- "GET boards/ecjobb/jobs" --> gh
  gh -- "jobs JSON (title, location, content)" --> w09
  w09 -- "top internships + mentioned skills" --> w12
  w12 -- "job + weights/threshold + candidates" --> w10
  w10 -- "allEvaluations, shortlist, excluded" --> w12
  w12 -- "sendMessage / sendPhoto (text, buttons, chart URL)" --> tg
  tg -- "chart URL fetched by Telegram" --> qc
  tg -- "reply messages + buttons" --> user
  w12 & w01 & w02 & w06 & w07 & w09 & w10 -. "failed execution: workflow, node, error, URL" .-> w05
  w05 -- "alert text to owner chat" --> tg
```

## Why it is split into sub-workflows

| Workflow | Role | Why separate |
| --- | --- | --- |
| 12 | Controller: receives every Telegram update, decides the action, sends replies | Only workflow that talks to Telegram; keeps UI logic in one place |
| 01 | Read-only catalogue API | Same contract as a real BAIT API would expose; swap the URL to go live |
| 02 | Candidate-to-jobs matching | Pure scoring logic, reused twice (matches and AI advice), testable alone |
| 06 | AI explanation | Isolates the only non-deterministic step; its failure cannot break scoring |
| 07 | Persistence | Database concerns in one place; can switch Data Table to Postgres without touching 12 |
| 09 | Live market evidence | External, unreliable API; isolated so a failure is contained (used by /drill) |
| 10 | Recruiter ranking | Declared inputs (job, candidates, allSynthetic); reused by 12 and tested by 11 |
| 05 | Error workflow | Linked in every workflow's settings; alerts the owner with the execution link |
