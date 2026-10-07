// Minimal loopback-only WebSocket signaling fixture; no external packages.
const http = require('node:http');
const crypto = require('node:crypto');
const rooms = new Map();
const clients = new Map();
let peerSerial = 0;

function frame(payload, opcode = 1) {
  const body = Buffer.isBuffer(payload) ? payload : Buffer.from(JSON.stringify(payload));
  const header = Buffer.alloc(body.length < 126 ? 2 : 4);
  header[0] = 0x80 | opcode;
  if (body.length < 126) header[1] = body.length;
  else { header[1] = 126; header.writeUInt16BE(body.length, 2); }
  return Buffer.concat([header, body]);
}
function send(peer, data) { if (!peer.socket.destroyed) peer.socket.write(frame(data)); }
function receive(peer, message) {
  if (message.type === 'create_room') {
    const key = `${message.app}:${message.room}`;
    if (rooms.has(key)) return send(peer, {type:'error',message:'Room already exists'});
    const room = {key, name:message.room, peers:new Map(), nextId:2, locked:false, host:peer.id};
    rooms.set(key, room); peer.room = room; peer.godotId = 1; room.peers.set(peer.id, peer);
    send(peer, {type:'room_created',peerId:peer.id,godotId:1,room:room.name});
  } else if (message.type === 'join_room') {
    const room = rooms.get(`${message.app}:${message.room}`);
    if (!room || room.locked || room.peers.size >= 4) return send(peer, {type:'error',message:'Room unavailable'});
    const existing = [...room.peers.values()];
    peer.room = room; peer.godotId = room.nextId++; room.peers.set(peer.id, peer);
    send(peer, {type:'joined_room',peerId:peer.id,godotId:peer.godotId,room:room.name,peers:existing.map(p=>({peerId:p.id,godotId:p.godotId}))});
    for (const other of existing) send(other, {type:'new_peer',peerId:peer.id,godotId:peer.godotId});
  } else if (message.type === 'signal') {
    const target = clients.get(message.to);
    if (target && target.room === peer.room) send(target, {type:'signal',from:peer.id,data:message.data});
  } else if (message.type === 'lock_room' && peer.room?.host === peer.id) peer.room.locked = true;
}
function leave(peer) {
  if (!clients.has(peer.id)) return;
  clients.delete(peer.id);
  const room = peer.room;
  if (!room) return;
  room.peers.delete(peer.id);
  if (room.host === peer.id) {
    for (const other of room.peers.values()) send(other, {type:'host_left'});
    rooms.delete(room.key);
  } else for (const other of room.peers.values()) send(other, {type:'peer_left',peerId:peer.id});
}
const server = http.createServer((req,res)=>{res.writeHead(200);res.end('Local WebRTC validation fixture');});
server.on('upgrade', (req, socket) => {
  const accept = crypto.createHash('sha1').update(req.headers['sec-websocket-key'] + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
  socket.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
  const peer = {id:`peer-${++peerSerial}`,socket,buffer:Buffer.alloc(0),room:null,godotId:0};
  clients.set(peer.id, peer);
  socket.on('data', bytes => {
    peer.buffer = Buffer.concat([peer.buffer, bytes]);
    while (peer.buffer.length >= 2) {
      const b = peer.buffer; const opcode = b[0] & 15; const masked = !!(b[1] & 128);
      let length = b[1] & 127; let offset = 2;
      if (length === 126) {if(b.length<4) return; length=b.readUInt16BE(2);offset=4;}
      if (length === 127) {socket.destroy();return;}
      const key = masked ? b.subarray(offset,offset+4) : null;
      if(masked) offset += 4;
      if(b.length<offset+length) return;
      const body=Buffer.from(b.subarray(offset,offset+length));peer.buffer=b.subarray(offset+length);
      if(masked) for(let i=0;i<body.length;i++) body[i]^=key[i%4];
      if(opcode===8) {socket.end(frame(body,8));return;}
      if(opcode===9) {socket.write(frame(body,10));continue;}
      if(opcode===1) {try {receive(peer,JSON.parse(body.toString()));} catch {socket.destroy();}}
    }
  });
  socket.on('close',()=>leave(peer));
  socket.on('error',()=>leave(peer));
});
server.listen(29910,'127.0.0.1',()=>console.log('Signaling fixture ready on ws://127.0.0.1:29910'));
