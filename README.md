# Campfire

Self-hosted team chat with integrated video conferencing, based on [Once Campfire](https://once.com/campfire) by 37signals.

## Features

### Messaging
- Real-time team chat with rooms (open, closed, direct messages)
- Rich text messages (ActionText) with file attachments
- **Threads** — reply in thread with sidebar panel
- **Pinned messages** — pin important messages with dropdown overlay
- @mentions with autocomplete
- Boosts / emoji reactions
- Typing indicators
- **Full-text search** with French stemming, unaccent support, and filename tokenization

### Video & Audio Calls
- Video and audio calls via **LiveKit** (self-hosted WebRTC)
- Background blur (client-side, GDPR-compliant)
- Screen sharing (HTTPS required)
- Teams-style call layout (participant grid + picture-in-picture)
- Chat sidebar during calls
- **Per-user ringtone selection** (11 built-in sounds)
- **Auto-leave** when last participant disconnects
- Call notifications via ActionCable + Turbo Streams

### Presence & Notifications
- **User status** — online (green), away (orange), in call (red), do not disturb (red bar), offline (grey)
- **Manual status override** — users choose their status in profile
- **Auto-detection** — in-call status detected from active call participants
- Status dots on avatars in sidebar, DMs, and profile
- **Mute per room** — toggle notifications per room
- Web Push notifications (VAPID)

### Internationalization
- **French and English** UI with per-user locale selector
- ~150 translated strings covering all views
- Configurable default locale via `DEFAULT_LOCALE` env var
- Fallback to English for missing translations

### Administration
- Account settings with custom logo and CSS
- User management (roles, ban/unban)
- Bot API with webhooks
- Room creation restriction (admin-only option)
- SSO via **OpenID Connect** (any OIDC provider)
- Session transfer via QR code (4h expiry, signed tokens)

### Security
- **Content Security Policy** with frame_ancestors, upgrade_insecure_requests
- **Rack Attack** — rate limiting (login, OTP, messages, search), brute force ban, dangerous path blocking
- **Permissions Policy** — camera/mic restricted to self
- Secure session cookies (httponly, same_site, secure in production)
- File upload validation (100MB max, executables blocked)
- OTP rate limiting (5 attempts / 3 min)
- CSRF protection, signed session tokens

### Self-Hosted & Sovereign
- No external dependencies (no Google, no AWS required)
- All data stays on your infrastructure
- Multi-instance CI/CD support (single workflow, per-instance secrets)
- S3-compatible object storage with per-app prefix (shared bucket)
- Docker deployment with Gitea Actions

## Stack

- **Ruby on Rails 8.2** (edge) with PostgreSQL
- **LiveKit** for WebRTC video/audio conferencing
- **Redis** for ActionCable, cache, and Resque job queue
- **Bun** for JavaScript bundling (minified in production, -40% bundle size)
- **Hotwire** (Turbo + Stimulus) for real-time UI
- **Propshaft** for asset pipeline
- **Rack Attack** for rate limiting and security

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

Open http://localhost:3000. On first run, create an admin account.

## Production Deployment

### Architecture

```
Browser --HTTPS--> Caddy (TLS) --> Campfire (Rails, port 3000)
                                   |- PostgreSQL
                                   |- Redis
                                   '- Resque worker

Browser --WSS----> Caddy (TLS) --> LiveKit Server (port 7880)
                   (Visio VPS)     '- WebRTC media (UDP 50000-50060)
```

### CI/CD

Deployed via Gitea Actions on push to `main`. The workflow supports multiple instances with per-instance secrets:

| Mode | Description |
|------|-------------|
| `DEPLOY_MODE=local` | Build and deploy on the same server (runner = host) |
| `DEPLOY_MODE=remote` | Build locally, push to registry, deploy via SSH |

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `RAILS_MASTER_KEY` | Decrypts `credentials.yml.enc` | Yes |
| `DATABASE_URL` | PostgreSQL connection string | Yes |
| `REDIS_URL` | Redis URL for ActionCable, cache, Resque | Yes |
| `LIVEKIT_URL` | LiveKit WebSocket URL (`wss://...`) | For calls |
| `LIVEKIT_API_KEY` | LiveKit API key | For calls |
| `LIVEKIT_API_SECRET` | LiveKit API secret | For calls |
| `DISABLE_SSL` | `true` when behind TLS-terminating proxy | Recommended |
| `VAPID_PUBLIC_KEY` | Web Push public key | For push |
| `VAPID_PRIVATE_KEY` | Web Push private key | For push |
| `APP_NAME` | Instance name (default: "Campfire") | No |
| `DEFAULT_LOCALE` | Default locale: `en` or `fr` | No |
| `S3_ACCESS_KEY_ID` | S3 access key (falls back to local storage) | No |
| `S3_SECRET_ACCESS_KEY` | S3 secret key | No |
| `S3_BUCKET` | S3 bucket name | No |
| `S3_REGION` | S3 region | No |
| `S3_ENDPOINT` | S3 endpoint URL | No |
| `S3_KEY_PREFIX` | S3 key prefix (default: "campfire") | No |
| `OIDC_ISSUER_URL` | OIDC provider URL (e.g. realm endpoint) | For SSO |
| `OIDC_CLIENT_ID` | OIDC client ID | For SSO |
| `OIDC_CLIENT_SECRET` | OIDC client secret | For SSO |
| `OIDC_REDIRECT_URI` | OIDC callback URL | For SSO |
| `SMTP_HOST` | SMTP server for emails | For email |
| `SMTP_PORT` | SMTP port | For email |
| `SMTP_USERNAME` | SMTP username | For email |
| `SMTP_PASSWORD` | SMTP password | For email |
| `SMTP_DOMAIN` | SMTP domain | For email |
| `MAILER_FROM` | From address for emails | For email |

### LiveKit Server

```bash
docker run -d \
  --name livekit \
  --restart unless-stopped \
  -p 7880:7880 -p 7881:7881 -p 50000-50060:50000-50060/udp \
  -v /opt/livekit/config.yaml:/etc/livekit.yaml:ro \
  livekit/livekit-server:latest \
  --config /etc/livekit.yaml \
  --node-ip=YOUR_SERVER_IP
```

Example `config.yaml`:

```yaml
port: 7880
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 50060
  use_external_ip: true
keys:
  your_api_key: your_api_secret
```

Caddy reverse proxy:

```caddy
livekit.your-domain.com {
    reverse_proxy localhost:7880
}
```

Required firewall ports: TCP 7880-7881, UDP 50000-50060.

## Worth Noting

Campfire is single-tenant by design. Rooms can be **open** (all users) or **closed** (invite-only with selected members). Admins can restrict room creation to administrators only. For fully separate organizations, deploy multiple instances.

## License

See [Once License](https://once.com/license).
