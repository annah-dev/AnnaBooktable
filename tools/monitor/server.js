#!/usr/bin/env node
/**
 * Anna's Booktable — Unified Monitor Server
 * 
 * Works identically on localhost and Azure App Service.
 * 
 * Local:  node server.js           → simulate, opens browser
 *         node server.js --live    → connects to Docker infra
 * Azure:  Deployed as App Service  → auto-detects Azure env, connects to Azure infra
 * 
 * Single port serves both HTTP (dashboard) and WebSocket (bridge) via upgrade.
 */

const http = require("http");
const fs = require("fs");
const path = require("path");
const { exec } = require("child_process");
const WebSocket = require("ws");

// ─── Environment Detection ───
const IS_AZURE = !!(process.env.WEBSITE_SITE_NAME || process.env.AZURE_FUNCTIONS_ENVIRONMENT);
const LIVE = IS_AZURE || process.argv.includes("--live");
const PORT = parseInt(process.env.PORT || process.env.HTTP_PORT || "3099");

// ─── Infrastructure Config ───
// Auto-resolves: env vars → Azure defaults → Docker Compose defaults
const config = {
  postgres: process.env.POSTGRES_URL
    || process.env.AZURE_POSTGRESQL_CONNECTIONSTRING
    || "postgresql://booktable_admin:LocalDev123!@localhost:5432/booktable",

  redis: process.env.REDIS_URL
    || process.env.AZURE_REDIS_CONNECTIONSTRING
    || "localhost:6379",

  // Messaging: supports both RabbitMQ (local) and Azure Service Bus (cloud)
  // Auto-detected by connection string format
  rabbitmq: process.env.RABBITMQ_URL || "amqp://guest:guest@localhost:5672",
  serviceBus: process.env.AZURE_SERVICEBUS_CONNECTIONSTRING || null,
  exchange: process.env.RABBITMQ_EXCHANGE || "booktable.events",
  serviceBusTopic: process.env.SERVICEBUS_TOPIC || "booktable-events",

  pollSlots: parseInt(process.env.POLL_INTERVAL_SLOTS || "2000"),
  pollMetrics: parseInt(process.env.POLL_INTERVAL_METRICS || "5000"),

  routingKeys: [
    "hold.acquired", "hold.expired", "hold.failed",
    "reservation.created", "reservation.cancelled", "reservation.conflict",
    "payment.charged", "payment.failed",
    "search.executed", "idempotency.hit",
  ],
};

// Determine messaging backend
const USE_SERVICE_BUS = !!config.serviceBus;

// PostgreSQL SSL config for Azure
function pgSslConfig() {
  const connStr = config.postgres;
  // Azure PostgreSQL requires SSL
  if (IS_AZURE || connStr.includes("azure") || connStr.includes("postgres.database.azure.com")) {
    return { connectionString: connStr, max: 5, ssl: { rejectUnauthorized: false } };
  }
  return { connectionString: connStr, max: 5 };
}

// Redis connection options for Azure vs local
function redisOpts() {
  const url = config.redis;
  // Azure Cache for Redis: "hostname:6380,password=xxx,ssl=True" or "rediss://..." format
  if (url.includes(",password=") || url.includes(",ssl=")) {
    // Parse Azure format: hostname:port,password=xxx,ssl=True
    const parts = url.split(",");
    const hostPort = parts[0].split(":");
    const password = (parts.find(p => p.startsWith("password=")) || "").replace("password=", "");
    const port = parseInt(hostPort[1]) || 6380;
    return { host: hostPort[0], port, password, tls: port === 6380 ? {} : undefined, retryStrategy: t => Math.min(t * 500, 5000), maxRetriesPerRequest: 3, lazyConnect: true };
  }
  if (url.startsWith("rediss://")) {
    return { ...parseRedisUrl(url), tls: {}, retryStrategy: t => Math.min(t * 500, 5000), maxRetriesPerRequest: 3, lazyConnect: true };
  }
  // Local: simple host:port or redis:// URL
  if (url.startsWith("redis://")) {
    return { ...parseRedisUrl(url), retryStrategy: t => Math.min(t * 500, 5000), maxRetriesPerRequest: 3, lazyConnect: true };
  }
  const [host, port] = url.split(":");
  return { host: host || "localhost", port: parseInt(port) || 6379, retryStrategy: t => Math.min(t * 500, 5000), maxRetriesPerRequest: 3, lazyConnect: true };
}

