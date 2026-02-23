import { Router } from "express";
import { registro, login, perfil } from "../controllers/auth.controllers";
import { verificarToken } from "../middlewares/auth.middleware";

const router = Router();

// Rutas públicas
router.post("/registro", registro);
router.post("/login", login);

// Rutas protegidas (requieren token)
router.get("/perfil", verificarToken, perfil);

export default router;