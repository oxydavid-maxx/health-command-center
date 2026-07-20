# Health Command Center extraction specification

Approved by 光佑 on 2026-07-20.

## Capability registry

| Cap-ID | Capability | Acceptance oracle |
|---|---|---|
| HCC-01 | Independent canonical product | repo root, entrypoint and remote match `manifests/registration.json` |
| HCC-02 | Cross-host discovery | Codex, Claude and shared agent registrations resolve to the canonical entrypoint |
| HCC-03 | Vault boundary | Vault stores binding/catalog/law/paths and no canonical skill bytes |
| HCC-04 | Garmin boundary | Garmin remains an independent runtime-data producer; Health owns the daily trigger |
| HCC-05 | Safe migration | migration source inventory and digest proof precede retirement |

## Non-negotiable behavior

The fixed menu remains the presumed baseline. Garmin and InBody observations,
strength actuals, recovery, and plan semantics are assessed together. Missing
data is never treated as zero. Recommendations do not mutate canonical menu or
plan bytes without explicit current approval.