function parseRedisUrl(url) {
  try {
    const u = new URL(url);
    return { host: u.hostname, port: parseInt(u.port) || 6379, password: u.password || undefined };
  } catch { return { host: "localhost", port: 6379 }; }
}

// ─── State ───
let wsClients = new Set();
let connected = { messaging: false, redis: false, postgres: false };
let rabbitConn, rabbitChannel, redis, pgPool, sbClient;

// ─── HTTP Server ───
const htmlPath = path.join(__dirname, "dashboard.html");

const httpServer = http.createServer((req, res) => {
  // CORS for Azure cross-origin
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
  if (req.method === "OPTIONS") { res.writeHead(204); res.end(); return; }

  if (req.url === "/" || req.url === "/index.html") {
    fs.readFile(htmlPath, (err, data) => {
      if (err) { res.writeHead(500); res.end("Dashboard not found"); return; }
      res.writeHead(200, { "Content-Type": "text/html", "Cache-Control": "no-cache" });
      res.end(data);
    });
  } else if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({
      status: "ok",
      mode: LIVE ? "live" : "simulate",
      env: IS_AZURE ? "azure" : "local",
      messaging: USE_SERVICE_BUS ? "service-bus" : "rabbitmq",
      connected,
      uptime: process.uptime(),
    }));
  } else {
    res.writeHead(404); res.end("Not found");
  }
});

// ─── WebSocket Server (shares HTTP port via upgrade) ───
const wss = new WebSocket.Server({ noServer: true });

httpServer.on("upgrade", (request, socket, head) => {
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit("connection", ws, request);
  });
});

wss.on("connection", (ws) => {
  log("WS", "Client connected");
  wsClients.add(ws);
  ws.send(JSON.stringify({ type: "connection_status", data: connected }));
  ws.send(JSON.stringify({ type: "mode", data: LIVE ? "live" : "simulate" }));
  ws.send(JSON.stringify({ type: "env", data: { azure: IS_AZURE, messaging: USE_SERVICE_BUS ? "service-bus" : "rabbitmq" } }));
  ws.on("close", () => { wsClients.delete(ws); });
  ws.on("message", (raw) => {
    try { handleCmd(JSON.parse(raw)); } catch {}
  });
});

function broadcast(type, data) {
  const msg = JSON.stringify({ type, data, ts: Date.now() });
  for (const ws of wsClients) if (ws.readyState === 1) ws.send(msg);
}

function handleCmd(msg) {
  if (msg.command === "refresh_slots") pollSlots();
  else if (msg.command === "refresh_metrics") pollMetrics();
  else if (msg.command === "get_holds") pollHolds();
}

// ─── RabbitMQ Connection (local / non-Azure) ───
async function connectRabbitMQ() {
  const amqplib = require("amqplib");
  try {
    rabbitConn = await amqplib.connect(config.rabbitmq);
    rabbitChannel = await rabbitConn.createChannel();
    await rabbitChannel.assertExchange(config.exchange, "topic", { durable: true });
    const { queue } = await rabbitChannel.assertQueue("monitor-" + Date.now(), { exclusive: true, autoDelete: true });
    for (const key of config.routingKeys) await rabbitChannel.bindQueue(queue, config.exchange, key);
    rabbitChannel.consume(queue, (msg) => {
      if (!msg) return;
      try {
        handleEvent(msg.fields.routingKey, JSON.parse(msg.content.toString()));
        rabbitChannel.ack(msg);
      } catch { rabbitChannel.ack(msg); }
    });
    connected.messaging = true;
    broadcast("connection_status", connected);
    log("RabbitMQ", `Connected, ${config.routingKeys.length} routing keys`);
    rabbitConn.on("error", () => { connected.messaging = false; broadcast("connection_status", connected); setTimeout(connectRabbitMQ, 5000); });
    rabbitConn.on("close", () => { connected.messaging = false; broadcast("connection_status", connected); setTimeout(connectRabbitMQ, 5000); });
  } catch (e) {
    log("RabbitMQ", "Failed: " + e.message, true);
    connected.messaging = false; broadcast("connection_status", connected);
    setTimeout(connectRabbitMQ, 5000);
  }
}

