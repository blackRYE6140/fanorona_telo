const http = require('http');
const express = require('express');
const { WebSocketServer, WebSocket } = require('ws');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

const PORT = Number(process.env.PORT || 8080);

const clients = new Map(); // WebSocket -> ClientState
const hostsById = new Map(); // hostId -> ClientState

class ClientState {
  constructor(ws) {
    this.ws = ws;
    this.displayName = 'Invite';
    this.avatar = null;

    this.isHost = false;
    this.ownedHostId = null;
    this.waitingHostId = null;
    this.peerWs = null;
  }
}

app.get('/', (_req, res) => {
  res.json({
    service: 'fanorona-relay-express',
    status: 'ok',
    clients: clients.size,
    hosts: hostsById.size,
  });
});

wss.on('connection', (ws) => {
  const client = new ClientState(ws);
  clients.set(ws, client);

  ws.on('message', (raw) => {
    const message = decodeMessage(raw);
    if (!message) {
      send(ws, { type: 'error', message: 'Message JSON invalide.' });
      return;
    }

    handleMessage(client, message);
  });

  ws.on('close', () => {
    handleDisconnect(client, true);
  });

  ws.on('error', () => {
    handleDisconnect(client, true);
  });
});

function decodeMessage(raw) {
  try {
    const text = Buffer.isBuffer(raw) ? raw.toString('utf8') : String(raw);
    const decoded = JSON.parse(text);

    if (decoded && typeof decoded === 'object' && !Array.isArray(decoded)) {
      return decoded;
    }
    return null;
  } catch (_error) {
    return null;
  }
}

function handleMessage(client, message) {
  const type = String(message.type || '').trim();
  if (!type) {
    send(client.ws, { type: 'error', message: 'Type de message manquant.' });
    return;
  }

  switch (type) {
    case 'host_announce':
      handleHostAnnounce(client, message);
      return;
    case 'discover_hosts':
      handleDiscoverHosts(client, message);
      return;
    case 'join_host':
      handleJoinHost(client, message);
      return;

    // Backward compatibility with previous protocol.
    case 'host_create':
      handleHostAnnounce(client, {
        type: 'host_announce',
        hostId: message.code,
        name: message.name,
        avatar: message.avatar,
      });
      return;
    case 'join_room':
      handleJoinHost(client, {
        type: 'join_host',
        hostId: message.code,
        name: message.name,
        avatar: message.avatar,
      });
      return;

    case 'leave':
      handleDisconnect(client, true);
      return;
    default:
      relayToPeer(client, message);
  }
}

function handleHostAnnounce(client, message) {
  const displayName = String(message.name || '').trim();
  if (displayName) {
    client.displayName = displayName;
  }
  client.avatar = typeof message.avatar === 'string' ? message.avatar : null;

  unpairClient(client, true);

  const preferredHostId = String(message.hostId || '').trim() || null;
  const hostId = activateHostMode(client, preferredHostId);

  send(client.ws, { type: 'host_ready', hostId });
}

function handleDiscoverHosts(client, message) {
  const displayName = String(message.name || '').trim();
  if (displayName) {
    client.displayName = displayName;
  }

  sendHostsList(client.ws);
}

function handleJoinHost(client, message) {
  const hostId = String(message.hostId || '').trim();
  if (!hostId) {
    send(client.ws, { type: 'error', message: 'ID host manquant.' });
    return;
  }

  const host = hostsById.get(hostId);
  if (!host) {
    send(client.ws, { type: 'error', message: 'Invitation introuvable.' });
    return;
  }
  if (host.ws === client.ws) {
    send(client.ws, {
      type: 'error',
      message: 'Impossible de rejoindre votre propre invitation.',
    });
    return;
  }
  if (host.peerWs) {
    send(client.ws, { type: 'error', message: 'Cet ami est déjà en partie.' });
    return;
  }
  if (client.peerWs) {
    send(client.ws, { type: 'error', message: 'Vous êtes déjà en partie.' });
    return;
  }

  const displayName = String(message.name || '').trim();
  if (displayName) {
    client.displayName = displayName;
  }
  client.avatar = typeof message.avatar === 'string' ? message.avatar : null;

  removeHostFromList(host);

  host.peerWs = client.ws;
  client.peerWs = host.ws;
  client.isHost = false;
  client.ownedHostId = null;
  client.waitingHostId = null;

  send(host.ws, {
    type: 'join',
    hostId,
    name: client.displayName,
    avatar: client.avatar,
  });
}

