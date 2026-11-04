// QuizAura — automatic Daily Quiz generator.
//
// Runs on a free GitHub Actions schedule (no Firebase Cloud Functions, so no
// Blaze plan). Each run:
//   1. works out the target quiz date (IST),
//   2. exits quietly if that quiz already exists (safe to run many times),
//   3. picks a random topic (not used in the last 7 days),
//   4. asks the AI for 10 MCQs (fails over across up to 3 API keys),
//   5. validates + writes dailyQuizzes/{YYYY-MM-DD} with questions q01..q10.
//
// The quiz is created ahead of time (from 22:00 IST) with publishAt = 12:00 AM
// IST, so it is already waiting when midnight arrives, even if GitHub starts
// the job a few minutes late.

import { fileURLToPath } from 'node:url';

// ── Config (keep in sync with lib/quizes/home/daily_quiz/daily_quiz_clock.dart)
export const IST_OFFSET_MINUTES = 330;
const IST_MS = IST_OFFSET_MINUTES * 60_000;
const DAY_MS = 86_400_000;
export const QUESTION_COUNT = 10;
const TIME_LIMIT_SECONDS = 600;
const XP_REWARD = 150;
const DIFFICULTY = 'Medium';
const TOPIC_COOLDOWN_DAYS = 7;

export const TOPICS = [
  // DSA
  'Arrays and Strings', 'Linked Lists', 'Trees and Graphs', 'Dynamic Programming',
  'Sorting Algorithms', 'Searching Algorithms', 'Stack and Queue',
  'Hashing and Hash Maps', 'Recursion and Backtracking', 'Heaps and Priority Queues',
  'Binary Search', 'Greedy Algorithms', 'Time and Space Complexity',
  // Core CS / programming
  'Object-Oriented Programming', 'Operating Systems Basics', 'DBMS and SQL',
  'Computer Networks Basics', 'Git and Version Control', 'Python Fundamentals',
  'Java Fundamentals', 'JavaScript Fundamentals', 'Flutter and Dart Basics',
  // Aptitude
  'Percentages and Profit-Loss', 'Time, Speed and Distance', 'Ratios and Proportions',
  'Simple and Compound Interest', 'Work and Time Problems', 'Number Systems',
  'Averages and Mixtures', 'Permutations and Combinations', 'Probability',
  'Geometry and Mensuration',
  // Logical reasoning
  'Blood Relations', 'Direction Sense', 'Coding and Decoding', 'Syllogisms',
  'Seating Arrangements', 'Puzzles and Rankings', 'Data Sufficiency',
  'Analogies and Series', 'Clocks and Calendars',
  // Verbal
  'Grammar and Error Spotting', 'Vocabulary and Synonyms', 'Sentence Completion',
  'Idioms and Phrases', 'One-word Substitution', 'Active and Passive Voice',
  // General knowledge
  'Indian History and Culture', 'World Geography', 'Science and Technology',
  'Sports and Olympics', 'Books and Authors', 'Awards and Honours',
  'Famous Inventions', 'Space Exploration', 'Environmental Science',
  'Indian Constitution and Polity', 'Famous Personalities', 'World Capitals and Currencies',
];

// ── Date helpers ───────────────────────────────────────────────────────────
export const istDateString = (ms) =>
  new Date(ms + IST_MS).toISOString().slice(0, 10);

/** Which quiz this run should make. From 22:00 IST onward that is *tomorrow's*
 *  quiz (pre-generation); earlier it is today's (catch-up if a run was missed). */
export function resolveTargetDate(nowMs = Date.now(), override = '') {
  if (override) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(override)) {
      throw new Error(`QUIZ_DATE must look like 2026-11-05, got "${override}"`);
    }
    return override;
  }
  return istDateString(nowMs + 2 * 3_600_000);
}

export function dayWindow(dateStr) {
  const publishAt = new Date(Date.parse(`${dateStr}T00:00:00Z`) - IST_MS); // 12:00 AM IST
  const expiresAt = new Date(publishAt.getTime() + DAY_MS - 1000);         // 11:59:59 PM IST
  return { publishAt, expiresAt };
}

