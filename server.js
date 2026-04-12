'use strict';

const express   = require('express');
const { createServer } = require('http');
const { ExpressPeerServer } = require('peer');
const path      = require('path');

const app        = express();
const httpServer = createServer(app);

// ─── PeerJS signaling server ─────────────────────────────────────────────────
// Provides WebRTC signaling so all devices on the same LAN can find each other
// without needing an external internet connection.
const peerServer = ExpressPeerServer(httpServer, {
  debug:   false,
  path:    '/',
  proxied: true,
});
app.use('/peerjs', peerServer);

// ─── Static files ────────────────────────────────────────────────────────────
app.use(express.static(path.join(__dirname)));

// ─── Start ────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, '0.0.0.0', () => {
  const os = require('os');
  const ifaces = os.networkInterfaces();
  const ips = [];
  Object.values(ifaces).forEach(list =>
    list.forEach(i => { if (i.family === 'IPv4' && !i.internal) ips.push(i.address); })
  );

  console.log('\n🎮 ECHO Game Server ready!');
  console.log(`   Local  -> http://localhost:${PORT}`);
  ips.forEach(ip => console.log(`   LAN    -> http://${ip}:${PORT}  (share this with your friends)`));
  console.log('\n📱 Players on the same Wi-Fi can open the LAN address in their browser.');
  console.log('   No internet required – the PeerJS signaling server is built in.\n');
});
