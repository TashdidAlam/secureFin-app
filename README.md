# SecureFin App — Microservice Application

Simple but realistic fintech microservice with a Node.js/Express backend and static HTML+JS frontend.

## Architecture

```
securefin-app/
├── backend/
│   ├── package.json          # Express + cors
│   └── src/
│       └── index.js          # API server (port 8080)
├── frontend/
│   └── index.html            # Dashboard UI (calls /api)
├── Dockerfile                # Multi-stage: node:18-alpine → distroless
├── docker-compose.yml        # Local testing with Docker
├── .github/workflows/
│   └── build-scan-deploy.yml # CI pipeline: build → trivy → ACR → gitops
├── .dockerignore
├── .gitignore
└── README.md
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/healthz` | Kubernetes liveness/readiness probe |
| GET | `/api` | Service metadata (name, version, environment, region, timestamp) |
| GET | `/` | Frontend dashboard (static HTML) |

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Node.js | >= 18 | Backend runtime |
| Docker | >= 20 | Container build |
| Azure CLI | >= 2.50 | ACR login, AKS credentials |

## Local Development

### Option 1: Docker Compose (recommended — runs the exact production image)

```bash
docker compose up --build
# → http://localhost:8080       (frontend dashboard)
# → http://localhost:8080/api   (backend API)
# → http://localhost:8080/healthz
```

Stop: `docker compose down`

### Option 2: Node.js directly (faster hot-reload for development)

```bash
cd backend
npm install

# Create symlink for frontend static files
mkdir -p public
cp -r ../frontend/* public/

npm run dev        # starts with --watch (auto-restart on changes)
# → http://localhost:8080
```

### Option 3: Docker build/run manually

```bash
docker build -t securefin-app:local .
docker run -p 8080:8080 securefin-app:local
# → http://localhost:8080
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Server listen port |
| `NODE_ENV` | `development` | Environment name |
| `APP_VERSION` | `1.0.0` | Displayed in /api response |
| `AZURE_REGION` | `local` | Displayed in /api response |

## CI/CD Flow

```
Push to dev/staging/production
  → GitHub Actions builds Docker image
  → Pushes to ACR (acrsecurefin<env>)
  → Updates image tag in securefin-gitops repo
  → ArgoCD detects change and deploys to AKS
```

## Image Tagging

Tags use the format `<branch>-<shortSHA>` (e.g., `dev-a1b2c3d`).
`:latest` is never used — every image is uniquely traceable to a commit.