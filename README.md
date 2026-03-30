# Campfire

Self-hosted team chat with integrated video conferencing, based on [Once Campfire](https://once.com/campfire) by 37signals.

## Features

- Real-time team chat with rooms (open, closed, direct messages)
- Video and audio calls via LiveKit (self-hosted WebRTC)
- Background blur (client-side, GDPR-compliant)
- Teams-style call layout (participant grid + picture-in-picture)
- Call notifications via ActionCable + Turbo Streams
- Rich text messages with file attachments
- Typing indicators and presence tracking
- Full-text search (PostgreSQL tsvector)
- @mentions, boosts, Web Push notifications
- Bot API integrations

## Stack

- **Ruby on Rails 8.2** (edge) with PostgreSQL
- **LiveKit** for WebRTC video/audio conferencing
- **Redis** for ActionCable, cache, and Resque job queue
- **Bun** for JavaScript bundling
- **Hotwire** (Turbo + Stimulus) for real-time UI
- **Propshaft** for asset pipeline

## Local Development

### Prerequisites

- Ruby 3.4.8 (via rbenv)
- PostgreSQL
- Redis
- [Bun](https://bun.sh/)
- [LiveKit server](https://docs.livekit.io/home/self-hosting/local/) (`brew install livekit`)
- [Overmind](https://github.com/DarthSim/overmind) (`brew install overmind`)

### Setup

```bash
bundle install
bun install
bin/rails db:create db:migrate
```

### Configuration

Create a `.env` file at the root:

```env
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=secret
LIVEKIT_URL=ws://localhost:7880
```

For a remote LiveKit server:

```env
LIVEKIT_API_KEY=your_api_key
LIVEKIT_API_SECRET=your_api_secret
LIVEKIT_URL=wss://livekit.your-domain.com
```

### Run

```bash
bin/dev
```

Starts all services via Overmind:

| Service | Description |
|---------|-------------|
| **web** | Rails server (Puma + Thruster) |
| **redis** | Redis server |
| **workers** | Resque job workers |
| **js** | Bun JS watcher/builder |
| **livekit** | LiveKit dev server (uncomment in Procfile) |

Open http://localhost:3000. On first run, create an admin account.

## Production Deployment

### Architecture

```
Browser ──HTTPS──▶ Caddy (TLS) ──▶ Campfire (Rails, port 3000)
                                    ├── PostgreSQL
                                    └── Redis
Browser ──WSS────▶ Caddy (TLS) ──▶ LiveKit Server (port 7880)
                   (Visio VPS)      └── WebRTC media (UDP)
```

### CI/CD

Deployed via Gitea Actions on push to `main`:

1. Build Docker image
2. Push to Gitea container registry
3. Deploy to VPS via SSH
4. `bin/start-app` runs `db:prepare` + `rails server`

### Environment Variables

| Variable | Description |
|----------|-------------|
| `RAILS_MASTER_KEY` | Decrypts `credentials.yml.enc` |
| `DATABASE_URL` | PostgreSQL connection string |
| `REDIS_URL` | Redis URL for ActionCable, cache, Resque |
| `LIVEKIT_URL` | LiveKit WebSocket URL (`wss://...`) |
| `LIVEKIT_API_KEY` | LiveKit API key |
| `LIVEKIT_API_SECRET` | LiveKit API secret |
| `DISABLE_SSL` | `true` when behind TLS-terminating proxy |
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` | Web Push notifications keypair |
| `SENTRY_DSN` | Error reporting (optional) |

### LiveKit Server

```bash
docker run -d \
  --name livekit \
  --restart unless-stopped \
  --network host \
  -v /opt/livekit/config.yaml:/etc/livekit.yaml:ro \
  livekit/livekit-server:latest \
  --config /etc/livekit.yaml
```

Example `config.yaml`:

```yaml
port: 7880
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 50100
  use_external_ip: true
keys:
  your_api_key: your_api_secret
logging:
  level: info
```

Caddy block:

```caddy
livekit.your-domain.com {
    reverse_proxy localhost:7880
}
```

Required firewall ports: TCP 7880-7881, UDP 50000-50100.

## Worth Noting

Campfire is single-tenant: any rooms designated "public" are accessible by all users. For distinct groups, deploy multiple instances.

## License

See [Once License](https://once.com/license).
