#!/usr/bin/env node

import { spawnSync } from "node:child_process";

let payload = {};

try {
  const raw = await new Promise((resolve, reject) => {
    const chunks = [];
    process.stdin.on("data", (chunk) => chunks.push(chunk));
    process.stdin.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    process.stdin.on("error", reject);
  });

  payload = raw.trim() ? JSON.parse(raw) : {};
} catch {
  payload = {};
}

const cwd =
  payload && typeof payload.cwd === "string" && payload.cwd
    ? payload.cwd
    : process.cwd();

let additionalContext = "Run `bd prime` manually if you need Beads workflow context before compacting.";

try {
  const result = spawnSync("bd", ["prime"], {
    cwd,
    encoding: "utf8",
  });

  const stdout = (result.stdout || "").trim();
  const stderr = (result.stderr || "").trim();

  if (stdout) {
    additionalContext = stdout.slice(0, 12000);
  } else if (stderr) {
    additionalContext = `bd prime did not return stdout. stderr: ${stderr.slice(0, 1000)}`;
  } else if (result.error?.message) {
    additionalContext = `bd prime failed to execute: ${result.error.message}`;
  }
} catch (error) {
  if (error instanceof Error && error.message) {
    additionalContext = `bd prime failed to execute: ${error.message}`;
  }
}

process.stdout.write(
  JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "PreCompact",
      additionalContext,
    },
  }),
);
