import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import authRoutes from "./routes/auth.routes";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// ── Middlewares globales ───────────────────────────────────
app.use(cors());
app.use(express.json());

// ── Rutas ─────────────────────────────────────────────────
app.use("/api/auth", authRoutes);

// ── Health check ──────────────────────────────────────────
app.get("/", (_, res) => {
  res.json({ mensaje: "Nexa Agro API corriendo 🌱" });
});

// ── Arrancar servidor ─────────────────────────────────────
app.listen(PORT, () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});