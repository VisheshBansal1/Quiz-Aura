require("dotenv").config();
const express = require("express");
const axios = require("axios");
const admin = require("firebase-admin");
const cors = require("cors");

const app = express();
app.use(cors());
app.use(express.json());

console.log("🚀 Starting backend...");

// =======================
// Firebase (DEV MODE)
// =======================
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// =======================
// Judge0 Config
// =======================
const JUDGE0_URL = "https://judge0-ce.p.rapidapi.com";
const JUDGE0_KEY = process.env.JUDGE0_KEY;
const JUDGE0_HOST = "judge0-ce.p.rapidapi.com";

// =======================
// Utils
// =======================
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const normalize = (text = "") =>
  text.trim().replace(/\r\n/g, "\n");

// =======================
// Judge0 helpers
// =======================
async function submit(code, input, languageId) {
  const res = await axios.post(
    `${JUDGE0_URL}/submissions?base64_encoded=false`,
    {
      source_code: code,
      stdin: input,
      language_id: languageId,
    },
    {
      headers: {
        "X-RapidAPI-Key": JUDGE0_KEY,
        "X-RapidAPI-Host": JUDGE0_HOST,
      },
    }
  );
  return res.data.token;
}

async function getResult(token) {
  while (true) {
    const res = await axios.get(
      `${JUDGE0_URL}/submissions/${token}?base64_encoded=false`,
      {
        headers: {
          "X-RapidAPI-Key": JUDGE0_KEY,
          "X-RapidAPI-Host": JUDGE0_HOST,
        },
      }
    );

    const status = res.data.status?.id;
    if (status === 1 || status === 2) {
      await sleep(700);
      continue;
    }
    return res.data;
  }
}

// =======================
// Grading logic
// =======================
async function grade(code, languageId, visible, hidden, points) {
  let passed = 0;

  const runCases = async (cases) => {
    for (const tc of cases) {
      const token = await submit(code, tc.input || "", languageId);
      const result = await getResult(token);

      if (result.status.id === 6) {
        throw new Error("Compilation Error");
      }

      if (result.status.id !== 3) continue;

      if (
        normalize(result.stdout) === normalize(tc.output)
      ) {
        passed++;
      }
    }
  };

  await runCases(visible);
  await runCases(hidden);

  return {
    passed,
    total: visible.length + hidden.length,
    score: passed * points,
  };
}

// =======================
// Routes
// =======================
app.get("/", (req, res) => {
  res.send("Judge0 backend running");
});

app.post("/grade", async (req, res) => {
  const { quizId, questionId, code, languageId } = req.body;

  if (!quizId || !questionId || !code || !languageId) {
    return res.status(400).json({ error: "Missing fields" });
  }

  try {
    const qRef = db
      .collection("quizzes")
      .doc(quizId)
      .collection("questions")
      .doc(questionId);

    const snap = await qRef.get();
    if (!snap.exists) {
      return res.status(404).json({ error: "Question not found" });
    }

    const q = snap.data();

    const result = await grade(
      code,
      languageId,
      q.visibleTestCases,
      q.hiddenTestCases,
      q.pointsPerTestCase || 1
    );

    res.json(result);
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

const PORT = 3000;

app.listen(PORT, "0.0.0.0", () => {
  console.log(`✅ Server running on 0.0.0.0:${PORT}`);
});
