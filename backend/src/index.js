const express = require("express");
const cors = require("cors");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 8080;

app.use(cors());
app.use(express.json());

// -------------------------------------------------------
// Serve frontend static files (in production the Docker
// image copies frontend/ into /app/public/)
// -------------------------------------------------------
const publicDir = path.join(__dirname, "..", "public");
app.use(express.static(publicDir));

// -------------------------------------------------------
// GET /healthz — Kubernetes liveness & readiness probes
// -------------------------------------------------------
app.get("/healthz", (_req, res) => {
  res.status(200).json({
    status: "healthy",
    timestamp: new Date().toISOString(),
  });
});

// -------------------------------------------------------
// GET /api — Service metadata (consumed by the frontend)
// -------------------------------------------------------
app.get("/api", (_req, res) => {
  res.json({
    service: "securefin-app",
    version: process.env.APP_VERSION || "1.0.0",
    environment: process.env.NODE_ENV || "development",
    region: process.env.AZURE_REGION || "local",
    timestamp: new Date().toISOString(),
  });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`securefin-backend listening on port ${PORT}`);
});
