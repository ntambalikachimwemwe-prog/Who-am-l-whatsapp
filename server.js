const express = require("express");
const http = require("http");
const crypto = require("crypto");
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);
const io = new Server(server);
const PORT = process.env.PORT || 10000;
app.use(express.json({limit:"1mb"}));
app.use(express.static("public"));
app.get("/health", (_,res)=>res.json({ok:true,service:"Social Hub"}));

const users = new Map();
const tokens = new Map();
const posts = [];
const conversations = new Map();
const messages = new Map();
const makeId = () => crypto.randomBytes(12).toString("hex");
const normalPhone = value => String(value||"").replace(/[^+\d]/g,"").slice(0,20);
const hashPin = (pin,salt) => crypto.scryptSync(String(pin),salt,64).toString("hex");
function auth(req,res,next) {
  const token=(req.headers.authorization||"").replace(/^Bearer\s+/i,"");
  const userId=tokens.get(token);
  const user=users.get(userId);
  if(!user) return res.status(401).json({error:"Please sign in again."});
  req.user=user; req.token=token; next();
}
function safeUser(user){return {id:user.id,name:user.name,phone:user.phone,bio:user.bio||"",joinedAt:user.joinedAt};}
function safePost(post,viewerId){
  return {...post,author:safeUser(users.get(post.authorId)),liked:post.likes.includes(viewerId),
    comments:post.comments.map(c=>({...c,author:safeUser(users.get(c.authorId)),replies:c.replies.map(r=>({...r,author:safeUser(users.get(r.authorId))}))}))};
}
function conversationKey(a,b){return [a,b].sort().join(":");}
function emitToUser(userId,event,payload){io.to("user:"+userId).emit(event,payload);}

