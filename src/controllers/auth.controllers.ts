import { Request, Response } from "express";
import * as authService from "../services/auth.service";
import { AuthRequest } from "../middlewares/auth.middleware";

/**
 * POST /api/auth/registro
 * Body: { nombre, email, contrasena, telefono?, direccion?, tipo_usuario }
 */
export const registro = async (req: Request, res: Response): Promise<void> => {
  try {
    const { nombre, email, contrasena, telefono, direccion, tipo_usuario } =
      req.body;

    // Validaciones básicas
    if (!nombre || !email || !contrasena || !tipo_usuario) {
      res.status(400).json({ mensaje: "Faltan campos obligatorios: nombre, email, contrasena, tipo_usuario" });
      return;
    }

    if (!["productor", "empresa", "transportista"].includes(tipo_usuario)) {
      res.status(400).json({ mensaje: "tipo_usuario debe ser: productor, empresa o transportista" });
      return;
    }

    if (contrasena.length < 6) {
      res.status(400).json({ mensaje: "La contraseña debe tener mínimo 6 caracteres" });
      return;
    }

    const resultado = await authService.registrarUsuario({
      nombre,
      email,
      contrasena,
      telefono,
      direccion,
      tipo_usuario,
    });

    res.status(201).json({
      mensaje: "Usuario registrado exitosamente",
      ...resultado,
    });
  } catch (error: any) {
    if (error.message === "El email ya está registrado") {
      res.status(409).json({ mensaje: error.message });
      return;
    }
    res.status(500).json({ mensaje: "Error interno del servidor", detalle: error.message });
  }
};

/**
 * POST /api/auth/login
 * Body: { email, contrasena }
 */
export const login = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, contrasena } = req.body;

    if (!email || !contrasena) {
      res.status(400).json({ mensaje: "Email y contraseña son obligatorios" });
      return;
    }

    const resultado = await authService.loginUsuario({ email, contrasena });

    res.status(200).json({
      mensaje: "Inicio de sesión exitoso",
      ...resultado,
    });
  } catch (error: any) {
    if (error.message === "Credenciales inválidas") {
      res.status(401).json({ mensaje: error.message });
      return;
    }
    if (error.message === "Tu cuenta está suspendida o inactiva") {
      res.status(403).json({ mensaje: error.message });
      return;
    }
    res.status(500).json({ mensaje: "Error interno del servidor", detalle: error.message });
  }
};

/**
 * GET /api/auth/perfil
 * Header: Authorization: Bearer <token>
 */
export const perfil = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.usuario) {
      res.status(401).json({ mensaje: "No autenticado" });
      return;
    }

    const usuario = await authService.obtenerPerfil(req.usuario.id);

    res.status(200).json({ usuario });
  } catch (error: any) {
    res.status(500).json({ mensaje: "Error interno del servidor", detalle: error.message });
  }
};