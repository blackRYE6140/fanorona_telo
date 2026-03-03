# Fanorona Relay (Express + WebSocket)

Serveur relay temps réel pour le mode internet (`Inviter amis` / `Rejoindre amis`).

## Local

```bash
cp .env.example .env
npm install
npm start
```

Par défaut, le serveur démarre sur `http://0.0.0.0:8080`.

## Render

### Option 1: Blueprint (`render.yaml`)

1. Pousse ce repo sur GitHub.
2. Dans Render: `New` -> `Blueprint` -> sélectionne le repo.
3. Render lit `render.yaml` à la racine du repo.

### Option 2: Web Service manuel

- Root Directory: `backend/relay-express`
- Build Command: `npm install`
- Start Command: `npm start`
- Environment variables:
  - `NODE_ENV=production`
  - `PORT` est fourni automatiquement par Render

URL finale: `https://<service>.onrender.com`

Côté Flutter, mets:

```env
FANORONA_RELAY_URL=wss://<service>.onrender.com
```

## Protocole WebSocket supporté

- `host_announce`
- `discover_hosts`
- `join_host`
- relay des messages de jeu (`start`, `state`, `leave`, etc.)

Compatibilité legacy conservée:

- `host_create` -> `host_announce`
- `join_room` -> `join_host`
