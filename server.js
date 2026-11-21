const express = require("express");
const http = require("http");
const crypto = require("crypto");
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);
const io = new Server(server);
const PORT = process.env.PORT || 10000;
app.use(express.static("public"));
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
  return {code:room.code, players:room.players.map(p=>({name:p.name,connected:!!p.socketId,score:p.score})), status:room.status, category:room.category, round:room.round, log:room.log.slice(-40), scores:room.players.map(p=>p.score), commitment:room.commitment};
}
function broadcast(room) { io.to(room.code).emit("state", publicState(room)); }
function playerFor(room,socketId) { return room.players.find(p=>p.socketId===socketId); }
function sendPrivate(room, player) {
  if (player && player.socketId) io.to(player.socketId).emit("assignment",{name:player.identity,category:room.category,round:room.round});
}
function beginRound(room) {
  const deck = PEOPLE[room.category] || Object.values(PEOPLE).flat();
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
  socket.on("create", ({name,category}) => {
    name=clean(name)||"Player 1";
    if(!PEOPLE[category]) category="Footballers";
    let code=makeCode(); while(rooms.has(code)) code=makeCode();
    const room={code,category,players:[{name,socketId:socket.id,score:0,identity:null},{name:"",socketId:null,score:0,identity:null}],status:"waiting",round:0,log:[],seed:null,commitment:null,assignments:[]};
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
    if(room.players.every(p=>p.socketId)){beginRound(room);} else broadcast(room);
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
      p.score+=10; room.status="finished";
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
