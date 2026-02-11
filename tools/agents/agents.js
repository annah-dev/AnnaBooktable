#!/usr/bin/env node
/**
 * Anna's Booktable — Customer Simulation Agents
 *
 * Three independent agents that simulate real customer behavior by
 * calling the Booktable API through the Gateway. They report their
 * state to the Monitor dashboard via WebSocket.
 *
 * Usage:
 *   node agents.js              → Run all 3 agents
 *   node agents.js --all        → Run all 3 agents
 *   node agents.js --agent=walk-ins
 *   node agents.js --agent=sushi-lovers
 *   node agents.js --agent=food-explorers
 *
 * Environment:
 *   GATEWAY_URL    → API gateway (default: http://localhost:5000)
 *   MONITOR_URL    → Monitor WebSocket (default: ws://localhost:3099)
 *   USER_ID        → Diner user ID (default: test user Anna)
 */

const http = require("http");
const https = require("https");
const WebSocket = require("ws");

// ─── Config ───
const GATEWAY = process.env.GATEWAY_URL || "http://localhost:5000";
const MONITOR_WS = process.env.MONITOR_URL || "ws://localhost:3099";
const USER_ID = process.env.USER_ID || "e0000000-0000-0000-0000-000000000001";

function getTomorrow() {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return d.toISOString().slice(0, 10);
}

// ─── HTTP helper ───
function apiCall(method, path, body) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, GATEWAY);
    const mod = url.protocol === "https:" ? https : http;
    const opts = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method,
      headers: { "Content-Type": "application/json" },
    };
    const req = mod.request(opts, (res) => {
      let data = "";
      res.on("data", (c) => (data += c));
      res.on("end", () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch { resolve({ status: res.statusCode, body: data }); }
      });
    });
    req.on("error", reject);
    req.setTimeout(10000, () => { req.destroy(); reject(new Error("Timeout")); });
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// ─── Monitor WebSocket ───
let monitorWs = null;
let reconnectTimer = null;

function connectMonitor() {
  try {
    monitorWs = new WebSocket(MONITOR_WS);
    monitorWs.on("open", () => log("Monitor", "Connected to dashboard"));
    monitorWs.on("close", () => { monitorWs = null; reconnectTimer = setTimeout(connectMonitor, 3000); });
    monitorWs.on("error", () => { monitorWs = null; });
  } catch { monitorWs = null; }
}

function reportToMonitor(agentStates) {
  if (monitorWs && monitorWs.readyState === 1) {
    monitorWs.send(JSON.stringify({ type: "agent_state", data: agentStates }));
  }
}

function reportEvent(agent, type, msg) {
  if (monitorWs && monitorWs.readyState === 1) {
    monitorWs.send(JSON.stringify({
      type: "event",
      data: { type: "agent." + type, routingKey: "agent." + type, data: { agent: agent.name, msg }, layer: null, ts: Date.now() },
    }));
  }
}

// ─── Agent Base ───
class Agent {
  constructor(name, description, color, intervalMs) {
    this.name = name;
    this.description = description;
    this.color = color;
    this.intervalMs = intervalMs;
    this.running = false;
    this.actionCount = 0;
    this.lastAction = null;
    this.status = "IDLE";
    this.timer = null;
  }

  start() {
    this.running = true;
    this.status = "RUNNING";
    log(this.name, `Started (every ${this.intervalMs / 1000}s)`);
    this.tick();
    this.timer = setInterval(() => this.tick(), this.intervalMs);
  }

  stop() {
    this.running = false;
    this.status = "STOPPED";
    if (this.timer) clearInterval(this.timer);
  }

  async tick() {
    if (!this.running) return;
    try {
      await this.act();
      this.actionCount++;
      this.lastAction = new Date().toISOString();
    } catch (e) {
      log(this.name, `Error: ${e.message}`, true);
    }
  }

  async act() { /* override in subclass */ }

  toJSON() {
    return {
      name: this.name,
      description: this.description,
      color: this.color,
      running: this.running,
      actionCount: this.actionCount,
      status: this.status,
      lastAction: this.lastAction,
    };
  }
}

// ─── Agent 1: Walk-ins ───
// Simulates casual diners who walk in: picks random restaurant, random time
class WalkInAgent extends Agent {
  constructor() {
    super("Walk-Ins", "Random restaurants, spontaneous bookings", "#b45309", 20000); // every 20s
    this.restaurants = [];
  }