// ─── Azure Service Bus Connection ───
async function connectServiceBus() {
  let sbModule;
  try { sbModule = require("@azure/service-bus"); } catch {
    log("ServiceBus", "Package @azure/service-bus not installed. Run: npm install @azure/service-bus", true);
    connected.messaging = false; broadcast("connection_status", connected);
    return;
  }
  try {
    sbClient = new sbModule.ServiceBusClient(config.serviceBus);
    // Subscribe to the topic (MassTransit creates topics matching event types)
    // Try each event type as a topic, with a monitor subscription
    const subscriptionName = "monitor-" + (process.env.WEBSITE_INSTANCE_ID || "local").slice(0, 8);

    for (const routingKey of config.routingKeys) {
      try {
        const adminClient = new sbModule.ServiceBusAdministrationClient(config.serviceBus);
        // MassTransit topic naming: replace dots with hyphens or use as-is
        const topicName = routingKey.replace(/\./g, "-");
        try { await adminClient.createSubscription(topicName, subscriptionName); } catch {}

        const receiver = sbClient.createReceiver(topicName, subscriptionName, { receiveMode: "receiveAndDelete" });
        receiver.subscribe({
          processMessage: async (msg) => { handleEvent(routingKey, msg.body); },
          processError: async (args) => { log("ServiceBus", `Error on ${topicName}: ${args.error.message}`, true); },
        });
      } catch {
        // Topic may not exist yet — that's fine, MassTransit creates on first publish
      }
    }

    // Also try a single "booktable-events" topic if it exists
    try {
      const receiver = sbClient.createReceiver(config.serviceBusTopic, subscriptionName, { receiveMode: "receiveAndDelete" });
      receiver.subscribe({
        processMessage: async (msg) => {
          const rk = msg.applicationProperties?.routingKey || msg.subject || "";
          handleEvent(rk, msg.body);
        },
        processError: async () => {},
      });
    } catch {}

    connected.messaging = true;
    broadcast("connection_status", connected);
    log("ServiceBus", "Connected to Azure Service Bus");
  } catch (e) {
    log("ServiceBus", "Failed: " + e.message, true);
    connected.messaging = false; broadcast("connection_status", connected);
    setTimeout(connectServiceBus, 10000);
  }
}

// ─── Redis Connection ───
async function connectRedis() {
  const Redis = require("ioredis");
  try {
    const opts = redisOpts();
    redis = new Redis(opts);
    await redis.connect();
    connected.redis = true; broadcast("connection_status", connected);
    log("Redis", `Connected (${opts.tls ? "TLS" : "plain"}) ${opts.host}:${opts.port}`);
    redis.on("error", () => { connected.redis = false; broadcast("connection_status", connected); });
    redis.on("close", () => { connected.redis = false; broadcast("connection_status", connected); });

    // Keyspace notifications (may not be available on Azure Basic tier)
    try {
      const sub = redis.duplicate();
      await sub.connect();
      await sub.subscribe("__keyevent@0__:expired");
      sub.on("message", (ch, key) => {
        if (key.startsWith("hold:")) {
          broadcast("event", { type: "hold.expired", routingKey: "hold.expired", data: { slotId: key.replace("hold:", ""), source: "redis_keyspace" } });
        }
      });
      log("Redis", "Subscribed to keyspace expired events");
    } catch {
      log("Redis", "Keyspace notifications not available (normal on Azure Basic)", true);
    }
  } catch (e) {
    log("Redis", "Failed: " + e.message, true);
    connected.redis = false; broadcast("connection_status", connected);
    setTimeout(connectRedis, 5000);
  }
}

