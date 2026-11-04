# QuizAura — Automatic Daily Quiz (free, no Firebase paid plan)

Every night a free GitHub Actions job asks the AI for **10 questions on a random topic**
and writes them to Firestore. The app already reads from there, so the new quiz is live
at **12:00 AM IST** with nobody touching anything.

Why not Cloud Functions? Scheduled Cloud Functions need the paid Blaze plan.
GitHub Actions + Firebase Admin SDK works on the **free Spark plan**.

## One-time setup (about 10 minutes)

1. **Create a GitHub repo** (private is fine) and upload everything in this folder
   (`generate-daily-quiz.mjs`, `package.json`, `selftest.mjs`, `.github/workflows/daily-quiz.yml`).
2. **Get a Firebase service account key** (free):
   Firebase Console → ⚙ Project settings → *Service accounts* → *Generate new private key*.
   Open the downloaded `.json` file and copy **all** of its text.
3. In the GitHub repo: *Settings → Secrets and variables → Actions → New repository secret*. Add:

   | Secret name | Value |
   |---|---|
   | `FIREBASE_SERVICE_ACCOUNT` | the full JSON from step 2 |
   | `QUIZ_API_1_KEY` | the same key as `Quiz_API` in your app's `.env` |
   | `QUIZ_API_2_KEY` | *(optional)* second key, used if the first fails |
   | `QUIZ_API_3_KEY` | *(optional)* third key |

   Optional per-key overrides use the same names as the app: `QUIZ_API_1_BASE_URL`, `QUIZ_API_1_MODEL`, etc.
4. **Test it now:** repo → *Actions → Daily Quiz Generator → Run workflow*.
   Leave the fields empty. In Firestore you should see `dailyQuizzes/<date>` with 10 docs in `questions`.
5. In the app project, replace the files from this package (paths match `lib/`).
6. **Firestore index (one time):** the leaderboard sorts by `percentage` then `timeTaken`. The first time you
   open it, Firestore prints a link in the debug console — click it, then *Create index* (free).

Done. From now on it runs by itself.

## When it runs (IST)

| Time | What |
|---|---|
| 11:00 PM | Creates **tomorrow's** quiz (ready before midnight) |
| 11:45 PM, 12:15 AM, 06:30 AM | Automatic retries. Each one exits instantly if the quiz already exists |

GitHub can start scheduled jobs a few minutes late, which is why the quiz is made *before*
midnight with `publishAt = 12:00 AM IST`.

## What the app does

- Quiz id = IST date (`2026-11-05`). Rolls over at 12:00 AM IST, even if the screen is open.
- Result is shown **immediately** after submitting (score, pass/fail, answer review, leaderboard).
- "View My Result" appears when the user has already played today.
- Admin → Daily Quiz Manager still works as a manual override (it now uses the same IST day).

## Notes

- The free Spark limits (20k writes/day) are far above the ~12 writes per day this uses.
- The app and the generator must agree on the timezone: `DailyQuizClock.offset` (Dart) and
  `IST_OFFSET_MINUTES` (JS).
- If GitHub ever pauses the schedule (it can for repos with no activity for a long time),
  open *Actions* and click *Enable workflow*. If a run fails, GitHub emails you.
- To regenerate a day that nobody has played yet: *Run workflow* → `force = true`.
- Rules: the generator uses the Admin SDK, which bypasses Firestore rules. Clients only need to
  **read** `dailyQuizzes`, as they do today.
