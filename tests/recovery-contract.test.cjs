const assert = require('node:assert/strict');
const test = require('node:test');

const { evaluateRecovery } = require('../scripts/evaluate-recovery.cjs');

test('current poor sleep and low Garmin evidence recommends rest without inventing a score', () => {
  const result = evaluateRecovery({
    meta: { normalized_date: '2026-07-21T07:46:00+08:00' },
    sleep: [{ date: '2026-07-21', total_hr: 5.5 }],
    hrv: [{ date: '2026-07-21', last_night_avg: 26, status: 'LOW', baseline_low: 30, baseline_upper: 44 }],
    training_readiness: [{ date: '2026-07-21', score: 28, level: 'LOW' }],
    body_battery: [{ date: '2026-07-21', at_wake: 22 }],
  }, { evaluationDate: '2026-07-21' });

  assert.equal(result.contract_version, '1.0');
  assert.equal(result.lifecycle, 'fresh');
  assert.equal(result.state, 'recover');
  assert.equal(result.presentation.action, '今天：休息');
  assert.match(result.presentation.evidence, /睡眠 5\.5 小時/);
  assert.equal(result.acquired_at, '2026-07-21T07:46:00+08:00');
  assert.match(result.presentation.freshness, /Garmin 7\/21/);
  assert.equal('score' in result, false);
});

test('stale sleep keeps the action unknown even when other Garmin rows are current', () => {
  const result = evaluateRecovery({
    meta: { export_date: '2026-07-21T07:46:00+08:00' },
    sleep: [{ date: '2026-07-20', total_hr: 7.2 }],
    hrv: [{ date: '2026-07-21', last_night_avg: 35, status: 'BALANCED' }],
    training_readiness: [{ date: '2026-07-21', score: 72, level: 'HIGH' }],
    resting_hr: [{ date: '2026-07-21', value: 52 }],
  }, { evaluationDate: '2026-07-21' });

  assert.equal(result.lifecycle, 'pending');
  assert.equal(result.state, 'unknown');
  assert.equal(result.presentation.action, '今天：等資料');
  assert.match(result.presentation.freshness, /睡眠只到 7\/20/);
});

test('a volunteered user recovery decision overrides Garmin and is not a missed workout', () => {
  const result = evaluateRecovery({
    meta: { export_date: '2026-07-21T07:46:00+08:00' },
    sleep: [{ date: '2026-07-21', total_hr: 7.5 }],
    hrv: [{ date: '2026-07-21', last_night_avg: 38, status: 'BALANCED' }],
    training_readiness: [{ date: '2026-07-21', score: 80, level: 'HIGH' }],
  }, {
    evaluationDate: '2026-07-21',
    userDecision: {
      date: '2026-07-21',
      decision: 'rest',
      reason: '昨晚沒睡好，所以今天不跑',
      planned_session: '輕鬆跑 5 km',
      source: 'user',
    },
  });

  assert.equal(result.state, 'recover');
  assert.equal(result.plan_effect, 'user-adjusted-recovery');
  assert.equal(result.presentation.action, '今天：休息');
  assert.equal(result.presentation.evidence, '你回報昨晚沒睡好，所以今天不跑。');
  assert.equal(result.user_decision.planned_session, '輕鬆跑 5 km');
});

test('current sleep alone cannot produce a confident green recommendation', () => {
  const result = evaluateRecovery({
    meta: { export_date: '2026-07-21T07:46:00+08:00' },
    sleep: [{ date: '2026-07-21', total_hr: 7.4 }],
  }, { evaluationDate: '2026-07-21' });

  assert.equal(result.state, 'watch');
  assert.equal(result.confidence, 'low');
  assert.equal(result.presentation.action, '今天：保守做');
  assert.deepEqual(result.reason_codes.sort(), ['hrv-missing', 'readiness-missing']);
});

test('the contract preserves prior user recovery decisions for later weekly reconciliation', () => {
  const history = [{
    date: '2026-07-21', decision: 'rest', reason: '昨晚沒睡好，所以今天不跑',
    planned_session: '輕鬆跑 5 km', source: 'user',
  }];
  const result = evaluateRecovery({
    meta: { normalized_date: '2026-07-22T07:46:00+08:00' },
    sleep: [{ date: '2026-07-22', total_hr: 7.2 }],
    hrv: [{ date: '2026-07-22', last_night_avg: 36, status: 'BALANCED' }],
    training_readiness: [{ date: '2026-07-22', score: 78, level: 'HIGH' }],
  }, { evaluationDate: '2026-07-22', userDecisions: history });

  assert.deepEqual(result.user_decisions, history);
  assert.equal(result.user_decision, undefined);
  assert.equal(result.state, 'good');
});