// ─── PostgreSQL Connection ───
async function connectPostgres() {
  const { Pool } = require("pg");
  try {
    pgPool = new Pool(pgSslConfig());
    const c = await pgPool.connect(); await c.query("SELECT 1"); c.release();
    connected.postgres = true; broadcast("connection_status", connected);
    log("PostgreSQL", "Connected" + (IS_AZURE ? " (SSL)" : ""));
    pgPool.on("error", () => { connected.postgres = false; broadcast("connection_status", connected); });
  } catch (e) {
    log("PostgreSQL", "Failed: " + e.message, true);
    connected.postgres = false; broadcast("connection_status", connected);
    setTimeout(connectPostgres, 5000);
  }
}

// ─── Event Handler ───
function handleEvent(routingKey, body) {
  const layerMap = {
    "hold.acquired": "L1", "hold.expired": "L1", "hold.failed": "L1",
    "reservation.created": "L2", "reservation.conflict": "L2", "reservation.cancelled": "L2",
    "idempotency.hit": "L3", "payment.charged": null, "payment.failed": null, "search.executed": null,
  };
  broadcast("event", { type: routingKey, routingKey, ...body, layer: layerMap[routingKey] || null, ts: Date.now() });
}

// ─── Polling ───
async function pollSlots() {
  if (!pgPool || !connected.postgres) return;
  try {
    const restaurants = await pgPool.query(`
      SELECT r.restaurant_id, r.name, r.cuisine, COUNT(DISTINCT t.table_id) AS table_count
      FROM restaurants r LEFT JOIN tables t ON t.restaurant_id = r.restaurant_id
      GROUP BY r.restaurant_id, r.name, r.cuisine ORDER BY r.name LIMIT 20
    `);
    const dateResult = await pgPool.query(`SELECT DISTINCT date FROM time_slots WHERE date >= CURRENT_DATE ORDER BY date LIMIT 1`);
    const slotDate = dateResult.rows.length > 0 ? dateResult.rows[0].date : null;
    if (!slotDate) { broadcast("slot_state", { restaurants: restaurants.rows, slots: [], aggregates: [] }); return; }
    const slotState = await pgPool.query(`
      SELECT ts.slot_id, ts.restaurant_id, ts.table_id, t.table_number,
             ts.start_time, ts.status, ts.held_by, ts.held_until,
             res.user_id AS booked_by, u.first_name AS booked_by_name
      FROM time_slots ts JOIN tables t ON t.table_id = ts.table_id
      LEFT JOIN reservations res ON res.slot_id = ts.slot_id AND res.status IN ('CONFIRMED','PENDING')
      LEFT JOIN users u ON u.user_id = res.user_id
      WHERE ts.date = $1 ORDER BY ts.restaurant_id, t.table_number, ts.start_time
    `, [slotDate]);
    const aggregates = await pgPool.query(`
      SELECT ts.restaurant_id, ts.status, COUNT(*) AS cnt FROM time_slots ts WHERE ts.date = $1 GROUP BY ts.restaurant_id, ts.status
    `, [slotDate]);
    broadcast("slot_state", { restaurants: restaurants.rows, slots: slotState.rows, aggregates: aggregates.rows, slotDate });
  } catch (e) { log("Poll:Slots", e.message, true); }
}

async function pollHolds() {
  if (!redis || !connected.redis) { broadcast("redis_state", { holds: [], stats: null }); return; }
  try {
    const holds = [];
    let cursor = "0";
    do {
      const [next, keys] = await redis.scan(cursor, "MATCH", "hold:*", "COUNT", 100);
      cursor = next;
      for (const k of keys) {
        const v = await redis.get(k); const ttl = await redis.ttl(k);
        const parts = (v || "").split(":");
        holds.push({ key: k, slotId: k.replace("hold:", ""), userId: parts[0], holdToken: parts[1], ttl });
      }
    } while (cursor !== "0");
    const info = await redis.info("stats"); const mem = await redis.info("memory");
    const p = (raw, f) => { const m = raw.match(new RegExp(f + ":(\\S+)")); return m ? m[1] : null; };
    const hits = parseInt(p(info, "keyspace_hits")) || 0;
    const misses = parseInt(p(info, "keyspace_misses")) || 0;
    broadcast("redis_state", { holds, stats: { hitRate: hits + misses > 0 ? ((hits / (hits + misses)) * 100).toFixed(1) + "%" : "N/A", memory: p(mem, "used_memory_human"), commands: p(info, "total_commands_processed") } });
  } catch (e) { log("Poll:Holds", e.message, true); }
}

