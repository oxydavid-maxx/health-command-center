# health-command-center

`health-command-center` is the canonical external skill for reviewing Health
trends, training execution, recovery, fixed-menu progress, and safe proposed
adjustments. Garmin acquisition remains independently owned by
[`garmin-claude-analysis`](https://github.com/oxydavid-maxx/garmin-claude-analysis).

Canonical skill entrypoint:
`skills/health-command-center/SKILL.md`.

`scripts/daily-refresh.ps1` owns the scheduled trigger and calls the independent
Garmin producer before rebuilding and publishing the Health projection.