app.post("/api/register",(req,res)=>{
  const name=String(req.body.name||"").trim().slice(0,40);
  const phone=normalPhone(req.body.phone);
  const pin=String(req.body.pin||"");
  if(name.length<2 || phone.length<7 || !/^\d{4,8}$/.test(pin)) return res.status(400).json({error:"Enter your name, a valid phone number and a 4–8 digit PIN."});
  if([...users.values()].some(u=>u.phone===phone)) return res.status(409).json({error:"That phone number is already registered. Please sign in."});
  const salt=crypto.randomBytes(16).toString("hex");
  const user={id:makeId(),name,phone,bio:"",salt,pinHash:hashPin(pin,salt),joinedAt:new Date().toISOString()};
  users.set(user.id,user);
  const token=makeId(); tokens.set(token,user.id);
  res.json({token,user:safeUser(user)});
});
app.post("/api/login",(req,res)=>{
  const phone=normalPhone(req.body.phone),pin=String(req.body.pin||"");
  const user=[...users.values()].find(u=>u.phone===phone);
  if(!user || hashPin(pin,user.salt)!==user.pinHash) return res.status(401).json({error:"Incorrect phone number or PIN."});
  const token=makeId(); tokens.set(token,user.id);
  res.json({token,user:safeUser(user)});
});
app.post("/api/logout",auth,(req,res)=>{tokens.delete(req.token);res.json({ok:true});});
app.get("/api/me",auth,(req,res)=>res.json({user:safeUser(req.user)}));
app.patch("/api/me",auth,(req,res)=>{
  const name=String(req.body.name||req.user.name).trim().slice(0,40);
  const bio=String(req.body.bio||"").trim().slice(0,160);
  if(name.length<2)return res.status(400).json({error:"Name is too short."});
  req.user.name=name;req.user.bio=bio;res.json({user:safeUser(req.user)});
});
app.get("/api/users/find",auth,(req,res)=>{
  const phone=normalPhone(req.query.phone);
  const found=[...users.values()].find(u=>u.phone===phone && u.id!==req.user.id);
  if(!found)return res.status(404).json({error:"No member found with that number."});
  res.json({user:safeUser(found)});
});
app.get("/api/posts",auth,(req,res)=>res.json({posts:posts.slice().reverse().map(p=>safePost(p,req.user.id))}));
app.post("/api/posts",auth,(req,res)=>{
  const body=String(req.body.body||"").trim().slice(0,2000);
  if(!body)return res.status(400).json({error:"Write something before posting."});
  const post={id:makeId(),authorId:req.user.id,body,createdAt:new Date().toISOString(),likes:[],comments:[]};
  posts.push(post);const result=safePost(post,req.user.id);
  io.emit("post:new",result);res.status(201).json({post:result});
});
app.post("/api/posts/:id/like",auth,(req,res)=>{
  const post=posts.find(p=>p.id===req.params.id);if(!post)return res.status(404).json({error:"Post not found."});
  const i=post.likes.indexOf(req.user.id);if(i>=0)post.likes.splice(i,1);else post.likes.push(req.user.id);
  res.json({post:safePost(post,req.user.id)});
});
app.post("/api/posts/:id/comments",auth,(req,res)=>{
  const post=posts.find(p=>p.id===req.params.id);const body=String(req.body.body||"").trim().slice(0,1000);
  if(!post)return res.status(404).json({error:"Post not found."});if(!body)return res.status(400).json({error:"Comment cannot be empty."});
  const comment={id:makeId(),authorId:req.user.id,body,createdAt:new Date().toISOString(),replies:[]};
  post.comments.push(comment);const result=safePost(post,req.user.id);io.emit("post:updated",result);res.status(201).json({post:result});
});
app.post("/api/posts/:postId/comments/:commentId/replies",auth,(req,res)=>{
  const post=posts.find(p=>p.id===req.params.postId);const comment=post&&post.comments.find(c=>c.id===req.params.commentId);
  const body=String(req.body.body||"").trim().slice(0,1000);
  if(!comment)return res.status(404).json({error:"Comment not found."});if(!body)return res.status(400).json({error:"Reply cannot be empty."});
  comment.replies.push({id:makeId(),authorId:req.user.id,body,createdAt:new Date().toISOString()});
  const result=safePost(post,req.user.id);io.emit("post:updated",result);res.status(201).json({post:result});
});
app.get("/api/inbox",auth,(req,res)=>{
  const list=[...conversations.values()].filter(c=>c.members.includes(req.user.id)).map(c=>{
    const otherId=c.members.find(id=>id!==req.user.id),other=safeUser(users.get(otherId)),items=messages.get(c.id)||[];
    return {id:c.id,other,lastMessage:items[items.length-1]||null,unread:items.filter(m=>m.to===req.user.id&&!m.read).length};
  }).sort((a,b)=>String(b.lastMessage?.createdAt||"").localeCompare(String(a.lastMessage?.createdAt||"")));
  res.json({conversations:list});
});
app.get("/api/messages/:otherId",auth,(req,res)=>{
  const key=conversationKey(req.user.id,req.params.otherId),c=conversations.get(key);
  if(!c)return res.json({conversationId:key,messages:[]});
  const items=messages.get(key)||[];items.forEach(m=>{if(m.to===req.user.id)m.read=true;});
  res.json({conversationId:key,messages:items});
});
app.post("/api/messages/:otherId",auth,(req,res)=>{
  const other=users.get(req.params.otherId),body=String(req.body.body||"").trim().slice(0,2000);
  if(!other||other.id===req.user.id)return res.status(404).json({error:"Member not found."});
  if(!body)return res.status(400).json({error:"Message cannot be empty."});
  const key=conversationKey(req.user.id,other.id);
  if(!conversations.has(key))conversations.set(key,{id:key,members:[req.user.id,other.id]});
  const item={id:makeId(),from:req.user.id,to:other.id,body,createdAt:new Date().toISOString(),read:false};
  const items=messages.get(key)||[];items.push(item);messages.set(key,items);
  emitToUser(other.id,"message:new",{conversationId:key,message:item,from:safeUser(req.user)});
  res.status(201).json({message:item});
});

io.use((socket,next)=>{
  const userId=tokens.get(socket.handshake.auth?.token);
  const user=users.get(userId);
  if(!user)return next(new Error("Please sign in."));
  socket.user=user;next();
});
io.on("connection",socket=>{socket.join("user:"+socket.user.id);});
server.listen(PORT,"0.0.0.0",()=>console.log("Social Hub listening on "+PORT));
