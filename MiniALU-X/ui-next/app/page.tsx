"use client";

import { useState } from "react";

const QUICK_OPS = [
  { value: "1", label: "ADD" },
  { value: "2", label: "SUB" },
  { value: "3", label: "AND" },
  { value: "4", label: "OR" },
  { value: "5", label: "XOR" },
  { value: "6", label: "SHL" },
  { value: "7", label: "SHR" },
  { value: "8", label: "CMP" },
];

const CHOICE_OPTIONS = [
  { value: "1", label: "1 - ADD" },
  { value: "2", label: "2 - SUB" },
  { value: "3", label: "3 - AND" },
  { value: "4", label: "4 - OR" },
  { value: "5", label: "5 - XOR" },
  { value: "6", label: "6 - SHL" },
  { value: "7", label: "7 - SHR" },
  { value: "8", label: "8 - CMP" },
  { value: "F", label: "F - Full Adder Table" },
  { value: "R", label: "R - Ripple Carry Adder" },
  { value: "T", label: "T - Logic Truth Table" },
  { value: "M", label: "M - Mini ALU System" },
];

function stripAnsi(raw: string): string {
  if (!raw) return "";
  return raw
    .replace(/\r\n?/g, "\n")
    .replace(/\u001B\][^\u0007]*(?:\u0007|\u001B\\)/g, "")
    .replace(/\u001B\[[0-?]*[ -/]*[@-~]/g, "")
    .replace(/\u001B[@-_]/g, "")
    .replace(/[^\x09\x0A\x20-\x7E]/g, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

export default function Home() {
  const [choice, setChoice] = useState("1");
  const [A, setA] = useState("2");
  const [B, setB] = useState("9");
  const [k, setK] = useState("1");
  const [loading, setLoading] = useState(false);
  const [output, setOutput] = useState("");
  const [status, setStatus] = useState<"idle" | "running" | "done" | "error">(
    "idle",
  );
  const [errorMsg, setErrorMsg] = useState("");
  const [copied, setCopied] = useState(false);

  async function run() {
    if (validationError) return;

    setLoading(true);
    setStatus("running");
    setErrorMsg("");
    setCopied(false);

    try {
      const res = await fetch("http://localhost:4000/run", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ choice, A, B, k }),
      });

      const data = await res.json();
      if (!res.ok || !data.ok) {
        const cleanError = stripAnsi(
          String(data?.err || data?.output || "Error running program"),
        );
        setErrorMsg(cleanError || "Error running program");
        setOutput(cleanError || "Error running program");
        setStatus("error");
      } else {
        const cleanOutput = stripAnsi(String(data?.output || ""));
        setOutput(cleanOutput || "(No output)");
        setStatus("done");
      }
    } catch (e: unknown) {
      const msg = stripAnsi(
        String(e instanceof Error ? e.message : "Request failed"),
      );
      setErrorMsg(msg || "Request failed");
      setOutput(msg || "Request failed");
      setStatus("error");
    } finally {
      setLoading(false);
    }
  }

  async function copyOutput() {
    if (!output) return;
    try {
      await navigator.clipboard.writeText(output);
      setCopied(true);
      setTimeout(() => setCopied(false), 1200);
    } catch {
      setCopied(false);
    }
  }

  const supportsRun = /^[1-8]$/.test(choice);
  const needsK = choice === "6" || choice === "7";
  const missingRequired =
    supportsRun &&
    (!A.trim() || !B.trim() || (needsK && !k.trim()));
  const validationError = !supportsRun
    ? "Current /run endpoint supports choices 1-8 only."
    : missingRequired
      ? `Please fill required fields: A, B${needsK ? ", and Shift k" : ""}.`
      : "";

  return (
    <main className="min-h-screen bg-gradient-to-b from-zinc-950 via-zinc-950 to-black px-4 py-8 text-zinc-100 sm:px-6">
      <div className="mx-auto w-full max-w-4xl space-y-6">
        <header className="text-center">
          <h1 className="text-3xl font-semibold tracking-tight text-cyan-300">
            MiniALU-X
          </h1>
          <p className="mt-2 text-sm text-zinc-400">
            Native x86-64 ALU simulator with a modern terminal-style UI.
          </p>
        </header>

        <section className="rounded-2xl border border-zinc-800 bg-zinc-900/70 p-4 shadow-xl shadow-black/30 backdrop-blur sm:p-5">
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="text-sm">
              <span className="text-zinc-300">Operation Choice</span>
              <select
                value={choice}
                onChange={(e) => setChoice(e.target.value)}
                className="mt-2 w-full rounded-lg border border-zinc-700 bg-zinc-950 px-3 py-2 text-sm outline-none transition focus:border-cyan-400 focus:ring-2 focus:ring-cyan-400/25"
              >
                {CHOICE_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </label>

            <label className="text-sm">
              <span className="text-zinc-300">Input A</span>
              <input
                value={A}
                onChange={(e) => setA(e.target.value)}
                placeholder="e.g. 2"
                className="mt-2 w-full rounded-lg border border-zinc-700 bg-zinc-950 px-3 py-2 text-sm outline-none transition focus:border-cyan-400 focus:ring-2 focus:ring-cyan-400/25"
              />
            </label>

            <label className="text-sm">
              <span className="text-zinc-300">Input B</span>
              <input
                value={B}
                onChange={(e) => setB(e.target.value)}
                placeholder="e.g. 9"
                className="mt-2 w-full rounded-lg border border-zinc-700 bg-zinc-950 px-3 py-2 text-sm outline-none transition focus:border-cyan-400 focus:ring-2 focus:ring-cyan-400/25"
              />
            </label>

            {needsK && (
              <label className="text-sm">
                <span className="text-zinc-300">Shift k</span>
                <input
                  value={k}
                  onChange={(e) => setK(e.target.value)}
                  placeholder="0..31"
                  className="mt-2 w-full rounded-lg border border-zinc-700 bg-zinc-950 px-3 py-2 text-sm outline-none transition focus:border-cyan-400 focus:ring-2 focus:ring-cyan-400/25"
                />
              </label>
            )}
          </div>

          <div className="mt-4 flex flex-wrap gap-2">
            {QUICK_OPS.map((op) => {
              const active = choice === op.value;
              return (
                <button
                  key={op.value}
                  type="button"
                  onClick={() => setChoice(op.value)}
                  className={`rounded-md border px-3 py-1.5 text-xs font-medium transition ${
                    active
                      ? "border-cyan-400 bg-cyan-500/20 text-cyan-200"
                      : "border-zinc-700 bg-zinc-900 text-zinc-300 hover:border-zinc-500 hover:bg-zinc-800"
                  }`}
                >
                  {op.label}
                </button>
              );
            })}
          </div>

          <div className="mt-5 flex flex-wrap items-center gap-3">
            <button
              onClick={run}
              disabled={loading || Boolean(validationError)}
              className="inline-flex items-center justify-center rounded-lg bg-cyan-400 px-5 py-2 text-sm font-semibold text-zinc-950 transition hover:bg-cyan-300 disabled:cursor-not-allowed disabled:bg-zinc-600 disabled:text-zinc-300"
            >
              {loading ? "Running..." : "Run"}
            </button>
            {validationError ? (
              <p className="text-sm text-rose-300">{validationError}</p>
            ) : (
              <p className="text-xs text-zinc-500">
                Tip: quick buttons auto-fill the choice field.
              </p>
            )}
          </div>
        </section>

        <section className="rounded-2xl border border-zinc-800 bg-zinc-900/70 p-4 shadow-xl shadow-black/30 backdrop-blur sm:p-5">
          <div className="mb-3 flex items-center justify-between gap-3">
            <h2 className="text-lg font-medium text-zinc-100">Output</h2>
            <button
              type="button"
              onClick={copyOutput}
              disabled={!output}
              className="rounded-md border border-zinc-700 bg-zinc-900 px-3 py-1.5 text-xs text-zinc-300 transition hover:border-zinc-500 hover:bg-zinc-800 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {copied ? "Copied" : "Copy output"}
            </button>
          </div>

          <div className="mb-3 flex min-h-6 items-center text-sm">
            {status === "running" ? (
              <div className="flex items-center gap-2 text-cyan-300">
                <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-cyan-300 border-t-transparent" />
                <span>Running...</span>
              </div>
            ) : status === "error" ? (
              <span className="text-rose-300">
                {errorMsg || "Execution failed."}
              </span>
            ) : status === "done" ? (
              <span className="text-emerald-300">Done</span>
            ) : (
              <span className="text-zinc-500">Ready</span>
            )}
          </div>

          <pre className="max-h-[26rem] overflow-auto rounded-xl border border-zinc-800 bg-zinc-950/80 p-4 font-mono text-sm leading-6 text-zinc-100">
            {output || "Run an operation to view output."}
          </pre>
        </section>
      </div>
    </main>
  );
}