// ── Small seeded RNG so a given date always picks the same topic ───────────
function hashString(str) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}
export function makeRng(seedStr) {
  let a = hashString(seedStr);
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function pickTopic(dateStr, recentTopics = []) {
  const recent = new Set(recentTopics.map((t) => String(t).toLowerCase()));
  const pool = TOPICS.filter((t) => !recent.has(t.toLowerCase()));
  const list = pool.length ? pool : TOPICS;
  return list[Math.floor(makeRng(`topic:${dateStr}`)() * list.length)];
}

// ── AI providers (OpenAI-compatible chat/completions; Groq by default) ─────
const DEFAULT_URL = 'https://api.groq.com/openai/v1/chat/completions';
const DEFAULT_MODEL = 'openai/gpt-oss-20b';
const env = (k) => (process.env[k] ?? '').trim();
const clean = (k) => k.replace(/["']/g, '').trim();

export function loadProviders() {
  const slots = [
    { id: 'API 1', key: env('QUIZ_API_1_KEY') || env('QUIZ_API'), n: 1 },
    { id: 'API 2', key: env('QUIZ_API_2_KEY'), n: 2 },
    { id: 'API 3', key: env('QUIZ_API_3_KEY'), n: 3 },
  ];
  return slots
    .filter((s) => clean(s.key))
    .map((s) => ({
      id: s.id,
      key: clean(s.key),
      url: env(`QUIZ_API_${s.n}_BASE_URL`) || DEFAULT_URL,
      model: env(`QUIZ_API_${s.n}_MODEL`) || DEFAULT_MODEL,
    }));
}

function buildPrompt(topic) {
  return `Generate exactly ${QUESTION_COUNT} UNIQUE multiple-choice questions on the topic "${topic}".
Difficulty: ${DIFFICULTY} (a sensible mix of easy and moderately hard).
The questions are for a daily quiz in a learning app, so they must be factually correct, unambiguous, and have exactly one correct answer.

Respond ONLY with a JSON object in this exact shape (no markdown, no text outside the JSON):
{
  "questions": [
    {
      "question": "string",
      "options": ["A","B","C","D"],
      "correctIndex": 0,
      "solution": "Short clear explanation why the correct answer is right"
    }
  ]
}

Rules:
- "questions" must contain exactly ${QUESTION_COUNT} items, none repeating each other.
- Exactly 4 distinct options per question, without "A)" / "1." prefixes.
- correctIndex must be an integer between 0 and 3.
- Keep each "solution" under 25 words.
- Do not include any keys other than question, options, correctIndex, solution.`;
}

async function callProvider(p, prompt) {
  const res = await fetch(p.url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${p.key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: p.model,
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.5,
      max_tokens: 5000,
      response_format: { type: 'json_object' },
    }),
    signal: AbortSignal.timeout(60_000),
  });
  if (!res.ok) {
    const body = (await res.text()).slice(0, 300);
    throw new Error(`${p.id} HTTP ${res.status}: ${body}`);
  }
  const json = await res.json();
  const choice = json?.choices?.[0];
  const content = choice?.message?.content;
  if (typeof content !== 'string' || !content.trim()) throw new Error(`${p.id}: empty response`);
  if (choice.finish_reason === 'length') throw new Error(`${p.id}: response truncated`);
  return content;
}

// ── Parse + validate ───────────────────────────────────────────────────────
export function parseQuestions(raw) {
  const start = raw.indexOf('{');
  const end = raw.lastIndexOf('}');
  if (start === -1 || end < start) throw new Error('No JSON object in AI response');
  const parsed = JSON.parse(raw.slice(start, end + 1));
  const list = Array.isArray(parsed) ? parsed : parsed?.questions;
  if (!Array.isArray(list)) throw new Error('No questions array in AI response');

  const seen = new Set();
  const out = [];
  for (const q of list) {
    const question = typeof q?.question === 'string' ? q.question.trim() : '';
    const options = Array.isArray(q?.options) ? q.options.map((o) => String(o).trim()) : [];
    const correctIndex = q?.correctIndex;
    const solution = typeof q?.solution === 'string' ? q.solution.trim() : '';

    if (!question) continue;
    if (options.length !== 4 || options.some((o) => !o)) continue;
    if (new Set(options.map((o) => o.toLowerCase())).size !== 4) continue;
    if (!Number.isInteger(correctIndex) || correctIndex < 0 || correctIndex > 3) continue;
    if (solution.length < 5) continue;
    const key = question.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ question, options, correctIndex, solution });
  }
  return out;
}

/** LLMs love putting the right answer first. Shuffle options (seeded) and
 *  remap correctIndex so answer positions are evenly spread. */
export function shuffleOptions(questions, seedStr) {
  const rng = makeRng(`opts:${seedStr}`);
  return questions.map((q) => {
    const order = [0, 1, 2, 3];
    for (let i = 3; i > 0; i--) {
      const j = Math.floor(rng() * (i + 1));
      [order[i], order[j]] = [order[j], order[i]];
    }
    return {
      ...q,
      options: order.map((i) => q.options[i]),
      correctIndex: order.indexOf(q.correctIndex),
    };
  });
}

