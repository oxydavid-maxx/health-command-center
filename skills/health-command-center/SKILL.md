---
name: health-command-center
description: Use when reviewing Health dashboard data, Garmin or InBody trends, weekly training adherence, menu adjustment, body-fat progress, strength preservation, progressive overload, recovery, or an Obsidian Health command-center projection.
---

# Health Command Center

Use this skill as the operational decision layer for Health. The skill is a
Vault-external tool; the Vault owns personal Health knowledge, domain law,
workflow bindings, allowed paths, and the external-skill catalog only.

## Establish current authority

When working in the Obsidian Vault, read these current authorities before
drawing a conclusion:

1. `00_指揮部/80_系統/10_治理/vault-structure.yaml`
2. `00_指揮部/80_系統/10_治理/domain-laws/Health.md`
3. `02_休閒 Health/status.md`
4. the current dated weekly training plan
5. the active body-fat Effort and its fixed menu

Fixed menu is the baseline and is presumed followed unless 光佑 reports a
deviation. Do not request daily food photos or a daily compliance check.

## Keep producers independent

Garmin is an independent runtime data producer. `garmin-claude-analysis` owns
Garmin login, acquisition, normalization, freshness, and runtime persistence;
it does not own this skill or Health decision policy. This product owns the
daily trigger and invokes that producer through `scripts/daily-refresh.ps1`.
Consume its normalized contract and preserve explicit missing, stale, and
error states. Never infer a zero from missing data.

InBody is supplied weekly by 光佑 as screenshots or CSV. Parse weight, skeletal
muscle mass, body-fat mass, and body-fat percentage with source date and
confidence. Ask for correction only when a value is ambiguous. Strength and
coach-session actuals are reconciled once during the weekly review because
Garmin normally cannot prove strength sets, load, RIR, pain, or completion.

## Preserve ownership boundaries

| Material | Owner |
|---|---|
| Garmin raw/normalized series, reconciliation rows, publication generations | producer runtime outside the Vault |
| Health knowledge, active goals, fixed menu, weekly plan, personal findings | Vault semantic paths |
| Current compact projection | `02_休閒 Health/status.md` |
| Today presentation | `00_指揮部/00_今日.md` as a consumer only |

`02_休閒 Health/70_Meals/` remains meal records only. Do not create `_generated` or a
second Health intake lane.

## Make the weekly decision

Lead with one conclusion, then show evidence, exact delta, stop condition, and
next checkpoint. Evaluate nutrition, Strength, cardio, and recovery together.
Use standardized multi-point InBody trends, comparable strength performance,
known menu deviations, plan semantics, and goal projection.

- Keep nutrition unchanged when progress is adequate or strength/recovery
  evidence is unresolved.
- Suppress an added deficit when strength and recovery both deteriorate.
- Propose exactly one nutrition lever only after a 14-day stall with adequate
  evidence.
- Treat maintained strength during a cut as success.
- Propose progressive overload only after two comparable, pain-free
  completions at acceptable RIR; choose repetitions or the smallest load
  increment, never both.
- Prefer reducing optional volume before stopping training. Escalate pain or
  persistent regression conservatively.

Recommendations remain proposed. Change no canonical menu or weekly-plan bytes
until 光佑 or an authorized coach supplies a current digest-bound, role-bound,
unexpired, single-use approval.

## Publish and verify

Publish only a compact validated projection to `02_休閒 Health/status.md`. Confirm
provenance and freshness, plan version, required/optional/OR semantics, unknown
states, the combined assessment, approval state, and atomic publication. The
Today card must show compact 3-month trends for resting heart rate, body weight,
skeletal muscle, body-fat mass, body-fat percentage, and weekly running volume.

## Daily recovery presentation

Use `docs/recovery-contract-v1.md` and
`contracts/recovery-contract-v1.schema.json` for recovery evaluation. Today may
show only one action sentence, one evidence sentence and one quiet freshness
line. Do not expose a traffic-light legend, custom recovery score, confidence
meter or recovery-tile row.

A volunteered user recovery decision outranks Garmin for that day. Record it as
`user-adjusted-recovery`; do not call it a missed workout and do not schedule a
make-up session automatically. Missing current-date sleep remains `pending` and
must not be made current by RHR or activity data.
