const express = require("express");
const cors = require("cors");
const { spawn } = require("child_process");
const fs = require("fs");
const path = require("path");

const app = express();
app.use(cors());
app.use(express.json());

// Graceful JSON parse errors.
app.use((err, req, res, next) => {
  if (err && err.type === "entity.parse.failed") {
    return res.status(400).json({ ok: false, err: "Invalid JSON body." });
  }
  next(err);
});

// Adjust this if your binary is elsewhere.
// This assumes: ui-next is inside MiniALU-X, and binary is at MiniALU-X/alu
const ALU_BIN = path.resolve(__dirname, "..", "..", "alu");

function cleanOutput(raw) {
  if (!raw) return "";

  let out = String(raw);

  // Normalize line endings first.
  out = out.replace(/\r\n?/g, "\n");

  // Strip ANSI escape/control sequences (CSI/OSC/short ESC forms).
  out = out.replace(/\u001B\][^\u0007]*(?:\u0007|\u001B\\)/g, "");
  out = out.replace(/\u001B\[[0-?]*[ -/]*[@-~]/g, "");
  out = out.replace(/\u001B[@-_]/g, "");

  // Remove remaining non-printable control chars except tab/newline.
  out = out.replace(/[^\x09\x0A\x20-\x7E]/g, "");

  // Trim right-space noise per line.
  out = out
    .split("\n")
    .map((line) => line.replace(/[ \t]+$/g, ""))
    .join("\n");

  // Collapse long blank runs and trim blank boundaries.
  out = out.replace(/\n{3,}/g, "\n\n");
  out = out.replace(/^\n+|\n+$/g, "");

  return out;
}

function extractUseful(cleaned, choice) {
  const opByChoice = {
    "1": "ADD",
    "2": "SUB",
    "3": "AND",
    "4": "OR",
    "5": "XOR",
    "6": "SHL",
    "7": "SHR",
    "8": "CMP",
  };

  const op = opByChoice[String(choice ?? "").trim()];
  if (!op) return cleaned;

  const startMarker = `--- ${op} ---`;
  const endMarker = "Press Enter to return to menu...";

  const start = cleaned.indexOf(startMarker);
  if (start < 0) return cleaned;

  const end = cleaned.indexOf(endMarker, start);
  const block = end < 0 ? cleaned.slice(start) : cleaned.slice(start, end);

  return cleanOutput(block);
}

app.get("/health", (req, res) => res.json({ ok: true, ALU_BIN }));

app.post("/run", (req, res) => {
  const { choice, A, B, k } = req.body || {};
  const reply = (status, payload) => {
    if (res.headersSent) return;
    res.status(status).json(payload);
  };

  // Validate request early. This bridge only supports numeric main-menu ALU ops (1..8).
  const c = String(choice ?? "").trim();
  if (!/^[1-8]$/.test(c)) {
    return reply(400, {
      ok: false,
      err: "Invalid choice. Supported: 1..8 (main ALU ops).",
    });
  }

  const coerceU32 = (v, def = 0) => {
    if (typeof v === "number" && Number.isFinite(v)) return v >>> 0;
    const s = String(v ?? "").trim();
    if (!/^-?\d+$/.test(s)) return def >>> 0;
    const n = Number(s);
    if (!Number.isFinite(n)) return def >>> 0;
    return (n >>> 0) >>> 0;
  };

  const aVal = coerceU32(A, 0);
  const bVal = coerceU32(B, 0);
  const kVal = Math.min(31, coerceU32(k, 0));
  const needsK = c === "6" || c === "7"; // SHL/SHR only

  try {
    fs.accessSync(ALU_BIN, fs.constants.X_OK);
  } catch {
    return reply(500, {
      ok: false,
      err: `ALU binary not executable or missing: ${ALU_BIN}`,
    });
  }

  const child = spawn(ALU_BIN, [], { stdio: ["pipe", "pipe", "pipe"] });

  // Capture combined output while preserving arrival order across stdout/stderr.
  const chunks = [];
  const pushChunk = (s) => {
    if (chunks.length > 8192) return; // hard cap chunk count
    chunks.push(s);
  };

  // Drive stdin one prompt at a time. Piping all lines at once is unsafe because
  // the NASM program reads fixed-size blocks and can consume multiple lines in one read().
  let sentChoice = false;
  let sentA = false;
  let sentB = false;
  let sentK = false;
  let sentEnter = false;
  let sentQuit = false;

  const sendLine = (line) => {
    try {
      child.stdin.write(String(line) + "\n");
    } catch {
      // ignore write errors after exit
    }
  };

  // Choice is read via a 2-byte read; send it immediately.
  sendLine(c);
  sentChoice = true;

  const maybeDriveFromText = (txt) => {
    // Prompts are printed before each read_line in the assembly program.
    if (!sentA && txt.includes("Enter A")) {
      sendLine(aVal);
      sentA = true;
    }
    if (sentA && !sentB && txt.includes("Enter B")) {
      sendLine(bVal);
      sentB = true;
    }
    if (needsK && sentA && sentB && !sentK && txt.includes("shift k")) {
      sendLine(kVal);
      sentK = true;
    }
    if (!sentEnter && txt.includes("Press Enter")) {
      sendLine("");
      sentEnter = true;
    }
    // After completing one operation, return to menu and exit cleanly.
    if (sentEnter && !sentQuit && txt.includes("Enter choice")) {
      sendLine("Q");
      sentQuit = true;
    }
  };

  child.stdout.on("data", (d) => {
    const s = d.toString("utf8");
    pushChunk(s);
    maybeDriveFromText(s);
  });

  child.stderr.on("data", (d) => {
    const s = d.toString("utf8");
    pushChunk(s);
    // stderr may also include prompts in some environments; drive defensively.
    maybeDriveFromText(s);
  });

  child.on("close", (code) => {
    const raw = chunks.join("");
    const cleaned = cleanOutput(raw);
    const useful = extractUseful(cleaned, c);

    if (code !== 0) return reply(500, { ok: false, code, err: useful || cleaned });
    reply(200, { ok: true, output: useful || cleaned });
  });

  child.on("error", (e) => {
    const raw = chunks.join("");
    const cleaned = cleanOutput(raw);
    reply(500, { ok: false, err: String(e?.message || e), output: cleaned });
  });

  // Safety timeout: if the binary blocks waiting for input, don't hang the server.
  const timeoutMs = 5000;
  const t = setTimeout(() => {
    try {
      child.kill("SIGKILL");
    } catch {}
  }, timeoutMs);
  child.on("close", () => clearTimeout(t));

  // Ensure stdin closes once the expected inputs are sent.
  // If prompts never appear (unexpected binary/UI), timeout will kill the child.
  // End stdin once we've sent what we can and Enter (or when Enter isn't needed).
  const endCheck = setInterval(() => {
    const doneAB = sentA && sentB;
    const doneK = !needsK || sentK;
    const done = sentChoice && doneAB && doneK && sentEnter && sentQuit;
    if (!done) return;
    clearInterval(endCheck);
    try {
      child.stdin.end();
    } catch {}
  }, 10);
  child.on("close", () => clearInterval(endCheck));
});

app.listen(4000, () => {
  console.log("Backend running on http://localhost:4000");
  console.log("Using ALU binary:", ALU_BIN);
});
