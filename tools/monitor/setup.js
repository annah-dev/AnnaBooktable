#!/usr/bin/env node
/**
 * First-run setup: installs dependencies then starts in requested mode.
 * Usage: node setup.js [--live]
 */
const { execSync, spawn } = require("child_process");
const fs = require("fs");
const path = require("path");

const LIVE = process.argv.includes("--live");

console.log("");
console.log("  ╔═══════════════════════════════════════════╗");
console.log("  ║   Anna's Booktable Monitor — Setup        ║");
console.log("  ╚═══════════════════════════════════════════╝");
console.log("");

// Check Node.js version
const nodeVer = parseInt(process.version.slice(1));
if (nodeVer < 18) {
  console.error("  ❌ Node.js 18+ required (you have " + process.version + ")");
  console.error("     Install from https://nodejs.org");
  process.exit(1);
}
console.log("  ✓ Node.js " + process.version);

// Install dependencies
const nmPath = path.join(__dirname, "node_modules");
if (!fs.existsSync(nmPath)) {
  console.log("  ⏳ Installing dependencies (first run only)...");
  try {
    execSync("npm install --production", { cwd: __dirname, stdio: "pipe" });
    console.log("  ✓ Dependencies installed");
  } catch (e) {
    console.error("  ❌ npm install failed:", e.message);
    process.exit(1);
  }
} else {
  console.log("  ✓ Dependencies already installed");
}

// If live mode, check infra connectivity
if (LIVE) {
  console.log("");
  console.log("  Checking infrastructure...");

  // Quick TCP checks
  const net = require("net");
  const checks = [
    { name: "PostgreSQL", host: "localhost", port: 5432 },
    { name: "Redis",      host: "localhost", port: 6379 },
    { name: "RabbitMQ",   host: "localhost", port: 5672 },
  ];

  let allOk = true;
  const results = [];

  function checkPort(name, host, port) {
    return new Promise((resolve) => {
      const s = new net.Socket();
      s.setTimeout(2000);
      s.on("connect", () => { s.destroy(); resolve({ name, ok: true }); });
      s.on("timeout", () => { s.destroy(); resolve({ name, ok: false }); });
      s.on("error", () => { s.destroy(); resolve({ name, ok: false }); });
      s.connect(port, host);
    });
  }

  Promise.all(checks.map(c => checkPort(c.name, c.host, c.port))).then((res) => {
    res.forEach(r => {
      console.log(`    ${r.ok ? "✓" : "✗"} ${r.name} ${r.ok ? "reachable" : "NOT reachable"}`);
      if (!r.ok) allOk = false;
    });

    if (!allOk) {
      console.log("");
      console.log("  ⚠ Some services not reachable.");
      console.log("    Make sure Docker is running: docker compose up -d");
      console.log("    Or start in simulate mode: npm start");
      console.log("");
      console.log("    Starting anyway (bridge will retry connections)...");
    }
    console.log("");
    launch();
  });
} else {
  console.log("");
  launch();
}

function launch() {
  const args = ["server.js"];
  if (LIVE) args.push("--live");
  console.log(`  🚀 Launching: node ${args.join(" ")}`);
  console.log("");
  const child = spawn("node", args, { cwd: __dirname, stdio: "inherit" });
  child.on("exit", (code) => process.exit(code || 0));
}
