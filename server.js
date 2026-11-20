const express = require("express");
const http = require("http");
const crypto = require("crypto");
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);
const io = new Server(server);
const PORT = process.env.PORT || 10000;
app.use(express.json({limit:"4mb"}));
app.use(express.static("public"));
const PAYMENT_DESTINATIONS = { airtel: "0992779365", tnm: "0899852077" };
const deposits = new Map();
const withdrawals = new Map();
const adminSessions = new Map();
const balances = new Map();
function adminAuth(req,res,next){ const token=(req.headers.authorization||"").replace(/^Bearer /,""); const expiry=adminSessions.get(token); if(!expiry||expiry<Date.now()){adminSessions.delete(token);return res.status(401).json({error:"Admin login required"});} next(); }
app.get("/api/payment-config",(_,res)=>res.json({destinations:PAYMENT_DESTINATIONS,amounts:[100,200,500,1000]}));
app.post("/api/admin/login",(req,res)=>{if(!process.env.ADMIN_PASSWORD)return res.status(503).json({error:"Admin password is not configured"});if(String(req.body.password||"")!==process.env.ADMIN_PASSWORD)return res.status(401).json({error:"Incorrect password"});const token=crypto.randomBytes(32).toString("hex");adminSessions.set(token,Date.now()+12*60*60*1000);res.json({token,expiresInHours:12});});
app.get("/api/admin/queue",adminAuth,(_,res)=>res.json({deposits:[...deposits.values()],withdrawals:[...withdrawals.values()],balances:[...balances.entries()].map(([key,value])=>({player:key,balance:value}))}));
app.post("/api/admin/deposits/:id/approve",adminAuth,(req,res)=>{const d=deposits.get(req.params.id);if(!d)return res.status(404).json({error:"Deposit not found"});if(d.status!=="pending")return res.status(409).json({error:"Deposit already reviewed"});d.status="approved";d.reviewedAt=new Date().toISOString();const room=rooms.get(d.roomCode);if(room&&room.players[d.seat]){room.players[d.seat].depositStatus="approved";if(room.players.every(p=>p.depositStatus==="approved")){beginRound(room);}else{room.status="awaiting_payments";broadcast(room);}}res.json({ok:true,deposit:d});});
app.post("/api/admin/deposits/:id/reject",adminAuth,(req,res)=>{const d=deposits.get(req.params.id);if(!d)return res.status(404).json({error:"Deposit not found"});d.status="rejected";d.reviewedAt=new Date().toISOString();const room=rooms.get(d.roomCode);if(room&&room.players[d.seat]){room.players[d.seat].depositStatus="rejected";broadcast(room);}res.json({ok:true});});
app.post("/api/admin/withdrawals/:id/paid",adminAuth,(req,res)=>{const w=withdrawals.get(req.params.id);if(!w)return res.status(404).json({error:"Withdrawal not found"});if(w.status!=="pending")return res.status(409).json({error:"Withdrawal already reviewed"});const current=balances.get(w.playerKey)||0;if(current<w.amount)return res.status(409).json({error:"Insufficient balance"});balances.set(w.playerKey,current-w.amount);w.status="paid";w.paidAt=new Date().toISOString();res.json({ok:true,withdrawal:w});});
app.post("/api/deposit",(req,res)=>{const {code,seat,method,amount,reference,screenshot,playerName}=req.body||{};const room=rooms.get(String(code||"").toUpperCase());if(!room||![0,1].includes(Number(seat))||!room.players[Number(seat)]?.socketId)return res.status(400).json({error:"Join the game room before submitting a deposit"});if(![100,200,500,1000].includes(Number(amount))||Number(amount)!==room.stakeAmount)return res.status(400).json({error:"Choose the exact stake amount selected for this room"});if(!["airtel","tnm"].includes(method))return res.status(400).json({error:"Choose Airtel Money or TNM Mpamba"});if(typeof screenshot!=="string"||!/^data:image\/(png|jpeg|webp);base64,/.test(screenshot)||screenshot.length>3500000)return res.status(400).json({error:"Upload a PNG, JPG or WebP screenshot under 2.5 MB"});const prior=[...deposits.values()].find(d=>d.roomCode===room.code&&d.seat===Number(seat)&&d.status!=="rejected");if(prior)return res.status(409).json({error:"A deposit has already been submitted for this player"});const id=crypto.randomUUID();const d={id,roomCode:room.code,seat:Number(seat),playerName:String(playerName||room.players[Number(seat)].name).slice(0,40),method,amount:Number(amount),reference:String(reference||"").slice(0,80),screenshot,status:"pending",submittedAt:new Date().toISOString()};deposits.set(id,d);room.players[Number(seat)].depositStatus="pending";room.status="awaiting_payments";broadcast(room);res.json({ok:true,message:"Screenshot submitted. Waiting for admin verification."});});
app.post("/api/withdrawal",(req,res)=>{const {playerName,amount,method,number}=req.body||{};const key=String(playerName||"").trim().slice(0,40);const value=Number(amount);if(!key||!Number.isInteger(value)||value<1||!["airtel","tnm"].includes(method)||!/^0[0-9]{9}$/.test(String(number||"")))return res.status(400).json({error:"Enter a valid amount, payment method and Malawi mobile-money number"});const balance=balances.get(key)||0;const reserved=[...withdrawals.values()].filter(w=>w.playerKey===key&&w.status==="pending").reduce((a,w)=>a+w.amount,0);if(value>balance-reserved)return res.status(400).json({error:"Insufficient available game balance"});const id=crypto.randomUUID();const w={id,playerKey:key,playerName:key,amount:value,method,number:String(number),status:"pending",requestedAt:new Date().toISOString()};withdrawals.set(id,w);res.json({ok:true,message:"Withdrawal request sent to admin."});});
app.get("/api/balance/:player", (req,res)=>{const key=String(req.params.player||"").slice(0,40);const reserved=[...withdrawals.values()].filter(w=>w.playerKey===key&&w.status==="pending").reduce((a,w)=>a+w.amount,0);res.json({balance:balances.get(key)||0,reserved,available:(balances.get(key)||0)-reserved});});
app.get("/health", (_, res) => res.json({ok:true, service:"Who Am I?"}));

