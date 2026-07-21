# Recovery Contract v1

The Health Command Center owns the recovery policy. Garmin remains an
independent acquisition and normalization dependency; Obsidian only renders the
validated projection.

## User-facing rule

Today shows exactly three pieces of recovery information:

1. one action sentence: `今天：照計畫`, `今天：保守做`, `今天：休息`, or `今天：等資料`;
2. one evidence sentence;
3. one quiet freshness line.

It does not show a traffic-light legend, custom recovery score, confidence
meter, or a row of recovery-state tiles. Internal lifecycle and reason codes
remain available for auditing.

## Decision boundary

- Current-date sleep is required for an automatic recommendation. Otherwise the
  lifecycle is `pending` and the action is `今天：等資料`.
- Garmin Training Readiness is evidence, never sole authority.
- HRV uses Garmin's personal baseline/status and `last_night_avg`; a single raw
  value is not decisive.
- Sleep below 7 hours is cautionary and below 6 hours is strong evidence.
- Body Battery at wake of 25 or below is supporting evidence.
- A volunteered user statement such as `昨晚沒睡好，所以今天不跑` overrides
  a conflicting Garmin suggestion for that day.
- A user recovery decision is `user-adjusted-recovery`, not `missing` or
  `failed`, and never creates an automatic make-up session.
- The contract carries the decision history in `user_decisions`; a decision is
  not discarded when the next evaluation date begins.
- Daily recovery never edits the fixed menu or weekly plan. Changes remain
  digest-bound proposals requiring explicit approval.

The machine contract is
[`contracts/recovery-contract-v1.schema.json`](../contracts/recovery-contract-v1.schema.json).
