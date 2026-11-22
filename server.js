const express = require("express");
const http = require("http");
const crypto = require("crypto");
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);
const io = new Server(server);
const PORT = process.env.PORT || 10000;
app.use(express.static("public"));
app.get("/health", (_, res) => res.json({ ok: true, service: "Sorting Battle" }));

const OBJECTS = [
  { id: "ghost", name: "Ghost", emoji: "👻" },
  { id: "skull", name: "Skull", emoji: "💀" },
  { id: "witch", name: "Witch", emoji: "🧙" },
  { id: "cauldron", name: "Cauldron", emoji: "🫖" }
];
const rooms = new Map();
const clean = (v, n = 32) => String(v || "").trim().slice(0, n);
const makeCode = () => crypto.randomBytes(3).toString("hex").toUpperCase();
const shuffle = list => {
  const a = list.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = crypto.randomInt(i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};
const playerFor = (room, socketId) => room.players.find(p => p.socketId === socketId);
const targetFor = (room, seat) => room.players[1 - seat].target;
const progressFor = (p, target) => p.arrangement.reduce((n, id, i) => n + (id === target[i] ? 1 : 0), 0);

function publicState(room, viewerSeat) {
  return {
    code: room.code, status: room.status, round: room.round,
    // Each player sees the other player's target, never their own.
    target: room.status === "waiting" ? null : targetFor(room, viewerSeat),
    players: room.players.map((p, seat) => {
      // Only disclose the viewer's own progress. The opponent's progress is
      // deliberately hidden because it is measured against the viewer's secret target.
      const isViewer = seat === viewerSeat;
      const progress = room.status === "waiting" ? 0 :
        (isViewer ? progressFor(p, targetFor(room, seat)) : null);
      return {
        seat, name: p.name, connected: !!p.socketId, arrangement: p.arrangement,
        progress, score: p.score,
        roundPoints: isViewer
          ? (room.status === "playing" ? progress * 10 : p.lastRoundPoints || 0)
          : null
      };
    }),
    winner: room.winner, chat: room.chat.slice(-60)
  };
}
function broadcast(room) {
  room.players.forEach((p, seat) => {
    if (p.socketId) io.to(p.socketId).emit("state", publicState(room, seat));
  });
}
function addChat(room, kind, text, from) {
  room.chat.push({ kind, text, from: from || "Game", at: new Date().toISOString() });
  if (room.chat.length > 100) room.chat.shift();
}
function beginRound(room) {
  room.round += 1;
  const firstTarget = shuffle(OBJECTS.map(x => x.id));
  let secondTarget = shuffle(OBJECTS.map(x => x.id));
  while (secondTarget.every((id, i) => id === firstTarget[i])) secondTarget = shuffle(OBJECTS.map(x => x.id));
  room.players[0].target = firstTarget;
  room.players[1].target = secondTarget;
  room.players.forEach((p, seat) => {
    p.arrangement = shuffle(OBJECTS.map(x => x.id));
    while (p.arrangement.every((id, i) => id === targetFor(room, seat)[i])) p.arrangement = shuffle(OBJECTS.map(x => x.id));
    p.lastRoundPoints = 0;
  });
  room.winner = null;
  room.status = "playing";
  addChat(room, "system", "Round " + room.round + " is live! Each player sees their friend's target and sorts against it. Your own target is shown only in your friend's room.");
  broadcast(room);
}
function finishRound(room, winner) {
  if (room.status !== "playing") return;
  room.status = "finished";
  room.winner = winner.name;
  room.players.forEach((p, seat) => {
    const points = progressFor(p, targetFor(room, seat)) * 10 + (p === winner ? 20 : 0);
    p.lastRoundPoints = points;
    p.score += points;
  });
  addChat(room, "system", winner.name + " completed the arrangement first and wins this round! Next round starts automatically.");
  broadcast(room);
  setTimeout(() => {
    const current = rooms.get(room.code);
    if (current === room && current.status === "finished" && current.players.some(p => p.socketId)) beginRound(current);
  }, 4500);
}

io.on("connection", socket => {
  socket.on("create", payload => {
    const name = clean(payload && payload.name) || "Player 1";
    let code = makeCode();
    while (rooms.has(code)) code = makeCode();
    const room = {
      code, status: "waiting", round: 0, winner: null, chat: [],
      players: [
        { name, socketId: socket.id, arrangement: [], score: 0, lastRoundPoints: 0 },
        { name: "", socketId: null, arrangement: [], score: 0, lastRoundPoints: 0 }
      ]
    };
    rooms.set(code, room);
    socket.join(code); socket.data.code = code; socket.data.seat = 0;
    socket.emit("joined", { code, seat: 0 });
    addChat(room, "system", name + " created the room. Share the code with your opponent.");
    broadcast(room);
  });

  socket.on("join", payload => {
    const code = clean(payload && payload.code, 8).toUpperCase();
    const name = clean(payload && payload.name) || "Player 2";
    const room = rooms.get(code);
    if (!room) return socket.emit("errorMsg", "Room not found. Check the code and try again.");
    let seat = room.players.findIndex(p => p.socketId === socket.id);
    if (seat < 0) seat = room.players.findIndex(p => !p.socketId && (!p.name || p.name.toLowerCase() === name.toLowerCase()));
    if (seat < 0) seat = room.players.findIndex(p => !p.socketId && !p.name);
    if (seat < 0) return socket.emit("errorMsg", "This room already has two players.");
    if (room.players[seat].socketId) return socket.emit("errorMsg", "That player is already connected.");
    room.players[seat].name = name;
    room.players[seat].socketId = socket.id;
    socket.join(code); socket.data.code = code; socket.data.seat = seat;
    socket.emit("joined", { code, seat });
    addChat(room, "system", name + " joined the battle.");
    if (room.players.every(p => p.socketId) && room.status === "waiting") beginRound(room);
    else broadcast(room);
  });

  socket.on("move", payload => {
    const room = rooms.get(socket.data.code);
    const p = room && playerFor(room, socket.id);
    if (!room || !p || room.status !== "playing") return;
    const from = Number(payload && payload.from), to = Number(payload && payload.to);
    if (!Number.isInteger(from) || !Number.isInteger(to) || from < 0 || from > 3 || to < 0 || to > 3 || from === to) return;
    [p.arrangement[from], p.arrangement[to]] = [p.arrangement[to], p.arrangement[from]];
    broadcast(room);
    if (progressFor(p, targetFor(room, socket.data.seat)) === 4) finishRound(room, p);
  });

  socket.on("chat", payload => {
    const room = rooms.get(socket.data.code);
    const p = room && playerFor(room, socket.id);
    const message = clean(payload && payload.text, 300);
    if (!room || !p || !message) return;
    addChat(room, "message", message, p.name);
    broadcast(room);
  });

  socket.on("disconnect", () => {
    const room = rooms.get(socket.data.code);
    if (!room) return;
    const p = playerFor(room, socket.id);
    if (p) {
      p.socketId = null;
      addChat(room, "system", p.name + " disconnected. They can rejoin with the same room code and name.");
      broadcast(room);
    }
    setTimeout(() => {
      const current = rooms.get(room.code);
      if (current === room && current.players.every(x => !x.socketId)) rooms.delete(room.code);
    }, 60 * 60 * 1000);
  });
});

server.listen(PORT, "0.0.0.0", () => console.log("Sorting Battle listening on " + PORT));
