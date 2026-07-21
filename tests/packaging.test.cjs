const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const ROOT = path.resolve(__dirname, '..');
const read = (rel) => fs.readFileSync(path.join(ROOT, rel), 'utf8');
const json = (rel) => JSON.parse(read(rel));

test('publishes one canonical Health skill with matching host manifests', () => {
  const skillPath = 'skills/health-command-center/SKILL.md';
  assert.ok(fs.existsSync(path.join(ROOT, skillPath)));
  const skill = read(skillPath);
  assert.match(skill, /^---\r?\nname: health-command-center\r?\n/);
  assert.match(skill, /description:\s+\S/);

  const codex = json('.codex-plugin/plugin.json');
  const claude = json('.claude-plugin/plugin.json');
  assert.equal(codex.name, 'health-command-center');
  assert.equal(claude.name, 'health-command-center');
  assert.equal(codex.skills, './skills/');
  assert.equal(codex.repository, 'https://github.com/oxydavid-maxx/health-command-center');
  assert.equal(codex.license, 'MIT');
});

test('registration manifest keeps the Vault external and Garmin independent', () => {
  const registration = json('manifests/registration.json');
  assert.equal(registration.canonical.local_root, 'C:/dev/skills/health-command-center');
  assert.equal(registration.canonical.entrypoint, 'skills/health-command-center/SKILL.md');
  assert.equal(registration.dependencies.garmin.role, 'runtime-data-producer');
  assert.equal(registration.dependencies.garmin.canonical_owner, 'garmin-claude-analysis');
  assert.equal(registration.dependencies.garmin.trigger_owner, 'health-command-center');
  assert.deepEqual(registration.vault.allowed_content.sort(), [
    'allowed-paths', 'domain-law', 'skill-catalog', 'workflow-binding'
  ]);
  assert.equal(registration.vault.skill_bytes_allowed, false);
  assert.equal(registration.installation.mode, 'junction-to-canonical-entrypoint');
});

test('Health owns the daily trigger while Garmin keeps acquisition implementation', () => {
  const refresh = read('scripts/daily-refresh.ps1');
  assert.match(refresh, /scripts\.garmin_refresh/);
  assert.match(refresh, /evaluate-recovery\.cjs/);
  assert.match(refresh, /src\.build_athlete_json/);
  assert.match(refresh, /src\.vault_sync/);
  const order = [
    refresh.indexOf('scripts.garmin_refresh'),
    refresh.indexOf('& $node $recoveryEvaluator'),
    refresh.indexOf('src.build_athlete_json'),
    refresh.indexOf('src.vault_sync'),
  ];
  assert.deepEqual(order, [...order].sort((a, b) => a - b));
  assert.doesNotMatch(refresh, /fetch_garmin\s*\(/);
});

test('scheduler binds the merged Garmin runtime without using the dirty development checkout', () => {
  const refresh = read('scripts/daily-refresh.ps1');
  const installer = read('scripts/install-schedule.ps1');
  const registration = json('manifests/registration.json');

  assert.match(refresh, /GarminRoot\s*=\s*'C:\\dev\\runtime\\garmin-health-command-center'/);
  assert.match(refresh, /PythonPath\s*=\s*'C:\\dev\\apps\\garmin-claude-analysis\\\.venv\\Scripts\\python\.exe'/);
  assert.doesNotMatch(refresh, /Join-Path\s+\$garminRootResolved\s+'\.venv\\Scripts\\python\.exe'/);
  assert.match(installer, /-GarminRoot/);
  assert.match(installer, /-PythonPath/);
  assert.match(installer, /Get-Command\s+pwsh\.exe/);
  assert.match(installer, /New-ScheduledTaskAction\s+-Execute\s+\$pwsh/);
  assert.equal(registration.dependencies.garmin.runtime_root, 'C:/dev/runtime/garmin-health-command-center');
  assert.equal(registration.dependencies.garmin.python_runtime, 'C:/dev/apps/garmin-claude-analysis/.venv/Scripts/python.exe');
});

test('skill preserves the approved Health decision and authority invariants', () => {
  const skill = read('skills/health-command-center/SKILL.md');
  for (const invariant of [
    'Fixed menu is the baseline',
    'Garmin is an independent runtime data producer',
    'InBody',
    'Strength',
    'Recommendations remain proposed',
    'Health/status.md',
  ]) assert.ok(skill.includes(invariant), `missing invariant: ${invariant}`);
});

test('repo owns a safe registration script and migration proof tool', () => {
  const register = read('scripts/register.ps1');
  assert.match(register, /New-Item\s+-ItemType\s+Junction/i);
  assert.match(register, /health-command-center/);
  assert.ok(fs.existsSync(path.join(ROOT, 'scripts/migration-proof.ps1')));
});

test('Recovery Contract keeps policy in Health and presentation deliberately plain', () => {
  const schema = json('contracts/recovery-contract-v1.schema.json');
  const policy = read('docs/recovery-contract-v1.md');
  assert.equal(schema.properties.contract_version.const, '1.0');
  assert.deepEqual(schema.properties.presentation.required, ['action', 'evidence', 'freshness']);
  assert.match(policy, /user-adjusted-recovery/);
  assert.match(policy, /traffic-light legend/);
  assert.match(policy, /never creates an automatic make-up session/);
});