  async act() {
    this.status = "SEARCHING";
    const date = getTomorrow();

    // Search for any available restaurant
    const searchRes = await apiCall("GET", `/api/search?date=${date}&partySize=2&pageSize=10`);
    if (searchRes.status !== 200 || !searchRes.body?.data?.results) {
      log(this.name, "Search failed");
      this.status = "IDLE";
      return;
    }

    const results = searchRes.body.data.results.filter(r => r.availableSlots?.length > 0);
    if (results.length === 0) {
      log(this.name, "No availability found");
      this.status = "IDLE";
      return;
    }

    // Pick random restaurant
    const restaurant = results[Math.floor(Math.random() * results.length)];
    reportEvent(this, "search", `Browsing ${restaurant.name}`);
    log(this.name, `Found ${restaurant.name} with ${restaurant.availableSlots.length} slots`);

    // Get full availability
    this.status = "SELECTING";
    const availRes = await apiCall("GET", `/api/inventory/availability?restaurantId=${restaurant.restaurantId}&date=${date}&partySize=2`);
    if (availRes.status !== 200 || !availRes.body?.data?.slots?.length) {
      this.status = "IDLE";
      return;
    }

    const slots = availRes.body.data.slots;
    const slot = slots[Math.floor(Math.random() * slots.length)];

    // Try to hold
    this.status = "HOLDING";
    reportEvent(this, "hold", `Holding ${restaurant.name} @ ${new Date(slot.startTime).toLocaleTimeString()}`);
    const holdRes = await apiCall("POST", "/api/inventory/hold", { slotId: slot.slotId, userId: USER_ID });

    if (holdRes.status !== 200 || !holdRes.body?.data?.holdToken) {
      log(this.name, `Hold failed for ${restaurant.name}: ${holdRes.body?.message || "conflict"}`);
      reportEvent(this, "conflict", `Hold failed at ${restaurant.name}`);
      this.status = "IDLE";
      return;
    }

    log(this.name, `Held slot at ${restaurant.name}`);

    // 70% chance to complete booking, 30% abandon (simulate walk-in indecision)
    if (Math.random() < 0.3) {
      await sleep(3000);
      await apiCall("DELETE", `/api/inventory/hold/${slot.slotId}`);
      log(this.name, `Changed mind, released hold at ${restaurant.name}`);
      reportEvent(this, "release", `Abandoned hold at ${restaurant.name}`);
      this.status = "IDLE";
      return;
    }

    // Book
    await sleep(2000);
    this.status = "BOOKING";
    const idempotencyKey = `agent-walkin-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const bookRes = await apiCall("POST", "/api/reservations", {
      slotId: slot.slotId,
      userId: USER_ID,
      partySize: 2,
      holdToken: holdRes.body.data.holdToken,
      paymentToken: "tok_dev_walkin",
      idempotencyKey,
    });

    if (bookRes.status === 200 && bookRes.body?.data?.confirmationCode) {
      log(this.name, `BOOKED ${restaurant.name} — ${bookRes.body.data.confirmationCode}`);
      reportEvent(this, "book", `Booked ${restaurant.name} (${bookRes.body.data.confirmationCode})`);
    } else {
      log(this.name, `Booking failed at ${restaurant.name}: ${bookRes.body?.message || "error"}`);
      reportEvent(this, "conflict", `Booking failed at ${restaurant.name}`);
    }
    this.status = "IDLE";
  }
}

// ─── Agent 2: Sushi Lovers ───
// A crowd of sushi enthusiasts targeting only Japanese restaurants
class SushiLoverAgent extends Agent {
  constructor() {
    super("Sushi Lovers", "Targets Japanese restaurants exclusively", "#b91c1c", 15000); // every 15s
  }

  async act() {
    this.status = "CRAVING SUSHI";
    const date = getTomorrow();

    // Search specifically for Japanese cuisine
    const searchRes = await apiCall("GET", `/api/search?cuisine=Japanese&date=${date}&partySize=2&pageSize=20`);
    if (searchRes.status !== 200 || !searchRes.body?.data?.results) {
      log(this.name, "Search for Japanese failed");
      this.status = "IDLE";
      return;
    }

    const results = searchRes.body.data.results.filter(r => r.availableSlots?.length > 0);
    if (results.length === 0) {
      log(this.name, "No sushi spots available!");
      reportEvent(this, "search", "No Japanese restaurants available");
      this.status = "IDLE";
      return;
    }

    // Pick a sushi place
    const restaurant = results[Math.floor(Math.random() * results.length)];
    const partySize = 2 + Math.floor(Math.random() * 3); // 2-4 people
    reportEvent(this, "search", `Sushi crew (${partySize}) eyeing ${restaurant.name}`);
    log(this.name, `Party of ${partySize} heading to ${restaurant.name}`);

    // Get availability for exact party size
    this.status = "CHOOSING TABLE";
    const availRes = await apiCall("GET", `/api/inventory/availability?restaurantId=${restaurant.restaurantId}&date=${date}&partySize=${partySize}`);
    if (availRes.status !== 200 || !availRes.body?.data?.slots?.length) {
      log(this.name, `No tables for ${partySize} at ${restaurant.name}`);
      this.status = "IDLE";
      return;
    }

    // Prefer prime time (7-8pm)
    const slots = availRes.body.data.slots;
    const primeSlots = slots.filter(s => {
      const h = new Date(s.startTime).getUTCHours();
      return h >= 1 && h <= 3; // 6-8pm PST in UTC
    });
    const slot = primeSlots.length > 0
      ? primeSlots[Math.floor(Math.random() * primeSlots.length)]
      : slots[Math.floor(Math.random() * slots.length)];

    // Hold aggressively
    this.status = "SECURING TABLE";
    reportEvent(this, "hold", `Sushi lovers holding at ${restaurant.name}`);
    const holdRes = await apiCall("POST", "/api/inventory/hold", { slotId: slot.slotId, userId: USER_ID });

    if (holdRes.status !== 200) {
      log(this.name, `Hold CONFLICT at ${restaurant.name} — someone else got it!`);
      reportEvent(this, "conflict", `Lost table at ${restaurant.name} to another group`);
      this.status = "IDLE";
      return;
    }

    // Sushi lovers always book (they're dedicated)
    await sleep(1500);
    this.status = "BOOKING";
    const idempotencyKey = `agent-sushi-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const bookRes = await apiCall("POST", "/api/reservations", {
      slotId: slot.slotId,
      userId: USER_ID,
      partySize,
      holdToken: holdRes.body.data.holdToken,
      paymentToken: "tok_dev_sushi",
      idempotencyKey,
      specialRequests: "Omakase if available",
    });

    if (bookRes.status === 200 && bookRes.body?.data?.confirmationCode) {
      log(this.name, `BOOKED ${restaurant.name} for ${partySize} — ${bookRes.body.data.confirmationCode}`);
      reportEvent(this, "book", `Sushi crew booked ${restaurant.name} (${bookRes.body.data.confirmationCode})`);
    } else {
      log(this.name, `Booking failed: ${bookRes.body?.message || "error"}`);
      reportEvent(this, "conflict", `Booking failed at ${restaurant.name}`);
    }
    this.status = "IDLE";
  }
}