async function generateQuestions(topic, dateStr, providers) {
  if (!providers.length) {
    throw new Error('No AI key configured. Add QUIZ_API_1_KEY (and optionally _2/_3) as GitHub secrets.');
  }
  const prompt = buildPrompt(topic);
  const errors = [];
  // Every provider gets up to 2 attempts; first one to return 10 valid MCQs wins.
  for (const p of providers) {
    for (let attempt = 1; attempt <= 2; attempt++) {
      try {
        const questions = parseQuestions(await callProvider(p, prompt));
        if (questions.length >= QUESTION_COUNT) {
          console.log(`✔ ${p.id} returned ${questions.length} valid questions (attempt ${attempt})`);
          return { questions: questions.slice(0, QUESTION_COUNT), provider: p.id };
        }
        throw new Error(`only ${questions.length}/${QUESTION_COUNT} valid questions`);
      } catch (e) {
        console.warn(`✖ ${p.id} attempt ${attempt}: ${e.message}`);
        errors.push(`${p.id}: ${e.message}`);
        await new Promise((r) => setTimeout(r, 2000 * attempt));
      }
    }
  }
  throw new Error(`All AI providers failed.\n${errors.join('\n')}`);
}

// ── Main ───────────────────────────────────────────────────────────────────
async function main() {
  const saJson = env('FIREBASE_SERVICE_ACCOUNT');
  if (!saJson) throw new Error('FIREBASE_SERVICE_ACCOUNT secret is missing.');

  const { default: admin } = await import('firebase-admin');
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(saJson)) });
  const db = admin.firestore();

  const dateStr = resolveTargetDate(Date.now(), env('QUIZ_DATE'));
  const force = ['1', 'true', 'yes'].includes(env('FORCE').toLowerCase());
  const { publishAt, expiresAt } = dayWindow(dateStr);
  console.log(`Target quiz: ${dateStr} (live ${publishAt.toISOString()} → ${expiresAt.toISOString()})`);

  const quizRef = db.collection('dailyQuizzes').doc(dateStr);
  const existing = await quizRef.get();
  if (existing.exists && !force) {
    const d = existing.data();
    const qs = await quizRef.collection('questions').get();
    if (d.isPublished === true && qs.size >= 5) {
      console.log(`Quiz ${dateStr} already exists (${qs.size} questions, source=${d.source ?? 'n/a'}). Nothing to do.`);
      return;
    }
    console.log('Existing quiz is incomplete — regenerating.');
  }
  if (existing.exists && force) {
    const attempts = await quizRef.collection('leaderboard').limit(1).get();
    if (!attempts.empty) {
      throw new Error(`Refusing to overwrite ${dateStr}: players have already submitted answers.`);
    }
  }

  // Recent topics → avoid repeats
  const recentSnap = await db.collection('dailyQuizzes').orderBy('publishAt', 'desc').limit(TOPIC_COOLDOWN_DAYS + 1).get();
  const recentTopics = recentSnap.docs.filter((d) => d.id !== dateStr).map((d) => d.data().topic).filter(Boolean);

  const topic = pickTopic(dateStr, recentTopics);
  console.log(`Topic: ${topic}`);

  const { questions: raw, provider } = await generateQuestions(topic, dateStr, loadProviders());
  const questions = shuffleOptions(raw, dateStr);

  const batch = db.batch();
  // Old docs (only possible on force/incomplete reruns) are replaced in place: ids are fixed.
  const old = await quizRef.collection('questions').get();
  old.docs.forEach((d) => batch.delete(d.ref));
  questions.forEach((q, i) => {
    batch.set(quizRef.collection('questions').doc(`q${String(i + 1).padStart(2, '0')}`), q);
  });
  batch.set(quizRef, {
    title: `Daily Challenge — ${topic}`,
    description: `Today's AI-curated quiz on ${topic}. 10 questions, 10 minutes. Good luck!`,
    topic,
    timeLimitSeconds: TIME_LIMIT_SECONDS,
    xpReward: XP_REWARD,
    totalQuestions: questions.length,
    publishAt: admin.firestore.Timestamp.fromDate(publishAt),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    isPublished: true,
    source: 'auto',
    generatedBy: provider,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await batch.commit(); // atomic: the app never sees a quiz without its questions
  console.log(`✅ Published dailyQuizzes/${dateStr} with ${questions.length} questions.`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((e) => {
    console.error('❌', e.message);
    process.exit(1);
  });
}
