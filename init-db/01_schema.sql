-- Runs once, the first time the postgres_data volume is created.
-- Project database for the BAIT n8n demo. Fictional data only; isolated from BAIT production.
CREATE TABLE IF NOT EXISTS bait_recommendations (
  record_key     TEXT PRIMARY KEY,          -- candidateId::jobId, makes saving idempotent (upsert)
  candidate_id   TEXT        NOT NULL,
  candidate_name TEXT,
  job_id         TEXT        NOT NULL,
  job_title      TEXT,
  company        TEXT,
  score          INTEGER     NOT NULL CHECK (score BETWEEN 0 AND 100),
  reason         TEXT,
  times_saved    INTEGER     NOT NULL DEFAULT 1,      -- +1 each time the same match is saved again
  first_saved    TIMESTAMPTZ NOT NULL DEFAULT now(),  -- written by the first run, read back by later runs
  last_checked   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_bait_recommendations_candidate ON bait_recommendations (candidate_id);