// ─── Agent 3: Food Explorers ───
// Visits a different restaurant every minute — browses, sometimes books
class FoodExplorerAgent extends Agent {
  constructor() {
    super("Food Explorers", "New restaurant every minute, adventurous diners", "#047857", 60000); // every 60s
    this.visitedRestaurants = new Set();
    this.allRestaurants = [];
    this.lastFetch = 0;
  }

  async act() {
    this.status = "EXPLORING";
    const date = getTomorrow();

    // Refresh restaurant list every 5 minutes
    if (Date.now() - this.lastFetch > 300000 || this.allRestaurants.length === 0) {
      const searchRes = await apiCall("GET", `/api/search?date=${date}&partySize=2&pageSize=100`);
      if (searchRes.status === 200 && searchRes.body?.data?.results) {
        this.allRestaurants = searchRes.body.data.results;
        this.lastFetch = Date.now();
      }
    }

    // Pick an unvisited restaurant
    const unvisited = this.allRestaurants.filter(r => !this.visitedRestaurants.has(r.restaurantId));
    if (unvisited.length === 0) {
      log(this.name, "Visited all restaurants! Resetting exploration...");
      this.visitedRestaurants.clear();
      this.status = "IDLE";
      return;
    }

    const restaurant = unvisited[Math.floor(Math.random() * unvisited.length)];
    this.visitedRestaurants.add(restaurant.restaurantId);
    reportEvent(this, "search", `Exploring ${restaurant.name} (${restaurant.cuisine})`);
    log(this.name, `Exploring ${restaurant.name} (${restaurant.cuisine}) — ${this.visitedRestaurants.size}/${this.allRestaurants.length} visited`);

    // View the detail page
    this.status = "BROWSING " + restaurant.name.slice(0, 15);
    const detailRes = await apiCall("GET", `/api/search/restaurants/${restaurant.restaurantId}`);
    if (detailRes.status !== 200) {
      this.status = "IDLE";
      return;
    }

    // Check availability
    const availRes = await apiCall("GET", `/api/inventory/availability?restaurantId=${restaurant.restaurantId}&date=${date}&partySize=2`);
    const hasSlots = availRes.status === 200 && availRes.body?.data?.slots?.length > 0;

    // 25% chance to book if available
    if (hasSlots && Math.random() < 0.25) {
      const slots = availRes.body.data.slots;
      const slot = slots[Math.floor(Math.random() * slots.length)];

      this.status = "IMPULSE BOOKING";
      reportEvent(this, "hold", `Explorer impulse-booking ${restaurant.name}!`);
      const holdRes = await apiCall("POST", "/api/inventory/hold", { slotId: slot.slotId, userId: USER_ID });

      if (holdRes.status === 200 && holdRes.body?.data?.holdToken) {
        await sleep(2000);
        const idempotencyKey = `agent-explorer-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
        const bookRes = await apiCall("POST", "/api/reservations", {
          slotId: slot.slotId,
          userId: USER_ID,
          partySize: 2,
          holdToken: holdRes.body.data.holdToken,
          paymentToken: "tok_dev_explorer",
          idempotencyKey,
          specialRequests: "First time here!",
        });

        if (bookRes.status === 200 && bookRes.body?.data?.confirmationCode) {
          log(this.name, `BOOKED ${restaurant.name} — ${bookRes.body.data.confirmationCode}`);
          reportEvent(this, "book", `Explorer booked ${restaurant.name} (${bookRes.body.data.confirmationCode})`);
        }
      }
    } else if (hasSlots) {
      log(this.name, `Browsed ${restaurant.name} — looks great, maybe next time`);
    } else {
      log(this.name, `${restaurant.name} is fully booked`);
    }
    this.status = "IDLE";
  }
}

// ─── Utilities ───
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

function log(tag, msg, isErr) {
  const line = `[${new Date().toISOString().slice(11, 19)}] [${tag}] ${msg}`;
  if (isErr) console.error(line); else console.log(line);
}

// ─── State reporting ───
const allAgents = [];

function startReporting() {
  setInterval(() => {
    reportToMonitor(allAgents.map(a => a.toJSON()));
  }, 2000);
}

// ─── Main ───
async function main() {
  const args = process.argv.slice(2);
  const agentFlag = args.find(a => a.startsWith("--agent="));
  const agentName = agentFlag ? agentFlag.split("=")[1] : null;
  const runAll = !agentName || args.includes("--all");

  console.log("");
  console.log("  ╔═══════════════════════════════════════════════╗");
  console.log("  ║   Booktable — Customer Simulation Agents      ║");
  console.log("  ╠═══════════════════════════════════════════════╣");
  console.log(`  ║   Gateway:  ${(GATEWAY + "                       ").slice(0, 33)}║`);
  console.log(`  ║   Monitor:  ${(MONITOR_WS + "                       ").slice(0, 33)}║`);
  console.log(`  ║   User:     ${(USER_ID.slice(0, 28) + "...   ").slice(0, 33)}║`);
  console.log("  ╚═══════════════════════════════════════════════╝");
  console.log("");

  // Connect to monitor
  connectMonitor();
  await sleep(1000);

  // Create agents
  const agents = {
    "walk-ins": () => new WalkInAgent(),
    "sushi-lovers": () => new SushiLoverAgent(),
    "food-explorers": () => new FoodExplorerAgent(),
  };

  if (runAll) {
    for (const [name, create] of Object.entries(agents)) {
      const agent = create();
      allAgents.push(agent);
      agent.start();
      log("Main", `Started agent: ${agent.name}`);
      await sleep(2000); // stagger start times
    }
  } else if (agents[agentName]) {
    const agent = agents[agentName]();
    allAgents.push(agent);
    agent.start();
    log("Main", `Started agent: ${agent.name}`);
  } else {
    console.error(`Unknown agent: ${agentName}. Available: ${Object.keys(agents).join(", ")}`);
    process.exit(1);
  }

  // Report state to monitor
  startReporting();

  log("Main", `${allAgents.length} agent(s) running. Press Ctrl+C to stop.`);

  // Graceful shutdown
  process.on("SIGINT", () => {
    log("Main", "Shutting down agents...");
    allAgents.forEach(a => a.stop());
    reportToMonitor(allAgents.map(a => a.toJSON()));
    setTimeout(() => process.exit(0), 500);
  });
}

main().catch(console.error);
