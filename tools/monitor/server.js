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
const config = {
  postgres: process.env.POSTGRES_URL
    || process.env.AZURE_POSTGRESQL_CONNECTIONSTRING
    || "postgresql://booktable_admin:LocalDev123!@localhost:5432/booktable",

  redis: process.env.REDIS_URL
    || process.env.AZURE_REDIS_CONNECTIONSTRING
    || "localhost:6379",

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

const USE_SERVICE_BUS = !!config.serviceBus;

// PostgreSQL SSL config for Azure
function pgSslConfig() {
  const connStr = config.postgres;
  if (IS_AZURE || connStr.includes("azure") || connStr.includes("postgres.database.azure.com")) {
    return { connectionString: connStr, max: 5, ssl: { rejectUnauthorized: false } };
  }
  return { connectionString: connStr, max: 5 };
}

// Redis connection options
function redisOpts() {
  const url = config.redis;
  if (url.includes(",password=") || url.includes(",ssl=")) {
    const parts = url.split(",");
    const hostPort = parts[0].split(":");
    const password = (parts.find(p => p.startsWith("password=")) || "").replace("password=", "");
    const port = parseInt(hostPort[1]) || 6380;
    return { host: hostPort[0], port, password, tls: port === 6380 ? {} : undefined, retryStrategy: t => Math.min(t * 500, 5000), maxRetriesPerRequest: 3, lazyConnect: true };
  }
  if (url.startsWith("rediss://")) {
    return { ...parseRedisUrl(url), tls: {}, retryStrategy: t => Math.min(t * 500, 5000), maxRetriesPerRequest: 3, lazyConnect: true };
  }
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

// View state
let viewDate = null; // null = auto-detect first available date

// Helper: normalize PG date to YYYY-MM-DD string
function isoDate(d) {
  if (d instanceof Date) return d.toISOString().slice(0, 10);
  const s = String(d);
  if (s.length >= 10 && s[4] === '-') return s.slice(0, 10);
  // fallback: try parsing
  try { return new Date(s).toISOString().slice(0, 10); } catch { return s; }
}

// Admin settings defaults
let adminSettings = {
  require_cc_hold_peak: false,
  require_cc_hold_holidays: false,
  reservation_duration_minutes: 90,
};

// ─── Gateway URL (for API proxy) ───
const GATEWAY_URL = process.env.GATEWAY_URL
  || (IS_AZURE ? "https://anna-booktable-gateway.azurewebsites.net" : "http://localhost:5000");

// ─── HTTP Server ───
const htmlPath = path.join(__dirname, "dashboard.html");

const httpServer = http.createServer((req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Idempotency-Key");
  if (req.method === "OPTIONS") { res.writeHead(204); res.end(); return; }

  // Proxy /api/* requests to the gateway
  if (req.url.startsWith("/api/")) {
    proxyToGateway(req, res);
    return;
  }

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

// ─── API Proxy ───
function proxyToGateway(clientReq, clientRes) {
  const target = new URL(GATEWAY_URL);
  const opts = {
    hostname: target.hostname,
    port: target.port || (target.protocol === "https:" ? 443 : 80),
    path: clientReq.url,
    method: clientReq.method,
    headers: { ...clientReq.headers, host: target.host },
  };
  // Use https if gateway is https
  const lib = target.protocol === "https:" ? require("https") : http;
  const proxyReq = lib.request(opts, (proxyRes) => {
    clientRes.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(clientRes, { end: true });
  });
  proxyReq.on("error", (e) => {
    log("Proxy", `Gateway error: ${e.message}`, true);
    clientRes.writeHead(502, { "Content-Type": "application/json" });
    clientRes.end(JSON.stringify({ success: false, message: "Gateway unavailable: " + e.message }));
  });
  clientReq.pipe(proxyReq, { end: true });
}

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
  ws.send(JSON.stringify({ type: "env", data: { azure: IS_AZURE, messaging: USE_SERVICE_BUS ? "service-bus" : "rabbitmq", gatewayUrl: IS_AZURE ? "https://anna-booktable-gateway.azurewebsites.net" : "http://localhost:5000" } }));
  ws.send(JSON.stringify({ type: "admin_settings", data: adminSettings }));
  ws.on("close", () => { wsClients.delete(ws); });
  ws.on("message", (raw) => {
    try {
      const msg = JSON.parse(raw);
      // Forward agent_state and event messages from external agents to all dashboard clients
      if (msg.type === "agent_state") { broadcast("agent_state", msg.data); return; }
      if (msg.type === "event") { broadcast("event", msg.data); return; }
      handleCmd(msg);
    } catch {}
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
  else if (msg.command === "get_bookings") pollBookingsList();
  else if (msg.command === "set_setting") handleSetSetting(msg);
  else if (msg.command === "get_settings") broadcast("admin_settings", adminSettings);
  else if (msg.command === "set_date") { viewDate = msg.date || null; pollSlots(); }
  else if (msg.command === "expand_slots") handleExpandSlots(msg);
}

// ─── Admin Settings ───
async function handleSetSetting(msg) {
  const { key, value } = msg;
  if (key && key in adminSettings) {
    adminSettings[key] = value;
    // Persist to Redis if connected
    if (redis && connected.redis) {
      try {
        await redis.hset("booktable:settings", key, JSON.stringify(value));
      } catch (e) { log("Settings", "Failed to write Redis: " + e.message, true); }
    }
    broadcast("admin_settings", adminSettings);
    log("Settings", `${key} = ${value}`);
  }
}

async function loadSettings() {
  if (!redis || !connected.redis) return;
  try {
    const all = await redis.hgetall("booktable:settings");
    for (const [k, v] of Object.entries(all)) {
      try { adminSettings[k] = JSON.parse(v); } catch { adminSettings[k] = v; }
    }
    broadcast("admin_settings", adminSettings);
    log("Settings", "Loaded from Redis");
  } catch {}
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
    const adminClient = new sbModule.ServiceBusAdministrationClient(config.serviceBus);
    const subscriptionName = "monitor-" + (process.env.WEBSITE_INSTANCE_ID || "local").slice(0, 8);

    // Discover MassTransit topics dynamically
    const topicIter = adminClient.listTopics();
    const discoveredTopics = [];
    for await (const topic of topicIter) {
      discoveredTopics.push(topic.name);
    }
    log("ServiceBus", `Discovered ${discoveredTopics.length} topics: ${discoveredTopics.join(", ")}`);

    // Match topics by known event type keywords
    const eventKeywords = ["slotheld", "slotreleased", "reservationcreated", "reservationcancelled", "paymentcharged"];
    const rkMap = {
      "slotheld": "hold.acquired", "slotreleased": "hold.expired",
      "reservationcreated": "reservation.created", "reservationcancelled": "reservation.cancelled",
      "paymentcharged": "payment.charged",
    };

    for (const topicName of discoveredTopics) {
      const lower = topicName.toLowerCase().replace(/[^a-z]/g, "");
      const matchedKeyword = eventKeywords.find(kw => lower.includes(kw));
      if (!matchedKeyword && !topicName.includes("booktable")) continue;

      try { await adminClient.createSubscription(topicName, subscriptionName); } catch {}

      const receiver = sbClient.createReceiver(topicName, subscriptionName, { receiveMode: "receiveAndDelete" });
      receiver.subscribe({
        processMessage: async (msg) => {
          const rk = rkMap[matchedKeyword] || msg.applicationProperties?.routingKey || msg.subject || topicName;
          handleEvent(rk, msg.body);
        },
        processError: async (args) => { log("ServiceBus", `Error on ${topicName}: ${args.error.message}`, true); },
      });
      log("ServiceBus", `Subscribed to topic: ${topicName} → ${rkMap[matchedKeyword] || "raw"}`);
    }

    connected.messaging = true;
    broadcast("connection_status", connected);
    log("ServiceBus", `Connected to Azure Service Bus (${discoveredTopics.length} topics)`);
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

    // Load admin settings from Redis
    await loadSettings();

    // Keyspace notifications
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
      WHERE r.is_active = true
      GROUP BY r.restaurant_id, r.name, r.cuisine ORDER BY r.name
    `);
    // Get all available dates
    const allDates = await pgPool.query(`SELECT DISTINCT date FROM time_slots WHERE date >= CURRENT_DATE ORDER BY date`);
    const availableDates = allDates.rows.map(r => r.date);

    // Use viewDate if set, otherwise auto-detect first available
    let slotDate = null;
    if (viewDate && availableDates.some(d => isoDate(d) === isoDate(viewDate))) {
      slotDate = viewDate;
    } else if (availableDates.length > 0) {
      slotDate = availableDates[0];
    }

    if (!slotDate) { broadcast("slot_state", { restaurants: restaurants.rows, slots: [], aggregates: [], availableDates: [] }); return; }
    const slotState = await pgPool.query(`
      SELECT ts.slot_id, ts.restaurant_id, ts.table_id, t.table_number,
             ts.start_time,
             CASE WHEN res.reservation_id IS NOT NULL THEN 'BOOKED' ELSE ts.status END AS status,
             ts.held_by, ts.held_until,
             res.user_id AS booked_by, u.first_name AS booked_by_name
      FROM time_slots ts JOIN tables t ON t.table_id = ts.table_id
      LEFT JOIN reservations res ON res.slot_id = ts.slot_id AND res.status IN ('CONFIRMED','PENDING')
      LEFT JOIN users u ON u.user_id = res.user_id
      WHERE ts.date = $1 ORDER BY ts.restaurant_id, t.table_number, ts.start_time
    `, [slotDate]);

    // Enrich with Redis holds (holds are Redis-only, key=hold:{slotId} value={userId}:{holdToken})
    const redisHolds = await getRedisHolds();
    const enrichedSlots = slotState.rows.map(s => {
      if (s.status !== 'BOOKED' && redisHolds[s.slot_id]) {
        return { ...s, status: 'HELD', held_by: redisHolds[s.slot_id].userId, held_until: null };
      }
      return s;
    });

    const aggregates = {};
    enrichedSlots.forEach(s => {
      const key = s.restaurant_id + ':' + s.status;
      if (!aggregates[key]) aggregates[key] = { restaurant_id: s.restaurant_id, status: s.status, cnt: 0 };
      aggregates[key].cnt++;
    });
    broadcast("slot_state", { restaurants: restaurants.rows, slots: enrichedSlots, aggregates: Object.values(aggregates), slotDate, availableDates });
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
               COUNT(*) FILTER (WHERE status = 'BOOKED') AS booked,
               COUNT(*) FILTER (WHERE status = 'BLOCKED') AS blocked
        FROM time_slots WHERE date = $1
      `, [slotDate]);
      util = u.rows[0] || util;
      // Add Redis holds count (Redis-only, not in DB)
      const redisHolds = await getRedisHolds();
      const heldCount = Object.keys(redisHolds).length;
      util.held = heldCount;
      util.available = parseInt(util.available) - heldCount; // some "available" are actually held
      if (util.available < 0) util.available = 0;
    }
    broadcast("metrics", { bookings: bk.rows[0], utilization: util });
  } catch (e) { log("Poll:Metrics", e.message, true); }
}

async function pollBookingsList() {
  if (!pgPool || !connected.postgres) return;
  try {
    const result = await pgPool.query(`
      SELECT r.reservation_id, r.confirmation_code, r.status, r.party_size, r.booked_at,
             rest.name AS restaurant_name, rest.cuisine,
             u.first_name, u.last_name,
             ts.start_time
      FROM reservations r
      JOIN restaurants rest ON rest.restaurant_id = r.restaurant_id
      LEFT JOIN users u ON u.user_id = r.user_id
      LEFT JOIN time_slots ts ON ts.slot_id = r.slot_id
      WHERE r.created_at::date = CURRENT_DATE
      ORDER BY r.created_at DESC LIMIT 50
    `);
    broadcast("bookings_list", result.rows);
  } catch (e) { log("Poll:Bookings", e.message, true); }
}

// ─── Redis Hold Lookup ───
async function getRedisHolds() {
  const holds = {};
  if (!redis || !connected.redis) return holds;
  try {
    let cursor = "0";
    do {
      const [next, keys] = await redis.scan(cursor, "MATCH", "hold:*", "COUNT", 200);
      cursor = next;
      for (const k of keys) {
        const v = await redis.get(k);
        if (!v) continue;
        const parts = v.split(":");
        const slotId = k.replace("hold:", "");
        holds[slotId] = { userId: parts[0], holdToken: parts[1] || null };
      }
    } while (cursor !== "0");
  } catch (e) { log("Redis:Holds", "Scan failed: " + e.message, true); }
  return holds;
}

// ─── Expand Slots (multi-day view) ───
async function handleExpandSlots(msg) {
  if (!pgPool || !connected.postgres) return;
  const status = msg.status; // "BOOKED" or "HELD"
  if (!status) return;
  try {
    const restaurants = await pgPool.query(`
      SELECT r.restaurant_id, r.name, r.cuisine, COUNT(DISTINCT t.table_id) AS table_count
      FROM restaurants r LEFT JOIN tables t ON t.restaurant_id = r.restaurant_id
      WHERE r.is_active = true
      GROUP BY r.restaurant_id, r.name, r.cuisine ORDER BY r.name
    `);

    if (status === 'HELD') {
      // Holds are Redis-only — scan Redis, then fetch slot details from DB
      const redisHolds = await getRedisHolds();
      const heldSlotIds = Object.keys(redisHolds);
      if (heldSlotIds.length === 0) {
        broadcast("expanded_slot_state", { restaurants: restaurants.rows, slotsByDate: {}, dates: [], status });
        return;
      }
      // Fetch slot details for all held slot IDs
      const slotsResult = await pgPool.query(`
        SELECT ts.slot_id, ts.restaurant_id, ts.table_id, t.table_number, ts.date,
               ts.start_time, ts.status
        FROM time_slots ts JOIN tables t ON t.table_id = ts.table_id
        WHERE ts.slot_id = ANY($1) AND ts.date >= CURRENT_DATE
        ORDER BY ts.date, ts.restaurant_id, t.table_number, ts.start_time
      `, [heldSlotIds]);

      // Enrich with Redis hold info
      const slotsByDate = {};
      const dateSet = new Set();
      for (const slot of slotsResult.rows) {
        const hold = redisHolds[slot.slot_id];
        const enriched = { ...slot, status: 'HELD', held_by: hold?.userId || null, held_until: null };
        const d = isoDate(slot.date);
        dateSet.add(d);
        if (!slotsByDate[d]) slotsByDate[d] = [];
        slotsByDate[d].push(enriched);
      }
      const dates = Array.from(dateSet).sort();
      broadcast("expanded_slot_state", { restaurants: restaurants.rows, slotsByDate, dates, status });

    } else {
      // BOOKED — query reservations from DB (unchanged logic)
      const statusCondition = `EXISTS(SELECT 1 FROM reservations r WHERE r.slot_id = ts.slot_id AND r.status IN ('CONFIRMED','PENDING'))`;
      const datesResult = await pgPool.query(
        `SELECT DISTINCT ts.date FROM time_slots ts WHERE (${statusCondition}) AND ts.date >= CURRENT_DATE ORDER BY ts.date`
      );
      const dates = datesResult.rows.map(r => r.date);
      if (dates.length === 0) { broadcast("expanded_slot_state", { restaurants: restaurants.rows, slotsByDate: {}, dates: [], status }); return; }

      const slotsResult = await pgPool.query(`
        SELECT ts.slot_id, ts.restaurant_id, ts.table_id, t.table_number, ts.date,
               ts.start_time, 'BOOKED' AS status,
               res.user_id AS booked_by, u.first_name AS booked_by_name
        FROM time_slots ts JOIN tables t ON t.table_id = ts.table_id
        JOIN reservations res ON res.slot_id = ts.slot_id AND res.status IN ('CONFIRMED','PENDING')
        LEFT JOIN users u ON u.user_id = res.user_id
        WHERE ts.date >= CURRENT_DATE
        ORDER BY ts.date, ts.restaurant_id, t.table_number, ts.start_time
      `);

      const slotsByDate = {};
      for (const slot of slotsResult.rows) {
        const d = isoDate(slot.date);
        if (!slotsByDate[d]) slotsByDate[d] = [];
        slotsByDate[d].push(slot);
      }
      broadcast("expanded_slot_state", { restaurants: restaurants.rows, slotsByDate, dates, status });
    }
  } catch (e) { log("Expand:Slots", e.message, true); }
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

  // Start HTTP server FIRST so Azure sees a healthy process immediately
  httpServer.listen(PORT, () => {
    const url = `http://localhost:${PORT}`;
    log("HTTP", `Dashboard ready at ${url}`);
    if (!IS_AZURE) {
      const cmd = process.platform === "win32" ? `start ${url}` : process.platform === "darwin" ? `open ${url}` : `xdg-open ${url}`;
      exec(cmd, () => {});
    }
  });

  // Connect to infrastructure in the background (non-blocking)
  if (LIVE) {
    log("Boot", `Connecting to infrastructure (${env})...`);
    log("Boot", `PostgreSQL: ${config.postgres.replace(/:[^:@]+@/, ":***@")}`);
    log("Boot", `Redis:      ${config.redis.replace(/password=[^,]+/, "password=***")}`);
    log("Boot", `Messaging:  ${USE_SERVICE_BUS ? "Azure Service Bus" : config.rabbitmq}`);

    // Fire and forget — each connector retries on its own
    connectRedis().catch(e => log("Boot", "Redis init error: " + e.message, true));
    connectPostgres().catch(e => log("Boot", "Postgres init error: " + e.message, true));
    if (USE_SERVICE_BUS) connectServiceBus().catch(e => log("Boot", "ServiceBus init error: " + e.message, true));
    else connectRabbitMQ().catch(e => log("Boot", "RabbitMQ init error: " + e.message, true));

    setInterval(pollSlots, config.pollSlots);
    setInterval(pollMetrics, config.pollMetrics);
    setInterval(pollHolds, config.pollSlots);
    setTimeout(() => { pollSlots(); pollMetrics(); pollHolds(); }, 3000);
  }
}

main().catch(console.error);
