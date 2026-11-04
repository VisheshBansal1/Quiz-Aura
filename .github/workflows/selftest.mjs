// Offline checks of the pure logic (no network, no Firebase): npm test
import assert from 'node:assert/strict';
import { resolveTargetDate, dayWindow, pickTopic, parseQuestions, shuffleOptions, TOPICS } from './generate-daily-quiz.mjs';

const utc = (s) => Date.parse(s);

// 22:00 IST (16:30 UTC) on Nov 4 -> pre-generate Nov 5
assert.equal(resolveTargetDate(utc('2026-11-04T16:30:00Z')), '2026-11-05');
// 21:59 IST (16:29 UTC) -> still today's (Nov 4)
assert.equal(resolveTargetDate(utc('2026-11-04T16:29:00Z')), '2026-11-04');
// 11:00 PM IST run (17:30 UTC Nov 4) -> Nov 5
assert.equal(resolveTargetDate(utc('2026-11-04T17:30:00Z')), '2026-11-05');
// 12:15 AM IST Nov 5 (18:45 UTC Nov 4) -> Nov 5
assert.equal(resolveTargetDate(utc('2026-11-04T18:45:00Z')), '2026-11-05');
// 06:30 AM IST Nov 5 (01:00 UTC Nov 5) -> Nov 5
assert.equal(resolveTargetDate(utc('2026-11-05T01:00:00Z')), '2026-11-05');
// year rollover
assert.equal(resolveTargetDate(utc('2026-12-31T17:30:00Z')), '2027-01-01');
assert.equal(resolveTargetDate(0, '2026-11-09'), '2026-11-09');

// 12:00 AM IST Nov 5 == 18:30 UTC Nov 4
const w = dayWindow('2026-11-05');
assert.equal(w.publishAt.toISOString(), '2026-11-04T18:30:00.000Z');
assert.equal(w.expiresAt.toISOString(), '2026-11-05T18:29:59.000Z');

// Topic: deterministic per date, respects cooldown
const t1 = pickTopic('2026-11-05', []);
assert.equal(t1, pickTopic('2026-11-05', []));
assert.notEqual(pickTopic('2026-11-05', [t1]), t1);
assert.ok(TOPICS.includes(t1));

// Parse + shuffle keep the right answer
const mk = (i) => ({ question: `Q${i}?`, options: [`a${i}`, `b${i}`, `c${i}`, `d${i}`], correctIndex: 0, solution: 'Because it is.' });
const raw = JSON.stringify({ questions: Array.from({ length: 12 }, (_, i) => mk(i)).concat([mk(1), { question: 'bad', options: ['x'] }]) });
const parsed = parseQuestions('noise ' + raw + ' noise');
assert.equal(parsed.length, 12); // dup + malformed dropped
const shuffled = shuffleOptions(parsed, '2026-11-05');
shuffled.forEach((q, i) => assert.equal(q.options[q.correctIndex], `a${i}`));
assert.ok(new Set(shuffled.map((q) => q.correctIndex)).size > 1);
console.log('All self-tests passed ✔');
