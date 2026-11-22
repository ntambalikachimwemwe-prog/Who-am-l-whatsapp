const express = require("express");
const http = require("http");
const crypto = require("crypto");
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);
const io = new Server(server);
const PORT = process.env.PORT || 10000;
app.use(express.json());
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
    code: room.code, status: room.status, round: room.round, totalRounds: 10, stake: room.stake, matchWinner: room.matchWinner || null, lastPayout: room.lastPayout || null, operatorShare: room.operatorShare || 0,
    // Each player sees the other player's target, never their own.
    target: room.status === "waiting" ? null : targetFor(room, viewerSeat),
    players: room.players.map((p, seat) => {
      // Progress is measured against each player's OWN target. The target itself
      // is never sent to that player; it is shown only in the opponent's room.
      const progress = room.status === "waiting" ? 0 : progressFor(p, p.target);
      return {
        seat, name: p.name, connected: !!p.socketId, arrangement: p.arrangement,
        progress, score: p.score,
        roundPoints: room.status === "playing" ? progress * 10 : p.lastRoundPoints || 0
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
    const points = progressFor(p, p.target) * 10 + (p === winner ? 20 : 0);
    p.lastRoundPoints = points;
    p.score += points;
  });
  addChat(room, "system", winner.name + " wins round " + room.round + " and receives " + winnerCut + " virtual credits. Operator share: " + operatorCut + ".");
  broadcast(room);
  setTimeout(() => {
    const current = rooms.get(room.code);
    if (current === room && current.status === "finished" && current.players.some(p => p.socketId)) beginRound(current);
  }, 4500);
}

io.on("connection", socket => {
  socket.on("create", payload => {
    const name = clean(payload && payload.name) || "Player 1";\n    const stake = Number(payload && payload.stake);\n    if (!Number.isSafeInteger(stake) || stake < 1 || stake > 10000000) return socket.emit("errorMsg", "Enter a valid virtual stake (minimum 1).");\n    const creatorWallet = walletFor(name);\n    if (creatorWallet.balance < stake) return socket.emit("errorMsg", "Your wallet does not have enough virtual credits. Request credits from the wallet page.");
    let code = makeCode();
    while (rooms.has(code)) code = makeCode();
    const room = {
      code, status: "waiting", round: 0, winner: null, chat: [], stake, operatorShare: 0, matchWinner: null,
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
    if (!room) return socket.emit("errorMsg", "Room not found. Check the code and try again.");\n    const joiningWallet = walletFor(name);\n    if (joiningWallet.balance < room.stake) return socket.emit("errorMsg", "Your wallet does not have enough virtual credits for the " + room.stake + " stake. Request credits first.");
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
    if (progressFor(p, p.target) === 4) finishRound(room, p);
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


/* Virtual-credit wallet and private admin dashboard.
   This in-memory ledger is intentionally for private play/testing only. */
const wallets = new Map();
const requests = [];
const ledger = [];
const adminPassword = process.env.ADMIN_PASSWORD || "";
const walletFor = name => {
  const key = clean(name, 32).toLowerCase();
  if (!key) return null;
  if (!wallets.has(key)) wallets.set(key, { name: clean(name,32), balance: 0 });
  return wallets.get(key);
};
const adminOnly = (req,res,next) => {
  if (!adminPassword || req.headers["x-admin-password"] !== adminPassword) return res.status(401).json({error:"Admin authentication required"});
  next();
};
app.get("/api/wallet", (req,res) => {
  const w = walletFor(req.query.name);
  if (!w) return res.status(400).json({error:"Enter a player name"});
  res.json({name:w.name,balance:w.balance,requests:requests.filter(x=>x.playerKey===w.name.toLowerCase())});
});
app.post("/api/wallet/request", (req,res) => {
  const name=clean(req.body && req.body.name,32), amount=Number(req.body && req.body.amount), type=req.body && req.body.type;
  if (!name || !Number.isSafeInteger(amount) || amount<1 || amount>100000000 || !["deposit","withdrawal"].includes(type)) return res.status(400).json({error:"Enter a valid player, amount and request type"});
  const w=walletFor(name);
  const pending= requests.filter(x=>x.playerKey===name.toLowerCase()&&x.type==="withdrawal"&&x.status==="pending").reduce((a,x)=>a+x.amount,0);
  if(type==="withdrawal" && amount>w.balance-pending) return res.status(400).json({error:"Insufficient available virtual credits"});
  const item={id:crypto.randomUUID(),player:w.name,playerKey:name.toLowerCase(),type,amount,status:"pending",createdAt:new Date().toISOString()};
  requests.unshift(item);
  res.json({ok:true,request:item,balance:w.balance});
});
app.get("/api/admin/summary",adminOnly,(req,res)=>{
  res.json({wallets:[...wallets.values()],requests,ledger,totals:{players:wallets.size,credits:[...wallets.values()].reduce((a,w)=>a+w.balance,0),operatorShare:ledger.filter(x=>x.type==="operator_share").reduce((a,x)=>a+x.amount,0)},matches:[...rooms.values()].map(r=>({code:r.code,round:r.round,status:r.status,players:r.players.map(p=>p.name),stake:r.stake,matchWinner:r.matchWinner,operatorShare:r.operatorShare}))});
});
app.post("/api/admin/request/:id",adminOnly,(req,res)=>{
  const item=requests.find(x=>x.id===req.params.id);
  if(!item||item.status!=="pending") return res.status(404).json({error:"Pending request not found"});
  const action=req.body && req.body.action;
  if(!["approve","reject"].includes(action)) return res.status(400).json({error:"Invalid action"});
  const w=walletFor(item.player);
  if(action==="approve"){
    if(item.type==="deposit") w.balance+=item.amount;
    else { if(w.balance<item.amount) return res.status(409).json({error:"Balance changed; withdrawal cannot be processed"}); w.balance-=item.amount; }
    ledger.unshift({id:crypto.randomUUID(),player:w.name,type:item.type,amount:item.amount,createdAt:new Date().toISOString(),requestId:item.id});
  }
  item.status=action==="approve"?"approved":"rejected";
  item.reviewedAt=new Date().toISOString();
  res.json({ok:true,request:item,balance:w.balance});
});
app.get("/admin", (req,res)=>res.sendFile(require("path").join(__dirname,"public","admin.html")));
app.get("/wallet", (req,res)=>res.sendFile(require("path").join(__dirname,"public","wallet.html")));

server.listen(PORT, "0.0.0.0", () => console.log("Sorting Battle listening on " + PORT));