const PEOPLE = {
  "Footballers": ["Lionel Messi","Cristiano Ronaldo","Kylian Mbappe","Erling Haaland","Mohamed Salah","Sadio Mane","Victor Osimhen","Didier Drogba","Samuel Eto'o","George Weah","Mia Hamm","Neymar","Vinicius Junior","Jude Bellingham","Bukayo Saka","Harry Kane","Luka Modric","Zlatan Ibrahimovic","David Beckham","Ronaldinho"],
  "Musicians": ["Burna Boy","Wizkid","Davido","Tems","Rihanna","Beyonce","Taylor Swift","Drake","Adele","Ed Sheeran","Diamond Platnumz","Fally Ipupa","Yemi Alade","Angelique Kidjo","Laufey","Bruno Mars","The Weeknd","Jay-Z","Akon","Yo Maps"],
  "Actors": ["Denzel Washington","Idris Elba","Lupita Nyongo","Jackie Chan","Leonardo DiCaprio","Zendaya","Morgan Freeman","Viola Davis","Chadwick Boseman","Will Smith","Angelina Jolie","Tom Cruise","Genevieve Nnaji","John Dumelo","Connie Ferguson","Robert Downey Jr."],
  "Politicians": ["Nelson Mandela","Barack Obama","Wangari Maathai","Kamala Harris","Donald Trump","Julius Nyerere","Hastings Kamuzu Banda","Joyce Banda","Lazarus Chakwera","Peter Mutharika","Paul Kagame","Emmerson Mnangagwa","Cyril Ramaphosa","Mia Mottley","Ellen Johnson Sirleaf"],
  "African celebrities": ["Trevor Noah","Minnie Dlamini","Bonang Matheba","Elsa Majimbo","Jackie Appiah","Rita Dominic","Sarkodie","Makhadzi","Kizz Daniel","Zari Hassan","Nadia Nakai","Wahu Kagwi","Lerato Kganyago","Anne Kansiime","Mpoza"]
};
const rooms = new Map();
const clean = s => String(s || "").trim().slice(0,40);
const makeCode = () => crypto.randomBytes(3).toString("hex").toUpperCase();
const hash = s => crypto.createHash("sha256").update(s).digest("hex");
function publicState(room) {
  return {code:room.code, players:room.players.map(p=>({name:p.name,connected:!!p.socketId,score:p.score,depositStatus:p.depositStatus})), status:room.status, category:room.category, round:room.round, log:room.log.slice(-40), scores:room.players.map(p=>p.score), commitment:room.commitment,stakeAmount:room.stakeAmount,prize:room.stakeAmount*2};
}
function broadcast(room) { io.to(room.code).emit("state", publicState(room)); }
function playerFor(room,socketId) { return room.players.find(p=>p.socketId===socketId); }
function sendPrivate(room, player) {
  if (player && player.socketId) io.to(player.socketId).emit("assignment",{name:player.identity,category:room.category,round:room.round});
}
function beginRound(room) {
  const category = room.category;
  const deck = PEOPLE[category] || Object.values(PEOPLE).flat();
  const seed = crypto.randomBytes(32).toString("hex");
  const rng = crypto.createHash("sha256").update(seed).digest();
  const n = rng.readUInt32BE(0) % deck.length;
  let m = rng.readUInt32BE(4) % deck.length;
  if (m===n) m=(m+1)%deck.length;
  room.seed = seed;
  room.commitment = hash(seed);
  room.assignments = [deck[n],deck[m]];
  room.players.forEach((p,i)=>{p.identity=room.assignments[i];p.guesses=0;});
  room.status = "playing";
  room.round += 1;
  room.log = [{type:"system",text:"Round "+room.round+" started. Ask yes/no questions in the game chat."}];
  room.players.forEach(p=>sendPrivate(room,p));
  broadcast(room);
}
function addLog(room, type, text, from) {
  room.log.push({type,text,from:from||"Game",at:new Date().toISOString()});
  if(room.log.length>80) room.log.shift();
}
io.on("connection", socket => {
  socket.on("create", ({name,category,stakeAmount}) => {
    name=clean(name)||"Player 1";
    if(!PEOPLE[category]) category="Footballers";
    let code=makeCode(); while(rooms.has(code)) code=makeCode();
    const stake=[100,200,500,1000].includes(Number(stakeAmount))?Number(stakeAmount):100; const room={code,category,stakeAmount:stake,players:[{name,socketId:socket.id,score:0,identity:null,depositStatus:"not_submitted"},{name:"",socketId:null,score:0,identity:null,depositStatus:"not_submitted"}],status:"waiting",round:0,log:[],seed:null,commitment:null,assignments:[]};
    rooms.set(code,room); socket.join(code); socket.data.code=code; socket.emit("joined",{code,seat:0}); broadcast(room);
  });
  socket.on("join", ({code,name}) => {
    code=clean(code).toUpperCase(); name=clean(name)||"Player 2";
    const room=rooms.get(code);
    if(!room) return socket.emit("errorMsg","That room code was not found. Ask your friend for a fresh invite.");
    let seat=room.players.findIndex(p=>p.socketId===socket.id);
    if(seat<0) seat=room.players.findIndex(p=>!p.socketId);
    if(seat<0) return socket.emit("errorMsg","This room already has two players.");
    room.players[seat].name=name; room.players[seat].socketId=socket.id;
    socket.join(code); socket.data.code=code; socket.emit("joined",{code,seat});
    addLog(room,"system",name+" joined the game.");
    if(room.players.every(p=>p.socketId)){room.status="awaiting_payments";broadcast(room);} else broadcast(room);
  });
  socket.on("start", ({category}) => {
    const room=rooms.get(socket.data.code); if(!room||!playerFor(room,socket.id)) return;
    if(room.players.some(p=>!p.socketId)) return socket.emit("errorMsg","Waiting for your friend to join.");
    if(!room.players.every(p=>p.depositStatus==="approved")) return socket.emit("errorMsg","Both deposits must be approved before play starts.");
    if(PEOPLE[category]) room.category=category;
    beginRound(room);
  });
  socket.on("chat", ({text}) => {
    const room=rooms.get(socket.data.code); const p=room&&playerFor(room,socket.id);
    text=String(text||"").trim().slice(0,240);
    if(!room||!p||room.status!=="playing"||!text) return;
    addLog(room,"chat",text,p.name); broadcast(room);
  });
  socket.on("answer", ({answer}) => {
    const room=rooms.get(socket.data.code); const p=room&&playerFor(room,socket.id);
    if(!room||!p||room.status!=="playing"||!["Yes","No","Not sure"].includes(answer)) return;
    addLog(room,"answer",answer,p.name); broadcast(room);
  });
  socket.on("guess", ({guess}) => {
    const room=rooms.get(socket.data.code); const p=room&&playerFor(room,socket.id);
    if(!room||!p||room.status!=="playing") return;
    const target=room.players[room.players.indexOf(p)===0?1:0];
    const correct=String(guess||"").trim().toLowerCase()===String(target.identity||"").toLowerCase();
    p.guesses++;
    if(correct) {
      p.score+=10; room.status="finished"; if(!room.prizeAwarded){const winnerKey=p.name; const winnings=room.stakeAmount*2; balances.set(winnerKey,(balances.get(winnerKey)||0)+winnings); room.prizeAwarded={winner:p.name,amount:winnings,at:new Date().toISOString()};}
      addLog(room,"system",p.name+" guessed correctly and wins 10 points!");
      io.to(room.code).emit("reveal",{identities:room.players.map(x=>x.identity),seed:room.seed,commitment:room.commitment,correctBy:p.name});
    } else {
      addLog(room,"system",p.name+" made an incorrect guess. The round continues.");
      socket.emit("guessResult",{correct:false,message:"Not quite. Keep asking questions."});
    }
    broadcast(room);
  });
  socket.on("revealRequest", () => {
    const room=rooms.get(socket.data.code); if(!room||room.status!=="finished") return;
    socket.emit("reveal",{identities:room.players.map(x=>x.identity),seed:room.seed,commitment:room.commitment});
  });
  socket.on("rematch", () => {
    const room=rooms.get(socket.data.code);
    if(!room || !playerFor(room,socket.id)) return;
    if(room.status!=="finished") return socket.emit("errorMsg","The next round becomes available after someone guesses correctly.");
    if(room.players.some(p=>!p.socketId)) return socket.emit("errorMsg","Both players must be connected to start the next round.");
    // The first player to press NEXT ROUND starts it for both players.
    // Changing status to playing immediately prevents a second click starting another round.
    beginRound(room);
  });
  socket.on("disconnect", () => {
    const code=socket.data.code, room=rooms.get(code); if(!room) return;
    const p=playerFor(room,socket.id); if(p){p.socketId=null; addLog(room,"system",p.name+" disconnected. They can rejoin using the same room code.");}
    broadcast(room);
    setTimeout(()=>{const r=rooms.get(code); if(r&&r.players.every(x=>!x.socketId)) rooms.delete(code);},1000*60*60);
  });
});
server.listen(PORT,"0.0.0.0",()=>console.log("Who Am I? listening on "+PORT));
