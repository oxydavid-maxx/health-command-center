#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const latest = (rows) => [...(rows || [])].sort((a, b) => String(a.date || '').localeCompare(String(b.date || ''))).at(-1) || null;
const finite = (value) => value !== null && value !== '' && Number.isFinite(Number(value));
const upper = (value) => String(value || '').trim().toUpperCase();
const md = (date) => {
  const [, month, day] = String(date || '').slice(0, 10).split('-').map(Number);
  return month && day ? `${month}/${day}` : '—';
};
function signal(row, value, evaluationDate) {
  if (!row) return { source_date: null, value: null, validity: 'missing' };
  return {
    source_date: String(row.date || '').slice(0, 10) || null,
    value,
    validity: String(row.date || '').slice(0, 10) === evaluationDate && finite(value) ? 'current' : finite(value) ? 'stale' : 'invalid',
  };
}

function evaluateRecovery(data, options = {}) {
  const evaluationDate = String(options.evaluationDate || new Date().toISOString().slice(0, 10));
  const sleepRow = latest(data.sleep);
  const hrvRow = latest(data.hrv);
  const readinessRow = latest(data.training_readiness);
  const batteryRow = latest(data.body_battery);
  const rhrRow = latest(data.resting_hr);
  const sleep = signal(sleepRow, sleepRow?.total_hr, evaluationDate);
  const hrv = signal(hrvRow, hrvRow?.last_night_avg, evaluationDate);
  const readiness = signal(readinessRow, readinessRow?.score, evaluationDate);
  const battery = signal(batteryRow, batteryRow?.at_wake, evaluationDate);
  const rhr = signal(rhrRow, rhrRow?.value ?? rhrRow?.bpm ?? rhrRow?.resting_hr, evaluationDate);
  const acquiredAt = String(
    data.meta?.export_date
    || data.meta?.normalized_date
    || data.meta?.db_read_date
    || data.meta?.generated_at
    || ''
  );
  const digest = crypto.createHash('sha256').update(JSON.stringify(data)).digest('hex');

  const userDecisions = (Array.isArray(options.userDecisions)
    ? options.userDecisions
    : options.userDecision ? [options.userDecision] : [])
    .filter((row) => row && row.date && row.decision)
    .sort((left, right) => String(left.date).localeCompare(String(right.date)));
  const userDecision = userDecisions
    .filter((row) => String(row.date || '').slice(0, 10) === evaluationDate)
    .at(-1) || null;
  if (userDecision) {
    const reason = String(userDecision.reason || '今天需要恢復').replace(/[。.!！]+$/, '');
    return {
      contract_version: '1.0', evaluation_date: evaluationDate, acquired_at: acquiredAt,
      source_digest: digest, lifecycle: sleep.validity === 'current' ? 'fresh' : 'partial',
      state: 'recover', confidence: 'high', reason_codes: ['user-recovery-decision'],
      plan_effect: 'user-adjusted-recovery', signals: { sleep, hrv, readiness, body_battery: battery, resting_heart_rate: rhr },
      user_decisions: userDecisions,
      user_decision: userDecision,
      presentation: {
        action: '今天：休息',
        evidence: `你回報${reason}。`,
        freshness: `Garmin ${md(acquiredAt)} 已同步；睡眠${sleep.source_date ? `到 ${md(sleep.source_date)}` : '尚未收到'}。`,
      },
    };
  }

  if (sleep.validity !== 'current') {
    return {
      contract_version: '1.0', evaluation_date: evaluationDate, acquired_at: acquiredAt,
      source_digest: digest, lifecycle: 'pending', state: 'unknown', confidence: 'none',
      reason_codes: ['current-sleep-missing'], plan_effect: 'none',
      signals: { sleep, hrv, readiness, body_battery: battery, resting_heart_rate: rhr },
      user_decisions: userDecisions,
      presentation: {
        action: '今天：等資料',
        evidence: '今天的睡眠尚未同步，不做自動恢復判讀。',
        freshness: `Garmin ${md(acquiredAt)} 已同步；睡眠${sleep.source_date ? `只到 ${md(sleep.source_date)}` : '尚未收到'}。`,
      },
    };
  }

  const reasons = [];
  const sleepHours = Number(sleep.value);
  if (sleepHours < 6) reasons.push('sleep-under-6h');
  else if (sleepHours < 7) reasons.push('sleep-under-7h');
  const readinessLevel = upper(readinessRow?.level);
  if (readiness.validity !== 'current') reasons.push('readiness-missing');
  else if (['LOW', 'POOR'].includes(readinessLevel)) reasons.push('readiness-low');
  else if (readinessLevel === 'MODERATE') reasons.push('readiness-moderate');
  const hrvStatus = upper(hrvRow?.status);
  if (hrv.validity !== 'current') reasons.push('hrv-missing');
  else if (['LOW', 'POOR', 'UNBALANCED'].includes(hrvStatus)) reasons.push('hrv-low');
  if (battery.validity === 'current' && Number(battery.value) <= 25) reasons.push('body-battery-low');

  const adverse = reasons.filter((reason) => ['sleep-under-6h', 'readiness-low', 'hrv-low', 'body-battery-low'].includes(reason));
  const state = (reasons.includes('readiness-low') && adverse.length >= 2) || adverse.length >= 2
    ? 'recover'
    : reasons.length ? 'watch' : 'good';
  const action = state === 'recover' ? '今天：休息' : state === 'watch' ? '今天：保守做' : '今天：照計畫';
  const evidenceParts = [`睡眠 ${sleepHours.toFixed(1)} 小時`];
  if (readinessLevel) evidenceParts.push(`Garmin readiness ${readinessLevel}`);
  if (hrvStatus) evidenceParts.push(`HRV ${hrvStatus}`);

  return {
    contract_version: '1.0', evaluation_date: evaluationDate, acquired_at: acquiredAt,
    source_digest: digest, lifecycle: 'fresh', state,
    confidence: readiness.validity === 'current' && hrv.validity === 'current' ? 'high' : readiness.validity === 'current' || hrv.validity === 'current' ? 'medium' : 'low',
    reason_codes: reasons, plan_effect: state === 'good' ? 'keep-plan' : state === 'watch' ? 'conservative-execution' : 'propose-recovery',
    signals: { sleep, hrv, readiness, body_battery: battery, resting_heart_rate: rhr },
    user_decisions: userDecisions,
    presentation: {
      action,
      evidence: `${evidenceParts.join('；')}。`,
      freshness: `Garmin ${md(acquiredAt)} 已同步；睡眠到 ${md(sleep.source_date)}。`,
    },
  };
}

function parseArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) result[argv[index].replace(/^--/, '')] = argv[index + 1];
  return result;
}

function main(argv = process.argv.slice(2)) {
  const args = parseArgs(argv);
  if (!args.input || !args.output || !args.date) throw new Error('required: --input --output --date');
  const data = JSON.parse(fs.readFileSync(args.input, 'utf8'));
  let userDecisions = [];
  if (args['user-decisions'] && fs.existsSync(args['user-decisions'])) {
    userDecisions = fs.readFileSync(args['user-decisions'], 'utf8').split(/\r?\n/).filter(Boolean).map((line) => JSON.parse(line));
  }
  const result = evaluateRecovery(data, { evaluationDate: args.date, userDecisions });
  fs.mkdirSync(path.dirname(args.output), { recursive: true });
  const temporary = `${args.output}.tmp-${process.pid}`;
  fs.writeFileSync(temporary, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
  fs.renameSync(temporary, args.output);
  return result;
}

if (require.main === module) main();

module.exports = { evaluateRecovery, main };