function relayToPeer(client, message) {
  const peerWs = client.peerWs;
  if (!peerWs) {
    send(client.ws, { type: 'error', message: 'Aucun adversaire connecté.' });
    return;
  }

  const peer = clients.get(peerWs);
  if (!peer) {
    client.peerWs = null;
    send(client.ws, { type: 'error', message: 'Adversaire indisponible.' });

    if (client.isHost) {
      const restoredHostId = activateHostMode(client, client.ownedHostId);
      send(client.ws, { type: 'host_ready', hostId: restoredHostId });
    }
    return;
  }

  send(peer.ws, message);
}

function handleDisconnect(client, notifyPeer) {
  if (!clients.has(client.ws)) {
    return;
  }

  removeHostFromList(client);
  unpairClient(client, notifyPeer);
  clients.delete(client.ws);

  if (client.ws.readyState === WebSocket.OPEN) {
    try {
      client.ws.close();
    } catch (_error) {
      // Ignore close failures.
    }
  }
}

function unpairClient(client, notifyPeer) {
  const peerWs = client.peerWs;
  client.peerWs = null;

  if (!peerWs) {
    return;
  }

  const peer = clients.get(peerWs);
  if (!peer) {
    return;
  }

  peer.peerWs = null;

  if (notifyPeer) {
    send(peer.ws, {
      type: 'leave',
      message: client.isHost
        ? 'Le host a quitté la session.'
        : 'Le joueur a quitté la session.',
    });
  }

  if (peer.isHost) {
    const restoredHostId = activateHostMode(peer, peer.ownedHostId);
    send(peer.ws, { type: 'host_ready', hostId: restoredHostId });
  }
}

function activateHostMode(client, preferredHostId) {
  client.isHost = true;

  removeHostFromList(client);

  const picked = pickHostId(preferredHostId);
  client.ownedHostId = picked;
  client.waitingHostId = picked;
  hostsById.set(picked, client);

  broadcastHostsList();
  return picked;
}

function removeHostFromList(client) {
  const waitingHostId = client.waitingHostId;
  if (!waitingHostId) {
    return;
  }

  const mapped = hostsById.get(waitingHostId);
  if (mapped === client) {
    hostsById.delete(waitingHostId);
    broadcastHostsList();
  }
  client.waitingHostId = null;
}

function pickHostId(preferredHostId) {
  const preferred = String(preferredHostId || '').trim();
  if (preferred && !hostsById.has(preferred)) {
    return preferred;
  }

  while (true) {
    const code = String(Math.floor(Math.random() * 900000) + 100000);
    if (!hostsById.has(code)) {
      return code;
    }
  }
}

function broadcastHostsList() {
  for (const ws of clients.keys()) {
    sendHostsList(ws);
  }
}

function sendHostsList(ws) {
  const hosts = Array.from(hostsById.entries())
    .map(([id, host]) => ({ id, name: host.displayName }))
    .sort((a, b) => a.name.localeCompare(b.name));

  send(ws, { type: 'hosts_list', hosts });
}

function send(ws, message) {
  if (ws.readyState !== WebSocket.OPEN) {
    return;
  }

  try {
    ws.send(JSON.stringify(message));
  } catch (_error) {
    // Ignore send failures; disconnect cleanup handles state.
  }
}

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Fanorona Express relay running on port ${PORT}`);
});