async function pollMetrics() {
  if (!pgPool || !connected.postgres) return;
  try {
    const bk = await pgPool.query(`
      SELECT COUNT(*) FILTER (WHERE status = 'CONFIRMED') AS total_bookings,
             COUNT(*) FILTER (WHERE status = 'CANCELLED') AS total_cancellations,
             COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '1 hour') AS last_hour,
             COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '5 minutes') AS last_5min
      FROM reservations WHERE created_at::date = CURRENT_DATE
    `);
    const dateResult = await pgPool.query(`SELECT DISTINCT date FROM time_slots WHERE date >= CURRENT_DATE ORDER BY date LIMIT 1`);
    const slotDate = dateResult.rows.length > 0 ? dateResult.rows[0].date : null;
    let util = { total_slots: 0, available: 0, held: 0, booked: 0, blocked: 0 };
    if (slotDate) {
      const u = await pgPool.query(`
        SELECT COUNT(*) AS total_slots, COUNT(*) FILTER (WHERE status = 'AVAILABLE') AS available,
               COUNT(*) FILTER (WHERE status = 'HELD') AS held, COUNT(*) FILTER (WHERE status = 'BOOKED') AS booked,
               COUNT(*) FILTER (WHERE status = 'BLOCKED') AS blocked
        FROM time_slots WHERE date = $1
      `, [slotDate]);
      util = u.rows[0] || util;
    }
    broadcast("metrics", { bookings: bk.rows[0], utilization: util });
  } catch (e) { log("Poll:Metrics", e.message, true); }
}

// ─── Logging ───
function log(tag, msg, isErr) {
  const line = `[${new Date().toISOString().slice(11,19)}] [${tag}] ${msg}`;
  if (isErr) console.error(line); else console.log(line);
}

// ─── Boot ───
async function main() {
  const env = IS_AZURE ? "AZURE" : "LOCAL";
  const msgBackend = USE_SERVICE_BUS ? "Azure Service Bus" : "RabbitMQ";
  console.log("");
  console.log("  ╔═══════════════════════════════════════════════╗");
  console.log("  ║   Anna's Booktable — System Monitor           ║");
  console.log("  ╠═══════════════════════════════════════════════╣");
  console.log(`  ║   Env:       ${(env + "                       ").slice(0,33)}║`);
  console.log(`  ║   Mode:      ${(LIVE ? "LIVE" : "SIMULATE") + "                       ".slice(0,29)}║`);
  console.log(`  ║   Messaging: ${(msgBackend + "                       ").slice(0,33)}║`);
  console.log(`  ║   Port:      ${(PORT + "                                ").slice(0,33)}║`);
  console.log("  ╚═══════════════════════════════════════════════╝");
  console.log("");

  if (LIVE) {
    log("Boot", `Connecting to infrastructure (${env})...`);
    log("Boot", `PostgreSQL: ${config.postgres.replace(/:[^:@]+@/, ":***@")}`);
    log("Boot", `Redis:      ${config.redis.replace(/password=[^,]+/, "password=***")}`);
    log("Boot", `Messaging:  ${USE_SERVICE_BUS ? "Azure Service Bus" : config.rabbitmq}`);

    const connectors = [connectRedis(), connectPostgres()];
    if (USE_SERVICE_BUS) connectors.push(connectServiceBus());
    else connectors.push(connectRabbitMQ());
    await Promise.allSettled(connectors);

    setInterval(pollSlots, config.pollSlots);
    setInterval(pollMetrics, config.pollMetrics);
    setInterval(pollHolds, config.pollSlots);
    setTimeout(() => { pollSlots(); pollMetrics(); pollHolds(); }, 1000);
  }

  httpServer.listen(PORT, () => {
    const url = `http://localhost:${PORT}`;
    log("HTTP", `Dashboard ready at ${url}`);
    if (!IS_AZURE) {
      const cmd = process.platform === "win32" ? `start ${url}` : process.platform === "darwin" ? `open ${url}` : `xdg-open ${url}`;
      exec(cmd, () => {});
    }
  });
}

main().catch(console.error);
