import { Router } from "express";
import { registro, login, perfil } from "../controllers/auth.controllers";
import { verificarToken } from "../middlewares/auth.middleware";

const router = Router();

/**
 * @swagger
 * tags:
 *   name: Autenticación
 *   description: Endpoints para registro, login y perfil
 */

/**
 * @swagger
 * /api/auth/registro:
 *   post:
 *     summary: Registrar un nuevo usuario
 *     tags: [Autenticación]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - nombre
 *               - email
 *               - contrasena
 *               - tipo_usuario
 *             properties:
 *               nombre:
 *                 type: string
 *                 example: Juan Pérez
 *               email:
 *                 type: string
 *                 example: juan@test.com
 *               contrasena:
 *                 type: string
 *                 example: "123456"
 *               telefono:
 *                 type: string
 *                 example: "3001234567"
 *               direccion:
 *                 type: string
 *                 example: "Calle 123"
 *               tipo_usuario:
 *                 type: string
 *                 enum: [productor, empresa, transportista]
 *                 example: productor
 *     responses:
 *       201:
 *         description: Usuario registrado exitosamente
 *       400:
 *         description: Faltan campos obligatorios
 *       409:
 *         description: El email ya está registrado
 */
router.post("/registro", registro);

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Iniciar sesión
 *     tags: [Autenticación]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - contrasena
 *             properties:
 *               email:
 *                 type: string
 *                 example: juan@test.com
 *               contrasena:
 *                 type: string
 *                 example: "123456"
 *     responses:
 *       200:
 *         description: Inicio de sesión exitoso, devuelve token JWT
 *       401:
 *         description: Credenciales inválidas
 *       403:
 *         description: Cuenta suspendida o inactiva
 */
router.post("/login", login);

/**
 * @swagger
 * /api/auth/perfil:
 *   get:
 *     summary: Obtener perfil del usuario autenticado
 *     tags: [Autenticación]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Perfil del usuario
 *       401:
 *         description: Token no proporcionado o inválido
 */
router.get("/perfil", verificarToken, perfil);

export default router;